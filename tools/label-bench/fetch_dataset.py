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
FIELDS = "code,product_name,brands,lang,nutrition_data_per,serving_size,quantity,nutriments,image_nutrition_url,images,selected_images"

# Запасной путь: поиск OFF часто отвечает 503, а карточка продукта по штрихкоду отдаётся из кэша стабильно.
# Известные европейские продукты (страна, язык этикетки, штрихкод); недоступные просто пропускаются.
BARCODES = [
    ("france", "fr", "3017620422003"),      # Nutella
    ("france", "fr", "3175680011480"),      # Gerblé biscuits sésame
    ("france", "fr", "3229820129488"),      # Bjorg
    ("france", "fr", "3033490004743"),      # LU Prince
    ("france", "fr", "3228857000166"),      # Harrys brioche
    ("germany", "de", "4001686301654"),     # Haribo Goldbären
    ("germany", "de", "4000417025005"),     # Ritter Sport Alpenmilch
    ("germany", "de", "4008400202013"),     # Kinder Riegel
    ("germany", "de", "4062300286177"),     # Hipp
    ("germany", "de", "4311501403792"),     # Edeka
    ("italy", "it", "8076800195057"),       # Barilla Spaghetti n.5
    ("italy", "it", "8000500310427"),       # Kinder Bueno
    ("italy", "it", "8001505005707"),       # Mulino Bianco
    ("italy", "it", "8002270014901"),       # Galbani
    ("spain", "es", "8410376013115"),       # Cola Cao
    ("spain", "es", "8480000160164"),       # Hacendado
    ("spain", "es", "8410179000060"),       # Bimbo
    ("united-kingdom", "en", "5449000000996"),  # Coca-Cola 330 ml
    ("united-kingdom", "en", "5000159484695"),  # Mars
    ("united-kingdom", "en", "5010029000153"),  # Heinz beans
    ("united-kingdom", "en", "5000168001098"),  # Cadbury
    ("netherlands", "nl", "8710398519689"),     # Calvé pindakaas
    ("netherlands", "nl", "8718906123366"),     # Albert Heijn
    ("poland", "pl", "5900259116543"),          # Wedel
    ("poland", "pl", "5901234123457"),
    ("czech-republic", "cs", "8593893772003"),  # Opavia
    ("russia", "ru", "4607043051007"),
    ("russia", "ru", "4600300030503"),
    ("russia", "ru", "4601605003002"),
]


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


def full_image_url(p, lang, any_language=False):
    """URL полноразмерного фото таблицы пищевой ценности на нужном языке (или на любом, если any_language)."""
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
    if any_language:
        display = ((p.get("selected_images") or {}).get("nutrition") or {}).get("display") or {}
        for _, url in sorted(display.items()):
            return url.replace(".400.jpg", ".full.jpg")
        if url400:
            return url400.replace(".400.jpg", ".full.jpg")
    return None


def product(code):
    r = get(f"https://world.openfoodfacts.org/api/v2/product/{code}.json?fields={FIELDS}")
    if r is None:
        return None
    try:
        data = r.json()
    except ValueError:
        return None
    return data.get("product") if data.get("status") == 1 else None


def is_candidate(p, lang, any_language=False):
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
    return full_image_url(p, lang, any_language) is not None


def save_product(p, url, country, lang, idx, manifest):
    """Скачивает фото, пишет data/<id>.jpg + .json, добавляет запись в manifest. Возвращает id или None."""
    r = get(url)
    if r is None:
        return None
    try:
        img = Image.open(io.BytesIO(r.content))
        img = ImageOps.exif_transpose(img).convert("RGB")
    except Exception as e:  # noqa: BLE001
        print(f"  bad image {url}: {e}", file=sys.stderr)
        return None
    orig = img.size
    if max(img.size) < 700:      # слишком мелкое фото — не показатель
        return None
    img.thumbnail((1600, 1600))
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
    print(f"+ {image_id}: {p.get('product_name')} ({p.get('brands')}) {orig}->{img.size}")
    return image_id


def write_attribution(manifest):
    """ATTRIBUTION.md по всему манифесту: синтетика, реальные фото из GitHub, Open Food Facts."""
    lines = ["# Источники изображений", "",
             "Синтетические этикетки (`s*`) сгенерированы скриптами `synth/` — HTML-таблица, отрисованная Chromium, "
             "с фотодеградацией (перспектива, поворот, цилиндр, блики, шум, JPEG). Лицензия: CC0.", "",
             "Реальные фото (`r*`) взяты из публичных GitHub-репозиториев (источник указан в поле `image_url`/`license` "
             "соответствующего JSON). Фото с Open Food Facts (`NN_xx_<штрихкод>`): фото участников OFF, CC BY-SA 3.0, данные ODbL.", ""]
    for m in manifest:
        if m.get("synthetic"):
            lines.append(f"- `{m['id']}` — синтетика: {m.get('product_name')}")
        elif m.get("code"):
            lines.append(f"- `{m['id']}` — {m.get('product_name')} ({m.get('brands')}) — {m['off_url']}")
        else:
            lines.append(f"- `{m['id']}` — {m.get('product_name')} — {m.get('license')}")
    (DATA / "ATTRIBUTION.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


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
                if save_product(p, full_image_url(p, lang), country, lang, idx + 1, manifest):
                    idx += 1
                    have_codes.add(p["code"])
                    got += 1
                time.sleep(1.0)
        print(f"{country}: {got}/{want}")

    # Запасной путь по известным штрихкодам (если поиск не сработал или дал мало).
    for country, lang, code in BARCODES:
        if code in have_codes:
            continue
        want = next((w for c, _, w in PLAN if c == country), 2)
        if sum(1 for m in manifest if m["country"] == country) >= want:
            continue
        p = product(code)
        if not p or not is_candidate(p, lang, any_language=True):
            print(f"  skip {code}: no product / no nutrition photo / incomplete data")
            time.sleep(0.5)
            continue
        if save_product(p, full_image_url(p, lang, any_language=True), country, lang, idx + 1, manifest):
            idx += 1
            have_codes.add(code)
        time.sleep(1.0)

    manifest.sort(key=lambda m: m["id"])
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    write_attribution(manifest)
    print(f"total {len(manifest)} images")


if __name__ == "__main__":
    main()
