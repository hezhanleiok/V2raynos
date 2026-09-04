import Foundation
import Network

/// 真实链接延迟测试（v2rayNG 同款）：本地临时起 Xray socks 入站，经代理实测 generate_204。
/// 失败自动回退 TCP 握手延迟。
final class LatencyTester: ObservableObject {
    @Published var results: [String: Int] = [:]   // guid -> ms；-1 = 失败
    @Published var testing = false

    private var testURLString: String { AppSettings.load().realPingURL }
    private let timeout: TimeInterval = 8
    private var concurrency: Int { AppSettings.load().realPingConcurrent }

    /// TCPing：纯 TCP 握手延迟（不经代理），v2rayNG「测试 TCP 延迟」同款。
    /// 并发控制：sem.wait() 在 async 外部阻塞，任意多的节点也只占 16 个线程。
    func tcpPingAll(_ servers: [ServerProfile]) {
        guard !testing, !servers.isEmpty else { return }
        testing = true
        results = [:]
        let group = DispatchGroup()
        let sem = DispatchSemaphore(value: 16)
        DispatchQueue.global().async {
            for s in servers {
                group.enter()
                sem.wait() // 在派发外部阻塞：不向 GCD 请求多余线程，防线程爆炸
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

    /// 真连接延迟（经代理访问测试 URL）。
    /// 同样外部 wait：并发上限 = 设置的 realPingConcurrent。
    func testAll(_ servers: [ServerProfile]) {
        guard !testing, !servers.isEmpty else { return }
        testing = true
        results = [:]
        let group = DispatchGroup()
        let sem = DispatchSemaphore(value: concurrency)
        DispatchQueue.global().async {
            for s in servers {
                group.enter()
                sem.wait() // 在派发外部阻塞：任意节点数只占 concurrency 个线程
                DispatchQueue.global().async {
                    self.testOne(s) { ms in
                        DispatchQueue.main.async { self.results[s.id] = ms }
                        sem.signal()
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) { self.testing = false }
        }
    }

    /// 经临时代理实测 generate_204
    private func testOne(_ s: ServerProfile, completion: @escaping (Int) -> Void) {
        let port = 20000 + Int.random(in: 0...20000)
        let cfg = ConfigGenerator.latencyJSON(profile: s, httpPort: port)
        if cfg == "{}" { tcpPing(s, completion: completion); return }
        let bridge = XrayBridge()
        bridge.setup(envPath: NSTemporaryDirectory(), key: "latency")
        do { try bridge.start(configJSON: cfg, tunFd: 0) } catch { tcpPing(s, completion: completion); return }

        let cfgObj = URLSessionConfiguration.ephemeral
        cfgObj.timeoutIntervalForRequest = timeout
        cfgObj.timeoutIntervalForResource = timeout
        cfgObj.requestCachePolicy = .reloadIgnoringLocalCacheData
        // iOS URLSession 不支持 SOCKS，用 http 入站 + HTTP 代理字典（字符串键在 iOS 有效）
        let proxyDict: [AnyHashable: Any] = [
            "HTTPEnable": 1,
            "HTTPProxy": "127.0.0.1",
            "HTTPPort": port,
            "HTTPSEnable": 1,
            "HTTPSProxy": "127.0.0.1",
            "HTTPSPort": port,
        ]
        cfgObj.connectionProxyDictionary = proxyDict
        let session = URLSession(configuration: cfgObj)
        guard let url = URL(string: testURLString) else { bridge.stop(); completion(-1); return }

        let start = Date()
        var finished = false
        let finish: (Int) -> Void = { ms in
            if finished { return }
            finished = true
            bridge.stop()
            completion(ms)
        }
        let task = session.dataTask(with: url) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                finish(Int(Date().timeIntervalSince(start) * 1000))
            } else {
                finish(-1)
            }
        }
        // 给 Xray 一点启动时间
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) { task.resume() }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 1) { finish(-1) }
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
