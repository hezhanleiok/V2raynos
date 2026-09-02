import SwiftUI
import UIKit
import Network

struct MainView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @Binding var drawerOpen: Bool

    @State private var showAdd = false
    @State private var latencies: [String: Int] = [:]   // guid -> ms；-1 = 超时/失败
    @State private var testing = false

    var current: ServerProfile? { store.currentServer() }
    var servers: [ServerProfile] { store.servers(inGroup: store.currentGroupID()) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                // --- 卡片式列表（Material 风格，不用 Form/Section）---
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(servers) { s in serverCard(s) }
                        if servers.isEmpty { emptyCard }
                    }
                    .padding(12)
                    .padding(.bottom, 90)
                }

                // --- 右下角蓝色 FAB ---
                Menu {
                    Button { importClipboard() } label: { Label("剪贴板导入", systemImage: "doc.on.clipboard") }
                    Button { showAdd = true } label: { Label("手动添加", systemImage: "square.and.pencil") }
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
                    Button { testAll() } label: {
                        if testing { ProgressView() } else { Image(systemName: "speedometer") }
                    }
                    Button { withAnimation(.easeInOut(duration: 0.25)) { drawerOpen.toggle() } } label: {
                        Image(systemName: "ellipsis.vertical")
                    }
                }
            }
            // --- 底部连接栏（v2rayNG 式）---
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .sheet(isPresented: $showAdd) { AddServerView(store: store) }
        }
    }

    // MARK: - 卡片

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
            if let ms = latencies[s.id] {
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
            Button("删除", role: .destructive) { store.removeServer(s) }
        }
    }

    var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray").font(.system(size: 40)).foregroundColor(.secondary)
            Text("还没有节点").font(.headline)
            Text("点右下角 + 从剪贴板导入，或打开左侧抽屉导入订阅")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - 底部连接栏

    var bottomBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(current?.name ?? "未选择节点")
                    .font(.subheadline).bold().lineLimit(1)
                Text(vpn.isConnected ? "运行中" : "已停止")
                    .font(.caption)
                    .foregroundColor(vpn.isConnected ? .green : .secondary)
            }
            Spacer()
            Button(action: toggle) {
                Image(systemName: vpn.isConnected ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(vpn.isConnected ? .red : .green)
            }
            .disabled(current == nil && !vpn.isConnected)
            .opacity(current == nil && !vpn.isConnected ? 0.4 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - 动作

    func toggle() {
        if vpn.isConnected { vpn.disconnect() }
        else if let s = current {
            let cfg = ConfigGenerator.xrayJSON(profile: s, routing: [])
            vpn.connect(configJSON: cfg)
        }
    }

    func importClipboard() {
        if let s = UIPasteboard.general.string {
            store.importLinks(s, into: store.currentGroupID())
        }
    }

    /// 测试全部延迟（TCP 连接耗时，v2rayNG 式批量测速）
    func testAll() {
        guard !testing else { return }
        let list = servers
        guard !list.isEmpty else { return }
        testing = true
        let group = DispatchGroup()
        for s in list {
            group.enter()
            testOne(s) { ms in
                DispatchQueue.main.async { self.latencies[s.id] = ms }
                group.leave()
            }
        }
        group.notify(queue: .main) { self.testing = false }
    }

    func testOne(_ s: ServerProfile, completion: @escaping (Int) -> Void) {
        guard let u16 = UInt16(exactly: s.port), let port = NWEndpoint.Port(rawValue: u16) else { completion(-1); return }
        let conn = NWConnection(host: NWEndpoint.Host(s.address), port: port, using: .tcp)
        let start = Date()
        let q = DispatchQueue(label: "ping.\(s.id)")
        var finished = false
        let finish: (Int) -> Void = { ms in
            q.async {
                if finished { return }
                finished = true
                conn.cancel()
                completion(ms)
            }
        }
        conn.stateUpdateHandler = { (st: NWConnection.State) in
            switch st {
            case .ready: finish(Int(Date().timeIntervalSince(start) * 1000))
            case .failed: finish(-1)
            default: break
            }
        }
        conn.start(queue: q)
        q.asyncAfter(deadline: .now() + 5) { finish(-1) }
    }
}

// MARK: - 手动添加节点

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
                        if let p = try? ProfileParser.parse(uri, groupID: store.currentGroupID()) {
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
