#!/usr/bin/env python3
"""Сравнивает ответы моделей с эталоном и считает метрики точности/стоимости.

Эталон: data/<id>.json (значения из Open Food Facts) + ручные правки truth_overrides.json:
    {"exclude": ["05_it_..."],
     "images": {"01_de_123": {"truth": {"fiber_g": "absent", "salt_g": {"lt": 0.01}, "sugars_g": 3.6}, "note": "..."}}}
Значение поля эталона: число | {"lt": x} (на этикетке "<x") | "absent" (строки нет на этикетке) | "skip" | null (неизвестно).
Цены: pricing.json — $/1M токенов {"model": {"input": .., "output": ..}}.
"""
import json
import statistics
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
RESULTS = HERE / "results"
FIELDS = ["energy_kcal", "energy_kj", "fat_g", "saturated_fat_g", "carbohydrates_g", "sugars_g",
          "fiber_g", "protein_g", "salt_g"]
SHORT = {"energy_kcal": "ккал", "energy_kj": "кДж", "fat_g": "жиры", "saturated_fat_g": "насыщ.",
         "carbohydrates_g": "углев.", "sugars_g": "сахара", "fiber_g": "клетч.", "protein_g": "белки", "salt_g": "соль"}


def tolerance(field, truth, converted=False):
    if field == "energy_kcal":
        t = max(1.0, 0.01 * truth)
    elif field == "energy_kj":
        t = max(2.0, 0.01 * truth)
    else:
        t = 0.051 + 0.005 * truth
    return max(t * 4, 0.5) if converted else t   # пересчёт из порции: допускаем округления модели


def load_truth():
    manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
    overrides = {"exclude": [], "images": {}}
    p = HERE / "truth_overrides.json"
    if p.exists():
        overrides.update(json.loads(p.read_text(encoding="utf-8")))
    truth, flags = {}, {}
    for m in manifest:
        if m["id"] in overrides["exclude"]:
            continue
        t = dict(m["truth"])
        t.update((overrides["images"].get(m["id"]) or {}).get("truth", {}))
        truth[m["id"]] = t
        flags[m["id"]] = {"converted": bool(m.get("converted")), "size": m.get("stored_size") or [1200, 900]}
    return truth, overrides, flags


PROMPT_TOKENS_EST = 700      # инструкция + схема
OUTPUT_TOKENS_EST = 350


def estimate_usage(size):
    """Для прогонов без данных usage (субагенты): токены изображения по формуле Anthropic (w*h/750, длинная сторона <=1568)."""
    w, h = size
    k = min(1.0, 1568 / max(w, h))
    return {"input_tokens": int(w * k * h * k / 750) + PROMPT_TOKENS_EST, "output_tokens": OUTPUT_TOKENS_EST, "estimated": True}


def judge(field, tv, pv, converted=False):
    """-> 'correct' | 'wrong' | 'missing' | 'hallucinated' | None (не оценивается)."""
    if tv is None or tv == "skip":
        return None
    if tv == "absent":
        return None if pv is None else "hallucinated"
    if isinstance(tv, dict) and "lt" in tv:
        if pv is None:
            return "missing"
        return "correct" if -1e-9 <= float(pv) <= tv["lt"] + 1e-9 else "wrong"
    if pv is None:
        return "missing"
    try:
        return "correct" if abs(float(pv) - float(tv)) <= tolerance(field, float(tv), converted) else "wrong"
    except (TypeError, ValueError):
        return "wrong"


