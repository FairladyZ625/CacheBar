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
if [[ -n "${CACHEBAR_SIGN_IDENTITY+x}" ]]; then
	SIGN_IDENTITY="$CACHEBAR_SIGN_IDENTITY"
elif security find-identity -v "$(security login-keychain 2>/dev/null | tr -d '\"')" 2>/dev/null | grep -Fq 'CacheBar Local Signing'; then
	SIGN_IDENTITY="CacheBar Local Signing"
else
	SIGN_IDENTITY="-"
	echo "No local signing identity found; using ad-hoc signing. See docs/signing.md to set one up."
fi

codesign --force --sign "$SIGN_IDENTITY" "$APP"

echo "Built $APP"
