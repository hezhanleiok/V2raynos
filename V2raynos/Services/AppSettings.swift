import Foundation

/// 全局运行设置（与 SettingsView 的 @AppStorage 键一一对应，真实作用于生成的 Xray 配置）
struct AppSettings {
    var localPort: Int = 10808
    var dynamicPort: Bool = false
    var sniffing: Bool = true
    var routeOnly: Bool = false
    var allowLAN: Bool = false
    var socksUDP: Bool = true
    var remoteDNS: String = "1.1.1.1"
    var directDNS: String = "223.5.5.5"
    var hevTun: Bool = true
    var mtu: Int = 1500
    var logLevel: String = "warning"
    var realPingURL: String = "https://www.gstatic.com/generate_204"
    var realPingConcurrent: Int = 3

    static func load() -> AppSettings {
        let d = UserDefaults.standard
        var s = AppSettings()
        if let v = d.object(forKey: "localPort") as? Int { s.localPort = v }
        if let v = d.object(forKey: "dynamicPortEnabled") as? Bool, v == true { s.localPort = 10808 + Int.random(in: 0...1000) }
        if let v = d.object(forKey: "dynamicPortEnabled") as? Bool { s.dynamicPort = v }
        if let v = d.object(forKey: "sniffingEnabled") as? Bool { s.sniffing = v }
        if let v = d.object(forKey: "routeOnlyEnabled") as? Bool { s.routeOnly = v }
        if let v = d.object(forKey: "allowLAN") as? Bool { s.allowLAN = v }
        if let v = d.object(forKey: "socks5UDP") as? Bool { s.socksUDP = v }
        if let v = d.string(forKey: "remoteDNS"), !v.isEmpty { s.remoteDNS = v }
        if let v = d.string(forKey: "directDNS"), !v.isEmpty { s.directDNS = v }
        if let v = d.object(forKey: "hevTunEnabled") as? Bool { s.hevTun = v }
        if let v = d.object(forKey: "vpnMTU") as? Int { s.mtu = v }
        if let v = d.string(forKey: "logLevel"), !v.isEmpty { s.logLevel = v }
        if let v = d.string(forKey: "realPingURL"), !v.isEmpty { s.realPingURL = v }
        if let v = d.object(forKey: "realPingConcurrent") as? Int { s.realPingConcurrent = v }
        return s
    }

    /// 序列化给 Packet Tunnel 扩展（providerConfiguration 携带，无 App Group 也可达）
    var settingsJSON: String {
        let dict: [String: Any] = [
            "localPort": localPort, "dynamicPort": dynamicPort, "sniffing": sniffing,
            "routeOnly": routeOnly, "allowLAN": allowLAN, "socksUDP": socksUDP,
            "remoteDNS": remoteDNS, "directDNS": directDNS, "hevTun": hevTun,
            "mtu": mtu, "logLevel": logLevel,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    /// 扩展端解析
    static func fromJSON(_ json: String?) -> AppSettings {
        var s = AppSettings()
        guard let json = json, let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return s }
        if let v = dict["localPort"] as? Int { s.localPort = v }
        if let v = dict["dynamicPort"] as? Bool { s.dynamicPort = v }
        if let v = dict["sniffing"] as? Bool { s.sniffing = v }
        if let v = dict["routeOnly"] as? Bool { s.routeOnly = v }
        if let v = dict["allowLAN"] as? Bool { s.allowLAN = v }
        if let v = dict["socksUDP"] as? Bool { s.socksUDP = v }
        if let v = dict["remoteDNS"] as? String { s.remoteDNS = v }
        if let v = dict["directDNS"] as? String { s.directDNS = v }
        if let v = dict["hevTun"] as? Bool { s.hevTun = v }
        if let v = dict["mtu"] as? Int { s.mtu = v }
        if let v = dict["logLevel"] as? String { s.logLevel = v }
        return s
    }
}