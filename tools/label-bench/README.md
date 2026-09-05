# Бенчмарк распознавания этикеток

Сравнивает модели OpenAI и Anthropic на одной инструкции (`prompt.txt`) и JSON-схеме (`schema.json`) —
тех же, что использует приложение.

## Состав

- `data/` — 18 фото (14 синтетических + 4 реальных) и эталон в `*.json`, `manifest.json`, `ATTRIBUTION.md`.
- `synth/` — генератор синтетических этикеток (`specs.py` → HTML → Chromium через `render.js` → фотодеградация в `make_synthetic.py`).
- `add_real_images.py` — реальные фото из публичных GitHub-репозиториев с расшифрованным вручную эталоном.
- `fetch_dataset.py` — добавляет реальные фото с Open Food Facts (нужен интернет; используется в workflow).
- `run_models.py` — прогон моделей (`--provider openai|anthropic`), результаты в `results/<provider>/<model>/`.
- `score.py` — метрики, `results/summary.md`, `results/details.json`. Цены — `pricing.json`, ручные правки эталона — `truth_overrides.json`.
- `results/anthropic-agent/` — ответы моделей Claude, полученные через субагентов Claude Code (см. docs/model-analysis.md).

## Запуск

Локально (нужны ключи и интернет):

```bash
pip install -r requirements.txt
OPENAI_API_KEY=... python run_models.py --provider openai            # модели подбираются автоматически
ANTHROPIC_API_KEY=... python run_models.py --provider anthropic
python score.py
```

На GitHub Actions: Actions → **Label parsing benchmark** → Run workflow, вставить ключи в поля формы
(они попадают во вложенный workflow как секреты и маскируются в логах). Результаты коммитятся в ветку.

Пересобрать синтетику: `python synth/make_synthetic.py` (нужны Node + Playwright Chromium).
