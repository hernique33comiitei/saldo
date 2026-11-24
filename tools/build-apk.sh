#!/usr/bin/env bash
# Builds the Saldo Android APK (arm64-v8a) with KDE Craft, the way KDE's own
# CI does it, using prebuilt Qt/KF6 from KDE's Craft cache.
#
# Runs inside KDE's Android image; from the host use:
#   tools/build-apk.sh --docker      # same container as the release workflow
# Inside the container (what the workflow calls):
#   tools/build-apk.sh
#
# Output: dist/saldo-<version>-arm64-v8a-unsigned.apk  (sign it with tools/sign-apk.sh)
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="invent-registry.kde.org/sysadmin/ci-images/android-qt611:latest"
TARGET="${CRAFT_TARGET:-android-arm64-clang}"

if [ "${1:-}" = "--docker" ]; then
    # Craft's downloads and cache persist between runs in this host folder.
    CACHE="${CRAFT_CACHE_DIR:-$HOME/.cache/saldo-craft}"
    mkdir -p "$CACHE" "$SRC/dist"
    # The image runs as its own "user"; let it write the cache and dist/.
    chmod a+rwx "$CACHE" "$SRC/dist"
    exec docker run --rm \
        -v "$SRC":/src \
        -v "$CACHE":/home/user/craft \
        -e CRAFT_WORK=/home/user/craft \
        "$IMAGE" bash /src/tools/build-apk.sh
fi

WORK="${CRAFT_WORK:-$HOME/craft}"
mkdir -p "$WORK"
cd "$WORK"

# The checkout belongs to another uid inside the container; let git read it.
git config --global --add safe.directory "$SRC"

[ -d craftmaster ] || git clone --depth=1 https://invent.kde.org/packaging/craftmaster.git
[ -d craft-ci ] || git clone --depth=1 https://invent.kde.org/sysadmin/craft-ci.git

# CraftMaster registers its own blueprints/ folder with Craft: put ours there.
rm -rf craftmaster/blueprints/saldo
cp -r "$SRC/craft/saldo" craftmaster/blueprints/saldo

craftmaster() {
    python3 craftmaster/CraftMaster.py \
        --config craft-ci/qt6/CraftConfig.ini \
        --config-override "$SRC/.craft.ini" \
        --target "$TARGET" \
        --variables "Root=$WORK" \
        "$@"
}

craftmaster --setup
craftmaster -c -i craft
craftmaster -c --install-deps saldo
# With a cache from an earlier build Craft says "saldo is up to date" and only
# repackages: the code is recompiled for the APK, but files installed by the
# build (translations, icons) stay stale. Start from a clean install.
craftmaster -c --unmerge saldo || true
craftmaster -c --no-cache --options "saldo.srcDir=$SRC" saldo
craftmaster -c --package --options "saldo.srcDir=$SRC" saldo

packageDir=$(craftmaster -c -q --get "packageDestinationDir()" virtual/base)
version=$(grep -oP 'project\(saldo VERSION \K[0-9.]+' "$SRC/CMakeLists.txt")
case "$TARGET" in
    *arm64*) abi=arm64-v8a ;;
    *x86_64*) abi=x86_64 ;;
    *) abi=unknown ;;
esac

mkdir -p "$SRC/dist"
apk=$(ls -t "$packageDir"/*.apk | head -1)
cp -v "$apk" "$SRC/dist/saldo-$version-$abi-unsigned.apk"
