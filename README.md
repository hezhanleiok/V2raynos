# V2raynos

iOS 端 V2rayNG 复刻项目：Xray-core 内核 + hev-socks5-tunnel TUN 路由 + SwiftUI iOS 风格 UI，功能与 v2rayNG 对齐，不上架 App Store，走「云端构建 .ipa → 越狱安装」。

## 目录
- BUILD_PLAN.md — 构建方案 / 功能清单
- PRINCIPLES.md — **原理/步骤/逻辑说明**（先读这个）
- project.yml — xcodegen 工程定义（App + PacketTunnel 双 target）
- scripts/ — 内核与 .ipa 构建脚本
- .github/workflows/ios-build.yml — 云端自动构建

## 快速开始（云端构建，无需 Mac）

1. 把 V2raynos/ 推到你的 GitHub 仓库。
2. 放好内核子模块：AndroidLibXrayLite、hev-socks5-tunnel（或其路径）。
3. 触发 ios-build workflow，macos runner 会自动：
   - build_xray_ios.sh → frameworks/XrayCore.xcframework
   - build_hev_ios.sh → frameworks/HevSocks5Tunnel.xcframework
   - xcodegen generate → 生成 .xcodeproj
   - xcodebuild ... CODE_SIGNING_ALLOWED=NO → 未签名 .app
   - 打包成 V2raynos.ipa（Artifact 下载）
4. 越狱 iPhone 装 AppSync Unified，用 Sideloadly 安装 V2raynos.ipa。

## 本机（Windows）当前状态
E:\ios 已拉取：AndroidLibXrayLite、hev-socks5-tunnel、v2rayNG(对照)。本机无 Go/无 Xcode，编译在云端 macOS 上进行。
