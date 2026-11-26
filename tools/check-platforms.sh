#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Where a release runs, for the README tables ("Onde roda"; CLAUDE.md,
# "Supported platforms"; the release skill runs it for each new X.Y series):
# tools/test-package.sh on every distribution release the README lists, the
# unsupported ones too (to confirm they still fail), and the APK's minimum
# Android version.
#
#   tools/check-platforms.sh [X.Y.Z]   default: the version in CMakeLists.txt
#
# Packages: from the GitHub release vX.Y.Z (gh, logged in), or from the folder
# SALDO_PLATFORMS_DIR (e.g. dist/, after tools/build-packages.sh). Needs docker.
set -euo pipefail

SRC=$(cd "$(dirname "$0")/.." && pwd)
REPO=hernique33comiitei/saldo
version=${1:-$(grep -oP 'project\(saldo VERSION \K[0-9.]+' "$SRC/CMakeLists.txt")}
ANDROID_IMAGE=invent-registry.kde.org/sysadmin/ci-images/android-qt611:latest

# The README's rows, oldest first in each family.
IMAGES=(fedora:41 fedora:42 fedora:43 fedora:44 fedora:45
        debian:12 debian:13 debian:testing
        ubuntu:22.04 ubuntu:24.04 ubuntu:26.04 ubuntu:26.10)

dir=${SALDO_PLATFORMS_DIR:-}
if [ -z "$dir" ]; then
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' EXIT
    echo "Downloading the v$version packages…"
    gh release download "v$version" -R "$REPO" -D "$dir" -p '*.x86_64.rpm' -p '*_amd64.deb' -p '*.apk'
fi

results=()
for image in "${IMAGES[@]}"; do
    docker pull -q "$image" >/dev/null 2>&1 || true
    if SALDO_TEST_VERSION=$version "$SRC/tools/test-package.sh" "$image" "$dir"; then
        results+=("$image ✅")
    else
        results+=("$image ❌")
    fi
done

apk=$(ls "$dir"/saldo-*.apk 2>/dev/null | grep -v dev | head -1 || true)
sdk=""
if [ -n "$apk" ]; then
    chmod a+r "$apk"
    sdk=$(docker run --rm -v "$(dirname "$apk")":/pkgs:ro --entrypoint sh "$ANDROID_IMAGE" \
          -c "/opt/android-sdk/build-tools/*/aapt2 dump badging /pkgs/$(basename "$apk")" \
          | grep -oP "^(minSdkVersion|sdkVersion):'\K[0-9]+" | head -1 || true)
fi

echo
echo "Saldo $version"
printf '  %s\n' "${results[@]}"
case "$sdk" in
    26) android="Android 8" ;; 27) android="Android 8.1" ;; 28) android="Android 9" ;;
    29) android="Android 10" ;; 30) android="Android 11" ;; 31) android="Android 12" ;;
    "") android="no APK checked" ;; *) android="API $sdk" ;;
esac
echo "  APK: minSdkVersion ${sdk:-?} ($android or newer)"
