import Foundation

enum ProfileParseError: Error { case unsupported(String), invalid(String) }

struct ProfileParser {
    static func parse(_ uri: String, groupID: String) throws -> ServerProfile {
        let t = uri.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("vmess://") { return try parseVmess(t, groupID: groupID) }
        if t.hasPrefix("vless://") { return try parseVless(t, groupID: groupID) }
        if t.hasPrefix("trojan://") { return try parseTrojan(t, groupID: groupID) }
        if t.hasPrefix("ss://") { return try parseSS(t, groupID: groupID) }
        if t.hasPrefix("hysteria2://") || t.hasPrefix("hy2://") { return try parseHysteria2(t, groupID: groupID) }
        throw ProfileParseError.unsupported("scheme")
    }

    private static func b64(_ s: String) -> String? {
        guard let d = Data(base64Encoded: s, options: .ignoreUnknownCharacters) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    private static func parseQuery(_ q: String) -> [String: String] {
        var out: [String: String] = [:]
        for kv in q.split(separator: "&") {
            let parts = kv.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { out[String(parts[0])] = String(parts[1].removingPercentEncoding ?? String(parts[1])) }
        }
        return out
    }

    private static func parseVmess(_ uri: String, groupID: String) throws -> ServerProfile {
        let payload = String(uri.dropFirst("vmess://".count))
        guard let s = b64(payload), let d = s.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { throw ProfileParseError.invalid("vmess") }
        let name = o["ps"] as? String ?? "VMess"
        return ServerProfile(groupID: groupID, name: name, protocolType: .vmess,
            address: o["add"] as? String ?? "", port: Int(o["port"] as? String ?? "0") ?? 0,
            uuid: o["id"] as? String ?? "", password: "", cipher: "auto",
            sni: o["sni"] as? String ?? "", network: o["net"] as? String ?? "tcp",
            path: o["path"] as? String ?? "", alpn: "", flow: "", publicKey: "",
            settingsJson: "", remark: name, raw: uri)
    }

    private static func parseVless(_ uri: String, groupID: String) throws -> ServerProfile {
        let body = String(uri.dropFirst("vless://".count))
        guard let at = body.firstIndex(of: "@") else { throw ProfileParseError.invalid("vless") }
        let uuid = String(body[..<at])
        let afterAt = String(body[body.index(after: at)...])
        let frag = afterAt.split(separator: "#", maxSplits: 1)
        let hp = String(frag[0])
        let name = frag.count > 1 ? String(frag[1]) : "VLESS"
        let hostPort = hp.split(separator: "?", maxSplits: 1)
        let hpc = hostPort[0].split(separator: ":")
        let host = hpc.first.map(String.init) ?? ""
        let port = hpc.count > 1 ? Int(hpc[1]) ?? 0 : 0
        let kv = hostPort.count > 1 ? parseQuery(String(hostPort[1])) : [:]
        return ServerProfile(groupID: groupID, name: name, protocolType: .vless,
            address: host, port: port, uuid: uuid, password: "", cipher: "none",
            sni: kv["sni"] ?? "", network: kv["type"] ?? "tcp", path: kv["path"] ?? "",
            alpn: kv["alpn"] ?? "", flow: kv["flow"] ?? "", publicKey: kv["pbk"] ?? "",
            settingsJson: "", remark: name, raw: uri)
    }

    private static func parseTrojan(_ uri: String, groupID: String) throws -> ServerProfile {
        let body = String(uri.dropFirst("trojan://".count))
        guard let at = body.firstIndex(of: "@") else { throw ProfileParseError.invalid("trojan") }
        let password = String(body[..<at])
        let afterAt = String(body[body.index(after: at)...])
        let frag = afterAt.split(separator: "#", maxSplits: 1)
        let hp = String(frag[0])
        let name = frag.count > 1 ? String(frag[1]) : "Trojan"
        let hostPort = hp.split(separator: "?", maxSplits: 1)
        let hpc = hostPort[0].split(separator: ":")
        let host = hpc.first.map(String.init) ?? ""
        let port = hpc.count > 1 ? Int(hpc[1]) ?? 0 : 0
        let kv = hostPort.count > 1 ? parseQuery(String(hostPort[1])) : [:]
        return ServerProfile(groupID: groupID, name: name, protocolType: .trojan,
            address: host, port: port, uuid: "", password: password, cipher: "",
            sni: kv["sni"] ?? "", network: kv["type"] ?? "tcp", path: kv["path"] ?? "",
            alpn: kv["alpn"] ?? "", flow: "", publicKey: "",
            settingsJson: "", remark: name, raw: uri)
    }

    private static func parseSS(_ uri: String, groupID: String) throws -> ServerProfile {
        let body = String(uri.dropFirst("ss://".count))
        // ss://BASE64(method:password)@host:port#name  (url-safe base64, may contain @)
        var hostPort = body
        var methodPass = ""
        if let at = body.lastIndex(of: "@") {
            hostPort = String(body[body.index(after: at)...])
            methodPass = String(body[..<at])
        }
        // 若是纯 base64 形式（无 @），则是 ss://BASE64(method:password@host:port)
        let frag = hostPort.split(separator: "#", maxSplits: 1)
        let hp = frag[0].split(separator: ":")
        let host = hp.first.map(String.init) ?? ""
        let port = hp.count > 1 ? Int(String(hp[1]).split(separator: "/").first.map(String.init) ?? "0") ?? 0 : 0
        let name = frag.count > 1 ? String(frag[1]) : "SS"
        var cipher = "aes-256-gcm"
        var pwd = ""
        if let decoded = b64(methodPass.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")) {
            let mp = decoded.split(separator: ":", maxSplits: 1)
            if mp.count == 2 { cipher = String(mp[0]); pwd = String(mp[1]) }
        }
        return ServerProfile(groupID: groupID, name: name, protocolType: .shadowsocks,
            address: host, port: port, uuid: "", password: pwd, cipher: cipher,
            sni: "", network: "tcp", path: "", alpn: "", flow: "", publicKey: "",
            settingsJson: "", remark: name, raw: uri)
    }

    private static func parseHysteria2(_ uri: String, groupID: String) throws -> ServerProfile {
        let body = String(uri.dropFirst(uri.hasPrefix("hy2://") ? "hy2://".count : "hysteria2://".count))
        let frag = body.split(separator: "#", maxSplits: 1)
        let hp = String(frag[0])
        let name = frag.count > 1 ? String(frag[1]) : "Hysteria2"
        let hpc = hp.split(separator: "@", maxSplits: 1)
        let hostPort = hpc.count > 1 ? hpc[1] : Substring(hp)
        let hp2 = hostPort.split(separator: ":")
        let host = hp2.first.map(String.init) ?? ""
        let port = hp2.count > 1 ? Int(hp2[1]) ?? 0 : 0
        let pwd = hpc.count > 1 ? String(hpc[0]) : ""
        return ServerProfile(groupID: groupID, name: name, protocolType: .hysteria2,
            address: host, port: port, uuid: "", password: pwd, cipher: "",
            sni: "", network: "udp", path: "", alpn: "", flow: "", publicKey: "",
            settingsJson: "", remark: name, raw: uri)
    }
}