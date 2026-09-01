# V2raynos — iOS 端 V2rayNG 复刻 构建方案

## 0. 目标
做一款 iOS App，**内核、功能与 v2rayNG 1:1 一致**，UI 改造成 iOS 风格。
不上架 App Store，通过**云端构建出 .ipa → 越狱设备安装**（不依赖付费开发者账号 / TestFlight）。

## 1. 内核（已核实，来自 v2rayNG 源码）
现代版 v2rayNG 的**真实内核不是 v2ray-core，而是两件套**：

| 组件 | 作用 | 语言 | iOS 构建方式 |
|------|------|------|------------|
| **Xray-core** | 代理协议引擎（VLESS/VMess/Trojan/SS/Hysteria2/WireGuard…） | Go | `AndroidLibXrayLite` 的 gomobile bind → iOS XCFramework |
| **hev-socks5-tunnel** | TUN 透明代理路由，把系统流量代理进核心 | C | `build-apple.sh` → iOS 静态库/XCFramework |

已拉取到 `E:\ios`：
- `v2ray-core\`（备用，现代 v2rayNG 已不用，可忽略）
- `v2rayNG\`（Android 客户端源码，作功能/界面对照）
- `AndroidLibXrayLite\`（Xray-core 的 gomobile bind，**内核核心**）
- `hev-socks5-tunnel\`（TUN 路由，自带 `build-apple.sh`/`module.modulemap`）

`AndroidLibXrayLite/libv2ray_main.go` 的关键 bind API：
```
InitCoreEnv(envPath, key)
NewCoreController(handler) *CoreController
CoreController.StartLoop(configContent string, tunFd int32) error   // tunFd=0 表示不建 TUN
CoreController.StopLoop() error
CheckVersionX() string
```

## 2. v2rayNG 全部功能清单（来自 V2rayNG/app/src/main/java/com/v2ray/ang/ui/）
```
main/                  主界面：服务器列表、当前节点、分组 Tab、导入菜单、顶栏/抽屉/对话框
server/                服务器编辑：
  ServerVmessActivity / ServerVlessActivity / ServerTrojanActivity /
  ServerShadowsocksActivity / ServerSocksActivity / ServerHysteria2Activity /
  ServerWireguardActivity / ServerHttpActivity / ServerProxyChainActivity
  ServerGroupActivity（分组）/ ServerCustomConfigActivity（自定义 JSON）
subscription/          订阅管理（SubEditActivity / SubSettingActivity）
routing/               路由规则（RoutingSettingActivity / RoutingEditActivity）
settings/              全局设置（SettingsActivity）
backup/                备份/恢复（BackupActivity）
logcat/                运行日志（LogcatActivity）
userasset/             用户资产 geosite/geoip（UserAssetActivity）
ScannerActivity        扫码导入 / ScScannerActivity
TranslatorsActivity    配置翻译
UrlSchemeActivity      深链导入
AboutActivity          关于/版本
checkupdate/           更新检查
```
Android 专属、iOS 需另处理：`perappproxy/`（分应用代理，iOS 无对应 API）、`apppicker/`（应用选择）、`shortcut/` 与 `TaskerActivity`（快捷方式）。

## 3. iOS 架构（与 v2rayNG 内核同源）
```
SwiftUI App（iOS 风格 UI，复刻上面的每一屏）
        │  控制 启动/停止/配置
        ▼
Network Extension（NEPacketTunnelProvider）
        │  xray 核心（XCFramework，由 AndroidLibXrayLite gomobile bind）
        │  hev-socks5-tunnel（静态库，build-apple.sh）做 TUN<->核心桥接
        ▼
系统级 TUN → 全流量代理
```

## 4. 构建产物管线（0 成本：不用 Mac/付费账号/审核）
1. `gomobile bind -target=ios -o XrayCore.xcframework`（在 AndroidLibXrayLite）
2. `./build-apple.sh`（在 hev-socks5-tunnel，产出 `HevSocks5Tunnel.xcframework`）
3. `xcodegen` 依据 `project.yml` 生成 Xcode 工程（App + Network Extension）
4. `xcodebuild ... CODE_SIGNING_ALLOWED=NO` 生产未签名 `.app`
5. 打包成 `Payload/V2raynos.app` → `V2raynos.ipa`（越狱装用）
6. GitHub Actions（macos runner）自动完成 1-5，产出 `.ipa` 供下载

> 未签名 .ipa 需在越狱设备上搭配 AppSync Unified 使用 Sideloadly 等工具安装。

## 5. 待办与风险
- go.mod 中 Xray-core 依赖为预发布版本、`go 1.26`，CI 需装匹配的 Go 工具链，首次 `go mod download` 可能需拉多次。
- iOS Network Extension 的 TUN 桥接、进程间传 fd，需真机验证（越狱/设备调试）。
- 复刻 UI 采用 SwiftUI；逐屏对照 v2rayNG 源码实现，工作量较大，分阶段完成。
