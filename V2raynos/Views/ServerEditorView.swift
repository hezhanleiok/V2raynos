import SwiftUI

/// 节点编辑器：字段与 v2rayNG ServerXxxActivity 模板 1:1
/// 公共段：别名/地址/端口 → 协议字段 → 传输协议(TCP/KCP/WS/HTTPUpgrade/XHTTP/H2/gRPC + 伪装类型/host/path) → TLS(REALITY 可选/SNI/Fingerprint/ALPN)
struct ServerEditorView: View {
    @ObservedObject var store: Store
    let initialProtocol: ConnectionProtocol
    let profile: ServerProfile?
    @Environment(\.dismiss) private var dismiss

    // 公共基础（CommonBasicFields）
    @State private var remarks = ""
    @State private var address = ""
    @State private var port = ""
    // 协议字段
    @State private var uuid_ = ""
    @State private var security = "auto"
    @State private var flow = ""
    @State private var password = ""
    // WireGuard
    @State private var secretKey = ""
    @State private var publicKey = ""
    @State private var presharedKey = ""
    @State private var reserved = ""
    @State private var localAddress = ""
    @State private var localMtu = "1420"
    // Hysteria2
    @State private var obfsPassword = ""
    @State private var portHopping = ""
    @State private var portHopInterval = ""
    @State private var bandwidthDown = ""
    @State private var bandwidthUp = ""
    // 传输（CommonNetworkFields）
    @State private var network = "tcp"
    @State private var headerType = "none"
    @State private var grpcMode = "gun"
    @State private var xhttpMode = "auto"
    @State private var host = ""
    @State private var path = ""
    // TLS（CommonStreamSecurityFields）
    @State private var streamSecurity = ""
    @State private var sni = ""
    @State private var fingerPrint = ""
    @State private var shortId = ""
    @State private var spiderX = ""
    @State private var alpn = ""
    @State private var allowInsecure = false

    let networkOptions = ["tcp", "kcp", "ws", "httpupgrade", "xhttp", "h2", "grpc"]
    let tcpHeaderOptions = ["none", "http"]
    let kcpHeaderOptions = ["none", "srtp", "utp", "wechat-video", "dtls", "wireguard", "dns"]
    let grpcModeOptions = ["gun", "multi"]
    let xhttpModeOptions = ["auto", "packet-up", "stream-up", "stream-one"]
    let streamSecurityOptions = ["", "tls", "reality"]
    let utlsOptions = ["", "chrome", "firefox", "safari", "ios", "android", "edge", "360", "qq", "random", "randomized"]
    let alpnOptions = ["", "h3", "h2", "http/1.1", "h3,h2,http/1.1", "h3,h2", "h2,http/1.1"]
    let vmessSecurityOptions = ["chacha20-poly1305", "aes-128-gcm", "auto", "none", "zero"]
    let ssSecurityOptions = ["aes-256-gcm", "aes-128-gcm", "chacha20-poly1305", "chacha20-ietf-poly1305", "xchacha20-poly1305", "xchacha20-ietf-poly1305", "none", "plain", "2022-blake3-aes-128-gcm", "2022-blake3-aes-256-gcm", "2022-blake3-chacha20-poly1305"]
    let flowOptions = ["", "xtls-rprx-vision"]

