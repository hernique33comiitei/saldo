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
#
# --dev: a test build for tools/phone-test.sh, installed next to the real app
# ("Saldo (dev)", id io.github.hernique33comiitei.saldo.dev, its own data) and
# already signed with a dev key kept in the Craft cache, so it needs no release
# key and the next dev build updates it in place:
#   dist/saldo-<version>-arm64-v8a-dev.apk
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="invent-registry.kde.org/sysadmin/ci-images/android-qt611:latest"
TARGET="${CRAFT_TARGET:-android-arm64-clang}"

docker=0
for arg in "$@"; do
    case "$arg" in
    --docker) docker=1 ;;
    --dev) export SALDO_APK_DEV=1 ;; # read by android/build.gradle
    *) echo "usage: $0 [--docker] [--dev]" >&2; exit 1 ;;
    esac
done

if [ "$docker" = 1 ]; then
    # Craft's downloads and cache persist between runs in this host folder.
    CACHE="${CRAFT_CACHE_DIR:-$HOME/.cache/saldo-craft}"
    mkdir -p "$CACHE" "$SRC/dist"
    # The image runs as its own "user"; let it write the cache and dist/.
    chmod a+rwx "$CACHE" "$SRC/dist"
    exec docker run --rm \
        -v "$SRC":/src \
        -v "$CACHE":/home/user/craft \
        -e CRAFT_WORK=/home/user/craft \
        -e SALDO_APK_DEV="${SALDO_APK_DEV:-}" \
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
if [ "${SALDO_APK_DEV:-}" = 1 ]; then
    unsigned="$SRC/dist/saldo-$version-$abi-dev-unsigned.apk"
    cp -v "$apk" "$unsigned"
    # A dev key (no secret: it only signs test builds) that stays in the Craft
    # cache, so each dev build updates the previous one on the phone.
    devkey="$WORK/saldo-dev.keystore"
    if [ ! -f "$devkey" ]; then
        keytool -genkeypair -keystore "$devkey" -alias saldo-dev -storepass android -keypass android \
            -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Saldo dev" >/dev/null 2>&1
    fi
    ANDROID_KEYSTORE_FILE="$devkey" ANDROID_KEYSTORE_PASSWORD=android ANDROID_KEY_ALIAS=saldo-dev \
        "$SRC/tools/sign-apk.sh" "$unsigned"
    rm -f "$unsigned"
else
    cp -v "$apk" "$SRC/dist/saldo-$version-$abi-unsigned.apk"
fi