def main():
    truth, overrides, flags = load_truth()
    RESULTS.mkdir(exist_ok=True)
    pricing = json.loads((HERE / "pricing.json").read_text(encoding="utf-8")) if (HERE / "pricing.json").exists() else {}
    rows = []
    details = {}
    for provider_dir in sorted(p for p in RESULTS.iterdir() if p.is_dir()):
        for model_dir in sorted(p for p in provider_dir.iterdir() if p.is_dir()):
            recs = [json.loads(f.read_text(encoding="utf-8")) for f in sorted(model_dir.glob("*.json"))]
            recs = [r for r in recs if r["image_id"] in truth]
            if not recs:
                continue
            per_field = {f: defaultdict(int) for f in FIELDS}
            outcomes = defaultdict(int)
            full_ok = 0
            lat, tin, tout, treason = [], [], [], []
            errors, estimated = 0, False
            img_details = {}
            for r in recs:
                if not r.get("ok"):
                    errors += 1
                    img_details[r["image_id"]] = {"error": r.get("error")}
                    continue
                if r.get("latency_s") is not None:
                    lat.append(r["latency_s"])
                u = r.get("usage") or {}
                if u.get("input_tokens") is None and pricing.get(model_dir.name):
                    u = estimate_usage(flags[r["image_id"]]["size"])
                    estimated = True
                if u.get("input_tokens") is not None:
                    tin.append(u["input_tokens"])
                    tout.append(u.get("output_tokens") or 0)
                    treason.append(u.get("reasoning_tokens") or 0)
                p = r["parsed"]
                t = truth[r["image_id"]]
                all_ok, verdicts = True, {}
                for f in FIELDS:
                    v = judge(f, t.get(f), p.get(f), flags[r["image_id"]]["converted"])
                    if v is None:
                        continue
                    per_field[f][v] += 1
                    outcomes[v] += 1
                    verdicts[f] = v if v == "correct" else f"{v}: got {p.get(f)} want {t.get(f)}"
                    if v != "correct":
                        all_ok = False
                if all_ok:
                    full_ok += 1
                img_details[r["image_id"]] = {"verdicts": verdicts, "confidence": p.get("confidence"),
                                              "values_source": p.get("values_source"), "basis": p.get("basis"),
                                              "notes": p.get("notes"), "latency_s": r.get("latency_s")}
            scored = sum(outcomes.values())
            n_ok = len(recs) - errors
            price = pricing.get(model_dir.name) or {}
            cost = None
            if tin and price:
                per_img = [(i * price.get("input", 0) + o * price.get("output", 0)) / 1e6 for i, o in zip(tin, tout)]
                cost = statistics.mean(per_img)
            row = {
                "provider": provider_dir.name, "model": model_dir.name,
                "images": len(recs), "api_errors": errors,
                "fields_scored": scored,
                "accuracy": outcomes["correct"] / scored if scored else None,
                "wrong": outcomes["wrong"], "missing": outcomes["missing"], "hallucinated": outcomes["hallucinated"],
                "fully_correct_images": full_ok, "fully_correct_rate": full_ok / n_ok if n_ok else None,
                "latency_median_s": statistics.median(lat) if lat else None,
                "latency_mean_s": statistics.mean(lat) if lat else None,
                "input_tokens_mean": statistics.mean(tin) if tin else None,
                "output_tokens_mean": statistics.mean(tout) if tout else None,
                "reasoning_tokens_mean": statistics.mean(treason) if treason else None,
                "cost_per_image_usd": cost,
                "cost_per_1000_usd": cost * 1000 if cost is not None else None,
                "cost_estimated": estimated,
                "per_field_accuracy": {f: (per_field[f]["correct"] / sum(per_field[f].values())) if sum(per_field[f].values()) else None for f in FIELDS},
                "effort": next((r.get("effort") for r in recs if r.get("effort")), None),
            }
            rows.append(row)
            details[f"{provider_dir.name}/{model_dir.name}"] = img_details

    rows.sort(key=lambda r: (-(r["accuracy"] or 0), r["cost_per_image_usd"] or 9))
    RESULTS.mkdir(exist_ok=True)
    (RESULTS / "summary.json").write_text(json.dumps({"rows": rows, "n_images": len(truth), "excluded": overrides["exclude"]},
                                                     ensure_ascii=False, indent=2))
    (RESULTS / "details.json").write_text(json.dumps(details, ensure_ascii=False, indent=2))

    def fmt(v, spec):
        return "—" if v is None else format(v, spec)

    lines = [f"# Сводка бенчмарка ({len(truth)} фото, {len(FIELDS)} полей на фото)", "",
             "| Модель | Точность полей | Фото без ошибок | Ошибки / пропуски / выдумано | Медиана, с | Токены вход/выход | $/фото | $/1000 фото |",
             "|---|---|---|---|---|---|---|---|"]
    for r in rows:
        lines.append(
            f"| {r['model']}{' (effort='+r['effort']+')' if r['effort'] else ''} | {fmt(r['accuracy'], '.1%')} | "
            f"{r['fully_correct_images']}/{r['images'] - r['api_errors']} | {r['wrong']} / {r['missing']} / {r['hallucinated']} | "
            f"{fmt(r['latency_median_s'], '.1f')} | {fmt(r['input_tokens_mean'], '.0f')} / {fmt(r['output_tokens_mean'], '.0f')} | "
            f"{fmt(r['cost_per_image_usd'], '.4f')}{'*' if r['cost_estimated'] else ''} | {fmt(r['cost_per_1000_usd'], '.2f')}{'*' if r['cost_estimated'] else ''} |")
    if any(r["cost_estimated"] for r in rows):
        lines += ["", "\\* стоимость оценена по размеру изображения (формула токенов Anthropic) и типичной длине ответа — прогон шёл не через API, а через субагентов."]
    lines += ["", "## Точность по полям", "", "| Модель | " + " | ".join(SHORT[f] for f in FIELDS) + " |",
              "|---|" + "---|" * len(FIELDS)]
    for r in rows:
        lines.append(f"| {r['model']} | " + " | ".join(fmt(r['per_field_accuracy'][f], '.0%') for f in FIELDS) + " |")
    if any(r["api_errors"] for r in rows):
        lines += ["", "## Ошибки API", ""]
        for r in rows:
            if r["api_errors"]:
                lines.append(f"- {r['model']}: {r['api_errors']} ошибок")
    (RESULTS / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
