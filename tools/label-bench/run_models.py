#!/usr/bin/env python3
"""Прогоняет фотографии этикеток через модели OpenAI / Anthropic и сохраняет сырые ответы.

    python run_models.py --provider openai            # автообнаружение подходящих моделей
    python run_models.py --provider openai --models gpt-5.6-luna,gpt-4.1-mini
    python run_models.py --provider anthropic --models claude-haiku-4-5,claude-sonnet-5

Ключи берутся из OPENAI_API_KEY / ANTHROPIC_API_KEY. Результаты: results/<provider>/<model>/<image_id>.json
(уже посчитанные пары модель+фото пропускаются — можно перезапускать).
Запрос к модели повторяет то, что делает iOS-приложение: та же инструкция (prompt.txt) и та же JSON-схема (schema.json).
"""
import argparse
import base64
import json
import os
import re
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
RESULTS = HERE / "results"
PROMPT = (HERE / "prompt.txt").read_text(encoding="utf-8")
SCHEMA = json.loads((HERE / "schema.json").read_text(encoding="utf-8"))

# Какие модели OpenAI берём при автообнаружении (без датированных снапшотов и спец. вариантов).
OPENAI_INCLUDE = [
    r"^gpt-5(\.\d+)?$",
    r"^gpt-5(\.\d+)?-(mini|nano|luna|terra|sol)$",
    r"^gpt-4\.1(-mini|-nano)?$",
    r"^gpt-4o(-mini)?$",
]
OPENAI_EXCLUDE = re.compile(r"(pro|codex|chat-latest|realtime|audio|search|transcribe|tts|image|preview|\d{4}-\d{2}-\d{2})")
ANTHROPIC_DEFAULT = ["claude-haiku-4-5", "claude-sonnet-5", "claude-opus-5", "claude-fable-5-1"]


def is_reasoning_model(model: str) -> bool:
    return model.startswith("gpt-5") or re.match(r"^o\d", model) is not None


def load_images(limit: int):
    manifest = json.loads((DATA / "manifest.json").read_text(encoding="utf-8"))
    excluded = set()
    ov = HERE / "truth_overrides.json"
    if ov.exists():
        excluded = set(json.loads(ov.read_text(encoding="utf-8")).get("exclude", []))
    items = [m for m in manifest if m["id"] not in excluded]
    return items[:limit] if limit > 0 else items


def b64_image(image_id: str) -> str:
    return base64.b64encode((DATA / f"{image_id}.jpg").read_bytes()).decode("ascii")


# ---------------------------------------------------------------- OpenAI

def openai_models(key: str):
    r = requests.get("https://api.openai.com/v1/models", headers={"Authorization": f"Bearer {key}"}, timeout=60)
    r.raise_for_status()
    ids = sorted(m["id"] for m in r.json()["data"])
    RESULTS.mkdir(parents=True, exist_ok=True)
    (RESULTS / "openai_models.json").write_text(json.dumps(ids, indent=2))
    chosen = [m for m in ids if any(re.match(p, m) for p in OPENAI_INCLUDE) and not OPENAI_EXCLUDE.search(m)]
    return chosen


