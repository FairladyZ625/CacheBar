#!/usr/bin/env bash
# 组出 dist/CacheBar.app 并 ad-hoc 签名（无 Apple 开发者证书，不做公证）。
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/CacheBar.app"
CONTENTS="$APP/Contents"

swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS"
cp .build/release/CacheBar "$CONTENTS/MacOS/CacheBar"
cp packaging/Info.plist "$CONTENTS/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP"
