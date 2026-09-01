import SwiftUI

@main
struct V2raynosApp: App {
    @StateObject private var store = Store()
    @StateObject private var vpn = VpnManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(vpn)
        }
    }
}