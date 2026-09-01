import Foundation
import NetworkExtension

/// PacketTunnelProvider 专用协议配置（必须子类化 NEVPNProtocol 保存自定义配置）
private final class V2rayTunnelProtocol: NEVPNProtocol {}

final class VpnManager: ObservableObject {
    @Published var status: NEVPNStatus = .disconnected
    private let manager = NEVPNManager.shared()
    private let tunnelBundleID = "com.v2raynos.app.packet-tunnel"

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged), name: .NEVPNStatusDidChange, object: nil)
    }

    var isConnected: Bool { manager.connection.status == .connected }

    /// 连接：把 Xray JSON 塞进 providerConfiguration，让扩展端读取
    func connect(configJSON: String) {
        let proto = V2rayTunnelProtocol()
        proto.providerBundleIdentifier = tunnelBundleID
        proto.serverAddress = "v2raynos"
        proto.providerConfiguration = ["xrayConfig": configJSON]
        proto.disconnectOnSleep = false

        manager.protocolConfiguration = proto
        manager.localizedDescription = "V2raynos"
        manager.isEnabled = true

        manager.saveToPreferences { [weak self] err in
            if err != nil { print("save err: \(err!.localizedDescription)"); return }
            self?.manager.loadFromPreferences { err2 in
                if err2 != nil { print("load err"); return }
                do { try self?.manager.connection.startVPNTunnel() } catch { print("start err: \(error)") }
            }
        }
    }

    func disconnect() { manager.connection.stopVPNTunnel() }

    @objc private func statusChanged() {
        DispatchQueue.main.async { self.status = self.manager.connection.status }
    }
}