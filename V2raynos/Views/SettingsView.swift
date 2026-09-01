import SwiftUI

struct SettingsView: View {
    @AppStorage("autoConnect") private var autoConnect = false
    @AppStorage("tunMode") private var tunMode = true
    @AppStorage("localPort") private var localPort = 10808
    var body: some View {
        NavigationStack {
            Form {
                Section("连接") {
                    Toggle("启动时自动连接", isOn: $autoConnect)
                    Toggle("TUN 模式（系统级代理）", isOn: $tunMode)
                    Stepper("本地 SOCKS 端口 \(localPort)", value: $localPort, in: 1024...65535)
                }
                Section("其它") {
                    Label("测速", systemImage: "speedometer")
                    Label("重置数据", systemImage: "trash")
                }
            }
            .navigationTitle("设置")
        }
    }
}