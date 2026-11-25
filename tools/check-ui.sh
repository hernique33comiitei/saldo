#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Design system check (see CLAUDE.md, "Design system"): the app's pages and
# components use org.saldo.ui (`import org.saldo.ui as UI`), never the
# controls it wraps directly, and its tokens instead of literal tints.
#
#   tools/check-ui.sh            list what still bypasses the design system
#   tools/check-ui.sh --strict   the same, failing when anything is listed
#                                (the ctest "check-ui" runs it this way)
set -euo pipefail
cd "$(dirname "$0")/.."

strict=0
[ "${1:-}" = --strict ] && strict=1

# Controls the design system wraps (UI.Button, UI.TextField, UI.Sheet…),
# where one is created ("Type {"): their enums (Kirigami.Dialog.Ok) are fine.
wrapped='(QQC2\.(Button|TextField|TextArea|ComboBox|Switch|SpinBox|ToolButton|BusyIndicator|Menu|ItemDelegate)'
wrapped+='|Kirigami\.(Dialog|PromptDialog|PasswordField|SearchField|InlineMessage|PlaceholderMessage|AbstractCard|ListSectionHeader|FormLayout))\s*\{'
# Literal looks: colors and radii come from UI.Tokens.
literal='Kirigami\.ColorUtils\.tintWithAlpha|radius: *[0-9]|"#[0-9a-fA-F]{6}"'

files=$(find src/app/pages src/app/components src/app/Main.qml -name '*.qml' | sort)
found=$(grep -nE "$wrapped|$literal" $files || true)

if [ -z "$found" ]; then
    echo "check-ui: every page and component goes through org.saldo.ui"
    exit 0
fi
echo "$found"
echo "check-ui: $(wc -l <<<"$found") use(s) above bypass the design system (org.saldo.ui)" >&2
exit $strict
