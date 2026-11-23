#!/usr/bin/env bash
# Creates the release keystore that signs every Saldo APK, once.
#
# All APKs must be signed with the same key, or Android refuses to install a
# new version over the old one. The keystore stays OUTSIDE the repository; the
# release workflow gets it from GitHub Actions secrets:
#
#   ANDROID_KEYSTORE_BASE64    (printed by this script)
#   ANDROID_KEYSTORE_PASSWORD  (the password you type below)
#
# Back the keystore and its password up (e.g. in your password manager):
# losing them means users must uninstall to get the next version.
set -euo pipefail

KEYSTORE="${1:-$HOME/.local/share/saldo-signing/saldo-release.keystore}"
if [ -e "$KEYSTORE" ]; then
    echo "$KEYSTORE already exists; refusing to overwrite it." >&2
    exit 1
fi
mkdir -p "$(dirname "$KEYSTORE")"
chmod 700 "$(dirname "$KEYSTORE")"

# keytool asks for the password interactively (and never echoes it).
keytool -genkeypair -v \
    -keystore "$KEYSTORE" -storetype PKCS12 \
    -alias saldo -keyalg RSA -keysize 4096 -validity 36500 \
    -dname "CN=Henrique Oliveira, O=Saldo, C=BR"
chmod 600 "$KEYSTORE"

echo
echo "Keystore: $KEYSTORE"
echo "Add these GitHub Actions secrets (repo → Settings → Secrets and variables → Actions):"
echo "  ANDROID_KEYSTORE_BASE64   = output of: base64 -w0 '$KEYSTORE'"
echo "  ANDROID_KEYSTORE_PASSWORD = the password you just typed"
echo "With the GitHub CLI:"
echo "  base64 -w0 '$KEYSTORE' | gh secret set ANDROID_KEYSTORE_BASE64 -R hernique33comiitei/saldo"
echo "  gh secret set ANDROID_KEYSTORE_PASSWORD -R hernique33comiitei/saldo"
