#!/usr/bin/env bash
# Removes what install.sh put into ~/.local. Your data (cache, preferences and
# the keyring entry) stays unless you pass --purge.
set -euo pipefail
cd "$(dirname "$0")"

PREFIX="$HOME/.local"
BUILD_DIR="build-user"
PURGE=0
for arg in "$@"; do
    case "$arg" in
        --purge) PURGE=1 ;;
        -h|--help) echo "usage: $0 [--purge]"; exit 0 ;;
        *) echo "unknown option: $arg (usage: $0 [--purge])" >&2; exit 2 ;;
    esac
done

MANIFEST="$BUILD_DIR/install_manifest.txt"
QML_DIR=""
if [ -f "$MANIFEST" ]; then
    # Read where the QML plugin went before the files disappear.
    QMLDIR_FILE=$(grep '/org/saldo/core/qmldir$' "$MANIFEST" | head -1 || true)
    [ -n "$QMLDIR_FILE" ] && QML_DIR="${QMLDIR_FILE%/org/saldo/core/qmldir}"

    while IFS= read -r file; do
        rm -f -- "$file"
    done < "$MANIFEST"
    rm -rf -- "$PREFIX/share/plasma/plasmoids/io.github.hernique33comiitei.saldo"
    [ -n "$QML_DIR" ] && rm -rf -- "$QML_DIR/org/saldo"
    echo "Removed the files listed in $MANIFEST."
else
    echo "No $MANIFEST found; nothing to remove." >&2
fi

rm -f -- "$HOME/.config/plasma-workspace/env/saldo.sh"

# Drop Saldo's directory (and stale "$PREFIX/" entries from an older
# install.sh) from the session's QML_IMPORT_PATH; keep everything else.
CURRENT=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^QML_IMPORT_PATH=//p' || true)
REMAINING=""
IFS=: read -ra ENTRIES <<< "$CURRENT"
for entry in "${ENTRIES[@]}"; do
    case "$entry" in
        ""|"$PREFIX"|"$PREFIX/") ;;
        *)
            if [ -n "$QML_DIR" ] && [ "$entry" = "$QML_DIR" ]; then
                continue
            fi
            REMAINING="${REMAINING:+$REMAINING:}$entry"
            ;;
    esac
done
if [ -z "$REMAINING" ]; then
    systemctl --user unset-environment QML_IMPORT_PATH 2>/dev/null || true
else
    systemctl --user set-environment "QML_IMPORT_PATH=$REMAINING" 2>/dev/null || true
fi
kbuildsycoca6 >/dev/null 2>&1 || true

if [ "$PURGE" = 1 ]; then
    rm -rf -- "$HOME/.local/share/saldo"
    rm -f -- "$HOME/.config/saldorc" "$HOME/.config/saldo-demorc"
    secret-tool clear service io.github.hernique33comiitei.Saldo account pluggy-credentials 2>/dev/null || true
    echo "Removed cached data, preferences and the keyring entry."
fi
