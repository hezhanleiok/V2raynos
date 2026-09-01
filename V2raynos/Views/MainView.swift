import SwiftUI
import UIKit

struct MainView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @State private var showAdd = false
    @State private var showImportSub = false
    @State private var showImportSheet = false

    var current: ServerProfile? { store.currentServer() }

    var body: some View {
        NavigationStack {
            List {
                // --- 连接/状态栏（v2rayNG 式）---
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: vpn.isConnected ? "checkmark.shield.fill" : "shield")
                                .foregroundColor(vpn.isConnected ? .green : .secondary)
                            Text(vpn.isConnected ? "已连接" : "未连接").font(.headline)
                            Spacer()
                            if let s = current { Text(s.name).font(.subheadline).foregroundColor(.secondary).lineLimit(1) }
                        }
                        Button(action: toggle) {
                            HStack {
                                Spacer()
                                Image(systemName: vpn.isConnected ? "stop.circle.fill" : "play.circle.fill")
                                Text(vpn.isConnected ? "断开" : "连接").font(.headline)
                                Spacer()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(vpn.isConnected ? .red : .green)
                        .controlSize(.large)
                    }
                    .padding(.vertical, 4)
                }

                // --- 服务器列表 ---
                Section("服务器") {
                    ForEach(store.servers(inGroup: store.currentGroupID())) { s in
                        Button { store.currentServerID = s.id } label: {
                            HStack {
                                Image(systemName: s.id == current?.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(s.id == current?.id ? .blue : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.body)
                                    Text("\(s.protocolType.display.uppercased()) · \(s.address):\(s.port)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if s.id == current?.id { Text("当前").font(.caption2).foregroundColor(.blue) }
                            }
                        }
                    }
                    .onDelete { i in
                        let gid = store.currentGroupID()
                        store.removeServer(store.servers(inGroup: gid)[i.first ?? 0])
                    }
                    if store.servers(inGroup: store.currentGroupID()).isEmpty {
                        Text("还没有节点。点击右上角 + 添加，或导入订阅。").font(.caption).foregroundColor(.secondary)
                    }
                }

                // --- 导入 ---
                Section {
                    Button("从剪贴板导入节点") { importClipboard() }
                    Button("导入订阅") { showImportSub = true }
                    Button("更新全部订阅") { store.updateAllSubscriptions() }
                }
            }
            .navigationTitle("V2raynos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showAdd = true } label: { Label("添加节点", systemImage: "plus.circle") }
                        Button { showImportSub = true } label: { Label("导入订阅", systemImage: "arrow.triangle.2.circlepath") }
                        Button { importClipboard() } label: { Label("从剪贴板导入", systemImage: "doc.on.clipboard") }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddServerView(store: store) }
            .sheet(isPresented: $showImportSub) { ImportSubscriptionView(store: store) }
        }
    }

    func importClipboard() {
        if let s = UIPasteboard.general.string {
            store.importLinks(s, into: store.currentGroupID())
        }
    }

    func toggle() {
        if vpn.isConnected { vpn.disconnect() }
        else if let s = current {
            let cfg = ConfigGenerator.xrayJSON(profile: s, routing: [])
            vpn.connect(configJSON: cfg)
        }
    }
}

struct ImportSubscriptionView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("订阅 URL", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("添加并更新") {
                    if !url.isEmpty {
                        let s = Subscription(name: "订阅", url: url, groupID: store.currentGroupID())
                        store.addSubscription(s)
                        store.updateSubscriptions(from: url)
                        dismiss()
                    }
                }
            }
            .navigationTitle("导入订阅")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}

struct AddServerView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var uri = ""
    var body: some View {
        NavigationStack {
            Form {
                TextField("粘贴 vmess:// vless:// ss:// trojan:// ...", text: $uri)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("从剪贴板导入") {
                    if let s = UIPasteboard.general.string { store.importLinks(s, into: store.currentGroupID()); dismiss() }
                }
            }
            .navigationTitle("添加节点")
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