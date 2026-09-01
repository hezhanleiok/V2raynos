import Foundation

enum RoutingPrefab: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case bypassLAN, proxyAll, global
    var display: String {
        switch self {
        case .bypassLAN: return "绕过局域网"
        case .proxyAll: return "全部走代理"
        case .global: return "全局"
        }
    }
}

struct RoutingRule: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var domain: String   // 或 geosite 标签
    var outbound: String // proxy / direct / block
    var enabled: Bool = true
}
