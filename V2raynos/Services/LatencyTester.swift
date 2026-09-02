import Foundation
import Network

/// 真实链接延迟测试（v2rayNG 同款）：本地临时起 Xray socks 入站，经代理实测 generate_204。
/// 失败自动回退 TCP 握手延迟。
final class LatencyTester: ObservableObject {
    @Published var results: [String: Int] = [:]   // guid -> ms；-1 = 失败
    @Published var testing = false

    private let testURLString = "http://cp.cloudflare.com/generate_204?v2raynos=1"
    private let timeout: TimeInterval = 8
    private let concurrency = 3

    func testAll(_ servers: [ServerProfile]) {
        guard !testing, !servers.isEmpty else { return }
        testing = true
        results = [:]
        let group = DispatchGroup()
        let sem = DispatchSemaphore(value: concurrency)
        for s in servers {
            group.enter()
            DispatchQueue.global().async {
                sem.wait()
                self.testOne(s) { ms in
                    DispatchQueue.main.async { self.results[s.id] = ms }
                    sem.signal()
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) { self.testing = false }
    }

    /// 经临时代理实测 generate_204
    private func testOne(_ s: ServerProfile, completion: @escaping (Int) -> Void) {
        let port = 20000 + Int.random(in: 0...20000)
        let cfg = ConfigGenerator.xrayJSON(profile: s, localPort: port)
        if cfg == "{}" { tcpPing(s, completion); return }
        let bridge = XrayBridge()
        bridge.setup(envPath: NSTemporaryDirectory(), key: "latency")
        do { try bridge.start(configJSON: cfg, tunFd: 0) } catch { tcpPing(s, completion); return }

        let cfgObj = URLSessionConfiguration.ephemeral
        cfgObj.timeoutIntervalForRequest = timeout
        cfgObj.timeoutIntervalForResource = timeout
        cfgObj.requestCachePolicy = .reloadIgnoringLocalCacheData
        let proxyDict: [AnyHashable: Any] = [
            kCFProxyTypeKey as String: kCFProxyTypeSOCKSProxy as Any,
            kCFProxyHostNameKey as String: "127.0.0.1",
            kCFProxyPortNumberKey as String: port,
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