    var body: some View {
        NavigationStack {
            Form {
                Section("基础") {
                    TextField("别名 (remarks)", text: $remarks)
                    TextField("地址 (address)", text: $address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("端口 (port)", text: $port)
                        .keyboardType(.numberPad)
                }
                protocolSection
                if initialProtocol != .hysteria2 && initialProtocol != .wireguard {
                    networkSection
                    streamSecuritySection
                }
                if initialProtocol == .hysteria2 {
                    hysteria2ExtraSection
                }
                if initialProtocol == .wireguard {
                    wireguardSection
                }
            }
            .navigationTitle(titleText)
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

    var titleText: String {
        let editing = profile != nil
        let base = initialProtocol.display
        return editing ? "编辑 \(base)" : "添加 [\(base)]"
    }

    // MARK: 协议字段（VLESS: id/encryption/flow；VMess: id/security；SS: password/security；Trojan: password；Hy2 特化段）
    @ViewBuilder
    var protocolSection: some View {
        switch initialProtocol {
        case .vmess:
            Section("VMess") {
                TextField("用户 ID (id)", text: $uuid_)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("加密方式 (security)", selection: $security) {
                    ForEach(vmessSecurityOptions, id: \.self) { Text($0).tag($0) }
                }
            }
        case .vless:
            Section("VLESS") {
                TextField("用户 ID (id)", text: $uuid_)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("加密方式 (encryption)", text: $security)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("流控 (flow)", selection: $flow) {
                    ForEach(flowOptions, id: \.self) { Text($0.isEmpty ? "（空）" : $0).tag($0) }
                }
            }
        case .shadowsocks:
            Section("Shadowsocks") {
                SecureField("密码", text: $password)
                Picker("加密方式 (security)", selection: $security) {
                    ForEach(ssSecurityOptions, id: \.self) { Text($0).tag($0) }
                }
            }
        case .trojan:
            Section("Trojan") {
                SecureField("密码", text: $password)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        case .hysteria2:
            Section("Hysteria2") {
                SecureField("密码", text: $password)
            }
        case .socks, .http:
            Section("认证") {
                TextField("用户名", text: $uuid_)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("密码 (可选)", text: $password)
            }
        case .wireguard:
            EmptyView()
        }
    }

    // MARK: 传输协议（CommonNetworkFields 1:1）
    var networkSection: some View {
        Section("底层传输方式 (transport)") {
            Picker("传输协议 (network)", selection: $network) {
                ForEach(networkOptions, id: \.self) { Text($0).tag($0) }
            }
            // 伪装类型 / gRPC 模式
            if network == "tcp" || network == "kcp" {
                Picker("伪装类型 (type)", selection: $headerType) {
                    ForEach(network == "tcp" ? tcpHeaderOptions : kcpHeaderOptions, id: \.self) { Text($0).tag($0) }
                }
            }
            if network == "grpc" {
                Picker("gRPC 传输模式 (mode)", selection: $grpcMode) {
                    ForEach(grpcModeOptions, id: \.self) { Text($0).tag($0) }
                }
            }
            if network == "xhttp" {
                Picker("XHTTP 模式", selection: $xhttpMode) {
                    ForEach(xhttpModeOptions, id: \.self) { Text($0).tag($0) }
                }
            }
            // 伪装域名 / host
            if network == "grpc" {
                TextField("gRPC Authority", text: $host)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } else {
                TextField(network == "ws" ? "ws host" : "伪装域名 (host)", text: $host)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            // path
            if network != "kcp" {
                TextField(pathLabel, text: $path)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            }
        }
    }

    var pathLabel: String {
        switch network {
        case "ws": return "ws path"
        case "httpupgrade": return "httpupgrade path"
        case "xhttp": return "xhttp path"
        case "h2": return "h2 path"
        case "grpc": return "gRPC serviceName"
        default: return "path"
        }
    }

    // MARK: TLS（CommonStreamSecurityFields 1:1）
    var streamSecuritySection: some View {
        Section("TLS") {
            Picker("TLS", selection: $streamSecurity) {
                Text("（不启用）").tag("")
                ForEach(streamSecurityOptions.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
            }
            if !streamSecurity.isEmpty {
                TextField("SNI", text: $sni)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Fingerprint", selection: $fingerPrint) {
                    ForEach(utlsOptions, id: \.self) { Text($0.isEmpty ? "（空）" : $0).tag($0) }
                }
                if streamSecurity == "tls" {
                    Toggle("跳过证书验证 (allowInsecure)", isOn: $allowInsecure)
                    Picker("ALPN", selection: $alpn) {
                        ForEach(alpnOptions, id: \.self) { Text($0.isEmpty ? "（空）" : $0).tag($0) }
                    }
                }
                if streamSecurity == "reality" {
                    TextField("PublicKey", text: $publicKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("ShortId", text: $shortId)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("SpiderX（可选）", text: $spiderX)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
            }
        }
    }

    // MARK: Hysteria2 特化（v2rayNG ServerHysteria2Activity）
    var hysteria2ExtraSection: some View {
        Section("Hysteria2 高级") {
            TextField("混淆密码", text: $obfsPassword)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("跳跃端口 (会覆盖服务器端口)", text: $portHopping)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("端口跳跃间隔 (秒)", text: $portHopInterval)
                .keyboardType(.numberPad)
            TextField("带宽下行 (支持的单位 k/m/g/t)", text: $bandwidthDown)
            TextField("带宽上行 (支持的单位 k/m/g/t)", text: $bandwidthUp)
            Toggle("跳过证书验证 (allowInsecure)", isOn: $allowInsecure)
            TextField("SNI", text: $sni)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }

    // MARK: WireGuard（v2rayNG ServerWireguardActivity）
    var wireguardSection: some View {
        Section("WireGuard") {
            TextField("SecretKey", text: $secretKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("PublicKey", text: $publicKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("PreSharedKey（可选）", text: $presharedKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Reserved (可选，逗号隔开)", text: $reserved)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("本地地址 (可选 IPv4/IPv6，逗号隔开)", text: $localAddress)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("MTU（可选，默认 1420）", text: $localMtu)
                .keyboardType(.numberPad)
        }
    }

    private func load() {
        if let p = profile {
            remarks = p.name; address = p.address; port = String(p.port)
            uuid_ = p.uuid; security = p.cipher.isEmpty ? "auto" : p.cipher
            flow = p.flow; password = p.password
            network = p.network.isEmpty ? "tcp" : p.network
            host = p.sni; path = p.path
            sni = p.sni; alpn = p.alpn
            publicKey = p.publicKey
            fingerPrint = p.fingerPrint
            shortId = p.shortId
            spiderX = p.spiderX
            streamSecurity = !p.publicKey.isEmpty ? "reality" : (p.sni.isEmpty ? "" : "tls")
        } else {
            network = "tcp"
        }
    }

    private func save() {
        if var p = profile {
            apply(to: &p)
            store.updateServer(p)
        } else {
            var p = ServerProfile(groupID: store.displayGroupID(),
                                   name: remarks.isEmpty ? address : remarks,
                                   protocolType: initialProtocol,
                                   address: address,
                                   port: Int(port) ?? 443,
                                   uuid: uuid_, password: password, cipher: security,
                                   sni: sni, network: network, path: path,
                                   alpn: alpn, flow: flow, publicKey: publicKey,
                                   fingerPrint: fingerPrint, shortId: shortId, spiderX: spiderX,
                                   settingsJson: "", remark: "", raw: "")
            apply(to: &p)
            store.addServer(p)
        }
        dismiss()
    }

    private func apply(to p: inout ServerProfile) {
        p.name = remarks.isEmpty ? p.address : remarks
        p.address = address
        p.port = Int(port) ?? p.port
        p.uuid = uuid_
        p.cipher = security
        p.flow = flow
        p.password = password
        p.network = network
        p.path = path
        p.sni = !sni.isEmpty ? sni : host
        p.alpn = alpn
        p.publicKey = publicKey
        p.fingerPrint = fingerPrint
        p.shortId = shortId
        p.spiderX = spiderX
    }
}