import Foundation

enum ConnectionProtocol: String, Codable, CaseIterable, Identifiable {
    case vless, vmess, trojan, shadowsocks, socks, http, hysteria2, wireguard
    var id: String { rawValue }
    var display: String {
        switch self {
        case .vless: return "VLESS"
        case .vmess: return "VMess"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .socks: return "Socks"
        case .http: return "HTTP"
        case .hysteria2: return "Hysteria2"
        case .wireguard: return "WireGuard"
        }
    }
}

/// 一个可用的代理节点，对应 v2rayNG 的 ServerConfig / ConfigBean
struct ServerProfile: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var groupID: String
    var name: String
    var protocolType: ConnectionProtocol
    var address: String
    var port: Int
    var uuid: String        // vmess / vless
    var password: String    // trojan / ss
    var cipher: String      // ss / hysteria2
    var sni: String         // tls serverName
    var network: String     // tcp / ws / grpc / quic
    var path: String        // ws/grpc path
    var alpn: String
    var flow: String        // xtls flow
    var publicKey: String   // wireguard / reality
    var settingsJson: String // 自定义高级 JSON
    var remark: String
    var raw: String         // 原始 URI（导入时保留）
    // 链式代理（v2rayNG 订阅链）：前置/落地代理配置别名
    var prevProfile: String? = nil
    var nextProfile: String? = nil
}
