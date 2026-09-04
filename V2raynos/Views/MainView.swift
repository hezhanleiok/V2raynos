import SwiftUI
import UIKit
import Network
import UniformTypeIdentifiers

/// 主界面：1:1 复刻 v2rayNG Android 首页布局（iOS Form/List 规范化）
struct MainView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @StateObject private var tester = LatencyTester()
    @Binding var drawerOpen: Bool

    // MARK: 交互状态
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showQR = false
    @State private var showEditor = false
    @State private var editingProto: ConnectionProtocol = .vless
    @State private var editTarget: ServerProfile? = nil
    @State private var addServerError: String? = nil
    @State private var showAddServerError = false
    @State private var showVpnError = false
    @State private var sortMode = SortMode.default
    @State private var showRename: ServerGroup? = nil
    @State private var renameText = ""
    @State private var showFileImporter = false
    @State private var showChainPicker = false

    enum SortMode: String, CaseIterable, Identifiable {
        case `default` = "默认"
        case name = "按名称"
        case latency = "按测试结果"
        var id: String { rawValue }
    }

    var current: ServerProfile? { store.currentServer() }
    var groupID: String { store.displayGroupID() }

    /// 当前分组 + 搜索过滤 + 排序
    var servers: [ServerProfile] {
        let inGroup = store.servers(inGroup: groupID)
        let filtered = searchText.isEmpty ? inGroup : inGroup.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.address.localizedCaseInsensitiveContains(searchText) }
        switch sortMode {
        case .default: return filtered
        case .name: return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .latency: return filtered.sorted { (tester.results[$0.id] ?? .max) < (tester.results[$1.id] ?? .max) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        groupTabBar
                        if showSearch { searchField }
                        ForEach(servers) { s in serverCard(s) }
                        if servers.isEmpty { emptyCard }
                    }
                    .padding(12)
                    .padding(.bottom, 110)
                }

                // 右下角圆形浮动连接按钮（v2rayNG 同位）
                fabButton
            }
            .navigationTitle("配置项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // 左上角设置按钮（打开抽屉）
                    Button { withAnimation(.easeInOut(duration: 0.25)) { drawerOpen.toggle() } } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                    }
                }
                // 标题左对齐（v2rayNG 是左对齐，iOS 借 toolbar 结构实现）
                ToolbarItem(placement: .principal) {
                    HStack {
                        Text("配置项").font(.headline.bold())
                        Spacer()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { withAnimation { showSearch.toggle() } } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    addMenu
                    moreMenu
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .sheet(isPresented: $showChainPicker) {
                ChainProxySheet(groupID: groupID)
            }
            .sheet(isPresented: $showQR) {
                QRScannerView { code in handleScan(code) }
            }
            .sheet(isPresented: $showEditor) {
                ServerEditorView(store: store, initialProtocol: editingProto, profile: editTarget)
                    .presentationDetents([.large])
            }
            .sheet(item: $editTarget) { p in
                ServerEditorView(store: store, initialProtocol: p.protocolType, profile: p)
            }
            .alert("节点导入失败", isPresented: $showAddServerError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(addServerError ?? "节点格式不支持或解析失败")
            }
            .alert("VPN 连接失败", isPresented: $showVpnError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(vpn.lastError ?? "连接被系统拒绝，请检查描述文件")
            }
            .onChange(of: vpn.lastError) { err in
                if err != nil { showVpnError = true }
            }
            .alert("分组改名", isPresented: Binding(get: { showRename != nil }, set: { if !$0 { showRename = nil } })) {
                TextField("新名称", text: $renameText)
                Button("保存") {
                    if let g = showRename { store.renameGroup(g, to: renameText) }
                    showRename = nil
                }
                Button("取消", role: .cancel) { showRename = nil }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.plainText, .text, .data]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource(),
                          let text = try? String(contentsOf: url, encoding: .utf8) else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        _ = try ProfileParser.parse(text.trimmingCharacters(in: .whitespacesAndNewlines), groupID: groupID)
                        store.importLinks(text, into: groupID)
                    } catch {
                        store.importLinks(text, into: groupID)
                        if store.servers.isEmpty { addServerError = "文件内容未解析出节点"; showAddServerError = true }
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - + 号下拉菜单（严格 v2rayNG 菜单项）

    var addMenu: some View {
        Menu {
            Button { showQR = true } label: { Label("扫描二维码", systemImage: "qrcode.viewfinder") }
            Button { importClipboard() } label: { Label("从剪贴板导入", systemImage: "doc.on.clipboard") }
            Button { importFromFile() } label: { Label("从本地导入", systemImage: "folder") }
            Divider()
            Button { openEditor(.vmess) } label: { Label("添加 [VMess]", systemImage: "number") }
            Button { openEditor(.vless) } label: { Label("添加 [VLESS]", systemImage: "number") }
            Button { openEditor(.shadowsocks) } label: { Label("添加 [Shadowsocks]", systemImage: "number") }
            Button { openEditor(.trojan) } label: { Label("添加 [Trojan]", systemImage: "number") }
            Button { openEditor(.hysteria2) } label: { Label("添加 [Hysteria2]", systemImage: "number") }
            Button { openEditor(.wireguard) } label: { Label("添加 [WireGuard]", systemImage: "number") }
            Divider()
            Button { showChainPicker = true } label: { Label("链式代理", systemImage: "link") }
        } label: {
            Image(systemName: "plus")
        }
    }

    // MARK: - ⋮ 号下拉菜单（严格 v2rayNG 菜单项）

    var moreMenu: some View {
        Menu {
            Button { restartService() } label: { Label("服务重启", systemImage: "arrow.triangle.2.circlepath") }
            Button { deleteConfig() } label: { Label("删除配置", systemImage: "trash") }
            Divider()
            Button { withAnimation { sortMode = .latency } } label: { Label("按测试结果排序", systemImage: "arrow.up.arrow.down") }
            Button { tester.tcpPingAll(servers) } label: { Label("测试 TCP 延迟 (TCPing)", systemImage: "speedometer") }
            Button { tester.testAll(servers) } label: { Label("测试真连接延迟", systemImage: "bolt.horizontal") }
            Divider()
            Button { store.updateAllSubscriptions() } label: { Label("更新订阅", systemImage: "arrow.triangle.2.circlepath") }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    // MARK: - 顶部横向分组栏（选中下划线高亮）

    var groupTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 22) {
                ForEach(store.groups) { g in
                    let selected = g.id == groupID
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { store.selectedGroupID = g.id }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Text(g.name).font(.subheadline.weight(selected ? .bold : .regular))
                                Text("\(store.servers(inGroup: g.id).count)")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                            // 选中下划线
                            Rectangle()
                                .fill(selected ? Color.blue : Color.clear)
                                .frame(height: 2.5)
                        }
                        .frame(minWidth: 30)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let sub = store.subscriptions.first(where: { $0.groupID == g.id }) {
                            Button { store.updateSubscriptions(from: sub.url) } label: { Label("更新订阅", systemImage: "arrow.triangle.2.circlepath") }
                        }
                        Button { renameText = g.name; showRename = g } label: { Label("重命名", systemImage: "pencil") }
                        Button(role: .destructive) { store.removeGroup(g) } label: { Label("删除分组", systemImage: "trash") }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("搜索节点", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.secondary) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - 节点卡片（名称/地址:端口/协议-传输  +  分享/编辑/删除 + Ping）

    func serverCard(_ s: ServerProfile) -> some View {
        let selected = s.id == current?.id
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(.headline).lineLimit(1)
                Text("\(s.address):\(s.port)")
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text("\(s.protocolType.display) / \(s.network.isEmpty ? "tcp" : s.network)\(s.sni.isEmpty ? "" : " / tls")")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            // 三小图标 + Ping
            HStack(spacing: 14) {
                Button { UIPasteboard.general.string = s.raw.isEmpty ? shareText(s) : s.raw } label: {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                Button { editTarget = s } label: {
                    Image(systemName: "square.and.pencil").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                Button(role: .destructive) { store.removeServer(s) } label: {
                    Image(systemName: "trash").font(.system(size: 15))
                }
                .buttonStyle(.plain)
                VStack(alignment: .trailing, spacing: 2) {
                    if tester.testing && tester.results[s.id] == nil {
                        ProgressView().scaleEffect(0.7)
                    } else if let ms = tester.results[s.id] {
                        Text(ms < 0 ? "超时" : "\(ms) ms")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(ms < 0 ? .red : (ms < 150 ? .green : .orange))
                    }
                }
                .frame(minWidth: 48, alignment: .trailing)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.currentServerID = s.id }
    }

    func shareText(_ s: ServerProfile) -> String {
        return "\(s.protocolType.display) | \(s.address):\(s.port) | \(s.name)"
    }

    var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.secondary)
            Text("该分组还没有节点").font(.headline)
            Text("点右上角 + 添加节点，或从左侧抽屉导入订阅")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - 底部栏：左状态 + 右 V 形按钮

    /// 状态色：未连接灰 / 已连接绿 / 断开中或异常红
    var statusColor: Color {
        switch vpn.status {
        case .connected: return .green
        case .connecting, .reasserting: return .gray
        case .disconnecting: return .red
        case .invalid, .disconnected: return .gray
        default: return .red
        }
    }

    var bottomBar: some View {
        HStack {
            // 左下角：状态文字
            Text(statusText)
                .font(.subheadline.weight(.medium))
                .foregroundColor(statusColor)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }

    var statusText: String {
        if let err = vpn.lastError, vpn.status != .connected { return err }
        switch vpn.status {
        case .connected: return "已连接"
        case .connecting: return "连接中…"
        case .disconnecting: return "断开中…"
        case .reasserting: return "重连中…"
        case .invalid: return "配置无效"
        default: return "未连接"
        }
    }

    var fabButton: some View {
        Button(action: toggle) {
            Image(systemName: vpn.status == .connected ? "checkmark.circle.fill" : "play.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(statusColor)
        }
        .disabled(current == nil && vpn.status != .connected)
        .opacity(current == nil && vpn.status != .connected ? 0.4 : 1)
        .padding(18)
    }

    // MARK: - 动作

    func toggle() {
        if vpn.status == .connected || vpn.status == .connecting {
            vpn.disconnect()
        } else if let s = current {
            let routing = RoutingRule.load()
            let strategy = UserDefaults.standard.string(forKey: "domainStrategy") ?? "IPIfNonMatch"
            let cfg = ConfigGenerator.xrayJSON(profile: s, routing: routing, domainStrategy: strategy, allServers: store.servers)
            vpn.connect(configJSON: cfg)
        }
    }

    func restartService() {
        if vpn.status == .connected || vpn.status == .connecting {
            vpn.disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let s = self.current {
                    let routing = RoutingRule.load()
                    let strategy = UserDefaults.standard.string(forKey: "domainStrategy") ?? "IPIfNonMatch"
                    self.vpn.connect(configJSON: ConfigGenerator.xrayJSON(profile: s, routing: routing, domainStrategy: strategy, allServers: self.store.servers))
                }
            }
        }
    }

    func deleteConfig() {
        if let s = current { store.removeServer(s) }
    }

    func openEditor(_ proto: ConnectionProtocol) {
        editingProto = proto
        editTarget = nil
        showEditor = true
    }

    /// 剪贴板导入：http 链接 → 订阅；否则单节点解析
    func importClipboard() {
        guard let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            addServerError = "剪贴板为空"
            showAddServerError = true
            return
        }
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            // 订阅分流：直接添加订阅并拉取
            let sub = Subscription(name: "订阅-剪贴板", url: text, groupID: groupID)
            store.addSubscription(sub)
            store.updateSubscriptions(from: text)
            return
        }
        do {
            _ = try ProfileParser.parse(text, groupID: groupID)
            store.importLinks(text, into: groupID)
        } catch {
            addServerError = "节点格式不支持或解析失败"
            showAddServerError = true
        }
    }

    /// 扫码结果分流：http → 订阅；分享链接 → 单节点；失败弹 Alert
    func handleScan(_ code: String) {
        let text = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            let sub = Subscription(name: "订阅-扫码", url: text, groupID: groupID)
            store.addSubscription(sub)
            store.updateSubscriptions(from: text)
            return
        }
        do {
            _ = try ProfileParser.parse(text, groupID: groupID)
            store.importLinks(text, into: groupID)
        } catch {
            addServerError = "节点格式不支持或解析失败"
            showAddServerError = true
        }
    }

    /// 本地导入：系统文件选择器（txt / 订阅文本文件）
    func importFromFile() {
        showFileImporter = true
    }
}

/// 链式代理设置（v2rayNG 同款语义）：给当前分组每个节点指定前置/落地代理
/// 前置代理 = 链入口；落地代理 = 链出口；通过 sockopt.dialerProxy 串联
struct ChainProxySheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let groupID: String
    @State private var prev = ""
    @State private var next = ""

    private var groupServers: [ServerProfile] { store.servers(inGroup: groupID) }
    private var candidates: [ServerProfile] {
        store.servers.filter { $0.groupID != groupID }   // 不能链到自己组
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("当前分组：\(store.groups.first { $0.id == groupID }?.name ?? "")") {
                    if groupServers.isEmpty {
                        Text("该分组没有节点")
                            .font(.caption).foregroundColor(.secondary)
                    } else {
                        Text("设置会应用到本分组 \(groupServers.count) 个节点的代理链")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Section("链式代理") {
                    Picker("前置代理配置别名", selection: $prev) {
                        Text("（无）").tag("")
                        ForEach(Array(candidates.enumerated()), id: \.offset) { _, s in
                            Text(s.name).tag(s.name)
                        }
                    }
                    Text("所选代理会添加到每个配置的前面，作为代理链的入口节点。")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("落地代理配置别名", selection: $next) {
                        Text("（无）").tag("")
                        ForEach(Array(candidates.enumerated()), id: \.offset) { _, s in
                            Text(s.name).tag(s.name)
                        }
                    }
                    Text("所选代理会添加到每个配置的后面，作为代理链的出口节点。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("链式代理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        for i in store.servers.indices where store.servers[i].groupID == groupID {
                            store.servers[i].prevProfile = prev.isEmpty ? nil : prev
                            store.servers[i].nextProfile = next.isEmpty ? nil : next
                        }
                        store.saveServers()
                        dismiss()
                    }
                    .disabled(groupServers.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                prev = groupServers.first?.prevProfile ?? ""
                next = groupServers.first?.nextProfile ?? ""
            }
        }
    }
}

// MARK: - 手动输入（历史保留，菜单已用编辑器替代）
struct AddServerView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var uri = ""
    @State private var showError = false
    @State private var error: String? = nil
    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴分享链接") {
                    TextField("vmess:// vless:// ss:// trojan:// hysteria2:// ...（请勿输入 http 订阅链接）", text: $uri)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("此页仅导入单条节点分享链接；订阅请到抽屉「订阅分组」页添加")
                        .font(.caption).foregroundColor(.secondary)
                }
                Button("从剪贴板填入") {
                    if let s = UIPasteboard.general.string { uri = s }
                }
            }
            .navigationTitle("手动输入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        do {
                            let p = try ProfileParser.parse(uri, groupID: store.displayGroupID())
                            store.addServer(p)
                            dismiss()
                        } catch {
                            self.error = "节点格式不支持或解析失败"
                            self.showError = true
                        }
                    }
                    .disabled(uri.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert("导入失败", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(error ?? "节点格式不支持或解析失败")
            }
        }
    }
}