import SwiftUI

/// 抽屉菜单页（v2rayNG 左侧栏同序）
enum DrawerPage: Int, Identifiable, Hashable {
    case subscriptions, routing, assets, settings, logcat, backup, about
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .subscriptions: return "订阅分组"
        case .routing: return "路由设置"
        case .assets: return "资源文件"
        case .settings: return "设置"
        case .logcat: return "Logcat"
        case .backup: return "备份 & 还原"
        case .about: return "关于"
        }
    }
    var icon: String {
        switch self {
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .routing: return "arrow.triangle.branch"
        case .assets: return "doc.on.doc"
        case .settings: return "gearshape"
        case .logcat: return "terminal"
        case .backup: return "externaldrive"
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
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { g in
                                if g.translation.width < -60 {
                                    withAnimation(.easeInOut(duration: 0.25)) { drawerOpen = false }
                                }
                            }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: drawerOpen)
        .sheet(item: $page) { p in
            switch p {
            case .subscriptions: SubscriptionView()
            case .routing: RoutingView()
            case .assets: AssetsView()
            case .settings: SettingsView()
            case .logcat: LogsView()
            case .backup: BackupView()
            case .about: AboutView()
            }
        }
    }
}

/// 左侧抽屉内容
struct DrawerView: View {
    @Binding var page: DrawerPage?
    @Binding var drawerOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            VStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Text("V2raynos").font(.title3.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(Color.blue.opacity(0.12))

            ForEach([DrawerPage.subscriptions, .routing, .assets, .settings, .logcat, .backup, .about], id: \.self) { p in
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
                if p == .backup { Divider() }
            }

            Spacer()
        }
    }
}

/// 资源文件
struct AssetsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("geoip.dat / geosite.dat") {
                    Label("geoip.dat · 内置", systemImage: "doc")
                    Label("geosite.dat · 内置", systemImage: "doc")
                }
                Section("说明") {
                    Text("Xray-core 已内置路由资源文件，无需手动下载更新")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("资源文件")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 备份 & 还原
struct BackupView: View {
    @EnvironmentObject var store: Store
    @State private var result: String? = nil
    var body: some View {
        NavigationStack {
            Form {
                Section("备份") {
                    Button("备份全部节点到剪贴板") {
                        let links = store.servers.map { $0.raw }.filter { !$0.isEmpty }.joined(separator: "\n")
                        UIPasteboard.general.string = links
                        result = "已复制 \(store.servers.count) 条节点链接"
                    }
                }
                Section("还原") {
                    Button("从剪贴板还原节点") {
                        if let text = UIPasteboard.general.string, !text.isEmpty {
                            store.importLinks(text, into: store.displayGroupID())
                            result = "已导入 \(store.servers.count) 条"
                        }
                    }
                }
                if let result = result {
                    Section { Text(result).font(.caption).foregroundColor(.secondary) }
                }
            }
            .navigationTitle("备份 & 还原")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}