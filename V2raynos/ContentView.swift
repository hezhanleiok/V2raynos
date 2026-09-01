import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var vpn: VpnManager
    var body: some View {
        TabView {
            MainView().tabItem { Label("连接", systemImage: "bolt.horizontal.circle") }
            SubscriptionView().tabItem { Label("订阅", systemImage: "arrow.triangle.2.circlepath") }
            RoutingView().tabItem { Label("路由", systemImage: "arrow.triangle.branch") }
            SettingsView().tabItem { Label("设置", systemImage: "gearshape") }
            AboutView().tabItem { Label("关于", systemImage: "info.circle") }
        }
    }
}