#!/usr/bin/env bash
# Signs an APK built by tools/build-apk.sh (zipalign + apksigner).
#
#   tools/sign-apk.sh dist/saldo-X.Y.Z-arm64-v8a-unsigned.apk
#
# Release key, from the environment (GitHub Actions secrets):
#   ANDROID_KEYSTORE_BASE64   base64 of the .jks/.keystore (tools/create-android-keystore.sh)
#   ANDROID_KEYSTORE_PASSWORD keystore password
#   ANDROID_KEY_ALIAS         key alias (default: saldo)
#   ANDROID_KEY_PASSWORD      key password (default: the keystore password)
# Or point ANDROID_KEYSTORE_FILE at a keystore on disk instead of the base64.
#
# Without a release key it falls back to a throwaway debug key and names the
# file *-debug-key.apk: it installs, but Android refuses to update it in place
# with an APK signed by another key (uninstall first, losing the app's data).
set -euo pipefail

# --docker: run inside KDE's Android image (has build-tools) instead of the host.
if [ "${1:-}" = "--docker" ]; then
    shift
    SRC="$(cd "$(dirname "$0")/.." && pwd)"
    rel="$(realpath --relative-to="$SRC" "${1:?usage: $0 --docker <unsigned.apk>}")"
    exec docker run --rm -v "$SRC":/src \
        -e ANDROID_KEYSTORE_BASE64 -e ANDROID_KEYSTORE_PASSWORD -e ANDROID_KEY_ALIAS -e ANDROID_KEY_PASSWORD \
        ${ANDROID_KEYSTORE_FILE:+-v "$ANDROID_KEYSTORE_FILE":/keystore:ro -e ANDROID_KEYSTORE_FILE=/keystore} \
        invent-registry.kde.org/sysadmin/ci-images/android-qt611:latest bash /src/tools/sign-apk.sh "/src/$rel"
fi

in="${1:?usage: $0 <unsigned.apk>}"
out="${in%-unsigned.apk}.apk"

# build-tools ships zipalign and apksigner (KDE's image sets ANDROID_HOME).
BT="${ANDROID_HOME:-/opt/android-sdk}/build-tools/${ANDROID_BUILD_TOOLS_REVISION:-$(ls "${ANDROID_HOME:-/opt/android-sdk}/build-tools" | sort -V | tail -1)}"
ZIPALIGN="$BT/zipalign"
APKSIGNER="$BT/apksigner"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

keystore="${ANDROID_KEYSTORE_FILE:-}"
if [ -z "$keystore" ] && [ -n "${ANDROID_KEYSTORE_BASE64:-}" ]; then
    keystore="$tmpdir/release.keystore"
    printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$keystore"
fi

if [ -n "$keystore" ]; then
    alias="${ANDROID_KEY_ALIAS:-saldo}"
    storepass="${ANDROID_KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD is required with a release keystore}"
    keypass="${ANDROID_KEY_PASSWORD:-$storepass}"
else
    echo "warning: no release keystore configured; signing with a throwaway debug key." >&2
    echo "         Updates over a previous install will fail. See tools/create-android-keystore.sh." >&2
    keystore="$tmpdir/debug.keystore"
    alias="debug"
    storepass="android"
    keypass="android"
    keytool -genkeypair -keystore "$keystore" -alias "$alias" -storepass "$storepass" -keypass "$keypass" \
        -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Saldo debug" >/dev/null 2>&1
    out="${in%-unsigned.apk}-debug-key.apk"
fi

"$ZIPALIGN" -p -f 4 "$in" "$tmpdir/aligned.apk"
# Passwords go through environment variables, never on the command line.
SALDO_STOREPASS="$storepass" SALDO_KEYPASS="$keypass" \
    "$APKSIGNER" sign --ks "$keystore" --ks-key-alias "$alias" \
    --ks-pass env:SALDO_STOREPASS --key-pass env:SALDO_KEYPASS \
    --out "$out" "$tmpdir/aligned.apk"
"$APKSIGNER" verify --print-certs "$out" | head -3
rm -f "$out.idsig"
echo "Signed: $out"
