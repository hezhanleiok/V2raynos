#!/bin/bash
# build_ipa.sh — 把未签名 .app 打包成可供越狱安装的 .ipa
# 用法: bash build_ipa.sh <V2raynos.app路径> <输出目录>
set -e
APP="$1"
OUT="$2"
if [ -z "$APP" ] || [ -z "$OUT" ]; then echo "usage: build_ipa.sh <app> <out>"; exit 1; fi
mkdir -p Payload
rm -rf Payload/* "$OUT/V2raynos.ipa"
cp -R "$APP" Payload/
ditto -c -k --keepParent Payload "$OUT/V2raynos.ipa"
echo "done: $OUT/V2raynos.ipa"