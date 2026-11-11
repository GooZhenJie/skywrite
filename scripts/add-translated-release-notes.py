#!/usr/bin/env python3
"""Adds translated release notes to one version in appcast.xml.

    scripts/add-translated-release-notes.py <appcast.xml> <version> <release-notes.md>

The translations of 0.1.3.md are the files next to it named 0.1.3.<language>.md, for example 0.1.3.zh-Hans.md and
0.1.3.zh-Hant.md. Each one becomes a <description xml:lang="<language>"> in the item for <version>, and the English
description gets xml:lang="en". Sparkle shows the description whose language matches the one Skywrite is shown in,
picking it the same way macOS picks Skywrite's own translations, and English otherwise.

scripts/update-appcast.sh runs this after generate_appcast. generate_appcast can only link translated notes by
two-letter language code, so it can't tell Simplified Chinese from Traditional Chinese.
"""
import pathlib
import re
import sys
import xml.dom.minidom

LANGUAGE = re.compile(r"[a-z]{2,3}(-[A-Za-z0-9]{2,8})*")
DESCRIPTION = re.compile(r"([ \t]*)<description\b([^>]*)>(.*?)</description>\n?", re.S)


def fail(message):
    print(f"add-translated-release-notes: {message}", file=sys.stderr)
    sys.exit(1)


def translations_of(notes):
    stem = notes.name.removesuffix(".md")
    found = {}
    for path in sorted(notes.parent.glob(f"{stem}.*.md")):
        language = path.name[len(stem) + 1:-len(".md")]
        if LANGUAGE.fullmatch(language):
            found[language] = path.read_text(encoding="utf-8")
    return found


def main():
    if len(sys.argv) != 4:
        fail("usage: add-translated-release-notes.py <appcast.xml> <version> <release-notes.md>")
    appcast = pathlib.Path(sys.argv[1])
    version = sys.argv[2]
    translations = translations_of(pathlib.Path(sys.argv[3]))
    if not translations:
        return

    text = appcast.read_text(encoding="utf-8")
    marker = f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>"
    items = [match for match in re.finditer(r"<item>.*?</item>", text, re.S) if marker in match.group(0)]
    if len(items) != 1:
        fail(f"expected one item for {version} in {appcast}, found {len(items)}")
    item = items[0]

    descriptions = list(DESCRIPTION.finditer(item.group(0)))
    english = [match for match in descriptions
               if "xml:lang=" not in match.group(2) or 'xml:lang="en"' in match.group(2)]
    if len(english) != 1:
        fail(f"expected one English description for {version}, found {len(english)}")
    indent = english[0].group(1)
    attributes = re.sub(r'\s*xml:lang="[^"]*"', "", english[0].group(2))
    format_attribute = re.search(r'\s*sparkle:format="[^"]*"', attributes)
    format_attribute = format_attribute.group(0) if format_attribute else ""

    replacement = [f'{indent}<description xml:lang="en"{attributes}>{english[0].group(3)}</description>\n']
    for language, notes in translations.items():
        if "]]>" in notes:
            fail(f"the {language} release notes contain ]]>, which can't go inside CDATA")
        replacement.append(f'{indent}<description xml:lang="{language}"{format_attribute}><![CDATA[{notes}]]></description>\n')

    # Replace every description in the item with the English one followed by the translations, at the first one's place.
    body = item.group(0)
    first = descriptions[0].start()
    for match in reversed(descriptions):
        body = body[:match.start()] + body[match.end():]
    body = body[:first] + "".join(replacement) + body[first:]

    result = text[:item.start()] + body + text[item.end():]
    xml.dom.minidom.parseString(result.encode("utf-8"))
    appcast.write_text(result, encoding="utf-8")
    print(f"Added {', '.join(translations)} release notes to {version} in {appcast}")


if __name__ == "__main__":
    main()
