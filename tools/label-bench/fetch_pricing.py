#!/usr/bin/env python3
"""Сохраняет снимок страниц с ценами (для ручной сверки pricing.json). Работает только там, где есть интернет."""
import html
import re
import sys
from pathlib import Path

import requests

OUT = Path(__file__).resolve().parent / "results" / "pricing"
URLS = {
    "openai_pricing": "https://developers.openai.com/api/docs/pricing",
    "openai_models": "https://developers.openai.com/api/docs/models",
    "openai_images_guide": "https://developers.openai.com/api/docs/guides/images-vision",
    "anthropic_pricing": "https://platform.claude.com/docs/en/about-claude/pricing",
}


def to_text(raw: str) -> str:
    raw = re.sub(r"(?is)<(script|style|noscript).*?</\1>", " ", raw)
    raw = re.sub(r"(?i)<br\s*/?>|</(p|div|tr|li|h\d|table)>", "\n", raw)
    raw = re.sub(r"(?i)</t[dh]>", " | ", raw)
    text = html.unescape(re.sub(r"<[^>]+>", " ", raw))
    text = re.sub(r"[ \t]+", " ", text)
    return re.sub(r"\n\s*\n+", "\n", text).strip()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, url in URLS.items():
        try:
            r = requests.get(url, timeout=60, headers={"User-Agent": "Mozilla/5.0 (FoodyLabelBench)"})
            (OUT / f"{name}.html").write_text(r.text, encoding="utf-8")
            (OUT / f"{name}.txt").write_text(to_text(r.text), encoding="utf-8")
            print(f"{name}: HTTP {r.status_code}, {len(r.text)} chars")
        except Exception as e:  # noqa: BLE001
            print(f"{name}: failed {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
