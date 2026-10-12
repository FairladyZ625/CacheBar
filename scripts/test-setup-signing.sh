#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

TEMP_DIR="$(mktemp -d)"
KEYCHAIN="$TEMP_DIR/cachebar-test.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
cleanup() {
	security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
	find "$TEMP_DIR" -type f -delete
	rmdir "$TEMP_DIR"
}
trap cleanup EXIT

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
export CACHEBAR_SIGN_KEYCHAIN="$KEYCHAIN"

scripts/setup-signing.sh --yes
scripts/setup-signing.sh --yes
scripts/build-app.sh
AUTHORITY="$(codesign -dv --verbose=2 dist/CacheBar.app 2>&1 | sed -n 's/^Authority=//p' | head -n 1)"
[[ "$AUTHORITY" == "CacheBar Local Signing" ]]
echo "Verified codesign Authority=$AUTHORITY"
scripts/setup-signing.sh --yes --remove
scripts/setup-signing.sh --yes --remove
echo "Temporary-keychain setup-signing end-to-end test passed."
