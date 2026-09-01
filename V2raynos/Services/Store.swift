import Foundation
import Combine

/// 简易持久化：把 servers/groups/subscriptions 以 JSON 存进 Documents
/// 对应 v2rayNG 的 MmkvManager / SettingsManager
class Store: ObservableObject {
    @Published var groups: [ServerGroup] = []
    @Published var servers: [ServerProfile] = []
    @Published var subscriptions: [Subscription] = []
    @Published var currentServerID: String? = nil

    private let fileManager = FileManager.default
    private var dir: URL { fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private func file(_ name: String) -> URL { dir.appendingPathComponent(name) }

    init() { load() }

    // --- 分组 ---
    func addGroup(_ name: String, subscriptionID: String? = nil) {
        let g = ServerGroup(name: name, subscriptionID: subscriptionID)
        groups.append(g); saveGroups()
    }
    func removeGroup(_ g: ServerGroup) {
        groups.removeAll { $0.id == g.id }
        servers.removeAll { $0.groupID == g.id }
        saveGroups(); saveServers()
    }
    func currentGroupID() -> String { (currentServerID.flatMap { id in servers.first { $0.id == id }?.groupID }) ?? groups.first?.id ?? "" }

    // --- 服务器 ---
    func addServer(_ p: ServerProfile) { servers.append(p); saveServers() }
    func updateServer(_ p: ServerProfile) {
        if let i = servers.firstIndex(where: { $0.id == p.id }) { servers[i] = p; saveServers() }
    }
    func removeServer(_ p: ServerProfile) { servers.removeAll { $0.id == p.id }; saveServers() }
    func currentServer() -> ServerProfile? { servers.first { $0.id == currentServerID } }
    func servers(inGroup gid: String) -> [ServerProfile] { servers.filter { $0.groupID == gid } }

    // --- 订阅 ---
    func addSubscription(_ s: Subscription) { subscriptions.append(s); saveSubscriptions() }
    func updateSubscriptions(from url: String) { updateSubscription(url: url) }

    func updateAllSubscriptions() { for s in subscriptions { updateSubscription(url: s.url) } }

    /// 批量解析订阅/文本中的链接并加入指定分组
    func importLinks(_ text: String, into groupID: String?) {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 订阅全文常是 base64 编码
        if body.range(of: "://") == nil, let dec = Self.b64decode(body) { body = dec }
        let links = body.split { $0.isNewline }.map { String($0).trimmingCharacters(in: .whitespaces) }.filter { $0.contains("://") }
        let gid = groupID ?? currentGroupID()
        var added = 0
        for link in links {
            if let p = try? ProfileParser.parse(link, groupID: gid) { servers.append(p); added += 1 }
        }
        if added > 0 { saveServers() }
    }

    private func updateSubscription(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: trimmed) else { return }
        URLSession.shared.dataTask(with: u) { data, _, _ in
            guard let data = data, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let gid = self.subscriptions.first { $0.url == trimmed }?.groupID ?? self.currentGroupID()
                self.importLinks(text, into: gid)
                if let i = self.subscriptions.firstIndex(where: { $0.url == trimmed }) {
                    self.subscriptions[i].lastUpdated = Date()
                    self.saveSubscriptions()
                }
            }
        }.resume()
    }

    private static func b64decode(_ s: String) -> String? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    // --- 持久化 ---
    private func load() {
        groups = loadArray("groups") ?? []
        servers = loadArray("servers") ?? []
        subscriptions = loadArray("subscriptions") ?? []
        currentServerID = try? String(contentsOf: file("current"), encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        if groups.isEmpty { groups = [ServerGroup(name: "默认")]; saveGroups() }
    }
    private func loadArray<T: Codable>(_ name: String) -> [T]? {
        guard let d = try? Data(contentsOf: file(name)) else { return nil }
        return try? JSONDecoder().decode([T].self, from: d)
    }
    private func save<T: Encodable>(_ v: T, _ name: String) {
        if let d = try? JSONEncoder().encode(v) { try? d.write(to: file(name), options: .atomic) }
    }
    private func saveGroups() { save(groups, "groups") }
    private func saveServers() { save(servers, "servers") }
    private func saveSubscriptions() { save(subscriptions, "subscriptions") }
    private func setCurrent(_ id: String?) { currentServerID = id; try? (id ?? "").write(to: file("current"), atomically: true, encoding: .utf8) }
}