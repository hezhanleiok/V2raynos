# V2raynos 实现原理与逻辑说明

> 这是一份「能看懂、能照着改」的原理文档。重点讲：整体原理、数据流、启动/停止逻辑、配置生成、内核与 TUN 桥接、以及每个文件是干什么的。

## 1. 整体原理（三层）

V2raynos 在 iOS 上复刻 v2rayNG，本质是「三层协作」：

~~~
SwiftUI App（UI 层）
   管理服务器/订阅/路由/设置，生成 Xray 配置
   通过 NEVPNManager 拉起下面的 Network Extension
        │
        ▼
PacketTunnelProvider（Network Extension）
   建立系统级 TUN（虚拟网卡）
   启动 Xray 核心（gomobile bind 的框架）
   用 hev-socks5-tunnel 把 TUN 流量桥进核心
        │
        ▼
Xray-core（Go）—— VLESS/VMess/Trojan/SS/Hysteria2/WireGuard
~~~

## 2. 一条数据包是怎么走的（核心数据流）

1. 手机上某个 App 发起网络请求，例如访问 example.com。
2. iOS 系统发现用户已开启 VPN，把这条流量交给我们的 PacketTunnelProvider 持有的 TUN 虚拟网卡。
3. PacketTunnelProvider 从 packetFlow 读取原始 IP 包（readPacket）。
4. 这些包被交给 hev-socks5-tunnel：它把 IP 包解析、按规则做路由，转成 SOCKS5 连接交给代理端口。
5. Xray 核心（gomobile bind 的 XrayCore.xcframework）接收 SOCKS5 请求，按配置中的出站协议（VLESS/Trojan/…）加密后发往远程节点。
6. 远端返回的数据原路返回：Xray → hev-socks5-tunnel → packetFlow 写回虚拟网卡 → 手机 App。

> 关键：iOS 上「TUN 虚拟网卡」由 Network Extension 提供；Android 里是 VpnService。这是 iOS/Android 最大的平台差异，也是必须写 Extension 的原因。

## 3. 启动流程逻辑（一次“连接”压到底）

~~~
用户点“连接”
  → App 端：从当前分组取当前服务器 Profile
  → ConfigGenerator 把 Profile/订阅/路由 生成 Xray JSON 配置字符串
  → Store 持久化（最近使用、配置）
  → VpnManager.connect() 调 NEVPNManager
        ├─ 设置 protocolConfiguration（扩展 Bundle ID + 把配置塞进 providerConfiguration）
        ├─ 授权 Personal VPN（首次弹系统授权）
        └─ manager.startVPNTunnel() → iOS 启动 PacketTunnelProvider
  → PacketTunnelProvider.startTunnel(options:)
        ├─ 从 providerConfiguration 读出 JSON 配置
        ├─ 初始化 Xray 核心：InitCoreEnv(配置目录, key)
        ├─ 建立 TUN 虚拟网卡（packetFlow）
        ├─ 创建 CoreController，调 StartLoop(configJSON, tunFd) 启动 Xray
        ├─ 连接 hev-socks5-tunnel 到 TUN 与内核，启动主循环
        └─ 上报 .connected，packetFlow 开始收发
~~~

## 4. 停止流程逻辑

~~~
用户点“断开”
  → VpnManager.disconnect() → manager.stopVPNTunnel()
  → PacketTunnelProvider.stopTunnel() 被调用
        ├─ 停 hev-socks5-tunnel 主循环、关闭 TUN fd
        ├─ CoreController.StopLoop() 停 Xray 核心
        └─ cancelTunnel() 上报 .disconnected
~~~

## 5. Xray JSON 配置是怎么生成的（ConfigGenerator）

Xray 核心只认一份标准 JSON 配置。ConfigGenerator 的作用是把「用户友好的 Profile」翻译成「Xray 能跑的 JSON」，核心三段：

