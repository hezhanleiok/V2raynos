#!/bin/bash
# build_xray_ios.sh — 把 AndroidLibXrayLite (Xray-core gomobile bind) 编成 iOS framework
# 用法: bash build_xray_ios.sh <repo路径> <输出目录> [git tag，默认 v26.8.20]
set -e
REPO="$1"
OUT="$2"
TAG="${3:-v26.8.20}"
if [ -z "$REPO" ] || [ -z "$OUT" ]; then echo "用法: build_xray_ios.sh <repo> <out> [tag]"; exit 1; fi
# 让 OUT 与 REPO 无关：相对路径按当前目录绝对化
if [[ "$OUT" != /* ]]; then OUT="$(pwd)/$OUT"; fi
cd "$REPO"
export GOTOOLCHAIN=auto
export PATH="$(go env GOPATH 2>/dev/null)/bin:$HOME/go/bin:$PATH"

echo "== 切到稳定 tag: $TAG =="
if [ -n "$TAG" ]; then
  git fetch --depth 1 origin tag "$TAG" >/dev/null 2>&1 || echo "warning: tag $TAG 拉取失败，使用当前HEAD"
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then git checkout -q "refs/tags/$TAG"; fi
fi

echo "== go version =="
go version
echo "== 下载依赖 =="
go mod download || { echo "go mod download 失败，尝试 go mod tidy"; go mod tidy; }

echo "== 确认 gomobile =="
which gomobile >/dev/null 2>&1 || go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

echo "== bind 出 iOS device framework (arm64) =="
mkdir -p "$OUT"
gomobile bind -target=ios -o "$OUT/XrayCore.xcframework" .
echo "完成: $OUT/XrayCore.xcframework"