import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                Text("V2raynos").font(.title).bold()
                Text("版本 1.0").foregroundColor(.secondary)
                Text("内核：Xray-core + hev-socks5-tunnel").font(.caption).foregroundColor(.secondary)
                Text("基于 v2rayNG 功能复刻，iOS 风格 UI。").font(.caption).foregroundStyle(.tertiary)

                // GitHub / Email 图标行
                HStack(spacing: 40) {
                    VStack(spacing: 6) {
                        Link(destination: URL(string: "https://github.com/hezhanleiok/V2raynos")!) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.black)
                        }
                        Text("GitHub").font(.caption2).foregroundColor(.secondary)
                    }
                    VStack(spacing: 6) {
                        Link(destination: URL(string: "mailto:hezhanleiok@users.noreply.github.com")!) {
                            Image(systemName: "envelope.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.blue)
                        }
                        Text("Email").font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)

                Spacer()
            }
            .padding()
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}