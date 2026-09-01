import Foundation

struct Subscription: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var url: String
    var groupID: String
    var lastUpdated: Date = Date()
    var updateIntervalSeconds: Int = 0    // 0 = 关闭自动更新
}
