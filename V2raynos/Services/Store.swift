import Foundation
import Combine

/// 简易持久化：把 servers/groups/subscriptions 以 JSON 存进 Documents
/// 对应 v2rayNG 的 MmkvManager / SettingsManager
class Store: ObservableObject {
    @Published var groups: [ServerGroup] = []
    @Published var servers: [ServerProfile] = []
    @Published var subscriptions: [Subscription] = []
    @Published var currentServerID: String? = nil
    @Published var selectedGroupID: String? = nil
    @Published var lastSubscriptionError: String? = nil

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
    /// 添加订阅：自动创建同名分组，节点导入该分组
    func addSubscription(_ s: Subscription) {
        var sub = s
        let g = ServerGroup(name: sub.name.isEmpty ? "订阅" : sub.name, subscriptionID: nil)
        groups.append(g)
        sub.groupID = g.id
        subscriptions.append(sub)
        if let gi = groups.firstIndex(where: { $0.id == g.id }) { groups[gi].subscriptionID = sub.id }
        saveGroups(); saveSubscriptions()
    }
    /// 删除订阅：连同其分组与组内节点
    func removeSubscription(_ s: Subscription) {
        subscriptions.removeAll { $0.id == s.id }
        if let g = groups.first(where: { $0.subscriptionID == s.id }) { removeGroup(g) }
        saveSubscriptions()
    }
    func renameGroup(_ g: ServerGroup, to name: String) {
        if let i = groups.firstIndex(where: { $0.id == g.id }), !name.isEmpty { groups[i].name = name; saveGroups() }
    }
    /// 当前界面显示的分组
    func displayGroupID() -> String { selectedGroupID ?? groups.first?.id ?? "" }
    func updateSubscriptions(from url: String) { updateSubscription(url: url) }
    func updateAllSubscriptions() { for s in subscriptions { updateSubscription(url: s.url) } }

    /// 抓取单个订阅：显式 User-Agent，防机场面板拦截
    private func updateSubscription(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let u = URL(string: trimmed) else { lastSubscriptionError = "订阅 URL 无效"; return }
        var req = URLRequest(url: u)
        req.timeoutInterval = 20
        req.setValue("v2rayNG/1.8.5", forHTTPHeaderField: "User-Agent")
        req.setValue("text/plain, */*;q=0.8", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.lastSubscriptionError = "抓取失败：\(error.localizedDescription)" }
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                DispatchQueue.main.async { self.lastSubscriptionError = "服务器返回状态码 \(http.statusCode)" }
                return
            }
            var text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            // 清除 \r，统一换行符
            text = text.replacingOccurrences(of: "\r\n", with: "\n")
                       .replacingOccurrences(of: "\r", with: "\n")
            let finalText = text
            DispatchQueue.main.async {
                let gid = self.subscriptions.first { $0.url == trimmed }?.groupID ?? self.displayGroupID()
                // 刷新 = 先清空该订阅分组旧节点，避免重复堆积
                self.servers.removeAll { $0.groupID == gid }
                self.importLinks(finalText, into: gid)
                if let i = self.subscriptions.firstIndex(where: { $0.url == trimmed }) {
                    self.subscriptions[i].lastUpdated = Date()
                    self.saveSubscriptions()
                }
                // 当前选中失效则自动选中该分组第一个
                if self.currentServerID == nil || !self.servers.contains(where: { $0.id == self.currentServerID }) {
                    self.currentServerID = self.servers.first { $0.groupID == gid }?.id
                }
                if self.servers.isEmpty { self.lastSubscriptionError = "订阅内容未解析出任何节点" }
            }
        }.resume()
    }

    /// 批量解析订阅/文本中的链接并加入指定分组
    func importLinks(_ text: String, into groupID: String?) {
        var body = text
        // 鲁棒 Base64：无论有没有 ://，先去掉 \n 与空格整体尝试解码，成功且含 :// 才采用
        let compact = text.replacingOccurrences(of: "\n", with: "")
                          .replacingOccurrences(of: " ", with: "")
                          .replacingOccurrences(of: "\t", with: "")
        if !compact.isEmpty, let dec = Self.b64decode(compact), dec.contains("://") {
            body = dec
        }
        let gid = groupID ?? displayGroupID()
        let links = body.split { $0.isNewline }
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { $0.contains("://") }
        var added = 0
        for link in links {
            guard !servers.contains(where: { $0.raw == link && $0.groupID == gid }) else { continue }
            if let p = try? ProfileParser.parse(link, groupID: gid) { servers.append(p); added += 1 }
        }
        if added > 0 { saveServers() }
    }

    /// 严格 Base64：非法字符直接失败（避免把明文误判为 base64），要求结果为合法 UTF-8
    private static func b64decode(_ s: String) -> String? {
        var b = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let d = Data(base64Encoded: b, options: []),
              let str = String(data: d, encoding: .utf8) else { return nil }
        return str
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
