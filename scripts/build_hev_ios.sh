#!/bin/bash
# build_hev_ios.sh — 只编 iOS 真机(arm64)切片，产出单个静态库，速度快
# 用法: bash build_hev_ios.sh <repo路径> <输出目录>
set -e
REPO="$1"
OUT="$2"
if [ -z "$REPO" ] || [ -z "$OUT" ]; then echo "用法: build_hev_ios.sh <repo> <out>"; exit 1; fi
if [[ "$OUT" != /* ]]; then OUT="$(pwd)/$OUT"; fi
cd "$REPO"

echo "== 初始化子模块（lwip/yaml/hev-task-system/core）=="
git submodule update --init --recursive

echo "== 只用 iphoneos arm64 编译（不编 simulator/macosx/tvos）=="
make PP="xcrun --sdk iphoneos --toolchain iphoneos clang" \
     CC="xcrun --sdk iphoneos --toolchain iphoneos clang" \
     CFLAGS="-arch arm64 -miphoneos-version-min=15.0" \
     LFLAGS="-arch arm64 -miphoneos-version-min=15.0 -Wl,-Bsymbolic-functions" static

echo "== 合并为单个静态库 =="
mkdir -p "$OUT"
libtool -static -o "$OUT/libhev-socks5-tunnel.a" \
    bin/libhev-socks5-tunnel.a \
    third-part/lwip/bin/liblwip.a \
    third-part/yaml/bin/libyaml.a \
    third-part/hev-task-system/bin/libhev-task-system.a
cp -f src/hev-main.h "$OUT/hev-main.h" 2>/dev/null || true

echo "完成: $OUT/libhev-socks5-tunnel.a"