#!/usr/bin/env python3
"""Генерирует синтетические фото этикеток (HTML -> Chromium -> «фотодеградация») и добавляет их в data/.

    python make_synthetic.py            # все спеки
    python make_synthetic.py s03 s11    # только выбранные (по префиксу id)
"""
import io
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

import specs

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"
RNG = np.random.default_rng(20260905)


# ------------------------------------------------------------------ degradations

def sample_bilinear(arr, xs, ys):
    """arr HxWxC float; xs, ys — карты координат источника (H'xW'). Вне границ -> nan (заполним фоном)."""
    h, w = arr.shape[:2]
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = (xs - x0)[..., None]
    fy = (ys - y0)[..., None]
    valid = (x0 >= 0) & (x0 < w - 1) & (y0 >= 0) & (y0 < h - 1)
    x0c = np.clip(x0, 0, w - 2)
    y0c = np.clip(y0, 0, h - 2)
    out = (arr[y0c, x0c] * (1 - fx) * (1 - fy) + arr[y0c, x0c + 1] * fx * (1 - fy)
           + arr[y0c + 1, x0c] * (1 - fx) * fy + arr[y0c + 1, x0c + 1] * fx * fy)
    return out, valid


def cylinder(img, k, bg):
    """Этикетка на банке/бутылке: горизонтальное сжатие к краям + затенение краёв."""
    arr = np.asarray(img).astype(np.float32)
    h, w = arr.shape[:2]
    us = np.linspace(-1, 1, w)
    src_u = np.arcsin(np.clip(us * k, -1, 1)) / math.asin(k)          # -1..1 -> положение в исходнике
    xs = (src_u + 1) / 2 * (w - 1)
    XS = np.broadcast_to(xs, (h, w))
    YS = np.broadcast_to(np.arange(h, dtype=np.float32)[:, None], (h, w))
    out, valid = sample_bilinear(arr, XS, YS)
    out[~valid] = bg
    shade = (1 - 0.55 * np.abs(us) ** 2.2)[None, :, None]
    out = out * shade + np.array(bg, dtype=np.float32) * 0
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def perspective(img, strength, bg):
    w, h = img.size
    dx, dy = strength * w, strength * h
    r = lambda s: float(RNG.uniform(-s, s))  # noqa: E731
    src = [(0, 0), (w, 0), (w, h), (0, h)]
    dst = [(r(dx), r(dy)), (w + r(dx), r(dy)), (w + r(dx), h + r(dy)), (r(dx), h + r(dy))]
    # решаем коэффициенты перспективы (dst -> src), как требует PIL
    A, B = [], []
    for (x, y), (u, v) in zip(dst, src):
        A.append([x, y, 1, 0, 0, 0, -u * x, -u * y]); B.append(u)
        A.append([0, 0, 0, x, y, 1, -v * x, -v * y]); B.append(v)
    coeffs = np.linalg.solve(np.array(A, dtype=np.float64), np.array(B, dtype=np.float64))
    pad = int(max(dx, dy)) + 4
    canvas = Image.new("RGB", (w + 2 * pad, h + 2 * pad), bg)
    canvas.paste(img, (pad, pad))
    # координаты со сдвигом на pad
    shifted = np.array(coeffs)
    out = canvas.transform(canvas.size, Image.Transform.PERSPECTIVE, tuple(shifted), Image.Resampling.BICUBIC, fillcolor=bg)
    return out


