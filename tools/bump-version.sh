#!/usr/bin/env bash
# Single source of truth for the release version: the CMake project() version.
#
# The app, the core library, the Plasma widget (metadata.json) and the Android
# APK (ECM's ecm-version.gradle) already derive their version from CMake. The
# packaging/metadata files (RPM spec, debian/changelog, AppStream metainfo,
# .po header) are read by external tools and can't import the CMake value, so
# this script propagates it to all of them from one place, and fills their
# changelog entries.
#
# Usage:
#   tools/bump-version.sh X.Y.Z notes.txt   # set version, sync, changelog from notes.txt
#   tools/bump-version.sh X.Y.Z             # ... changelog drafted from commits since last tag
#   tools/bump-version.sh                    # re-sync every file to the current CMake version
#
# notes.txt holds one changelog line per entry (blank lines ignored). Releases
# always ship a curated, user-facing changelog, so a notes file is the normal
# path; the commit-derived draft is just a starting point to curate from.
#
# After bumping: review the diff, `git commit -am "chore: release X.Y.Z"`, then
# `git tag vX.Y.Z && git push origin main vX.Y.Z`.
set -euo pipefail
cd "$(dirname "$0")/.."

CMAKE=CMakeLists.txt
SPEC=packaging/fedora/saldo.spec
META=data/io.github.hernique33comiitei.Saldo.metainfo.xml
DEB=debian/changelog
PO=po/pt_BR.po
AUTHOR="Henrique Oliveira <henriik.dev@gmail.com>"

cur=$(grep -oP 'project\(saldo VERSION \K[0-9]+\.[0-9]+\.[0-9]+' "$CMAKE")
new="${1:-$cur}"
if ! [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 [X.Y.Z] [notes-file]" >&2; exit 1
fi

today=$(date +%Y-%m-%d)
rpmdate=$(LC_ALL=C date '+%a %b %d %Y')
debdate=$(LC_ALL=C date -R)

# --- Change list: from a notes file (one entry per line) when given, else the
#     commit subjects since the last tag (a draft to curate). ---
notes="${2:-}"
if [ -n "$notes" ] && [ -s "$notes" ]; then
  mapfile -t changes < <(grep -v '^[[:space:]]*$' "$notes")
  source_desc="$notes"
else
  lasttag=$(git describe --tags --abbrev=0 2>/dev/null || true)
  range=""; [ -n "$lasttag" ] && range="$lasttag..HEAD"
  mapfile -t raw < <(git log --no-merges --pretty='%s' $range 2>/dev/null || true)
  changes=()
  for c in "${raw[@]}"; do
    case "$c" in
      "chore: release "*|"chore: bump version"*) continue ;;  # skip our own bump commits
    esac
    changes+=("$c")
  done
  source_desc="commits since ${lasttag:-start}"
fi
[ ${#changes[@]} -eq 0 ] && changes=("Release $new")

xml_escape() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# 1) CMake project() — the canonical source.
sed -i -E "s/(project\(saldo VERSION )[0-9]+\.[0-9]+\.[0-9]+/\1$new/" "$CMAKE"

# 2) RPM spec: Version field + a new %changelog entry (only when the version is new).
sed -i -E "s/^(Version:[[:space:]]*)[0-9]+\.[0-9]+\.[0-9]+/\1$new/" "$SPEC"
if ! grep -q "\- $new-1\$" "$SPEC"; then
  frag=$(mktemp)
  { echo "* $rpmdate $AUTHOR - $new-1"
    for c in "${changes[@]}"; do echo "- $c"; done
    echo ""; } > "$frag"
  awk -v f="$frag" '/^%changelog/ && !d { print; while ((getline l < f) > 0) print l; d=1; next } { print }' \
    "$SPEC" > "$SPEC.tmp" && mv "$SPEC.tmp" "$SPEC"
  rm -f "$frag"
fi

# 3) AppStream metainfo: prepend a <release> with a <ul> list (only when the version is new).
if ! grep -q "release version=\"$new\"" "$META"; then
  frag=$(mktemp)
  { echo "    <release version=\"$new\" date=\"$today\">"
    echo "      <description>"
    echo "        <ul>"
    for c in "${changes[@]}"; do echo "          <li>$(printf '%s' "$c" | xml_escape)</li>"; done
    echo "        </ul>"
    echo "      </description>"
    echo "    </release>"; } > "$frag"
  awk -v f="$frag" '/<releases>/ && !d { print; while ((getline l < f) > 0) print l; d=1; next } { print }' \
    "$META" > "$META.tmp" && mv "$META.tmp" "$META"
  rm -f "$frag"
fi

# 4) debian/changelog: prepend a new entry (only when the version is new).
if ! head -1 "$DEB" | grep -q "($new-1)"; then
  frag=$(mktemp)
  { echo "saldo ($new-1) unstable; urgency=medium"; echo ""
    for c in "${changes[@]}"; do echo "  * $c"; done
    echo ""; echo " -- $AUTHOR  $debdate"; echo ""; } > "$frag"
  cat "$frag" "$DEB" > "$DEB.tmp" && mv "$DEB.tmp" "$DEB"
  rm -f "$frag"
fi

# 5) .po header (informational).
sed -i -E "s/(Project-Id-Version: saldo )[0-9]+\.[0-9]+\.[0-9]+/\1$new/" "$PO"

echo "Version synced to $new (${#changes[@]} changelog line(s) from $source_desc):"
echo "  CMakeLists.txt                -> $(grep -oP 'project\(saldo VERSION \K[0-9.]+' "$CMAKE")"
echo "  $SPEC  -> $(grep -oP '^Version:[[:space:]]*\K[0-9.]+' "$SPEC")"
echo "  $DEB             -> $(head -1 "$DEB" | grep -oP '\(\K[0-9.]+')"
echo "  $META -> $(grep -oP 'release version=\"\K[0-9.]+' "$META" | head -1)"
echo "  $PO                   -> $(grep -oP 'Project-Id-Version: saldo \K[0-9.]+' "$PO")"
