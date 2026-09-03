import Foundation

/// 把 ServerProfile + 设置 + 路由 转成 Xray 能跑的 JSON 配置字符串
struct ConfigGenerator {
    /// 全参版：所有 Settings 开关真实生效
    static func xrayJSON(profile: ServerProfile, settings: AppSettings = AppSettings.load(),
                         routing: [RoutingRule] = [], domainStrategy: String = "IPIfNonMatch") -> String {
        let listen = settings.allowLAN ? "0.0.0.0" : "127.0.0.1"
        let sniffing: [String: Any] = [
            "enabled": settings.sniffing,
            "routeOnly": settings.routeOnly,
            "destOverride": ["http", "tls", "quic"],
        ]
        let inbounds: [[String: Any]] = [
            ["listen": listen, "port": settings.localPort, "protocol": "socks",
             "settings": ["udp": settings.socksUDP], "sniffing": sniffing],
            ["listen": "127.0.0.1", "port": settings.localPort + 1, "protocol": "dokodemo-door",
             "settings": ["address": "8.8.8.8", "port": 53, "network": "tcp,udp"], "sniffing": sniffing],
        ]
        let outbounds: [Any] = [ outboundDict(profile) ] + extraOutbounds()
        let config: [String: Any] = [
            "log": ["loglevel": settings.logLevel],
            "inbounds": inbounds,
            "outbounds": outbounds,
            "routing": routingDict(routing, domainStrategy: domainStrategy),
            "dns": ["servers": [settings.remoteDNS, settings.directDNS]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    /// 延迟测试专用：http 入站（iOS URLSession 不支持 SOCKS，走 HTTP 代理）
    static func latencyJSON(profile p: ServerProfile, httpPort: Int) -> String {
        let outbounds: [Any] = [ outboundDict(p) ] + extraOutbounds()
        let config: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": [
                ["listen": "127.0.0.1", "port": httpPort, "protocol": "http", "settings": ["allowTransparent": false]],
            ],
            "outbounds": outbounds,
            "dns": ["servers": ["1.1.1.1", "8.8.8.8"]],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    private static func outboundDict(_ p: ServerProfile) -> [String: Any] {
        var base: [String: Any] = [
            "tag": "proxy",
            "server": p.address,
            "port": p.port,
            "streamSettings": streamDict(p),
        ]
        switch p.protocolType {
        case .vless: base["protocol"] = "vless"; base["settings"] = vlessSettings(p)
        case .vmess: base["protocol"] = "vmess"; base["settings"] = vmessSettings(p)
        case .trojan: base["protocol"] = "trojan"; base["settings"] = trojanSettings(p)
        case .shadowsocks: base["protocol"] = "shadowsocks"; base["settings"] = ssSettings(p)
        case .hysteria2: base["protocol"] = "hysteria2"; base["settings"] = hysteria2Settings(p)
        default: base["protocol"] = "vless"; base["settings"] = vlessSettings(p)
        }
        return base
    }

    private static func vlessSettings(_ p: ServerProfile) -> [String: Any] {
        ["vnext": [["address": p.address, "port": p.port, "users": [["id": p.uuid, "encryption": "none", "flow": p.flow, "security": "auto"]]]]]
    }

    private static func vmessSettings(_ p: ServerProfile) -> [String: Any] {
        ["vnext": [["address": p.address, "port": p.port, "users": [["id": p.uuid, "alterId": 0, "security": "auto"]]]]]
    }

    private static func trojanSettings(_ p: ServerProfile) -> [String: Any] {
        ["servers": [["address": p.address, "port": p.port, "password": p.password]]]
    }

    private static func ssSettings(_ p: ServerProfile) -> [String: Any] {
        ["servers": [["address": p.address, "port": p.port, "method": p.cipher, "password": p.password]]]
    }

    private static func hysteria2Settings(_ p: ServerProfile) -> [String: Any] {
        ["servers": [["address": p.address, "port": p.port, "auth_str": p.password]]]
    }

    private static func streamDict(_ p: ServerProfile) -> [String: Any] {
        var sd: [String: Any] = ["network": p.network, "security": p.sni.isEmpty ? "none" : "tls"]
        if !p.sni.isEmpty { sd["tlsSettings"] = ["serverName": p.sni, "allowInsecure": false, "alpn": p.alpn.isEmpty ? ["h2", "http/1.1"] : p.alpn.split(separator: ",").map { String($0) }] }
        if p.network == "ws" { sd["wsSettings"] = ["path": p.path, "headers": ["Host": p.sni.isEmpty ? p.address : p.sni]] }
        if p.network == "grpc" { sd["grpcSettings"] = ["serviceName": p.path] }
        if p.network == "kcp" { sd["kcpSettings"] = ["mtu": 1350] }
        return sd
    }

    private static func extraOutbounds() -> [Any] {
        let arr: [[String: Any]] = [["protocol": "freedom", "tag": "direct"], ["protocol": "blackhole", "tag": "block"]]
        return arr as [Any]
    }

    private static func routingDict(_ rules: [RoutingRule], domainStrategy: String) -> [String: Any] {
        var list: [[String: Any]] = rules.filter { $0.enabled }.map {
            ["type": "field", "domain": [$0.domain], "outboundTag": $0.outbound]
        }
        list.append(["type": "field", "ip": ["geoip:private"], "outboundTag": "direct"])
        return ["domainStrategy": domainStrategy, "rules": list]
    }
}