def call_openai(key: str, model: str, image_id: str, effort: str, detail: str):
    body = {
        "model": model,
        "input": [{
            "role": "user",
            "content": [
                {"type": "input_text", "text": PROMPT},
                {"type": "input_image", "image_url": f"data:image/jpeg;base64,{b64_image(image_id)}", "detail": detail},
            ],
        }],
        "text": {"format": {"type": "json_schema", "name": "nutrition_label", "strict": True, "schema": SCHEMA}},
        "max_output_tokens": 4000,
        "store": False,
    }
    if is_reasoning_model(model) and effort:
        body["reasoning"] = {"effort": effort}
    t0 = time.time()
    r = requests.post("https://api.openai.com/v1/responses", json=body, timeout=300,
                      headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    latency = time.time() - t0
    rec = {"provider": "openai", "model": model, "image_id": image_id, "latency_s": round(latency, 2),
           "http_status": r.status_code, "effort": effort if "reasoning" in body else None, "detail": detail}
    try:
        data = r.json()
    except ValueError:
        rec.update(ok=False, error=f"non-json response: {r.text[:300]}")
        return rec
    if r.status_code != 200:
        rec.update(ok=False, error=json.dumps(data.get("error", data))[:500])
        return rec
    usage = data.get("usage") or {}
    rec["usage"] = {
        "input_tokens": usage.get("input_tokens"),
        "output_tokens": usage.get("output_tokens"),
        "reasoning_tokens": (usage.get("output_tokens_details") or {}).get("reasoning_tokens"),
        "cached_tokens": (usage.get("input_tokens_details") or {}).get("cached_tokens"),
    }
    rec["status"] = data.get("status")
    text = None
    for item in data.get("output", []):
        if item.get("type") == "message":
            for c in item.get("content", []):
                if c.get("type") == "output_text":
                    text = c.get("text")
                elif c.get("type") == "refusal":
                    rec["error"] = "refusal: " + str(c.get("refusal"))
    rec["raw_text"] = text
    if text:
        try:
            rec["parsed"] = json.loads(text)
            rec["ok"] = True
        except ValueError as e:
            rec.update(ok=False, error=f"json decode: {e}")
    else:
        rec.setdefault("error", f"no output text (status={data.get('status')}, details={data.get('incomplete_details')})")
        rec["ok"] = False
    return rec


# ---------------------------------------------------------------- Anthropic

def call_anthropic(key: str, model: str, image_id: str, effort: str, detail: str):
    body = {
        "model": model,
        "max_tokens": 4000,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64_image(image_id)}},
                {"type": "text", "text": PROMPT},
            ],
        }],
        "output_config": {"format": {"type": "json_schema", "schema": SCHEMA}},
    }
    if effort and not model.startswith("claude-haiku"):
        body["output_config"]["effort"] = effort
    t0 = time.time()
    r = requests.post("https://api.anthropic.com/v1/messages", json=body, timeout=300,
                      headers={"x-api-key": key, "anthropic-version": "2023-06-01", "Content-Type": "application/json"})
    latency = time.time() - t0
    rec = {"provider": "anthropic", "model": model, "image_id": image_id, "latency_s": round(latency, 2),
           "http_status": r.status_code, "effort": body["output_config"].get("effort"), "detail": None}
    try:
        data = r.json()
    except ValueError:
        rec.update(ok=False, error=f"non-json response: {r.text[:300]}")
        return rec
    if r.status_code != 200:
        rec.update(ok=False, error=json.dumps(data.get("error", data))[:500])
        return rec
    usage = data.get("usage") or {}
    rec["usage"] = {"input_tokens": usage.get("input_tokens"), "output_tokens": usage.get("output_tokens"),
                    "reasoning_tokens": None, "cached_tokens": usage.get("cache_read_input_tokens")}
    rec["status"] = data.get("stop_reason")
    text = next((b.get("text") for b in data.get("content", []) if b.get("type") == "text"), None)
    rec["raw_text"] = text
    if data.get("stop_reason") == "refusal":
        rec.update(ok=False, error="refusal")
    elif text:
        try:
            rec["parsed"] = json.loads(text)
            rec["ok"] = True
        except ValueError as e:
            rec.update(ok=False, error=f"json decode: {e}")
    else:
        rec.update(ok=False, error="no text block")
    return rec


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--provider", required=True, choices=["openai", "anthropic"])
    ap.add_argument("--models", default="", help="comma-separated; empty = auto")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--effort", default="low", help="reasoning effort for reasoning models ('' to omit)")
    ap.add_argument("--detail", default="high", help="OpenAI image detail: auto|low|high")
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("OPENAI_API_KEY" if args.provider == "openai" else "ANTHROPIC_API_KEY", "")
    if not key:
        print("no API key in environment; nothing to do")
        return 0
    models = [m.strip() for m in args.models.split(",") if m.strip()]
    if not models:
        models = openai_models(key) if args.provider == "openai" else ANTHROPIC_DEFAULT
    print(f"models: {models}")
    images = load_images(args.limit)
    print(f"images: {len(images)}")
    call = call_openai if args.provider == "openai" else call_anthropic

    for model in models:
        out_dir = RESULTS / args.provider / model
        out_dir.mkdir(parents=True, exist_ok=True)
        todo = [m["id"] for m in images if args.force or not (out_dir / f"{m['id']}.json").exists()]
        print(f"\n=== {model}: {len(todo)} to run")
        lat, errs = [], 0
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = {ex.submit(call, key, model, iid, args.effort, args.detail): iid for iid in todo}
            for f in as_completed(futs):
                iid = futs[f]
                try:
                    rec = f.result()
                except Exception as e:  # noqa: BLE001
                    rec = {"provider": args.provider, "model": model, "image_id": iid, "ok": False, "error": repr(e)}
                (out_dir / f"{iid}.json").write_text(json.dumps(rec, ensure_ascii=False, indent=2))
                if rec.get("ok"):
                    lat.append(rec["latency_s"])
                    p = rec["parsed"]
                    print(f"  {iid}: {rec['latency_s']}s kcal={p.get('energy_kcal')} P={p.get('protein_g')} "
                          f"F={p.get('fat_g')} C={p.get('carbohydrates_g')} conf={p.get('confidence')}")
                else:
                    errs += 1
                    print(f"  {iid}: ERROR {rec.get('error')}")
        if lat:
            print(f"  median latency {statistics.median(lat):.1f}s, errors {errs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
