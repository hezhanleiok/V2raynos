import NetworkExtension
import XrayCore

/// Network Extension：iOS 端唯一的“系统级代理”入口。
/// 职责：1) 建立虚拟网卡(TUN)  2) 启动 Xray 核心(socks 入站)  3) hev-socks5-tunnel 桥接 TUN <-> Xray
class PacketTunnelProvider: NEPacketTunnelProvider {
    private var bridge: XrayBridge?
    private var hevThread: Thread?

    /// 本地 Xray socks 入站端口（与 ConfigGenerator 默认一致，hev 指向它）
    private let socksPort = 10808

    override func startTunnel(options: [String : NSObject]?) async throws {
        guard let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
              let cfg = tunnelProtocol.providerConfiguration?["xrayConfig"] as? String else {
            NSLog("[v2raynos] 拿到配置失败")
            throw NSError(domain: "v2raynos", code: 1, userInfo: [NSLocalizedDescriptionKey: "no xray config"])
        }

        // 1) 建立虚拟网卡网络设置（对应 v2rayNG 的 VpnService）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        settings.mtu = NSNumber(value: 1500)
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.0.0"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        // 2) 应用网络设置（async/await）
        try await setTunnelNetworkSettings(settings)

        // 3) 启动 Xray 核心（本地 SOCKS 入站 10808；tunFd=0：Xray 不直接碰 TUN）
        let bridge = XrayBridge()
        self.bridge = bridge
        bridge.setup(envPath: configDirPath(), key: "")
        do {
            try bridge.start(configJSON: cfg, tunFd: 0)
            NSLog("[v2raynos] Xray core started, socks 127.0.0.1:10808")
        } catch {
            NSLog("[v2raynos] Xray start failed")
            throw error
        }

        // 4) 启动 hev-socks5-tunnel：TUN fd <-> Xray socks 入站
        guard let tunFd = tunFileDescriptor() else {
            NSLog("[v2raynos] 无法获取 TUN fd")
            throw NSError(domain: "v2raynos", code: 2, userInfo: [NSLocalizedDescriptionKey: "no tun fd"])
        }
        let yaml = hevConfig()
        let thread = Thread { [weak self] in
            guard self != nil else { return }
            let bytes = Array(yaml.utf8)
            let r = bytes.withUnsafeBufferPointer { buf -> Int32 in
                hev_socks5_tunnel_main_from_str(buf.baseAddress, UInt32(bytes.count), Int32(tunFd))
            }
            NSLog("[v2raynos] hev tunnel exited")
        }
        thread.name = "hev-socks5-tunnel"
        thread.start()
        hevThread = thread
    }

    /// KVC 取 packetFlow 的 utun 文件描述符（iOS 无公开 API，业内通行做法）
    private func tunFileDescriptor() -> Int32? {
        let flow: AnyObject = packetFlow
        guard let fdAny = flow.value(forKeyPath: "socket.fileDescriptor") else { return nil }
        if let fd = fdAny as? Int32 { return fd }
        if let fd = fdAny as? Int { return Int32(fd) }
        return nil
    }

    /// hev 配置（YAML）：tunnel 用已建网卡的参数，socks5 指向 Xray 入站
    private func hevConfig() -> String {
        let y = [
            "tunnel:",
            "  name: tun0",
            "  mtu: 1500",
            "  multi-queue: false",
            "  ipv4: 198.18.0.1",
            "  ipv6: fc00::1",
            "  icmp: reply",
            "socks5:",
            "  port: 10808",
            "  address: 127.0.0.1",
            "  udp: udp",
            "misc:",
            "  log-file: null",
            "  log-level: info",
        ]
        return y.joined(separator: "\n") + "\n"
    }

    private func configDirPath() -> String {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return doc.path
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        hev_socks5_tunnel_quit()
        bridge?.stop()
    }
}