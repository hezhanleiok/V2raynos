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
        Libv2rayInitCoreEnv(envPath, key)
    }

    func start(configJSON: String, tunFd: Int32) throws {
        let h = MyCallbackHandler()
        handler = h
        let c = Libv2rayNewCoreController(h)
        controller = c
        try c.startLoop(configJSON, tunFd)
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
    func startup() -> Int32 { return 0 }
    func shutdown() -> Int32 { return 0 }
    func onEmitStatus(_ level: Int32, _ msg: String) -> Int32 {
        print("[xray] \(msg)")
        return 0
    }
}