import Foundation
import Network

/// 延迟测试（v2rayNG 同款思路）：
/// - TCPing：纯 TCP 握手，高并发，无内核参与
/// - 真连接：所有节点打包成一个多 Inbound/多 Outbound 的单个 Xray 配置，
///   单次拉起内核，inboundTag -> outboundTag 一对一路由，URLSession 全并发测试。
/// 彻底修复：
/// 1. 每次循环独立实例化 URLSessionConfiguration——它是 Class（引用类型），
///    共享 baseCfg 会让最后一个节点的代理端口覆盖所有节点，测速结果串号。
/// 2. NSLock + finished 双保险超时：任何请求异常不回调时强制 leave，
///    DispatchGroup 计数绝不失衡，测速状态永不卡死。
final class LatencyTester: ObservableObject {
    @Published var results: [String: Int] = [:]   // guid -> ms；-1 = 失败
    @Published var testing = false

    private var testURLString: String { AppSettings.load().realPingURL }
    private let timeout: TimeInterval = 8
    private var activeBridge: XrayBridge? = nil

    /// TCPing：纯 TCP 握手延迟（不经代理、不起内核），可高并发
    func tcpPingAll(_ servers: [ServerProfile]) {
        guard !testing, !servers.isEmpty else { return }
        testing = true
        results = [:]
        let group = DispatchGroup()
        let sem = DispatchSemaphore(value: 16) // TCPing 无内核参与，可以高并发
        DispatchQueue.global().async {
            for s in servers {
                group.enter()
                sem.wait() // 派发外部阻塞：任意节点数只占 16 个线程，防线程爆炸
                DispatchQueue.global().async {
                    self.tcpPing(s) { ms in
                        DispatchQueue.main.async { self.results[s.id] = ms }
                        sem.signal()
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) { self.testing = false }
        }
    }

    /// 真连接延迟：聚合配置 + 单内核 + 全并发（v2rayNG 方案）
    func testAll(_ servers: [ServerProfile]) {
        guard !testing, !servers.isEmpty else { return }
        testing = true
        results = [:]

        var inbounds: [[String: Any]] = []
        var outbounds: [[String: Any]] = []
        var portMap: [String: Int] = [:]

        // 随机起始端口段：连续两次测速之间旧内核可能尚未完全释放端口，固定段会冲突
        var currentPort = Int.random(in: 21000...35000)

        for s in servers {
            currentPort += 1
            portMap[s.id] = currentPort
            inbounds.append([
                "listen": "127.0.0.1", "port": currentPort, "protocol": "http",
                "tag": "in-\(s.id)", "settings": ["allowTransparent": false]
            ])
            var ob = ConfigGenerator.outboundDict(s)
            ob["tag"] = "out-\(s.id)"
            outbounds.append(ob)
        }
        outbounds.append(["protocol": "freedom", "tag": "direct"])
        outbounds.append(["protocol": "blackhole", "tag": "block"])

        let routingRules: [[String: Any]] = servers.map {
            ["type": "field", "inboundTag": ["in-\($0.id)"], "outboundTag": "out-\($0.id)"]
        }

        let config: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": inbounds,
            "outbounds": outbounds,
            "routing": ["rules": routingRules],
        ]

        guard let configData = try? JSONSerialization.data(withJSONObject: config),
              let configJSON = String(data: configData, encoding: .utf8) else {
            self.testing = false
            return
        }

        // 单次拉起内核：activeBridge 强持有，结束后 stop 释放端口
        let bridge = XrayBridge()
        self.activeBridge = bridge
        bridge.setup(envPath: SharedGroup.dir.path, key: "latency_all")
        do {
            try bridge.start(configJSON: configJSON, tunFd: 0)
        } catch {
            self.activeBridge = nil
            self.testing = false
            return
        }

        let group = DispatchGroup()

        for s in servers {
            group.enter()
            let port = portMap[s.id]!

            // 【关键修复 1】每次循环独立创建 URLSessionConfiguration，防止引用共享导致端口串号
            let sessionCfg = URLSessionConfiguration.ephemeral
            sessionCfg.timeoutIntervalForRequest = timeout
            sessionCfg.timeoutIntervalForResource = timeout
            sessionCfg.requestCachePolicy = .reloadIgnoringLocalCacheData
            sessionCfg.connectionProxyDictionary = [
                "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": port,
                "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": port,
            ]
            let session = URLSession(configuration: sessionCfg)

            guard let url = URL(string: testURLString) else {
                group.leave()
                continue
            }

            let start = Date()
            var finished = false
            let lock = NSLock()

            let task = session.dataTask(with: url) { _, response, _ in
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true

                let ms: Int
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    ms = Int(Date().timeIntervalSince(start) * 1000)
                } else {
                    ms = -1
                }
                DispatchQueue.main.async { self.results[s.id] = ms }
                group.leave()
            }

            // 【关键修复 2】防死锁双保险超时，确保 group.leave 绝对能被调用
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { task.resume() }
            DispatchQueue.global().asyncAfter(deadline: .now() + self.timeout + 1.5) {
                lock.lock()
                defer { lock.unlock() }
                if !finished {
                    finished = true
                    DispatchQueue.main.async { self.results[s.id] = -1 }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.activeBridge?.stop()
            self.activeBridge = nil
            self.testing = false
        }
    }

    /// TCP 握手延迟（保底）
    private func tcpPing(_ s: ServerProfile, completion: @escaping (Int) -> Void) {
        guard let u16 = UInt16(exactly: s.port), let port = NWEndpoint.Port(rawValue: u16) else { completion(-1); return }
        let conn = NWConnection(host: NWEndpoint.Host(s.address), port: port, using: .tcp)
        let start = Date()
        let q = DispatchQueue(label: "latency.\(s.id)")
        var finished = false
        let finish: (Int) -> Void = { ms in
            q.async {
                if finished { return }
                finished = true
                conn.cancel()
                completion(ms)
            }
        }
        conn.stateUpdateHandler = { (st: NWConnection.State) in
            switch st {
            case .ready: finish(Int(Date().timeIntervalSince(start) * 1000))
            case .failed: finish(-1)
            default: break
            }
        }
        conn.start(queue: q)
        q.asyncAfter(deadline: .now() + .seconds(5)) { finish(-1) }
    }
}