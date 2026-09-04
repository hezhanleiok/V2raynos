import SwiftUI

/// 抽屉菜单页（v2rayNG 左侧栏同序）
enum DrawerPage: Int, Identifiable, Hashable {
    case subscriptions, routing, assets, settings, logcat, backup, about
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .subscriptions: return L10n.t("subscriptions")
        case .routing: return L10n.t("routing")
        case .assets: return L10n.t("assets")
        case .settings: return L10n.t("settings")
        case .logcat: return L10n.t("logcat")
        case .backup: return L10n.t("backup")
        case .about: return L10n.t("about")
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

/// 资源文件：geosite.dat / geoip.dat 真实下载管理（存共享目录，Xray 启动即读）
struct AssetsView: View {
    @State private var geoDownloading = false
    @State private var siteDownloading = false
    @State private var geoStatus = "未下载"
    @State private var siteStatus = "未下载"
    @State private var downloadError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("路由资源文件（存共享目录，扩展进程直接读取）") {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("geosite.dat").font(.subheadline.weight(.semibold))
                            Text(siteStatus).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if siteDownloading { ProgressView().scaleEffect(0.8) }
                        Button(siteExists && !siteDownloading ? "更新" : "下载") {
                            downloadAsset(url: "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat",
                                          saveAs: "geosite.dat", isGeo: false)
                        }
                        .disabled(siteDownloading)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("geoip.dat").font(.subheadline.weight(.semibold))
                            Text(geoStatus).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if geoDownloading { ProgressView().scaleEffect(0.8) }
                        Button(geoExists && !geoDownloading ? "更新" : "下载") {
                            downloadAsset(url: "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat",
                                          saveAs: "geoip.dat", isGeo: true)
                        }
                        .disabled(geoDownloading)
                    }
                }
                if let err = downloadError {
                    Section {
                        Text(err).font(.caption).foregroundColor(.red)
                    }
                }
                Section("说明") {
                    Text("下载后重启 VPN 生效。geosite.dat 用于域名路由（geosite:cn 等），geoip.dat 用于 IP 路由（geoip:cn 等）。")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("资源文件")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshStatus() }
        }
    }

    private var siteExists: Bool { FileManager.default.fileExists(atPath: SharedGroup.dir.appendingPathComponent("geosite.dat").path) }
    private var geoExists: Bool { FileManager.default.fileExists(atPath: SharedGroup.dir.appendingPathComponent("geoip.dat").path) }

    private func refreshStatus() {
        func fmt(_ name: String) -> String {
            let u = SharedGroup.dir.appendingPathComponent(name)
            guard let attr = try? FileManager.default.attributesOfItem(atPath: u.path),
                  let size = attr[.size] as? Int, size > 0 else { return "未下载" }
            let mb = Double(size) / 1048576.0
            let date = (attr[.modificationDate] as? Date) ?? Date.distantPast
            return String(format: "已就绪 · %.1f MB · %@", mb, date.formatted(.dateTime.month().day().hour().minute()))
        }
        siteStatus = fmt("geosite.dat")
        geoStatus = fmt("geoip.dat")
    }

    /// 下载并覆盖保存到共享目录
    private func downloadAsset(url: String, saveAs: String, isGeo: Bool) {
        downloadError = nil
        if isGeo { geoDownloading = true } else { siteDownloading = true }
        guard let u = URL(string: url) else { finish(isGeo, err: "下载链接无效"); return }
        let req = URLRequest(url: u, timeoutInterval: 120)
        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                defer {
                    if isGeo { self.geoDownloading = false } else { self.siteDownloading = false }
                    self.refreshStatus()
                }
                if let error = error {
                    self.downloadError = "下载失败：\(error.localizedDescription)"
                    return
                }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let data = data, !data.isEmpty else {
                    self.downloadError = "下载失败：服务器返回异常"
                    return
                }
                let dest = SharedGroup.dir.appendingPathComponent(saveAs)
                do { try data.write(to: dest, options: .atomic) } catch {
                    self.downloadError = "保存失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }

    private func finish(_ isGeo: Bool, err: String) {
        downloadError = err
        if isGeo { geoDownloading = false } else { siteDownloading = false }
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