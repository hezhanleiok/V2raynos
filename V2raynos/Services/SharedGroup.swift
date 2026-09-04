import Foundation

/// 跨进程共享目录（App Groups）：App 与 PacketTunnel 扩展共同读写。
/// 存放 geosite.dat / geoip.dat / xray_error.log；无签名侧载时容器回退 App 沙盒 Documents。
struct SharedGroup {
    static let id = "group.com.v2raynos.app"
    static var dir: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}