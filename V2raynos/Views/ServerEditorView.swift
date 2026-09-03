import SwiftUI

/// 节点编辑器：按协议加载模板（+菜单添加 [协议] → 表单）
struct ServerEditorView: View {
    @ObservedObject var store: Store
    /// 新建时为 nil；编辑已有节点时传值
    let initialProtocol: ConnectionProtocol
    let profile: ServerProfile?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var uuid_ = ""
    @State private var address = ""
    @State private var port = "443"
    @State private var password = ""
    @State private var cipher = "auto"
    @State private var sni = ""
    @State private var network = "tcp"
    @State private var path = ""
    @State private var alpn = ""
    @State private var flow = ""
    @State private var publicKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("名称（备注）", text: $name)
                    TextField("地址 (address)", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("端口 (port)", text: $port)
                        .keyboardType(.numberPad)
                }
                if initialProtocol == .vmess || initialProtocol == .vless {
                    Section("认证") {
                        TextField(initialProtocol == .vmess ? "用户 ID (UUID)" : "用户 ID (UUID)", text: $uuid_)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        if initialProtocol == .vless {
                            TextField("Flow (xtls-rprx-vision，可留空)", text: $flow)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                    }
                    Section("传输") {
                        Picker("网络 (network)", selection: $network) {
                            ForEach(["tcp","ws","grpc","kcp"], id: \.self) { Text($0).tag($0) }
                        }
                        TextField("路径 (path / serviceName)", text: $path)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("SNI (serverName)", text: $sni)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("ALPN (逗号分隔，可留空)", text: $alpn)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                if initialProtocol == .shadowsocks || initialProtocol == .trojan || initialProtocol == .hysteria2 {
                    Section("认证") {
                        TextField(initialProtocol == .shadowsocks ? "密码 (password)" : "密码 (password)", text: $password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        if initialProtocol == .shadowsocks {
                            Picker("加密 (security)", selection: $cipher) {
                                ForEach(["aes-128-gcm","aes-256-gcm","chacha20-poly1305","2022-blake3-aes-128-gcm","none"], id: \.self) { Text($0).tag($0) }
                            }
                        }
                    }
                    Section("传输") {
                        Picker("网络 (network)", selection: $network) {
                            ForEach(["tcp","ws","grpc"], id: \.self) { Text($0).tag($0) }
                        }
                        TextField("SNI (serverName)", text: $sni)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                if initialProtocol == .wireguard {
                    Section("WireGuard") {
                        TextField("私钥 (privateKey)", text: $password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("公钥 (peerPublicKey)", text: $publicKey)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("预共享密钥 (presharedKey，可留空)", text: $uuid_)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                if initialProtocol == .socks || initialProtocol == .http {
                    Section("认证") {
                        TextField("用户名", text: $uuid_)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("密码", text: $password)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle(initialProtocol == .vless ? "添加 [VLESS]" :
                             initialProtocol == .vmess ? "添加 [VMess]" :
                             initialProtocol == .shadowsocks ? "添加 [Shadowsocks]" :
                             initialProtocol == .trojan ? "添加 [Trojan]" :
                             initialProtocol == .hysteria2 ? "添加 [Hysteria2]" :
                             "添加 [\(initialProtocol.display)]")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(address.isEmpty || Int(port) == nil)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        if let p = profile {
            name = p.name; address = p.address; port = String(p.port)
            uuid_ = p.uuid; password = p.password; cipher = p.cipher
            sni = p.sni; network = p.network; path = p.path
            alpn = p.alpn; flow = p.flow; publicKey = p.publicKey
        } else {
            network = "tcp"
        }
    }

    private func save() {
        if var p = profile {
            p.name = name.isEmpty ? p.name : name
            p.address = address
            p.port = Int(port) ?? p.port
            p.uuid = uuid_; p.password = password; p.cipher = cipher
            p.sni = sni; p.network = network; p.path = path
            p.alpn = alpn; p.flow = flow; p.publicKey = publicKey
            store.updateServer(p)
        } else {
            let p = ServerProfile(groupID: store.displayGroupID(),
                                   name: name.isEmpty ? address : name,
                                   protocolType: initialProtocol,
                                   address: address,
                                   port: Int(port) ?? 443,
                                   uuid: uuid_, password: password, cipher: cipher,
                                   sni: sni, network: network, path: path,
                                   alpn: alpn, flow: flow, publicKey: publicKey,
                                   settingsJson: "", remark: "", raw: "")
            store.addServer(p)
        }
        dismiss()
    }
}