#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Test Saldo on the phone over adb: the standard check for every Android
# change (the desktop's mobile mode does not show Android-only behavior such as
# Qt's Android theme fonts, the system bars or libintl-lite's plurals).
#
# Needs adb (sudo dnf install android-tools) and the phone connected with USB
# debugging on (`adb devices` lists it as "device"). See CLAUDE.md.
#
# Works on the test build ("Saldo (dev)", from tools/build-apk.sh --docker --dev),
# which installs next to the real app and never touches it or its data.
# SALDO_PHONE_PACKAGE=io.github.hernique33comiitei.saldo targets the real app.
#
#   tools/phone-test.sh install [apk]   install or update the app
#                                       (default: the newest dist/*-dev.apk)
#   tools/phone-test.sh run [args...]   restart the app with arguments, e.g.
#                                       --demo --page cards --theme dark
#   tools/phone-test.sh shot <png>      screenshot of the phone's screen
#   tools/phone-test.sh night <mode>    the phone's dark mode: yes, no or auto
#   tools/phone-test.sh lang <code>     language of the --demo runs: pt_BR, en or system
#                                       (writes the demo config; debuggable test app only)
#   tools/phone-test.sh log             the app's messages since it last started
#   tools/phone-test.sh smoke           run the demo and fail on QML warnings
#   tools/phone-test.sh matrix [dir]    screenshots of the main pages with demo
#                                       data for every phone dark mode x app theme,
#                                       in Portuguese (default dir: dist/phone-shots)
#
# Runs with --demo never touch the real data (own files, no keyring), so
# screenshots show made-up numbers only. SALDO_PHONE_WAIT: seconds to let the
# app start and draw (default 6).
set -euo pipefail

DEV_PKG=io.github.hernique33comiitei.saldo.dev
PKG=${SALDO_PHONE_PACKAGE:-$DEV_PKG}
ACTIVITY=$PKG/org.qtproject.qt.android.bindings.QtActivity
WAIT=${SALDO_PHONE_WAIT:-6}
SRC=$(cd "$(dirname "$0")/.." && pwd)

need_phone() {
    if ! command -v adb >/dev/null; then
        echo "adb not found: sudo dnf install android-tools" >&2
        exit 1
    fi
    if [ "$(adb get-state 2>/dev/null)" != device ]; then
        echo "No phone: connect it with USB debugging on and accept the prompt on the phone (adb devices)" >&2
        exit 1
    fi
}

need_app() {
    if ! adb shell pm path "$PKG" | grep -q '^package:'; then
        echo "$PKG is not installed: tools/phone-test.sh install" >&2
        exit 1
    fi
}

# An asleep or locked phone gives black screenshots: wake it, dismiss a swipe
# lock screen, and stop if it needs the PIN.
screen_ready() {
    adb shell input keyevent KEYCODE_WAKEUP
    if adb shell dumpsys window | grep -q 'isKeyguardShowing=true'; then
        adb shell wm dismiss-keyguard >/dev/null 2>&1 || true
        sleep 1
        if adb shell dumpsys window | grep -q 'isKeyguardShowing=true'; then
            echo "The phone is locked: unlock it and run this again" >&2
            exit 1
        fi
    fi
}

