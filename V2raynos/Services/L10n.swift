import Foundation

/// 应用内语言切换：核心界面文案的本地化字典。
/// appLanguage: "system" 跟随系统（系统为中文→zh，否则 en）；"zh" 强制中文；"en" 强制英文。
enum L10n {
    static var language: String {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
        if saved == "zh" || saved == "en" { return saved }
        // 跟随系统：首选语言含 zh 即中文
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("zh") ? "zh" : "en"
    }

    static func t(_ key: String) -> String {
        let zh: [String: String] = [
            "config.title": "配置项",
            "subscriptions": "订阅分组",
            "routing": "路由设置",
            "assets": "资源文件",
            "settings": "设置",
            "logcat": "Logcat",
            "backup": "备份 & 还原",
            "about": "关于",
            "theme": "主题模式",
            "theme.system": "跟随系统",
            "theme.light": "浅色模式",
            "theme.dark": "深色模式",
            "language": "应用语言",
            "lang.system": "跟随系统",
            "lang.zh": "简体中文",
            "lang.en": "English",
            "appearance": "个性化",
        ]
        let en: [String: String] = [
            "config.title": "Configs",
            "subscriptions": "Subscriptions",
            "routing": "Routing",
            "assets": "Asset Files",
            "settings": "Settings",
            "logcat": "Logcat",
            "backup": "Backup & Restore",
            "about": "About",
            "theme": "Theme",
            "theme.system": "Follow System",
            "theme.light": "Light",
            "theme.dark": "Dark",
            "language": "App Language",
            "lang.system": "Follow System",
            "lang.zh": "简体中文",
            "lang.en": "English",
            "appearance": "Appearance",
        ]
        let dict = language == "zh" ? zh : en
        return dict[key] ?? key
    }
}