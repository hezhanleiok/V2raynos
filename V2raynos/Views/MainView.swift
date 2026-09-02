import SwiftUI
import UIKit
import Network

struct MainView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @StateObject private var tester = LatencyTester()
    @Binding var drawerOpen: Bool

    @State private var showAdd = false
    @State private var showQR = false
    @State private var showRename: ServerGroup? = nil
    @State private var renameText = ""
    @State private var sortMode = SortMode.default

    enum SortMode: String, CaseIterable, Identifiable {
        case `default` = "默认"
        case name = "按名称"
        case latency = "按延迟"
        var id: String { rawValue }
    }

    var current: ServerProfile? { store.currentServer() }
    var groupID: String { store.displayGroupID() }
    var servers: [ServerProfile] {
        let list = store.servers(inGroup: groupID)
        switch sortMode {
        case .default: return list
        case .name: return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .latency: return list.sorted { (tester.results[$0.id] ?? .max) < (tester.results[$1.id] ?? .max) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        groupChips
                        ForEach(servers) { s in serverCard(s) }
                        if servers.isEmpty { emptyCard }
                    }
                    .padding(12)
                    .padding(.bottom, 90)
                }

                // FAB
                Menu {
                    Button { importClipboard() } label: { Label("剪贴板导入", systemImage: "doc.on.clipboard") }
                    Button { showAdd = true } label: { Label("手动添加", systemImage: "square.and.pencil") }
                    Button { showQR = true } label: { Label("扫码添加", systemImage: "qrcode.viewfinder") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.blue))
                        .shadow(color: .black.opacity(0.28), radius: 7, y: 4)
                }
                .padding(20)
            }
            .navigationTitle("V2raynos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { withAnimation(.easeInOut(duration: 0.25)) { drawerOpen.toggle() } } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // 测速按钮（明显）
                    Button { tester.testAll(servers) } label: {
                        HStack(spacing: 4) {
                            if tester.testing { ProgressView().scaleEffect(0.8) }
                            else { Image(systemName: "speedometer") }
                            Text("测速").font(.subheadline.bold())
                        }
                    }
                    .disabled(tester.testing)
                    Menu {
                        Picker("排序", selection: $sortMode) {
                            ForEach(SortMode.allCases) { m in Text(m.rawValue).tag(m) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .sheet(isPresented: $showAdd) { AddServerView(store: store) }
            .sheet(isPresented: $showQR) {
                QRScannerView { code in handleScan(code) }
            }
            .alert("分组改名", isPresented: Binding(get: { showRename != nil }, set: { if !$0 { showRename = nil } })) {
                TextField("新名称", text: $renameText)
                Button("保存") {
                    if let g = showRename { store.renameGroup(g, to: renameText) }
                    showRename = nil
                }
                Button("取消", role: .cancel) { showRename = nil }
                Button("删除分组", role: .destructive) {
                    if let g = showRename { store.removeGroup(g) }
                    showRename = nil
                }
            }
        }
    }

    // MARK: - 分组 chips

    var groupChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.groups) { g in
                    Button {
                        store.selectedGroupID = g.id
                    } label: {
                        HStack(spacing: 5) {
                            Text(g.name).font(.subheadline)
                            Text("\(store.servers(inGroup: g.id).count)")
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(
                            Capsule().fill(g.id == groupID ? Color.blue : Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundColor(g.id == groupID ? .white : .primary)
                    }
                    .contextMenu {
                        Button("重命名") { renameText = g.name; showRename = g }
                        Button("删除", role: .destructive) { store.removeGroup(g) }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - 节点卡片

    func serverCard(_ s: ServerProfile) -> some View {
        let selected = s.id == current?.id
        return HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(selected ? .blue : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(s.name).font(.headline).foregroundColor(.primary).lineLimit(1)
                Text("\(s.protocolType.display.uppercased()) · \(s.address):\(s.port)")
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if let ms = tester.results[s.id] {
                Text(ms < 0 ? "超时" : "\(ms)ms")
                    .font(.caption)
                    .foregroundColor(ms < 0 ? .red : (ms < 150 ? .green : .orange))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(selected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.currentServerID = s.id }
        .contextMenu {
            Button("设为当前") { store.currentServerID = s.id }
            Button("测试此节点") { tester.testAll([s]) }
            Button("删除", role: .destructive) { store.removeServer(s) }
        }
    }

    var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.secondary)
            Text("该分组还没有节点").font(.headline)
            Text("点右下角 + 添加节点，或到抽屉「订阅」里导入订阅")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - 底部连接栏（大启动按钮）

    var bottomBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(current?.name ?? "未选择节点").font(.subheadline).bold().lineLimit(1)
                Text(vpn.status == .connected ? "运行中" : vpn.status == .connecting ? "连接中…" : "已停止")
                    .font(.caption)
                    .foregroundColor(vpn.status == .connected ? .green : .secondary)
            }
            Spacer()
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: vpn.status == .connected ? "stop.fill" : "power")
                    Text(vpn.status == .connected ? "停止" : "启动 VPN")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Capsule().fill(vpn.status == .connected ? Color.red : Color.blue))
                .foregroundColor(.white)
                .shadow(color: (vpn.status == .connected ? Color.red : Color.blue).opacity(0.4), radius: 6, y: 3)
            }
            .disabled(current == nil && vpn.status != .connected)
            .opacity(current == nil && vpn.status != .connected ? 0.4 : 1)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - 动作

    func toggle() {
        if vpn.status == .connected || vpn.status == .connecting {
            vpn.disconnect()
        } else if let s = current {
            let cfg = ConfigGenerator.xrayJSON(profile: s, routing: [])
            vpn.connect(configJSON: cfg)
        }
    }

    func importClipboard() {
        if let s = UIPasteboard.general.string {
            store.importLinks(s, into: groupID)
        }
    }

    /// 扫码结果分流：分享链接→节点；URL→订阅
    func handleScan(_ code: String) {
        if code.contains("://") && !code.hasPrefix("http") {
            if let p = try? ProfileParser.parse(code, groupID: groupID) { store.addServer(p) }
        } else if code.hasPrefix("http") {
            let sub = Subscription(name: "订阅-扫码", url: code, groupID: groupID)
            store.addSubscription(sub)
            store.updateSubscriptions(from: code)
        }
    }
}

// MARK: - 手动添加

struct AddServerView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var uri = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("粘贴分享链接") {
                    TextField("vmess:// vless:// ss:// trojan:// hysteria2:// ...", text: $uri)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button("从剪贴板填入") {
                    if let s = UIPasteboard.general.string { uri = s }
                }
            }
            .navigationTitle("手动添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        if let p = try? ProfileParser.parse(uri, groupID: store.displayGroupID()) {
                            store.addServer(p); dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}