# Restart the app; Qt passes the intent's applicationArguments to main().
run_app() {
    screen_ready
    adb shell am force-stop "$PKG"
    if [ $# -gt 0 ]; then
        adb shell am start -W -n "$ACTIVITY" -e applicationArguments "'$*'" >/dev/null
    else
        adb shell am start -W -n "$ACTIVITY" >/dev/null
    fi
    sleep "$WAIT"
}

# The demo runs' settings (files/settings/saldo-demorc in the app's data);
# run-as only works on the debuggable test build.
set_demo_language() {
    local code=$1
    [ "$code" = system ] && code=""
    printf '[View]\nlanguage=%s\n' "$code" |
        adb shell "run-as $PKG sh -c 'mkdir -p files/settings && cat > files/settings/saldo-demorc'"
}

app_log() {
    local pid
    pid=$(adb shell pidof -s "$PKG" | tr -d '\r')
    if [ -z "$pid" ]; then
        echo "Saldo is not running" >&2
        return 1
    fi
    adb logcat -d --pid="$pid"
}

command=${1:-}
[ $# -gt 0 ] && shift
case "$command" in
install)
    need_phone
    apk=${1:-$(ls -t "$SRC"/dist/*-dev.apk 2>/dev/null | head -1 || true)}
    if [ -z "$apk" ]; then
        echo "No test build in dist/: tools/build-apk.sh --docker --dev" >&2
        exit 1
    fi
    case "$apk" in
    *-unsigned.apk) echo "Not signed: tools/sign-apk.sh $apk" >&2; exit 1 ;;
    esac
    echo "Installing $apk"
    if ! out=$(adb install -r "$apk" 2>&1); then
        echo "$out" >&2
        # A test build signed with another dev key (a new Craft cache): only the
        # test app's demo data is lost, never the real app's.
        if [[ "$out" == *INSTALL_FAILED_USER_RESTRICTED* ]]; then
            echo "The phone refused it: Xiaomi/MIUI needs Developer options -> \"Install via USB\" on," >&2
            echo "and the install confirmed on the phone's screen when it asks." >&2
            exit 1
        elif [[ "$out" == *INSTALL_FAILED_UPDATE_INCOMPATIBLE* && "$apk" == *-dev.apk ]]; then
            echo "Reinstalling Saldo (dev), signed with another dev key" >&2
            adb uninstall "$DEV_PKG" >/dev/null
            adb install "$apk"
        else
            exit 1
        fi
    else
        echo "$out"
    fi
    ;;
run)
    need_phone
    need_app
    run_app "$@"
    ;;
shot)
    need_phone
    [ $# -eq 1 ] || { echo "Usage: $0 shot <file.png>" >&2; exit 1; }
    screen_ready
    adb exec-out screencap -p >"$1"
    echo "$1"
    ;;
night)
    need_phone
    [ $# -eq 1 ] || { echo "Usage: $0 night yes|no|auto" >&2; exit 1; }
    adb shell cmd uimode night "$1"
    ;;
lang)
    need_phone
    need_app
    [ $# -eq 1 ] || { echo "Usage: $0 lang pt_BR|en|system" >&2; exit 1; }
    set_demo_language "$1"
    ;;
log)
    need_phone
    need_app
    app_log
    ;;
smoke)
    need_phone
    need_app
    run_app --demo
    log=$(app_log) || exit 1
    # Warnings and errors from Qt and the app (logcat tags: default = QML and
    # qWarning, qml, js, saldo, kf.*, qt.*), not Android's own (nativeloader,
    # OpenGLRenderer). The PageRow line is Kirigami's own, expected (CLAUDE.md).
    problems=$(awk '$5 ~ /^[WEF]$/ && $6 ~ /^(default|qml|js|saldo|kf\.|qt\.)/' <<<"$log" |
        grep -v 'Created graphical object was not placed in the graphics scene' || true)
    if [ -n "$problems" ]; then
        echo "$problems"
        echo "Smoke test: the lines above need a look" >&2
        exit 1
    fi
    echo "Smoke test: no QML warnings"
    ;;
matrix)
    need_phone
    need_app
    dir=${1:-$SRC/dist/phone-shots}
    mkdir -p "$dir"
    set_demo_language "${SALDO_PHONE_LANG:-pt_BR}" # the users' language
    old=$(adb shell cmd uimode night | sed -n 's/^Night mode: //p' | tr -d '\r')
    # Keep the screen on during the run (it sleeps between shots otherwise).
    stay=$(adb shell settings get global stay_on_while_plugged_in | tr -d '\r')
    adb shell svc power stayon usb
    trap 'adb shell cmd uimode night "${old:-auto}" >/dev/null; adb shell settings put global stay_on_while_plugged_in "${stay:-0}"; adb shell am force-stop "$PKG"' EXIT
    for night in no yes; do
        adb shell cmd uimode night "$night" >/dev/null
        sleep 2
        phone=$([ "$night" = yes ] && echo dark || echo light)
        for theme in system light dark; do
            for page in overview transactions; do
                run_app --demo --theme "$theme" --page "$page"
                adb exec-out screencap -p >"$dir/$page-phone-$phone-app-$theme.png"
                echo "$dir/$page-phone-$phone-app-$theme.png"
            done
        done
    done
    ;;
*)
    awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "$0"
    exit 1
    ;;
esac
