import SwiftUI

/// 抽屉菜单页（v2rayNG 式左侧滑出）
enum DrawerPage: Int, Identifiable, Hashable {
    case subscriptions, routing, settings, about
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .subscriptions: return "订阅"
        case .routing: return "路由"
        case .settings: return "设置"
        case .about: return "关于"
        }
    }
    var icon: String {
        switch self {
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .routing: return "arrow.triangle.branch"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    @State private var drawerOpen = false
    @State private var page: DrawerPage? = nil

    var body: some View {
        ZStack(alignment: .leading) {
            MainView(drawerOpen: $drawerOpen)

            if drawerOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { drawerOpen = false } }
                    .transition(.opacity)

                DrawerView(page: $page, drawerOpen: $drawerOpen)
                    .frame(width: 280)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 14, x: 4)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: drawerOpen)
        .sheet(item: $page) { p in
            switch p {
            case .subscriptions: SubscriptionView()
            case .routing: RoutingView()
            case .settings: SettingsView()
            case .about: AboutView()
            }
        }
    }
}

/// 左侧抽屉内容
struct DrawerView: View {
    @Binding var page: DrawerPage?
    @Binding var drawerOpen: Bool
    @EnvironmentObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "network")
                    .font(.system(size: 38))
                    .foregroundColor(.blue)
                Text("V2raynos").font(.title2).bold()
                Text("Xray-core · hev-socks5-tunnel")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.blue.opacity(0.12))

            ForEach([DrawerPage.subscriptions, .routing, .settings, .about], id: \.self) { p in
                Button {
                    drawerOpen = false
                    page = p
                } label: {
                    HStack(spacing: 18) {
                        Image(systemName: p.icon)
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                            .frame(width: 26)
                        Text(p.title).font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 20)
            }

            Spacer()
        }
    }
}
