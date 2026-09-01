import Foundation

struct ServerGroup: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var sort: Int = 0
    var subscriptionID: String? = nil   // 订阅所属分组
    // 可扩展：路由规则 / DNS 绑定到分组
    var routingJSON: String = ""
}
