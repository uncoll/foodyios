#!/usr/bin/env python3
"""Добавляет в data/ реальные фото этикеток, найденные в публичных GitHub-репозиториях
(единственный источник картинок, доступный из облачного контейнера — другие хосты закрыты сетевой политикой).

Эталон расшифрован вручную по фото. Для американских этикеток (значения только на порцию) эталон на 100 г/мл
пересчитан из порции; такие записи помечены converted=true (в скоринге для них шире допуск).
"""
import json
import shutil
from pathlib import Path

from PIL import Image, ImageOps

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"

REAL = [
    dict(id="r01_en_cookies", src="/home/user/openfoodfacts/openfoodfacts-dart/test/test_assets/nutrition_en.jpg",
         source="https://github.com/openfoodfacts/openfoodfacts-dart (test/test_assets/nutrition_en.jpg), фото участников Open Food Facts, CC BY-SA 3.0",
         lang="en", basis="per_100g", product="Cookies (UK label, red foil, glare)", serving_size=21, converted=False,
         truth=dict(energy_kcal=497, energy_kj=2085, fat_g=22.6, saturated_fat_g=11.6, carbohydrates_g=66.3, sugars_g=37.3,
                    fiber_g=3.1, protein_g=5.5, salt_g=0.6)),
    dict(id="r02_us_cranberry", src="/home/user/natthasath/python-nutrition-label/nutrition_extractor/data/test_images/ocr_eng_01.jpg",
         source="https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_01.jpg)",
         lang="en", basis="per_100ml", product="Cranberry juice (US label, per 240 ml serving only)", serving_size=240, converted=True,
         truth=dict(energy_kcal=45.8, energy_kj="absent", fat_g=0, saturated_fat_g="absent", carbohydrates_g=11.67, sugars_g=11.67,
                    fiber_g="absent", protein_g=0, salt_g="skip")),
    dict(id="r03_us_orange_nosize", src="/home/user/natthasath/python-nutrition-label/nutrition_extractor/data/test_images/ocr_eng_02.jpg",
         source="https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_02.jpg)",
         lang="en", basis="per_100ml", product="Orange juice (US label, serving '1 bottle' without size -> no per-100 values possible)",
         serving_size=None, converted=True,
         truth=dict(energy_kcal="absent", energy_kj="absent", fat_g="absent", saturated_fat_g="absent", carbohydrates_g="absent",
                    sugars_g="absent", fiber_g="absent", protein_g="absent", salt_g="skip")),
    dict(id="r04_us_bread", src="/home/user/natthasath/python-nutrition-label/nutrition_extractor/data/test_images/ocr_eng_03.jpg",
         source="https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_03.jpg)",
         lang="en", basis="per_100g", product="Bread (US label, per 28 g slice, blurry)", serving_size=28, converted=True,
         truth=dict(energy_kcal=250, energy_kj="absent", fat_g=5.36, saturated_fat_g=0, carbohydrates_g=46.4, sugars_g=7.14,
                    fiber_g=10.7, protein_g=10.7, salt_g="skip")),
]


def main():
    DATA.mkdir(parents=True, exist_ok=True)
    manifest_path = DATA / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    manifest = [m for m in manifest if m["id"] not in {r["id"] for r in REAL}]
    for r in REAL:
        img = ImageOps.exif_transpose(Image.open(r["src"])).convert("RGB")
        orig = img.size
        img.thumbnail((1600, 1600))
        img.save(DATA / f"{r['id']}.jpg", "JPEG", quality=88)
        entry = {"id": r["id"], "code": None, "product_name": r["product"], "brands": None, "country": "real", "lang": r["lang"],
                 "basis": r["basis"], "synthetic": False, "converted": r["converted"], "serving_size": r["serving_size"],
                 "off_url": None, "image_url": r["source"], "original_size": list(orig), "stored_size": list(img.size),
                 "license": r["source"], "truth": r["truth"]}
        (DATA / f"{r['id']}.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2))
        manifest.append(entry)
        print(f"+ {r['id']} {orig} -> {img.size}")
    manifest.sort(key=lambda m: m["id"])
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    lines = ["# Источники изображений", "",
             "Синтетические этикетки (`s*`) сгенерированы скриптами `synth/` — HTML-таблица, отрисованная Chromium, "
             "с фотодеградацией (перспектива, поворот, цилиндр, блики, шум, JPEG). Лицензия: CC0.", "",
             "Реальные фото (`r*`) взяты из публичных GitHub-репозиториев:", ""]
    lines += [f"- `{r['id']}` — {r['product']} — {r['source']}" for r in REAL]
    lines += ["", "Записи из Open Food Facts (`NN_xx_<barcode>`, если есть) добавляются workflow `label-bench.yml`: "
              "фото участников OFF, CC BY-SA 3.0, данные ODbL."]
    (DATA / "ATTRIBUTION.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"manifest: {len(manifest)}")


if __name__ == "__main__":
    main()
