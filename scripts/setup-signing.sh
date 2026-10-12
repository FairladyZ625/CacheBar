#!/usr/bin/env bash
set -euo pipefail

NAME="CacheBar Local Signing"
KEYCHAIN="${CACHEBAR_SIGN_KEYCHAIN:-$(security login-keychain | sed -e 's/^[[:space:]]*"//' -e 's/"[[:space:]]*$//')}"
KEYCHAIN_LABEL="login keychain"
if [[ -n "${CACHEBAR_SIGN_KEYCHAIN:-}" ]]; then
	KEYCHAIN_LABEL="keychain '$KEYCHAIN'"
fi
REMOVE=0
YES=0

usage() {
	cat <<'EOF'
Usage: scripts/setup-signing.sh [--yes] [--remove]
  --yes     Skip confirmation
  --remove  Remove the local signing identity
EOF
}

for arg in "$@"; do
	case "$arg" in
		--yes) YES=1 ;;
		--remove) REMOVE=1 ;;
		-h|--help) usage; exit 0 ;;
		*) usage >&2; exit 2 ;;
	esac
done

if security find-identity "$KEYCHAIN" 2>/dev/null | grep -Fq "\"$NAME\""; then
	if (( REMOVE == 0 )); then
		echo "Signing identity '$NAME' already exists in the $KEYCHAIN_LABEL."
		exit 0
	fi
	ACTION="Remove '$NAME' from the $KEYCHAIN_LABEL."
else
	if (( REMOVE == 1 )); then
		echo "Signing identity '$NAME' was not found in the $KEYCHAIN_LABEL."
		exit 0
	fi
	ACTION="Create a 10-year self-signed code-signing identity named '$NAME' in the $KEYCHAIN_LABEL, allowing only /usr/bin/codesign to use its private key."
fi

echo "$ACTION"
if (( YES == 0 )); then
	read -r -p "Continue? [y/N] " answer
	[[ "$answer" == [yY] || "$answer" == [yY][eE][sS] ]] || { echo "Cancelled."; exit 1; }
fi

if (( REMOVE == 1 )); then
	security delete-identity -c "$NAME" "$KEYCHAIN"
	echo "Removed '$NAME'."
	exit 0
fi

TEMP_DIR="$(mktemp -d)"
cleanup() {
	find "$TEMP_DIR" -type f -delete
	rmdir "$TEMP_DIR"
}
trap cleanup EXIT
PASSWORD="$(openssl rand -hex 32)"
cat > "$TEMP_DIR/extensions.cnf" <<'EOF'
[req]
distinguished_name = subject
x509_extensions = signing
prompt = no
[subject]
CN = CacheBar Local Signing
[signing]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:FALSE
EOF

openssl req -new -newkey rsa:2048 -nodes -x509 -days 3650 \
	-config "$TEMP_DIR/extensions.cnf" \
	-keyout "$TEMP_DIR/key.pem" -out "$TEMP_DIR/cert.pem"
openssl pkcs12 -export -inkey "$TEMP_DIR/key.pem" -in "$TEMP_DIR/cert.pem" \
	-out "$TEMP_DIR/identity.p12" -passout "pass:$PASSWORD" -name "$NAME"
security import "$TEMP_DIR/identity.p12" -k "$KEYCHAIN" -f pkcs12 \
	-P "$PASSWORD" -T /usr/bin/codesign
echo "Created '$NAME' in the $KEYCHAIN_LABEL. No system trust settings were changed."
