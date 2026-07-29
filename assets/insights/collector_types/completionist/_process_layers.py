"""Build registered Completionist animation layers on a shared 1024 canvas.

Pipeline:
1. Matte light studio / circular backdrops from raw AI layers
2. Template-match each sprite against the registration / source plate
3. Paste onto identical 1024x1024 transparent canvases
4. Synthesize blink.png eyelids aligned to head.png
5. Write stack preview for visual QA
"""

from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DST = Path(__file__).resolve().parent
RAW = {
    "body": DST / "_raw_body.png",
    "head": DST / "_raw_head.png",
    "crown": DST / "_raw_crown.png",
    "arms_trophy": DST / "_raw_arms_trophy.png",
    "decorations": DST / "_raw_decorations.png",
}
REG = DST / "_registration_full.png"
SRC_FULL = DST / "_source_full.png"
CANVAS = 1024


def matte_rgba(im: Image.Image) -> Image.Image:
    """Knock out near-white / neutral studio backgrounds into alpha."""
    im = im.convert("RGBA")
    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    lum = rgb.mean(axis=2)

    corners = np.concatenate(
        [
            rgb[0:24, 0:24].reshape(-1, 3),
            rgb[0:24, -24:].reshape(-1, 3),
            rgb[-24:, 0:24].reshape(-1, 3),
            rgb[-24:, -24:].reshape(-1, 3),
        ]
    )
    bg = np.median(corners, axis=0)
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))

    # Neutral light studio / paper
    near_bg = dist < 28
    white = (r > 242) & (g > 242) & (b > 242)
    light_neutral = (lum > 228) & (sat < 0.08)
    # Soft sage circular plate leftovers (desaturated green-gray)
    sage_plate = (
        (lum > 175)
        & (lum < 235)
        & (sat < 0.12)
        & (g >= r - 8)
        & (g >= b - 5)
        & (np.abs(r - b) < 25)
    )

    keep = ~(near_bg | white | light_neutral | sage_plate)

    # Drop tiny speckles; keep largest connected components
    mask_u8 = keep.astype(np.uint8) * 255
    num, labels, stats, _ = cv2.connectedComponentsWithStats(mask_u8, connectivity=8)
    cleaned = np.zeros_like(mask_u8)
    for i in range(1, num):
        area = int(stats[i, cv2.CC_STAT_AREA])
        if area >= 80:
            cleaned[labels == i] = 255

    # Soft edge
    soft = cv2.GaussianBlur(cleaned, (0, 0), 0.8)
    out = arr.copy()
    out[:, :, 3] = soft
    # Zero RGB on fully transparent to avoid fringe when compositing
    out[soft < 8, :3] = 0
    return Image.fromarray(out, "RGBA")


def trim_sprite(im: Image.Image, pad: int = 2) -> Image.Image:
    arr = np.array(im)
    alpha = arr[:, :, 3] > 12
    if not alpha.any():
        return im
    ys, xs = np.where(alpha)
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(im.width, int(xs.max()) + 1 + pad)
    y1 = min(im.height, int(ys.max()) + 1 + pad)
    return im.crop((x0, y0, x1, y1))


