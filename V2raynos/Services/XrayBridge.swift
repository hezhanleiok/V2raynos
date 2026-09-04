import Foundation

/// 封装「gomobile bind -target=ios -o XrayCore.xcframework」编译出的 Xray 内核调用。
/// ⚠️ 依赖名(import)、类名、方法名以 `gomobile bind` 实际输出的头文件为准，
///    若与本文件不一致，只需改这一个文件。
import XrayCore   // 框架模块名 = gomobile bind 的 -o 基名(XrayCore)；类名前缀 Libv2ray 来自 Go 包名 libv2ray

final class XrayBridge {
    private var controller: Libv2rayCoreController?
    // 记录状态回调（对应 Go 接口 CoreCallbackHandler）
    private var handler: Libv2rayCoreCallbackHandlerProtocol?

    func setup(envPath: String, key: String) {
        // iOS 内存加固（见 PacketTunnelProvider.startTunnel 注释）：Jetsam 红线防静默强杀。
        // 放在进 Go runtime 的最前面；overwrite=1 确保覆盖任何旧值。
        setenv("GOGC", "30", 1)
        setenv("GOMEMLIMIT", "10485760", 1)
        Libv2rayInitCoreEnv(envPath, key)
    }

    func start(configJSON: String, tunFd: Int32) throws {
        let h = MyCallbackHandler()
        handler = h
        guard let c = Libv2rayNewCoreController(h) else {
            throw NSError(domain: "v2raynos", code: 1, userInfo: [NSLocalizedDescriptionKey: "create controller failed"])
        }
        controller = c
        try c.startLoop(configJSON, tunFd: tunFd)
    }

    func stop() {
        try? controller?.stopLoop()
        controller = nil
    }

    func version() -> String {
        (controller != nil) ? Libv2rayCheckVersionX() : "not started"
    }
}

/// 实现 Go 接口 CoreCallbackHandler 的回调
final class MyCallbackHandler: NSObject, Libv2rayCoreCallbackHandlerProtocol {
    func startup() -> Int { return 0 }
    func shutdown() -> Int { return 0 }
    func onEmitStatus(_ level: Int, p1: String?) -> Int {
        if let m = p1 { print("[xray] \(m)") }
        return 0
    }
}