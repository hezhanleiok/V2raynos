import SwiftUI

/// 设置：字段全面对齐 v2rayNG（iOS Form 规范）
struct SettingsView: View {
    @AppStorage("realPingURL") private var realPingURL = "https://www.gstatic.com/generate_204"
    @AppStorage("realPingConcurrent") private var realPingConcurrent = 3
    @AppStorage("sniffingEnabled") private var sniffingEnabled = true
    @AppStorage("routeOnlyEnabled") private var routeOnlyEnabled = false
    @AppStorage("dynamicPortEnabled") private var dynamicPortEnabled = false
    @AppStorage("localPort") private var localPort = 10808
    @AppStorage("allowLAN") private var allowLAN = false
    @AppStorage("socks5UDP") private var socks5UDP = true
    @AppStorage("remoteDNS") private var remoteDNS = "1.1.1.1"
    @AppStorage("directDNS") private var directDNS = "223.5.5.5"
    @AppStorage("hevTunEnabled") private var hevTunEnabled = true
    @AppStorage("vpnMTU") private var vpnMTU = 1500
    @AppStorage("logLevel") private var logLevel = "warning"

    var body: some View {
        NavigationStack {
            Form {
                Section("测试与进阶") {
                    TextField("真连接延迟测试 URL", text: $realPingURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Stepper("并发测试数：\(realPingConcurrent)", value: $realPingConcurrent, in: 1...20)
                }
                Section("核心设置") {
                    Toggle("启用流量探测 (Sniffing)", isOn: $sniffingEnabled)
                    Toggle("启用 routeOnly", isOn: $routeOnlyEnabled)
                }
                Section("本地代理") {
                    Toggle("启用动态本地代理端口", isOn: $dynamicPortEnabled)
                    if !dynamicPortEnabled {
                        Stepper("本地代理端口：\(localPort)", value: $localPort, in: 1024...65535)
                    }
                    Toggle("允许来自局域网的连接", isOn: $allowLAN)
                    Toggle("SOCKS5 UDP", isOn: $socks5UDP)
                }
                Section("DNS 设置") {
                    TextField("远程 DNS（默认 Cloudflare）", text: $remoteDNS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("直连 DNS", text: $directDNS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section("Hev TUN 设置（iOS 特化）") {
                    Toggle("启用 Hev TUN 功能", isOn: $hevTunEnabled)
                    Stepper("VPN MTU：\(vpnMTU)", value: $vpnMTU, in: 1200...9000, step: 100)
                    Picker("日志级别", selection: $logLevel) {
                        ForEach(["debug","info","warning","error"], id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}