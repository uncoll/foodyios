# Источники изображений

Синтетические этикетки (`s*`) сгенерированы скриптами `synth/` — HTML-таблица, отрисованная Chromium, с фотодеградацией (перспектива, поворот, цилиндр, блики, шум, JPEG). Лицензия: CC0.

Реальные фото (`r*`) взяты из публичных GitHub-репозиториев:

- `r01_en_cookies` — Cookies (UK label, red foil, glare) — https://github.com/openfoodfacts/openfoodfacts-dart (test/test_assets/nutrition_en.jpg), фото участников Open Food Facts, CC BY-SA 3.0
- `r02_us_cranberry` — Cranberry juice (US label, per 240 ml serving only) — https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_01.jpg)
- `r03_us_orange_nosize` — Orange juice (US label, serving '1 bottle' without size -> no per-100 values possible) — https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_02.jpg)
- `r04_us_bread` — Bread (US label, per 28 g slice, blurry) — https://github.com/natthasath/python-nutrition-label (data/test_images/ocr_eng_03.jpg)

Записи из Open Food Facts (`NN_xx_<barcode>`, если есть) добавляются workflow `label-bench.yml`: фото участников OFF, CC BY-SA 3.0, данные ODbL.
