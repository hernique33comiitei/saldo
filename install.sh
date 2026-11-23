#!/usr/bin/env bash
# Builds Saldo and installs it into ~/.local (app, Plasma widget, QML plugin,
# icons, translations). Run ./install.sh --restart-plasma to reload the panel.
set -euo pipefail
cd "$(dirname "$0")"

PREFIX="$HOME/.local"
BUILD_DIR="build-user"
RESTART_PLASMA=0
for arg in "$@"; do
    case "$arg" in
        --restart-plasma) RESTART_PLASMA=1 ;;
        -h|--help)
            echo "Usage: $0 [--restart-plasma]"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

# Dependencies installed together with the app: build tools, Qt/KF6 dev
# packages, the runtime QML modules it dlopens and libsecret (secret-tool).
DEPS=(
  extra-cmake-modules cmake ninja-build gcc-c++ gettext
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg
  kf6-kirigami-devel kf6-ki18n-devel kf6-kcoreaddons-devel kf6-kquickcharts
  libsecret
)

if command -v dnf >/dev/null 2>&1; then
    missing=()
    for pkg in "${DEPS[@]}"; do
        rpm -q "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Installing dependencies (sudo): ${missing[*]}"
        sudo dnf install -y "${missing[@]}"
    fi
else
    echo "warning: not Fedora: install the build dependencies listed in README.md (\"From source (other distributions)\") and secret-tool (libsecret-tools)." >&2
fi

cmake -B "$BUILD_DIR" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_TESTING=OFF
cmake --build "$BUILD_DIR"
cmake --install "$BUILD_DIR"

# plasmashell only searches the system QML directory; tell it about ~/.local.
# Take the directory from the install manifest: KDE_INSTALL_QMLDIR is empty in
# CMakeCache.txt (ECM computes the default in a normal variable).
QMLDIR_FILE=$(grep '/org/saldo/core/qmldir$' "$BUILD_DIR/install_manifest.txt" | head -1 || true)
if [ -z "$QMLDIR_FILE" ]; then
    echo "error: the Saldo QML plugin is missing from $BUILD_DIR/install_manifest.txt" >&2
    exit 1
fi
QML_DIR="${QMLDIR_FILE%/org/saldo/core/qmldir}"

ENV_DIR="$HOME/.config/plasma-workspace/env"
ENV_FILE="$ENV_DIR/saldo.sh"
mkdir -p "$ENV_DIR"
cat > "$ENV_FILE" <<EOF
# Added by Saldo's install.sh: lets plasmashell load the Saldo QML plugin.
case ":\${QML_IMPORT_PATH:-}:" in
    *":$QML_DIR:"*) ;;
    *) export QML_IMPORT_PATH="$QML_DIR\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}" ;;
esac
EOF

# Same for the running session, so a plasmashell restart is enough. Rebuild the
# list: Saldo's dir first, other entries kept, stale "$PREFIX/" entries (written
# by an older install.sh) dropped.
CURRENT=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^QML_IMPORT_PATH=//p' || true)
NEW_PATH="$QML_DIR"
IFS=: read -ra ENTRIES <<< "$CURRENT"
for entry in "${ENTRIES[@]}"; do
    case "$entry" in
        ""|"$QML_DIR"|"$PREFIX"|"$PREFIX/") ;;
        *) NEW_PATH="$NEW_PATH:$entry" ;;
    esac
done
systemctl --user set-environment "QML_IMPORT_PATH=$NEW_PATH" 2>/dev/null || true

# Is the running plasmashell already using it?
SHELL_PID=$(pgrep -u "$(id -u)" -x plasmashell | head -1 || true)
SHELL_HAS_PATH=0
if [ -n "$SHELL_PID" ]; then
    # Compare path entries exactly (no regex: the path may contain dots).
    SHELL_QML=$(tr '\0' '\n' < "/proc/$SHELL_PID/environ" 2>/dev/null | sed -n 's/^QML_IMPORT_PATH=//p' | head -1 || true)
    IFS=':' read -r -a SHELL_QML_ENTRIES <<< "$SHELL_QML"
    for entry in "${SHELL_QML_ENTRIES[@]}"; do
        [ "$entry" = "$QML_DIR" ] && SHELL_HAS_PATH=1
    done
fi

update-desktop-database "$PREFIX/share/applications" >/dev/null 2>&1 || true
kbuildsycoca6 >/dev/null 2>&1 || true

echo
echo "Saldo installed into $PREFIX."
echo "  App:    open \"Saldo\" from the application launcher (or run $PREFIX/bin/saldo)."
echo "  Demo:   $PREFIX/bin/saldo --demo"
echo "  Widget: right-click the panel → Add or Manage Widgets → \"Saldo\","
echo "          or Configure System Tray → Entries → Saldo."

if [ "$RESTART_PLASMA" = 1 ]; then
    echo "Restarting plasmashell…"
    systemctl --user restart plasma-plasmashell.service
elif [ "$SHELL_HAS_PATH" = 0 ]; then
    echo "The widget needs plasmashell to reload once:"
    echo "  systemctl --user restart plasma-plasmashell.service   (or log out and back in)"
elif [ -n "$SHELL_PID" ]; then
    # plasmashell keeps the previous libsaldocore loaded until it restarts.
    echo "If the widget is in use, reload plasmashell so it runs this version too:"
    echo "  systemctl --user restart plasma-plasmashell.service   (or ./install.sh --restart-plasma)"
fi
