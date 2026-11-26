#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Builds Saldo's distribution packages, each in a clean container of the
# distribution it is for (a package installs on the release it was built on,
# or newer): fedora:NN → the RPM (+ source RPM), debian:NN / ubuntu:NN.NN →
# the DEB, named with the distribution (saldo_X.Y.Z-1-debian13_amd64.deb), since
# each one gets its own. The release workflow runs it once per target; run it
# the same way to check a target locally.
#
#   tools/build-packages.sh fedora:42 fedora:43 fedora:44 debian:13 ubuntu:26.04
#
# Builds the git-tracked files as they are in the working tree (the release
# workflow's checkout is the tag). Output in dist/. Needs docker. The RPM's
# %check runs the tests.
set -euo pipefail

SRC=$(cd "$(dirname "$0")/.." && pwd)
[ $# -gt 0 ] || { awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"; exit 1; }

version=$(grep -oP 'project\(saldo VERSION \K[0-9.]+' "$SRC/CMakeLists.txt")
mkdir -p "$SRC/dist"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The sources: tracked files only (no build trees, no dist/).
(cd "$SRC" && git ls-files -z | tar --null -T - --transform "s,^,saldo-$version/," -czf "$work/saldo-$version.tar.gz")
chmod -R a+rX "$work"

for image in "$@"; do
    echo "=== $image"
    case "$image" in
    fedora:*)
        docker run --rm -v "$work":/in:ro -v "$SRC/dist":/out -e V="$version" -e OWNER="$(id -u):$(id -g)" \
            "$image" bash -euxc '
                dnf -y -q install rpm-build rpmdevtools dnf-plugins-core
                rpmdev-setuptree
                cp /in/saldo-$V.tar.gz ~/rpmbuild/SOURCES/
                tar -xzf /in/saldo-$V.tar.gz -C /tmp saldo-$V/packaging/fedora/saldo.spec
                dnf -y -q builddep /tmp/saldo-$V/packaging/fedora/saldo.spec
                rpmbuild -ba /tmp/saldo-$V/packaging/fedora/saldo.spec
                find ~/rpmbuild/RPMS ~/rpmbuild/SRPMS -name "*.rpm" ! -name "*-debug*" -exec cp {} /out/ \;
                chown "$OWNER" /out/*.rpm'
        ;;
    debian:* | ubuntu:*)
        # debian:13 → debian13, ubuntu:26.04 → ubuntu26.04
        distro=${image/:/}
        docker run --rm -v "$work":/in:ro -v "$SRC/dist":/out -e V="$version" -e DISTRO="$distro" \
            -e OWNER="$(id -u):$(id -g)" -e DEBIAN_FRONTEND=noninteractive "$image" bash -euxc '
                apt-get -qq update
                apt-get -y -qq install --no-install-recommends devscripts equivs >/dev/null
                mkdir /build && tar -xzf /in/saldo-$V.tar.gz -C /build && cd /build/saldo-$V
                mk-build-deps -i -r -t "apt-get -y -qq --no-install-recommends" debian/control
                dpkg-buildpackage -us -uc -b
                # Not the debug symbols (as the RPMs leave out -debuginfo).
                for deb in $(ls ../*.deb | grep -v dbgsym); do
                    name=$(basename "$deb" _amd64.deb)
                    cp "$deb" "/out/${name}-${DISTRO}_amd64.deb"
                    chown "$OWNER" "/out/${name}-${DISTRO}_amd64.deb"
                done'
        ;;
    *)
        echo "Unknown target $image (fedora:NN, debian:NN, ubuntu:NN.NN)" >&2
        exit 1
        ;;
    esac
done
ls -l "$SRC"/dist/*"$version"*.rpm "$SRC"/dist/*"$version"*.deb 2>/dev/null || true
