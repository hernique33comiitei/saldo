#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Smoke test of a built package on one distribution release (CLAUDE.md,
# "Packaging"): in a clean container of it, installs the package made for it,
# runs `saldo --version`, then the demo on every page (offscreen), and fails
# on any QML warning but Kirigami's known PageRow one. That loads all the QML
# with that release's Qt and Kirigami: where Debian 13 (Qt 6.8, KDE Frameworks
# 6.13) would break. The release workflow runs it for every supported release
# before publishing; tools/check-platforms.sh runs it for the README's rows.
#
#   tools/test-package.sh <image> [packages-dir]   e.g. fedora:45 dist
#
# The package: for fedora:NN the RPM built for that Fedora or the newest older
# one; for debian:* / ubuntu:* the DEB named after that family
# (tools/build-packages.sh). SALDO_TEST_SHOTS=<dir>: also a screenshot of each
# page (<dir>/<image>-<page>.png). Needs docker.
set -euo pipefail

image=${1:?usage: $0 <image> [packages-dir]}
dir=$(cd "${2:-$(dirname "$0")/../dist}" && pwd)
version=${SALDO_TEST_VERSION:-$(grep -oP 'project\(saldo VERSION \K[0-9.]+' "$(dirname "$0")/../CMakeLists.txt")}
PAGES="overview accounts cards transactions investments settings setup about gallery"

# The package for an image (see above); the oldest RPM when none is older
# (an unsupported Fedora: expected to fail).
package_for() {
    local best="" oldest="" release fc rpm
    case "$image" in
    fedora:*)
        release=${image#fedora:}
        for rpm in $(ls "$dir"/saldo-"$version"-*.fc*.x86_64.rpm 2>/dev/null | sort -V); do
            fc=$(grep -oP '\.fc\K[0-9]+' <<<"$rpm")
            [ -z "$oldest" ] && oldest=$rpm
            [ "$fc" -le "$release" ] && best=$rpm
        done
        echo "${best:-$oldest}"
        ;;
    debian:*) ls "$dir"/saldo_"$version"-*-debian*_amd64.deb 2>/dev/null | sort -V | tail -1 ;;
    ubuntu:*) ls "$dir"/saldo_"$version"-*-ubuntu*_amd64.deb 2>/dev/null | sort -V | tail -1 ;;
    esac
}

pkg=$(package_for)
[ -n "$pkg" ] || { echo "$image: no package for saldo $version in $dir" >&2; exit 2; }
name=$(basename "$pkg")
case "$image" in
fedora:*) install="dnf -y -q install /pkgs/$name >/dev/null" ;;
*) install="apt-get -qq update && apt-get -y -qq install /pkgs/$name >/dev/null" ;;
esac

shots=${SALDO_TEST_SHOTS:-}
mounts=(-v "$dir":/pkgs:ro)
if [ -n "$shots" ]; then
    mkdir -p "$shots"
    chmod a+rwx "$shots"
    mounts+=(-v "$(cd "$shots" && pwd)":/shots)
fi
# Readable by the containers' users (apt's _apt).
chmod a+rx "$dir"
chmod a+r "$pkg"

echo "=== $image: $name"
docker run --rm "${mounts[@]}" -e QT_QPA_PLATFORM=offscreen -e QT_FORCE_STDERR_LOGGING=1 \
    -e DEBIAN_FRONTEND=noninteractive -e V="$version" -e PAGES="$PAGES" -e IMAGE="${image/:/-}" \
    -e SHOTS="$shots" "$image" sh -c "$install"' && set -e
        saldo --version | grep -qx "saldo $V" || { echo "saldo --version: not $V"; exit 1; }
        failed=0
        for page in $PAGES; do
            if [ -n "$SHOTS" ]; then
                export SALDO_SCREENSHOT="/shots/$IMAGE-$page.png" SALDO_SCREENSHOT_SIZE=1100x820
            fi
            timeout 10 saldo --demo --page "$page" >/tmp/run.log 2>&1 || true
            # QML errors and warnings (a type or module missing, a script
            # error), but Kirigami'"'"'s own PageRow line (CLAUDE.md, smoke test).
            if grep -E "qml|QML|TypeError|ReferenceError|is not a type|is not installed|Unable to assign|Cannot assign" /tmp/run.log \
                    | grep -v "Created graphical object was not placed in the graphics scene" >/tmp/problems; then
                echo "--- $page:"; cat /tmp/problems; failed=1
            else
                echo "$page: ok"
            fi
        done
        exit $failed'
