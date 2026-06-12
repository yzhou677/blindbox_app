#!/usr/bin/env python3
"""Generate Google Play listing raster assets from Shelfy branding."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "play_store"
ICON_SRC = REPO / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset" / "Icon-App-1024x1024@1x.png"
FALLBACK_ICON = REPO / "assets" / "images" / "app_icon.png"

# Shelfy theme tokens (lib/core/theme/app_theme.dart)
PURPLE_PRIMARY = (102, 82, 165)  # #6652A5
PURPLE_DEEP = (37, 32, 48)  # #252030
PURPLE_GLOW = (164, 146, 204)  # #A492CC
CREAM = (255, 250, 252)  # #FFFAFC
PEACH = (229, 152, 120)  # #E59878


def _load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = []
    if bold:
        candidates += [
            "C:/Windows/Fonts/segoeuib.ttf",
            "C:/Windows/Fonts/arialbd.ttf",
        ]
    else:
        candidates += [
            "C:/Windows/Fonts/segoeui.ttf",
            "C:/Windows/Fonts/arial.ttf",
        ]
    for path in candidates:
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size=size)
    return ImageFont.load_default()


def export_icon_512() -> Path:
    src = ICON_SRC if ICON_SRC.exists() else FALLBACK_ICON
    img = Image.open(src).convert("RGBA")
    icon = img.resize((512, 512), Image.Resampling.LANCZOS)
    out = OUT / "icon_512.png"
    # Play requires 32-bit PNG; flatten alpha on deep plum if needed for size compliance.
    flat = Image.new("RGBA", (512, 512), (*PURPLE_DEEP, 255))
    flat.alpha_composite(icon)
    flat.save(out, format="PNG", optimize=True)
    return out


def _radial_glow(size: tuple[int, int], center: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for r in range(radius, 0, -4):
        alpha = int(color[3] * (r / radius) ** 2)
        draw.ellipse(
            (center[0] - r, center[1] - r, center[0] + r, center[1] + r),
            fill=(color[0], color[1], color[2], alpha),
        )
    return glow.filter(ImageFilter.GaussianBlur(18))


def export_feature_graphic() -> Path:
    w, h = 1024, 500
    canvas = Image.new("RGB", (w, h), PURPLE_DEEP)
    draw = ImageDraw.Draw(canvas)

    # Soft diagonal wash
    for y in range(h):
        t = y / h
        r = int(PURPLE_DEEP[0] * (1 - t) + PURPLE_PRIMARY[0] * t * 0.55)
        g = int(PURPLE_DEEP[1] * (1 - t) + PURPLE_PRIMARY[1] * t * 0.55)
        b = int(PURPLE_DEEP[2] * (1 - t) + PURPLE_PRIMARY[2] * t * 0.55)
        draw.line([(0, y), (w, y)], fill=(r, g, b))

    glow = _radial_glow((w, h), (780, 250), 280, (*PURPLE_GLOW, 90))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), glow).convert("RGB")
    draw = ImageDraw.Draw(canvas)

    # Decorative stars
    import random

    rng = random.Random(42)
    for _ in range(28):
        x, y = rng.randint(0, w), rng.randint(0, h)
        s = rng.randint(1, 3)
        draw.ellipse((x, y, x + s, y + s), fill=(220, 200, 245))

    title_font = _load_font(46, bold=True)
    body_font = _load_font(28, bold=False)
    brand_font = _load_font(34, bold=True)

    draw.text((64, 64), "Shelfy", font=brand_font, fill=CREAM)
    draw.text((64, 118), "Track your", font=title_font, fill=CREAM)
    draw.text((64, 172), "collectibles", font=title_font, fill=CREAM)
    bullets = [
        "Discover new releases",
        "Explore the market",
    ]
    y = 248
    for line in bullets:
        draw.ellipse((64, y + 10, 78, y + 24), fill=PEACH)
        draw.text((92, y), line, font=body_font, fill=(235, 228, 248))
        y += 52

    src = ICON_SRC if ICON_SRC.exists() else FALLBACK_ICON
    mascot = Image.open(src).convert("RGBA")
    target_h = 380
    scale = target_h / mascot.height
    mascot = mascot.resize((int(mascot.width * scale), target_h), Image.Resampling.LANCZOS)
    x = w - mascot.width + 48
    y = (h - mascot.height) // 2 + 8
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(mascot, (x, y))
    canvas = canvas_rgba.convert("RGB")

    out = OUT / "feature_graphic_1024x500.png"
    canvas.save(out, format="PNG", optimize=True)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "screenshots" / "phone").mkdir(parents=True, exist_ok=True)
    icon = export_icon_512()
    feature = export_feature_graphic()
    print(f"Wrote {icon}")
    print(f"Wrote {feature}")


if __name__ == "__main__":
    main()
