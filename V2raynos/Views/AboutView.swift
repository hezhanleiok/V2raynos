import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "network").font(.system(size: 64)).foregroundColor(.blue)
                Text("V2raynos").font(.title).bold()
                Text("版本 1.0").foregroundColor(.secondary)
                Text("内核：Xray-core + hev-socks5-tunnel").font(.caption).foregroundColor(.secondary)
                Text("基于 v2rayNG 功能复刻，iOS 风格 UI。").font(.caption).foregroundStyle(.tertiary)
            }
            .padding()
            .navigationTitle("关于")
        }
    }
}