"""
Normalize a circular mascot PNG to match Completionist / Loyalist / Curator.

- One full-bleed circular artwork (fills mid-edges of the square)
- Pure black only in the corners outside the circle
- No flat outer plate, nested ring, or wide soft dark fringe
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


def _art_radius(arr: np.ndarray) -> float:
    h, w = arr.shape[:2]
    cx = cy = (w - 1) / 2.0
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    lum = arr.astype(np.float64).sum(2)
    half = w / 2.0
    for r in np.linspace(0.995, 0.55, 120):
        ring = (dist >= (r - 0.01) * half) & (dist < (r + 0.01) * half)
        if ring.sum() < 40:
            continue
        if (lum[ring] > 45).mean() >= 0.55:
            return float(r * half)
    raise RuntimeError('could not detect artwork circle radius')


def _bilinear(arr: np.ndarray, sx: np.ndarray, sy: np.ndarray) -> np.ndarray:
    h, w = arr.shape[:2]
    x0 = np.floor(sx).astype(np.int32)
    y0 = np.floor(sy).astype(np.int32)
    x1 = np.clip(x0 + 1, 0, w - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    x0 = np.clip(x0, 0, w - 1)
    y0 = np.clip(y0, 0, h - 1)
    xa = (sx - x0).clip(0, 1)[..., None]
    ya = (sy - y0).clip(0, 1)[..., None]
    c00 = arr[y0, x0].astype(np.float64)
    c10 = arr[y0, x1].astype(np.float64)
    c01 = arr[y1, x0].astype(np.float64)
    c11 = arr[y1, x1].astype(np.float64)
    return (c00 * (1 - xa) + c10 * xa) * (1 - ya) + (c01 * (1 - xa) + c11 * xa) * ya


def normalize_full_bleed(src: Path, dst: Path) -> None:
    """Expand the painted circle so mid-edges match Completionist fill."""
    im = Image.open(src).convert('RGB')
    arr = np.array(im)
    h, w = arr.shape[:2]
    if h != w:
        raise ValueError(f'{src} must be square, got {w}x{h}')

    art_rad = _art_radius(arr)
    cx = cy = (w - 1) / 2.0
    # Distance from center to a mid-edge pixel (Completionist fill).
    mid_edge_rad = float(cy)  # ~511.5 on 1024
    fill_rad = mid_edge_rad + 0.5
    scale = fill_rad / art_rad

    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)

    sx = cx + (xx - cx) / scale
    sy = cy + (yy - cy) / scale
    sampled = _bilinear(arr, sx, sy)

    # Keep source interior; tiny post-scale rim uses scene bg (not a second plate).
    src_dist = dist / scale
    inside_src = src_dist <= art_rad - 1.0

    bg_samples: list[np.ndarray] = []
    for inset in (0.04, 0.07, 0.10):
        for deg in range(0, 360, 10):
            ang = np.deg2rad(deg)
            r = art_rad * (1.0 - inset)
            x = int(round(cx + r * np.sin(ang)))
            y = int(round(cy - r * np.cos(ang)))
            if 0 <= x < w and 0 <= y < h:
                p = arr[y, x].astype(np.float64)
                if p.sum() > 120:
                    bg_samples.append(p)
    bg = np.median(np.stack(bg_samples), axis=0) if bg_samples else np.array(
        [180.0, 160.0, 190.0]
    )

    out = np.zeros((h, w, 3), dtype=np.float64)
    out[inside_src] = sampled[inside_src]

    need_bg = (dist <= fill_rad) & ~inside_src
    out[need_bg] = bg

    lum = out.sum(2)
    bad = (dist <= fill_rad) & (lum < 50)
    out[bad] = bg

    # ~1px AA only — avoid the wide darkened fringe that reads as an inner ring.
    aa = np.clip(fill_rad + 0.5 - dist, 0.0, 1.0)
    out = out * aa[..., None]
    out[dist > fill_rad + 1.0] = 0

    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(
        dst, format='PNG', optimize=True
    )
    print(
        f'{src.name} -> {dst.name}  art_rad={art_rad:.1f}  '
        f'scale={scale:.3f}  fill_rad={fill_rad:.1f}  '
        f'bg=({int(bg[0])},{int(bg[1])},{int(bg[2])})'
    )


def main() -> None:
    regen = Path(r'C:\Users\runze\.cursor\projects\d-blindbox-app\assets')
    out = Path('assets/insights/collector_types')
    normalize_full_bleed(regen / 'dreamer_regen2.png', out / 'dreamer.png')
    normalize_full_bleed(regen / 'hunter_regen2.png', out / 'hunter.png')


if __name__ == '__main__':
    main()
