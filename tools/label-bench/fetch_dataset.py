#!/usr/bin/env python3
"""Собирает тестовый набор фотографий этикеток с Open Food Facts.

Для каждой страны/языка берём популярные продукты, у которых есть фото таблицы
пищевой ценности и заполненные значения на 100 г. Фото уменьшается до 1600 px
по длинной стороне (примерно то, что приложение отправит в модель).
Ground truth берётся из OFF (краудсорсинг!) и затем проверяется вручную по фото —
правки лежат в truth_overrides.json.

Лицензия данных/фото: Open Database License / CC BY-SA 3.0 (Open Food Facts contributors).
"""
import io
import json
import os
import sys
import time
from pathlib import Path

import requests
from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
UA = {"User-Agent": "FoodyLabelBench/1.0 (https://github.com/uncoll/foodyios; benchmark of label OCR models)"}

# (country tag, language of the nutrition photo, how many products)
PLAN = [
    ("germany", "de", 3),
    ("france", "fr", 3),
    ("italy", "it", 2),
    ("spain", "es", 2),
    ("poland", "pl", 1),
    ("netherlands", "nl", 1),
    ("czech-republic", "cs", 1),
    ("russia", "ru", 2),
]

REQUIRED = ["energy-kcal_100g", "fat_100g", "saturated-fat_100g", "carbohydrates_100g",
            "sugars_100g", "proteins_100g", "salt_100g"]
TRUTH_KEYS = {
    "energy_kcal": "energy-kcal_100g",
    "energy_kj": "energy-kj_100g",
    "fat_g": "fat_100g",
    "saturated_fat_g": "saturated-fat_100g",
    "monounsaturated_fat_g": "monounsaturated-fat_100g",
    "polyunsaturated_fat_g": "polyunsaturated-fat_100g",
    "carbohydrates_g": "carbohydrates_100g",
    "sugars_g": "sugars_100g",
    "polyols_g": "polyols_100g",
    "starch_g": "starch_100g",
    "fiber_g": "fiber_100g",
    "protein_g": "proteins_100g",
    "salt_g": "salt_100g",
    "sodium_g": "sodium_100g",
}
FIELDS = "code,product_name,brands,lang,nutrition_data_per,serving_size,quantity,nutriments,image_nutrition_url,images"


def get(url, **kw):
    for attempt in range(4):
        try:
            r = requests.get(url, headers=UA, timeout=60, **kw)
            if r.status_code == 200:
                return r
            print(f"  HTTP {r.status_code} for {url}", file=sys.stderr)
        except requests.RequestException as e:  # noqa: PERF203
            print(f"  error {e} for {url}", file=sys.stderr)
        time.sleep(3 * (attempt + 1))
    return None


def search(country, page):
    url = ("https://world.openfoodfacts.org/api/v2/search"
           f"?countries_tags_en={country}&fields={FIELDS}&sort_by=unique_scans_n&page_size=100&page={page}")
    r = get(url)
    if r is None:
        return []
    try:
        return r.json().get("products", [])
    except ValueError:
        return []


def full_image_url(p, lang):
    """URL полноразмерного фото таблицы пищевой ценности на нужном языке."""
    images = p.get("images") or {}
    key = f"nutrition_{lang}"
    info = images.get(key)
    url400 = p.get("image_nutrition_url") or ""
    if info and isinstance(info, dict) and "imgid" in info and url400:
        # .../products/301/762/042/2003/nutrition_fr.66.400.jpg -> .../nutrition_fr.66.full.jpg
        base = url400.rsplit("/", 1)[0]
        rev = info.get("rev")
        return f"{base}/{key}.{rev}.full.jpg" if rev else url400.replace(".400.jpg", ".full.jpg")
    if url400 and f"nutrition_{lang}." in url400:
        return url400.replace(".400.jpg", ".full.jpg")
    return None


def is_candidate(p, lang):
    n = p.get("nutriments") or {}
    if (p.get("nutrition_data_per") or "100g") != "100g":
        return False
    if any(k not in n for k in REQUIRED):
        return False
    try:
        if float(n.get("energy-kcal_100g", 0)) <= 5:
            return False
    except (TypeError, ValueError):
        return False
    return full_image_url(p, lang) is not None


def to_num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main():
    DATA.mkdir(parents=True, exist_ok=True)
    manifest_path = DATA / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    have_codes = {m["code"] for m in manifest}
    idx = len(manifest)

    for country, lang, want in PLAN:
        got = sum(1 for m in manifest if m["country"] == country)
        page = 1
        stride_seen = 0
        while got < want and page <= 4:
            products = search(country, page)
            page += 1
            if not products:
                break
            for p in products:
                if got >= want:
                    break
                if p.get("code") in have_codes or not is_candidate(p, lang):
                    continue
                stride_seen += 1
                if stride_seen % 3 != 1:   # берём каждый третий кандидат — больше разнообразия
                    continue
                url = full_image_url(p, lang)
                r = get(url)
                if r is None:
                    continue
                try:
                    img = Image.open(io.BytesIO(r.content))
                    img = ImageOps.exif_transpose(img).convert("RGB")
                except Exception as e:  # noqa: BLE001
                    print(f"  bad image {url}: {e}", file=sys.stderr)
                    continue
                orig = img.size
                if max(img.size) < 700:      # слишком мелкое фото — не показатель
                    continue
                img.thumbnail((1600, 1600))
                idx += 1
                image_id = f"{idx:02d}_{lang}_{p['code']}"
                img.save(DATA / f"{image_id}.jpg", "JPEG", quality=88, optimize=True)
                n = p.get("nutriments") or {}
                truth = {k: to_num(n.get(src)) for k, src in TRUTH_KEYS.items()}
                if truth.get("salt_g") is None and truth.get("sodium_g") is not None:
                    truth["salt_g"] = round(truth["sodium_g"] * 2.5, 3)
                entry = {
                    "id": image_id,
                    "code": p["code"],
                    "product_name": p.get("product_name"),
                    "brands": p.get("brands"),
                    "country": country,
                    "lang": lang,
                    "quantity": p.get("quantity"),
                    "serving_size": p.get("serving_size"),
                    "off_url": f"https://world.openfoodfacts.org/product/{p['code']}",
                    "image_url": url,
                    "original_size": list(orig),
                    "stored_size": list(img.size),
                    "license": "Open Food Facts contributors, ODbL / CC BY-SA 3.0",
                    "truth": truth,
                }
                (DATA / f"{image_id}.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2))
                manifest.append(entry)
                have_codes.add(p["code"])
                got += 1
                print(f"+ {image_id}: {p.get('product_name')} ({p.get('brands')}) {orig}->{img.size}")
                time.sleep(1.0)
        print(f"{country}: {got}/{want}")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    attribution = ["# Источники изображений", "",
                   "Фото таблиц пищевой ценности взяты из базы Open Food Facts (лицензия фото CC BY-SA 3.0, данные ODbL).",
                   "Используются только для тестирования качества распознавания.", ""]
    for m in manifest:
        attribution.append(f"- `{m['id']}` — {m.get('product_name')} ({m.get('brands')}) — {m['off_url']}")
    (DATA / "ATTRIBUTION.md").write_text("\n".join(attribution) + "\n")
    print(f"total {len(manifest)} images")


if __name__ == "__main__":
    main()
