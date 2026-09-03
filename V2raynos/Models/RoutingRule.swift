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

    // MARK: 持久化（Documents/routing_rules.json）
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("routing_rules.json")
    }

    static func load() -> [RoutingRule] {
        guard let data = try? Data(contentsOf: fileURL),
              let rules = try? JSONDecoder().decode([RoutingRule].self, from: data) else {
            return [RoutingRule(domain: "geosite:cn", outbound: "direct"),
                    RoutingRule(domain: "geosite:google", outbound: "proxy")]
        }
        return rules
    }

    static func save(_ rules: [RoutingRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
