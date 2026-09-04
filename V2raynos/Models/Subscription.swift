import Foundation

/// 订阅（对齐 v2rayNG SubscriptionItem）
struct Subscription: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var url: String
    var groupID: String
    var lastUpdated: Date = Date()
    var updateIntervalSeconds: Int = 0    // 0 = 关闭自动更新（分钟*60）

    // v2rayNG 高级字段
    var enabled: Bool = true               // 启用更新
    var autoUpdate: Bool = false           // 启用自动更新
    var prevProfile: String? = nil         // 前置代理配置别名
    var nextProfile: String? = nil         // 落地代理配置别名
    var filter: String? = nil              // 别名正则过滤
    var userAgent: String? = nil           // 自定义 UA
    var requestHeaders: String? = nil      // 请求头（JSON）

    enum CodingKeys: String, CodingKey {
        case id, name, url, groupID, lastUpdated, updateIntervalSeconds
        case enabled, autoUpdate, prevProfile, nextProfile, filter, userAgent, requestHeaders
    }

    init(name: String, url: String, groupID: String) {
        self.name = name; self.url = url; self.groupID = groupID
    }

    /// 旧数据兼容：旧 JSON 没有新字段时用默认值，解码不失败
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "订阅"
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        groupID = try c.decodeIfPresent(String.self, forKey: .groupID) ?? ""
        lastUpdated = try c.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        updateIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .updateIntervalSeconds) ?? 0
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        autoUpdate = try c.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? false
        prevProfile = try c.decodeIfPresent(String.self, forKey: .prevProfile)
        nextProfile = try c.decodeIfPresent(String.self, forKey: .nextProfile)
        filter = try c.decodeIfPresent(String.self, forKey: .filter)
        userAgent = try c.decodeIfPresent(String.self, forKey: .userAgent)
        requestHeaders = try c.decodeIfPresent(String.self, forKey: .requestHeaders)
    }
}