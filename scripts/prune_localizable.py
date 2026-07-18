#!/usr/bin/env python3
"""Remove Localizable.strings keys not referenced from osmBus Swift sources."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "osmBus"
LANGS = ("en", "ja", "vi")

DIRECT_KEY_PATTERN = re.compile(
    r'AppLocaleString\.(?:text|currentText|formatted|currentFormatted)\(\s*"([^"]+)"'
)
ENTRY_PATTERN = re.compile(r'^"(.+)"\s*=\s*"(.*)"\s*;\s*$')

# Keys passed indirectly via enums, structs, or string arrays.
INDIRECT_PATTERNS = [
    re.compile(
        r'(?:nameKey|titleKey|bodyKey|settingsTitleKey|localizationKey|savedMessageKey|'
        r'introLeadKey|introSupplementKey|roleHeaderKey|beginnerHeaderKey|'
        r'beginnerWhatTitleKey|beginnerWhatBodyKey|beginnerFreeTitleKey|beginnerFreeBodyKey|'
        r'beginnerStepsTitleKey|beginnerStepsBodyKey|deviceStorageBodyKey|googleSendBodyKey|'
        r'keyInputFooterKey|keyObtainLinkKey|activationGuideKey|testFooterKey|deleteKeyKey|'
        r'premiumOnlyBodyKey|roleTitleKey|roleBodyKey):\s*"([^"]+)"'
    ),
    re.compile(r'compassDirectionKeys\s*=\s*\[(.*?)\]', re.S),
    re.compile(r'isTrialExhausted\s*\?\s*"([^"]+)"\s*:\s*"([^"]+)"'),
    re.compile(r'place == nil \? "([^"]+)" : "([^"]+)"'),
    re.compile(r'role == \.origin \? "([^"]+)" : "([^"]+)"'),
]


def collect_swift_keys() -> set[str]:
    keys: set[str] = set()
    for path in ROOT.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        keys.update(DIRECT_KEY_PATTERN.findall(text))
        keys.update(re.findall(r'localized\("([^"]+)"\)', text))
        for pattern in INDIRECT_PATTERNS[:1]:
            keys.update(pattern.findall(text))
        for m in re.finditer(r'compassDirectionKeys\s*=\s*\[(.*?)\]', text, re.S):
            keys.update(re.findall(r'"([^"]+)"', m.group(1)))
        for pattern in INDIRECT_PATTERNS[2:]:
            for match in pattern.findall(text):
                if isinstance(match, tuple):
                    keys.update(match)
                else:
                    keys.add(match)
        for m in re.finditer(r'case\s+\.\w+:\s*return\s+"([^"]+)"', text):
            k = m.group(1)
            if "_" in k or k.startswith(("help_", "Routes", "Maps", "テンキー", "キーフィードバック", "サウンド")):
                keys.add(k)

    keys.update({"FREE", "PREMIUM"})
    return keys


def prune_language(lang: str, used: set[str]) -> tuple[int, int]:
    strings_path = ROOT / f"Resources/Localization/{lang}.lproj/Localizable.strings"
    content = strings_path.read_text(encoding="utf-8")

    kept: list[tuple[list[str], str, str]] = []
    comment: list[str] = []
    total = 0

    for line in content.splitlines():
        stripped = line.strip()
        if stripped.startswith("//"):
            comment.append(line)
            continue
        match = ENTRY_PATTERN.match(stripped)
        if match:
            total += 1
            key, value = match.group(1), match.group(2)
            if key in used:
                kept.append((comment, key, value))
            comment = []
        elif stripped == "" and comment:
            comment.append(line)

    out: list[str] = []
    for block, key, value in kept:
        out.extend(block)
        out.append(f'"{key}" = "{value}";')
        out.append("")

    strings_path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
    return len(kept), total - len(kept)


def main() -> int:
    used = collect_swift_keys()
    print(f"Referenced keys: {len(used)}")
    for lang in LANGS:
        kept, removed = prune_language(lang, used)
        print(f"  {lang}: kept {kept}, removed {removed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
