import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @State private var showAdd = false
    @State private var showEditor = false

    var current: ServerProfile? { store.currentServer() }

    var body: some View {
        NavigationStack {
            List {
                if let s = current {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.name).font(.headline)
                            Text("\(s.protocolType.display) · \(s.address):\(s.port)").font(.subheadline).foregroundColor(.secondary)
                            Button(action: toggle) {
                                Label(vpn.isConnected ? "断开" : "连接", systemImage: vpn.isConnected ? "stop.circle" : "play.circle")
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                }
                Section("服务器") {
                    ForEach(store.servers(inGroup: store.currentGroupID())) { s in
                        Button { store.currentServerID = s.id } label: {
                            HStack {
                                Image(systemName: s.id == current?.id ? "checkmark.circle.fill" : "circle").foregroundColor(.blue)
                                VStack(alignment: .leading) { Text(s.name); Text(s.protocolType.display.uppercased()).font(.caption).foregroundColor(.secondary) }
                                Spacer()
                            }
                        }
                    }
                    .onDelete { i in
                        let gid = store.currentGroupID()
                        store.removeServer(store.servers(inGroup: gid)[i.first ?? 0])
                    }
                    Button("添加节点") { showAdd = true }
                }
            }
            .navigationTitle("V2raynos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("导入订阅") {}
                        Button("扫码导入") {}
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddServerView(store: store)
            }
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
            }
        }
    }
}