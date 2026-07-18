#!/usr/bin/env python3
"""Dedupe Localizable.strings and refresh Vietnamese entries missing diacritics."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "osmBus/Resources/Localization"

VIET_CHARS = set(
    "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ"
    "ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ"
)
SKIP_VALUES = {
    "FREE",
    "PREMIUM",
    "OK",
    "Google Routes API",
    "Google Maps API",
    "© OpenStreetMap",
}
KV_RE = re.compile(
    r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";$'
)


def unescape(s: str) -> str:
    return s.replace('\\"', '"').replace("\\\\", "\\")


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def parse_strings(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = KV_RE.match(line.strip())
        if m:
            entries[unescape(m.group(1))] = unescape(m.group(2))
    return entries


def needs_vi_fix(value: str) -> bool:
    if not value or not re.search(r"[a-zA-Z]{3,}", value):
        return False
    if any(c in VIET_CHARS for c in value):
        return False
    if value in SKIP_VALUES or value.startswith("HTTP "):
        return False
    return True


def dedupe_content(content: str) -> str:
    lines = content.splitlines()
    last_idx: dict[str, int] = {}
    for i, line in enumerate(lines):
        m = KV_RE.match(line.strip())
        if m:
            last_idx[unescape(m.group(1))] = i
    out: list[str] = []
    for i, line in enumerate(lines):
        m = KV_RE.match(line.strip())
        if m:
            key = unescape(m.group(1))
            if last_idx[key] != i:
                continue
        out.append(line)
    trailing = "\n" if content.endswith("\n") else ""
    return "\n".join(out) + trailing


def ensure_translator():
    try:
        from deep_translator import GoogleTranslator  # noqa: PLC0415

        return GoogleTranslator
    except ImportError:
        subprocess.check_call(
            [sys.executable, "-m", "pip", "install", "deep-translator", "-q"]
        )
        from deep_translator import GoogleTranslator  # noqa: PLC0415

        return GoogleTranslator


def refresh_vi(en: dict[str, str], vi: dict[str, str]) -> dict[str, str]:
    GoogleTranslator = ensure_translator()
    translator = GoogleTranslator(source="en", target="vi")
    to_fix = [k for k, v in vi.items() if needs_vi_fix(v)]
    print(f"Translating {len(to_fix)} Vietnamese entries...")
    batch_size = 30
    updated = dict(vi)
    for i in range(0, len(to_fix), batch_size):
        batch = to_fix[i : i + batch_size]
        texts = [en.get(k, k) for k in batch]
        try:
            results = translator.translate_batch(texts)
        except Exception:
            results = [translator.translate(t) for t in texts]
        for key, translated in zip(batch, results):
            if translated:
                updated[key] = translated
        print(f"  {min(i + batch_size, len(to_fix))}/{len(to_fix)}")
    return updated


def rewrite_vi_file(vi_path: Path, vi: dict[str, str]) -> None:
    lines = vi_path.read_text(encoding="utf-8").splitlines()
    new_lines: list[str] = []
    for line in lines:
        m = KV_RE.match(line.strip())
        if not m:
            new_lines.append(line)
            continue
        key = unescape(m.group(1))
        value = vi.get(key, unescape(m.group(2)))
        new_lines.append(f'"{escape(key)}" = "{escape(value)}";')
    vi_path.write_text(dedupe_content("\n".join(new_lines) + "\n"), encoding="utf-8")


def main() -> None:
    en = parse_strings(LOC / "en.lproj/Localizable.strings")
    vi_path = LOC / "vi.lproj/Localizable.strings"
    vi = parse_strings(vi_path)
    vi = refresh_vi(en, vi)
    rewrite_vi_file(vi_path, vi)
    print("vi updated and deduped")

    for lang in ("en", "ja"):
        path = LOC / f"{lang}.lproj/Localizable.strings"
        path.write_text(dedupe_content(path.read_text(encoding="utf-8")), encoding="utf-8")
        print(f"{lang} deduped")


if __name__ == "__main__":
    main()
