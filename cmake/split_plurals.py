#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Rewrite a .po for Android, where plural entries never translate.

KDE Craft builds KI18n on Android with libintl-lite, whose ngettext returns
gettext(singular) when n == 1 and gettext(plural) otherwise, and whose lookup
never finds the .mo key of a plural entry ("singular\\0plural"): every i18np()
came out in English on the phone ("5 accounts"). Each translated plural entry
becomes two plain entries instead: the (context +) singular msgid gets
msgstr[0] and the plural msgid gets msgstr[1], which is what that ngettext
looks up. Two forms cover the app's languages; n == 1 picks, as there.

Usage: split_plurals.py <in.po> <out.po>
"""

import re
import sys

KEYWORD = re.compile(r'^(msgctxt|msgid_plural|msgid|msgstr(?:\[\d+\])?)\s+(".*")\s*$')


def parse(text):
    """Entries as (comments, {keyword: [quoted lines]}), quoting kept as is."""
    entries = []
    for block in re.split(r"\n[ \t]*\n", text.strip("\n")):
        comments, fields, key = [], {}, None
        for line in block.split("\n"):
            if line.startswith("#"):
                comments.append(line)
                continue
            match = KEYWORD.match(line)
            if match:
                key = match.group(1)
                fields[key] = [match.group(2)]
            elif line.startswith('"') and key:
                fields[key].append(line)
            else:
                sys.exit(f"split_plurals.py: unexpected line: {line}")
        entries.append((comments, fields))
    return entries


def value(lines):
    """The text of quoted lines (escapes left as they are)."""
    return "".join(line.strip()[1:-1] for line in lines or [])


def entry(context, msgid, msgstr):
    out = []
    if context is not None:
        out.append("msgctxt " + "\n".join(context))
    out.append("msgid " + "\n".join(msgid))
    out.append("msgstr " + "\n".join(msgstr))
    return "\n".join(out)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as source:
        entries = parse(source.read())

    plain = {(value(f.get("msgctxt")), value(f.get("msgid")))
             for _, f in entries if "msgid_plural" not in f}
    blocks = []
    for comments, fields in entries:
        if "msgid_plural" not in fields:
            blocks.append("\n".join(comments + [line for key in fields
                                                for line in [key + " " + "\n".join(fields[key])]]))
            continue
        fuzzy = any(c.startswith("#,") and "fuzzy" in c for c in comments)
        one, other = fields.get("msgstr[0]"), fields.get("msgstr[1]")
        if fuzzy or not value(one) or not value(other):
            continue  # untranslated: English either way
        context = fields.get("msgctxt")
        for key, msgid, msgstr in [((value(context), value(fields["msgid"])), fields["msgid"], one),
                                   (("", value(fields["msgid_plural"])), fields["msgid_plural"], other)]:
            if key in plain:
                continue  # already an entry of its own (or written for another plural)
            plain.add(key)
            blocks.append(entry(context if msgid is fields["msgid"] else None, msgid, msgstr))

    with open(sys.argv[2], "w", encoding="utf-8") as target:
        target.write("\n\n".join(blocks) + "\n")


if __name__ == "__main__":
    main()