def shade_and_glare(img, shade, glare):
    arr = np.asarray(img).astype(np.float32)
    h, w = arr.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if shade > 0:
        ang = RNG.uniform(0, 2 * math.pi)
        grad = (np.cos(ang) * (xx / w - 0.5) + np.sin(ang) * (yy / h - 0.5))
        light = 1 - shade * 0.5 * (grad + 0.5)
        light += shade * 0.15 * np.cos((xx / w) * 6 + RNG.uniform(0, 3))   # лёгкие складки
        arr *= np.clip(light, 0.45, 1.15)[..., None]
    if glare > 0:
        cx, cy = RNG.uniform(0.2, 0.8) * w, RNG.uniform(0.2, 0.8) * h
        sx, sy = w * RNG.uniform(0.08, 0.2), h * RNG.uniform(0.25, 0.6)
        blob = np.exp(-(((xx - cx) / sx) ** 2 + ((yy - cy) / sy) ** 2))
        arr = arr + (255 - arr) * (glare * 0.9 * blob)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def photo_background(img, bg):
    """Кладём этикетку на «стол» с полями, как на реальном фото."""
    w, h = img.size
    m = int(0.06 * max(w, h))
    base = tuple(int(c) for c in RNG.integers(60, 140, size=3))
    canvas = Image.new("RGB", (w + 2 * m, h + 2 * m), base)
    noise = RNG.normal(0, 6, size=(canvas.size[1], canvas.size[0], 1)).astype(np.float32)
    arr = np.clip(np.asarray(canvas).astype(np.float32) + noise, 0, 255).astype(np.uint8)
    canvas = Image.fromarray(arr)
    canvas.paste(img, (m, m))
    return canvas


def degrade(img, d, bg):
    if d.get("cylinder"):
        img = cylinder(img, d["cylinder"], bg)
    if d.get("perspective"):
        img = perspective(img, d["perspective"], bg)
    if d.get("rotate"):
        img = img.rotate(d["rotate"], resample=Image.Resampling.BICUBIC, expand=True, fillcolor=bg)
    img = photo_background(img, bg)
    img = shade_and_glare(img, d.get("shade", 0), d.get("glare", 0))
    if d.get("tint"):
        arr = np.asarray(img).astype(np.float32) * np.array(d["tint"], dtype=np.float32)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    if d.get("scale", 1.0) != 1.0:
        img = img.resize((max(1, int(img.width * d["scale"])), max(1, int(img.height * d["scale"]))), Image.Resampling.LANCZOS)
    if d.get("blur"):
        img = img.filter(ImageFilter.GaussianBlur(d["blur"]))
    if d.get("noise"):
        arr = np.asarray(img).astype(np.float32) + RNG.normal(0, d["noise"], size=np.asarray(img).shape)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=d.get("jpeg", 80))
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def hex_rgb(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


# ------------------------------------------------------------------ main

def main(prefixes):
    chosen = [s for s in specs.SPECS if not prefixes or any(s["id"].startswith(p) for p in prefixes)]
    DATA.mkdir(parents=True, exist_ok=True)
    manifest_path = DATA / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    manifest = [m for m in manifest if m["id"] not in {s["id"] for s in chosen}]
    with tempfile.TemporaryDirectory() as tmp:
        html_dir, png_dir = Path(tmp) / "html", Path(tmp) / "png"
        html_dir.mkdir()
        for s in chosen:
            (html_dir / f"{s['id']}.html").write_text(specs.html_for(s), encoding="utf-8")
        subprocess.run(["node", str(HERE / "render.js"), str(html_dir), str(png_dir), "2"], check=True)
        for s in chosen:
            img = Image.open(png_dir / f"{s['id']}.png").convert("RGB")
            clean_size = img.size
            out = degrade(img, s["degrade"], hex_rgb(s["style"]["bg"]))
            out.thumbnail((1600, 1600))
            out.save(DATA / f"{s['id']}.jpg", "JPEG", quality=90)
            truth = {k: None for k in specs.FIELDS}
            truth.update(s["values"])
            entry = {
                "id": s["id"], "code": None, "product_name": s["product"], "brands": None,
                "country": s["lang"], "lang": s["lang"], "basis": s["basis"], "synthetic": True,
                "serving_size": s.get("serving_g"), "off_url": None, "image_url": None,
                "original_size": list(clean_size), "stored_size": list(out.size),
                "license": "synthetic label rendered for this benchmark (CC0)",
                "degrade": s["degrade"], "truth": truth,
            }
            (DATA / f"{s['id']}.json").write_text(json.dumps(entry, ensure_ascii=False, indent=2))
            manifest.append(entry)
            print(f"+ {s['id']} {clean_size} -> {out.size}")
    manifest.sort(key=lambda m: m["id"])
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"manifest: {len(manifest)} entries")


if __name__ == "__main__":
    main(sys.argv[1:])
