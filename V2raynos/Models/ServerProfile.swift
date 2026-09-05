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
    var fingerPrint: String = "" // uTLS 伪装指纹（chrome/ios/…）
    var shortId: String = ""     // REALITY shortId
    var spiderX: String = ""     // REALITY spiderX
    var settingsJson: String // 自定义高级 JSON
    var remark: String
    var raw: String         // 原始 URI（导入时保留）
    // 链式代理（v2rayNG 订阅链）：前置/落地代理配置别名
    var prevProfile: String? = nil
    var nextProfile: String? = nil

    // Codable 兜底：Swift 合成解码器不用属性默认值，旧版/缺字段的 JSON 会 keyNotFound 抛错。
    // 全字段 decodeIfPresent + 默认值，旧备份（REALITY 字段加入前）也能无损导入。
    enum CodingKeys: String, CodingKey {
        case id, groupID, name, protocolType, address, port, uuid, password, cipher
        case sni, network, path, alpn, flow, publicKey, fingerPrint, shortId, spiderX
        case settingsJson, remark, raw, prevProfile, nextProfile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID) ?? ""
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        protocolType = try c.decodeIfPresent(ConnectionProtocol.self, forKey: .protocolType) ?? .vless
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? 443
        uuid = try c.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
        cipher = try c.decodeIfPresent(String.self, forKey: .cipher) ?? ""
        sni = try c.decodeIfPresent(String.self, forKey: .sni) ?? ""
        network = try c.decodeIfPresent(String.self, forKey: .network) ?? "tcp"
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        alpn = try c.decodeIfPresent(String.self, forKey: .alpn) ?? ""
        flow = try c.decodeIfPresent(String.self, forKey: .flow) ?? ""
        publicKey = try c.decodeIfPresent(String.self, forKey: .publicKey) ?? ""
        fingerPrint = try c.decodeIfPresent(String.self, forKey: .fingerPrint) ?? ""
        shortId = try c.decodeIfPresent(String.self, forKey: .shortId) ?? ""
        spiderX = try c.decodeIfPresent(String.self, forKey: .spiderX) ?? ""
        settingsJson = try c.decodeIfPresent(String.self, forKey: .settingsJson) ?? ""
        remark = try c.decodeIfPresent(String.self, forKey: .remark) ?? ""
        raw = try c.decodeIfPresent(String.self, forKey: .raw) ?? ""
        prevProfile = try c.decodeIfPresent(String.self, forKey: .prevProfile)
        nextProfile = try c.decodeIfPresent(String.self, forKey: .nextProfile)
    }
}
