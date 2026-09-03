import Foundation
import NetworkExtension
import Combine

/// NETunnel Provider 版 VPN 管理（NEVPNManager 只管传统 VPN，拉不起 Packet Tunnel 扩展）
final class VpnManager: ObservableObject {
    @Published var status: NEVPNStatus = .disconnected
    @Published var lastError: String? = nil

    private var manager: NETunnelProviderManager?
    private let tunnelBundleID = "com.v2raynos.app.packet-tunnel"

    init() {
        reloadManagers()
        NotificationCenter.default.addObserver(self, selector: #selector(statusChanged(_:)), name: .NEVPNStatusDidChange, object: nil)
    }

    var isConnected: Bool { status == .connected }

    /// 读取系统 VPN 配置；返回空数组则新建实例并保存
    private func reloadManagers(completion: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            let existing = managers?.first(where: { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.tunnelBundleID })
            if let existing = existing {
                self.manager = existing
                DispatchQueue.main.async { self.status = existing.connection.status }
                completion?()
            } else {
                // 空数组：新建并保存
                let m = NETunnelProviderManager()
                let proto = NETunnelProviderProtocol()
                proto.providerBundleIdentifier = self.tunnelBundleID
                proto.serverAddress = "v2raynos"
                proto.providerConfiguration = ["xrayConfig": "{}"]
                m.protocolConfiguration = proto
                m.localizedDescription = "V2raynos"
                m.isEnabled = true
                m.saveToPreferences { _ in
                    m.loadFromPreferences { _ in
                        self.manager = m
                        completion?()
                    }
                }
                if let error = error {
                    DispatchQueue.main.async { self.lastError = "读取 VPN 配置提示：" + error.localizedDescription }
                }
            }
        }
    }

    /// 连接：写入配置 → 保存 → 载入 → startVPNTunnel(options:)
    func connect(configJSON: String) {
        lastError = nil
        if let m = manager {
            apply(configJSON: configJSON, to: m)
        } else {
            reloadManagers { [weak self] in
                guard let self = self else { return }
                if let m = self.manager {
                    self.apply(configJSON: configJSON, to: m)
                } else {
                    DispatchQueue.main.async { self.lastError = "VPN 配置未就绪，请再点一次启动" }
                }
            }
        }
    }

    private func apply(configJSON: String, to m: NETunnelProviderManager) {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleID
        proto.serverAddress = "v2raynos"
        proto.providerConfiguration = ["xrayConfig": configJSON]
        m.protocolConfiguration = proto
        m.localizedDescription = "V2raynos"
        m.isEnabled = true
        m.saveToPreferences { [weak self] err in
            guard let self = self else { return }
            if let err = err {
                DispatchQueue.main.async { self.lastError = "保存 VPN 配置失败：" + err.localizedDescription }
                return
            }
            m.loadFromPreferences { err2 in
                if let err2 = err2 {
                    DispatchQueue.main.async { self.lastError = "载入 VPN 配置失败：" + err2.localizedDescription }
                    return
                }
                do {
                    try m.connection.startVPNTunnel(options: [:])
                } catch {
                    DispatchQueue.main.async { self.lastError = "启动 VPN 失败：" + error.localizedDescription }
                }
            }
        }
    }

    func disconnect() { manager?.connection.stopVPNTunnel() }

    @objc private func statusChanged(_ n: Notification) {
        guard let conn = n.object as? NEVPNConnection else { return }
        DispatchQueue.main.async { self.status = conn.status }
    }
}