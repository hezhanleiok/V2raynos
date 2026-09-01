import NetworkExtension
import XrayCore

/// Network Extension：iOS 端唯一的“系统级代理”入口。
/// 职责：1) 建立虚拟网卡(TUN)  2) 启动 Xray 核心  3) 在 packetFlow 与内核间收发数据包
class PacketTunnelProvider: NEPacketTunnelProvider {
    private var bridge: XrayBridge?
    private var stopped = false

    override func startTunnel(with options: [String : NSObject]?) {
        guard let cfg = protocolConfiguration.providerConfiguration?["xrayConfig"] as? String else {
            NSLog("[v2raynos] 拿到配置失败");
            cancelTunnel(withError: NSError(domain: "v2raynos", code: 1, userInfo: [NSLocalizedDescriptionKey: "no xray config"]));
            return
        }

        // 1) 建立虚拟网卡网络设置（对应 v2rayNG 的 VpnService）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        settings.mtu = NSNumber(value: 1500)
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.0.0"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")]
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.cancelTunnel(withError: error); return
            }
            // 2) 启动 Xray 核心（提供本地 SOCKS 入站，tunFd 传 0 表示由 hev 桥接）
            let bridge = XrayBridge()
            self.bridge = bridge
            bridge.setup(envPath: self.configDirPath(), key: "")
            do {
                try bridge.start(configJSON: cfg, tunFd: 0)
                NSLog("[v2raynos] Xray core started")
            } catch {
                NSLog("[v2raynos] core start err: \(error)");
                self.cancelTunnel(withError: error); return
            }
            // 3) 进入包收发循环（hev-socks5-tunnel 桥接 TUN <-> 内核 SOCKS）
            self.startPacketPump()
        }
    }

    private func configDirPath() -> String {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return doc.path
    }

    /// 在 packetFlow 与 TUN 之间搬运数据包。
    /// 这里通过 hev-socks5-tunnel（C，见 scripts/build_hev_ios.sh 编的框架）把
    /// packetFlow 读到的包转成 SOCKS5 请求发给 Xray 的本地入站；
    /// 实际调用会封装在 build_hev 产物提供的能力里，此处为骨架示意。
    private func startPacketPump() {
        let queue = DispatchQueue(label: "v2raynos.pump")
        queue.async { [weak self] in
            guard let self = self else { return }
            while !self.stopped {
                self.packetFlow.readPacketObjects { packets in
                    guard let self = self else { return }
                    if packets.isEmpty { return }
                    // 把读到的包交给 hev/xray 处理，得到 return 包后写回虚拟网卡
                    let out = self.handle(packets: packets)
                    self.packetFlow.writePackets(out.map { $0.data }, withProtocols: out.map { $0.protocolFamily })
                }
            }
        }
    }

    /// 骨架：真正的转发逻辑需要在真机上接 hev-socks5-tunnel / Xray SOCKS 入站
    private func handle(packets: [NEPacket]) -> [NEPacket] {
        // TODO(真机验证)：调用 HevSocks5Tunnel 处理读到的包，返回需写回的包
        return packets
    }

    override func stopTunnel(with reason: NEProviderStopReason) {
        stopped = true
        bridge?.stop()
        cancelTunnel(with: reason)
    }
}