- outbounds：最主要的出站。根据协议类型（VLESS/Trojan/SS…）生成对应字段：
  protocol: vless, settings.vnext, streamSettings(tcp/ws/grpc/xtls/tls reality…)。
  - VLESS: vnext[0].users[0].id = uuid, encryption: none
  - Trojan: password / troop header
  - Shadowsocks: method+password
  - 还有 socks/http 入站给 hev 桥接用。
- inbounds：本地入站。常用 socks:127.0.0.1:10808 和 dokodemo:127.0.0.1:10809, listen 0.0.0.0。
  hev-socks5-tunnel 就把出站流量连到这里的 SOCKS 入站。
- routing：路由规则。把需要走代理的（geosite 之类）与直连的（局域网/国内）分开，domainStrategy、rules。
- dns：DNS 设置。

## 6. 内核桥接逻辑（关键难点）

AndroidLibXrayLite 是一个 Go 包，用 gomobile bind -target=ios 编成 Xcode 框架。Swift 里依赖它：

~~~
let handler = XrayCoreCallbackHandler { ... }   // 回调：Startup/Shutdown/OnEmitStatus
let ctrl = XrayCoreCoreController(handler: handler)
XrayCoreInitCoreEnv(configDir, key)
try ctrl.startLoop(configJSON, tunFd)   // tunFd 为 TUN 描述符；0 表示不建 TUN
try ctrl.stopLoop()
~~~

⚠️ 具体类名/方法名以 gomobile bind -target=ios -o XrayCore.xcframework . 实际输出的头文件为准；本工程的 XrayBridge 封装了这些调用，若名字不同，只需改 XrayBridge 一处。

## 7. 工程结构 & 文件职责

| 文件 | 职责 |
|------|------|
| V2raynosApp.swift | App 入口，注入 Store/ViewModel |
| ContentView.swift | 主导航（TabBar） |
| Views/MainView.swift | 主界面：服务器列表、当前节点、连接/断开 |
| Views/ServerEditorView.swift | 协议编辑（VLESS/Trojan/SS…） |
| Views/SubscriptionView.swift | 订阅管理 |
| Views/RoutingView.swift | 路由规则 |
| Views/SettingsView.swift | 全局设置 |
| Views/LogsView.swift | 运行日志 |
| Views/AboutView.swift | 关于/版本 |
| Models/* | Profile / Group / Subscription / RoutingRule 数据模型 |
| Services/ProfileParser.swift | 解析 vmess:// vless:// ss:// trojan:// 等 URI |
| Services/ConfigGenerator.swift | Profile→Xray JSON |
| Services/VpnManager.swift | NEVPNManager 拉起/断开扩展 |
| Services/XrayBridge.swift | 调用 gomobile 内核（可被扩展端复用） |
| Services/Store.swift | 持久化（UserDefaults/文件） |
| PacketTunnel/PacketTunnelProvider.swift | Network Extension：TUN+内核+桥接主循环 |
| project.yml | xcodegen 生成 Xcode 工程（App+Extension 双 target） |
| scripts/* | 内核框架 / .ipa 构建脚本 |
| .github/workflows/ios-build.yml | 云端自动构建出 .ipa |

## 8. 你需要重点在真机/云端验证的点（风险清单）

1. gomobile 输出框架的真实类名/签名，与 XrayBridge 对齐。
2. go.mod 里 Xray-core 为预发布版、go 1.26，CI 需装匹配 Go 工具链。
3. TUN fd 的创建与传给 Xray、以及 hev 桥接在 iOS 上的行为，必须在真机验证（未签名 .ipa + 越狱设备）。
4. Network Extension 的 VPN entitlement（com.apple.developer.networking.vpn.api）在未签名构建下不嵌入，越狱侧通过 AppSync 绕开。

## 9. 一句话总结

> UI 管「配置与开关」，Extension 管「系统级 TUN」，Xray 管「加密协议」，hev 管「TUN↔核心的路由桥」。四样拼起来，就是 v2rayNG 在 iOS 上的等价实现。