def reference_rgba() -> Image.Image:
    """Prefer registration plate; fall back to source full with black keyed."""
    if REG.exists():
        return matte_rgba(Image.open(REG))
    src = Image.open(SRC_FULL).convert("RGBA")
    arr = np.array(src)
    rgb = arr[:, :, :3].astype(np.float32)
    # Black letterbox outside circular art
    black = rgb.mean(axis=2) < 18
    arr[:, :, 3] = np.where(black, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def match_place(
    sprite: Image.Image,
    reference: Image.Image,
    *,
    scales: list[float] | None = None,
    search_margin: float = 0.0,
) -> tuple[Image.Image, dict]:
    """Place sprite onto 1024 canvas via multi-scale template match."""
    scales = scales or [0.55, 0.65, 0.75, 0.85, 0.95, 1.0, 1.05, 1.15, 1.25, 1.4]
    ref = np.array(reference.convert("RGBA"))
    ref_rgb = ref[:, :, :3]
    ref_a = ref[:, :, 3] > 20
    # Match against luminance of opaque reference pixels
    ref_gray = cv2.cvtColor(ref_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
    ref_gray = np.where(ref_a, ref_gray, 0).astype(np.float32)

    spr = np.array(sprite.convert("RGBA"))
    best = None  # (score, scale, x, y, w, h, resized_rgba)

    for s in scales:
        w = max(8, int(round(spr.shape[1] * s)))
        h = max(8, int(round(spr.shape[0] * s)))
        if w >= CANVAS - 4 or h >= CANVAS - 4:
            continue
        resized = cv2.resize(spr, (w, h), interpolation=cv2.INTER_AREA)
        tmpl_rgb = resized[:, :, :3]
        tmpl_a = resized[:, :, 3] > 20
        if tmpl_a.mean() < 0.01:
            continue
        tmpl_gray = cv2.cvtColor(tmpl_rgb, cv2.COLOR_RGB2GRAY).astype(np.float32)
        # Zero out transparent template pixels for cleaner match
        tmpl_gray = np.where(tmpl_a, tmpl_gray, 0).astype(np.float32)

        # OpenCV matchTemplate needs tmpl smaller than image
        if h >= ref_gray.shape[0] or w >= ref_gray.shape[1]:
            continue
        res = cv2.matchTemplate(ref_gray, tmpl_gray, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(res)
        x, y = int(max_loc[0]), int(max_loc[1])
        score = float(max_val)
        if best is None or score > best[0]:
            best = (score, s, x, y, w, h, resized)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    meta: dict = {"matched": False}
    if best is None:
        # Fallback: center horizontally, lower third for body-like
        fallback = sprite.resize(
            (
                min(CANVAS, sprite.width),
                min(CANVAS, sprite.height),
            ),
            Image.Resampling.LANCZOS,
        )
        x = (CANVAS - fallback.width) // 2
        y = (CANVAS - fallback.height) // 2
        canvas.paste(fallback, (x, y), fallback)
        meta.update({"score": 0.0, "scale": 1.0, "x": x, "y": y, "fallback": True})
        return canvas, meta

    score, s, x, y, w, h, resized = best
    layer = Image.fromarray(resized, "RGBA")
    canvas.paste(layer, (x, y), layer)
    meta.update(
        {
            "matched": True,
            "score": round(score, 4),
            "scale": round(s, 4),
            "x": x,
            "y": y,
            "w": w,
            "h": h,
        }
    )
    return canvas, meta


def make_blink(head: Image.Image) -> Image.Image:
    """Eyelids-only overlay registered to head canvas."""
    blink = Image.new("RGBA", head.size, (0, 0, 0, 0))
    arr = np.array(head)
    alpha = arr[:, :, 3] > 20
    ys, xs = np.where(alpha)
    if len(xs) == 0:
        return blink

    # Prefer face band: peach skin pixels inside head bbox
    rgb = arr[:, :, :3].astype(np.float32)
    peach = (
        (rgb[:, :, 0] > 180)
        & (rgb[:, :, 1] > 140)
        & (rgb[:, :, 2] > 120)
        & (rgb[:, :, 0] > rgb[:, :, 2] + 15)
        & alpha
    )
    if peach.sum() > 200:
        fys, fxs = np.where(peach)
        x0, x1 = int(fxs.min()), int(fxs.max())
        y0, y1 = int(fys.min()), int(fys.max())
    else:
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())

    bw = max(1, x1 - x0)
    bh = max(1, y1 - y0)
    draw = ImageDraw.Draw(blink)

    # Closed smiling eyes sit ~42% down the face
    eye_y = y0 + int(bh * 0.42)
    left_cx = x0 + int(bw * 0.33)
    right_cx = x0 + int(bw * 0.67)
    lid_w = max(14, int(bw * 0.16))
    lid_h = max(8, int(bh * 0.07))

    # Soft clay eyelid (slightly darker than skin, sage-tinted)
    fill = (210, 195, 175, 235)
    edge = (120, 95, 75, 200)
    for cx in (left_cx, right_cx):
        box = [cx - lid_w, eye_y - lid_h // 3, cx + lid_w, eye_y + lid_h]
        draw.ellipse(box, fill=fill)
        # thin lash curve
        draw.arc(
            [cx - lid_w, eye_y - lid_h // 2, cx + lid_w, eye_y + lid_h // 2],
            start=200,
            end=340,
            fill=edge,
            width=max(2, lid_h // 3),
        )

    return blink.filter(ImageFilter.GaussianBlur(0.8))


def opaque_ratio(im: Image.Image) -> float:
    a = np.array(im)[:, :, 3]
    return float((a > 12).mean())


def main() -> None:
    reference = reference_rgba()
    reference.save(DST / "_ref_matted.png", "PNG")

    layers: dict[str, Image.Image] = {}
    match_meta: dict[str, dict] = {}

    # Per-layer scale priors (AI sprites are often larger / tighter framed)
    scale_hints = {
        "body": [0.5, 0.58, 0.66, 0.74, 0.82, 0.9, 0.98, 1.05],
        "head": [0.35, 0.42, 0.5, 0.58, 0.66, 0.74, 0.82, 0.9],
        "crown": [0.25, 0.32, 0.4, 0.48, 0.56, 0.64, 0.72, 0.8],
        "arms_trophy": [0.35, 0.42, 0.5, 0.58, 0.66, 0.74, 0.82, 0.9],
        "decorations": [0.55, 0.65, 0.75, 0.85, 0.95, 1.05, 1.15],
    }

    for name, path in RAW.items():
        if not path.exists():
            print(f"MISSING {path}")
            continue
        matted = matte_rgba(Image.open(path))
        sprite = trim_sprite(matted, pad=4)
        # Keep a debug dump of the isolated sprite
        sprite.save(DST / f"_sprite_{name}.png", "PNG")
        placed, meta = match_place(sprite, reference, scales=scale_hints[name])
        layers[name] = placed
        match_meta[name] = meta
        placed.save(DST / f"{name}.png", "PNG")
        print(
            f"{name}.png opaque={opaque_ratio(placed):.3f} "
            f"match={meta}"
        )

    head = layers.get("head")
    if head is not None:
        blink = make_blink(head)
        blink.save(DST / "blink.png", "PNG")
        layers["blink"] = blink
        print(f"blink.png opaque={opaque_ratio(blink):.4f}")

    order = ["decorations", "body", "arms_trophy", "head", "blink", "crown"]
    comp = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for name in order:
        layer = layers.get(name)
        if layer is None:
            continue
        comp = Image.alpha_composite(comp, layer)

    preview_bg = Image.new("RGBA", (CANVAS, CANVAS), (240, 240, 238, 255))
    preview = Image.alpha_composite(preview_bg, comp)
    preview.convert("RGB").save(DST / "_preview_stack.jpg", quality=93)

    # Side-by-side with source for QA
    src = Image.open(SRC_FULL).convert("RGB").resize((CANVAS, CANVAS))
    side = Image.new("RGB", (CANVAS * 2 + 16, CANVAS), (30, 30, 30))
    side.paste(src, (0, 0))
    side.paste(preview.convert("RGB"), (CANVAS + 16, 0))
    side.save(DST / "_preview_compare.jpg", quality=92)

    manifest = {
        "canvas": {"width": CANVAS, "height": CANVAS},
        "stack_order": order,
        "body": {
            "file": "body.png",
            "anchor": "center_bottom",
            "notes": "torso, cape, legs, shoes, reconstructed chest/neck",
        },
        "head": {
            "file": "head.png",
            "anchor": "center_bottom",
            "notes": "full head hair ears face; no crown",
        },
        "blink": {
            "file": "blink.png",
            "anchor": "center_bottom",
            "notes": "eyelids-only overlay aligned to head.png",
        },
        "crown": {
            "file": "crown.png",
            "anchor": "center_bottom",
            "notes": "crown only for bounce animation",
        },
        "arms_trophy": {
            "file": "arms_trophy.png",
            "anchor": "center",
            "notes": "both arms, hands, trophy; reconstructed sleeves",
        },
        "decorations": {
            "file": "decorations.png",
            "anchor": "center",
            "optional": True,
            "notes": "stars, checklist, books, badge, sparkles",
        },
        "animation_hints": {
            "idle_breathing": "scale body 0.985-1.015 around center_bottom",
            "head_bob": "translate head+blink+crown together ±4px Y",
            "crown_bounce": "translate crown alone with slight overshoot",
            "blink": "opacity blink 0→1→0 over ~120ms",
            "arm_bounce": "rotate arms_trophy ±3deg around chest center",
            "trophy_celebration": "scale arms_trophy 1.0→1.08 with bounce",
            "sparkle": "opacity/scale decorations particles",
        },
        "registration": match_meta,
    }
    (DST / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("wrote manifest.json, _preview_stack.jpg, _preview_compare.jpg")


if __name__ == "__main__":
    main()
