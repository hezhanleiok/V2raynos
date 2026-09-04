import SwiftUI

@main
struct V2raynosApp: App {
    @StateObject private var store = Store()
    @StateObject private var vpn = VpnManager()
    @AppStorage("appTheme") private var appTheme = "system"      // system / light / dark
    @AppStorage("appLanguage") private var appLanguage = "system" // system / zh / en

    var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // nil 即跟随系统
        }
    }

    var currentLocale: Locale {
        switch appLanguage {
        case "zh": return Locale(identifier: "zh-Hans")
        case "en": return Locale(identifier: "en")
        default: return Locale.autoupdatingCurrent
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(vpn)
                .preferredColorScheme(colorScheme)
                .environment(\.locale, currentLocale)
        }
    }
}