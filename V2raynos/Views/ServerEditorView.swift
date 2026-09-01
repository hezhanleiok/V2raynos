import SwiftUI

struct ServerEditorView: View {
    @ObservedObject var store: Store
    let profile: ServerProfile
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var uuid = ""
    @State private var address = ""
    @State private var port = "443"
    @State private var sni = ""
    @State private var network = "tcp"
    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("名称", text: $name)
                    TextField("地址", text: $address).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("端口", text: $port).keyboardType(.numberPad)
                }
                Section("协议") {
                    TextField("UUID/ID", text: $uuid).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("传输") {
                    TextField("SNI", text: $sni).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("网络", selection: $network) {
                        ForEach(["tcp","ws","grpc","kcp"], id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("编辑节点")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var p = profile;
                        p.name = name.isEmpty ? profile.name : name
                        p.address = address; p.port = Int(port) ?? profile.port
                        p.uuid = uuid; p.sni = sni; p.network = network
                        store.updateServer(p); dismiss()
                    }
                }
            }
            .onAppear {
                name = profile.name; address = profile.address; port = String(profile.port)
                uuid = profile.uuid; sni = profile.sni; network = profile.network
            }
        }
    }
}