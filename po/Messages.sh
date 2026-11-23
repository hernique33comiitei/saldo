#!/usr/bin/env bash
# Extracts translatable strings into po/saldo.pot and merges them into po/*.po.
set -euo pipefail
cd "$(dirname "$0")/.."

KEYWORDS=(-ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3
          -ki18nd:2 -ki18ndc:2c,3 -ki18ndp:2,3 -ki18ndcp:2c,3,4)
COMMON=(--from-code=UTF-8 --add-comments=TRANSLATORS --package-name=saldo --msgid-bugs-address=https://github.com/hernique33comiitei/saldo/issues)

xgettext "${COMMON[@]}" -C "${KEYWORDS[@]}" -o po/cpp.pot $(find src -name '*.cpp' | sort)
xgettext "${COMMON[@]}" --language=JavaScript "${KEYWORDS[@]}" -o po/qml.pot $(find src plasmoid -name '*.qml' | sort)
msgcat --use-first -o po/saldo.pot po/cpp.pot po/qml.pot
rm -f po/cpp.pot po/qml.pot

for po in po/*.po; do
    msgmerge --quiet --update --backup=none "$po" po/saldo.pot
done
