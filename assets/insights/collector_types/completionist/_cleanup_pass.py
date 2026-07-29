"""Conservative cleanup for head/arms/trophy — fringe & crumbs only."""
from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

DST = Path(__file__).resolve().parent


def keep_n_largest(arr: np.ndarray, n: int, min_area: int = 1) -> np.ndarray:
    num, labels, stats, _ = cv2.connectedComponentsWithStats(
        (arr[:, :, 3] > 0).astype(np.uint8), 8
    )
    areas = sorted(
        ((int(stats[i, 4]), i) for i in range(1, num)),
        reverse=True,
    )
    out = np.zeros_like(arr)
    for area, i in areas[:n]:
        if area >= min_area:
            out[labels == i] = arr[labels == i]
    return out


def harden_alpha(arr: np.ndarray, thr: int = 32) -> np.ndarray:
    out = arr.copy()
    a = out[:, :, 3]
    out[a < thr, 3] = 0
    out[a >= thr, 3] = 255
    out[out[:, :, 3] == 0, :3] = 0
    return out


def scrub_isolated(arr: np.ndarray, min_neighbors: int = 2) -> np.ndarray:
    out = arr.copy()
    a = (out[:, :, 3] > 0).astype(np.uint8)
    ker = np.ones((3, 3), np.uint8)
    ker[1, 1] = 0
    nbr = cv2.filter2D(a, -1, ker)
    out[(a > 0) & (nbr < min_neighbors), 3] = 0
    out[out[:, :, 3] == 0, :3] = 0
    return out


def drop_tiny_ccs(arr: np.ndarray, min_area: int) -> np.ndarray:
    num, labels, stats, _ = cv2.connectedComponentsWithStats(
        (arr[:, :, 3] > 0).astype(np.uint8), 8
    )
    out = arr.copy()
    for i in range(1, num):
        if int(stats[i, 4]) < min_area:
            out[labels == i, 3] = 0
            out[labels == i, :3] = 0
    return out


def clear_handle_interior_noise(arr: np.ndarray, max_fill: int = 80) -> np.ndarray:
    """Remove tiny opaque flecks inside handle holes; do not fill the holes."""
    m = (arr[:, :, 3] > 0).astype(np.uint8) * 255
    ff = m.copy()
    cv2.floodFill(ff, np.zeros((m.shape[0] + 2, m.shape[1] + 2), np.uint8), (0, 0), 128)
    # Enclosed transparent regions (handle loops + small bubbles)
    holes = ff == 0
    # Dilate holes slightly; any opaque pixel inside dilated hole that is a tiny island → clear
    # Actually: find opaque CCs that are small and surrounded — simpler: clear opaque
    # pixels that sit in the bounding boxes of medium handle holes but are disconnected wisps
    # inside the hole (alpha noise). Approach: for each hole 400-2000px, clear any
    # opaque pixels that fall strictly inside the hole region after eroding the solid.
    out = arr.copy()
    # Invert: solid object eroded, then anything opaque in original hole stays hole
    # Clear semi-connected crumbs: pixels with alpha that have few opaque neighbors
    # already handled by scrub. Extra: zero RGB flecks with alpha in hole after close
    closed = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    # flecks = opaque in original, transparent after... no
    # Find small opaque components entirely surrounded by transparency
    num, labels, stats, _ = cv2.connectedComponentsWithStats(
        (arr[:, :, 3] > 0).astype(np.uint8), 8
    )
    if num <= 1:
        return out
    # Keep only large components; tiny ones near handles get dropped via drop_tiny
    return out


def clean_trophy(pre: np.ndarray, arms: np.ndarray) -> np.ndarray:
    t = pre.copy()
    r, g, b, a = [t[:, :, i].astype(np.float32) for i in range(4)]
    m = a > 12

    # Arms color samples
    am = arms[:, :, 3] > 20
    ar, ag, ab = [arms[:, :, i].astype(np.float32) for i in range(3)]
    sleeve = am & (ar > 190) & (ag > 180) & (ab > 145) & (np.abs(ar - ag) < 30)
    hand = (
        am
        & (ar > 185)
        & (ag > 135)
        & (ag < 200)
        & (ab > 105)
        & (ab < 175)
        & ((ar - ag) > 18)
    )
    if sleeve.any():
        sleeve_mean = np.array(
            [ar[sleeve].mean(), ag[sleeve].mean(), ab[sleeve].mean()]
        )
    else:
        sleeve_mean = np.array([220.0, 210.0, 190.0])
    if hand.any():
        hand_mean = np.array([ar[hand].mean(), ag[hand].mean(), ab[hand].mean()])
    else:
        hand_mean = np.array([230.0, 170.0, 140.0])

    gold = (
        m
        & (r > 120)
        & (g > 80)
        & (b < 150)
        & ((r - b) > 28)
        & ((g - b) > 8)
    )
    if gold.any():
        gold_mean = np.array([r[gold].mean(), g[gold].mean(), b[gold].mean()])
    else:
        gold_mean = np.array([200.0, 155.0, 75.0])

    rgb = np.stack([r, g, b], axis=2)
    d_gold = np.linalg.norm(rgb - gold_mean, axis=2)
    d_sleeve = np.linalg.norm(rgb - sleeve_mean, axis=2)
    d_hand = np.linalg.norm(rgb - hand_mean, axis=2)

    arms_d = cv2.dilate(
        (am.astype(np.uint8) * 255), np.ones((11, 11), np.uint8)
    )
    # Remnant: under/near arms AND clearly closer to sleeve/hand than gold
    remnant = (
        m
        & (arms_d > 0)
        & ((d_sleeve + 12 < d_gold) | (d_hand + 18 < d_gold))
        & ~gold
    )
    # Also clear cream-like anywhere (tight)
    cream = (
        m
        & (r > 200)
        & (g > 190)
        & (b > 160)
        & (np.abs(r - g) < 22)
        & ((r - b) < 50)
    )
    print("trophy remnants", int(remnant.sum()), "cream", int(cream.sum()))

    t[remnant | cream, 3] = 0
    t[remnant | cream, :3] = 0

    t = harden_alpha(t, 36)
    t = scrub_isolated(t, 2)
    t = drop_tiny_ccs(t, 60)
    t = keep_n_largest(t, 1)

    # Fill only tiny enclosed holes (<120) — rim nicks, not handle loops
    m8 = (t[:, :, 3] > 0).astype(np.uint8) * 255
    ff = m8.copy()
    cv2.floodFill(ff, np.zeros((1026, 1026), np.uint8), (0, 0), 128)
    holes = ff == 0
    numh, labh, stath, _ = cv2.connectedComponentsWithStats(holes.astype(np.uint8), 8)
    fill = np.zeros_like(holes)
    for i in range(1, numh):
        area = int(stath[i, 4])
        if area < 120:
            fill[labh == i] = True
    print("trophy tiny hole fill", int(fill.sum()))
    if fill.any():
        bg = np.zeros((1024, 1024, 3), np.uint8)
        bg[:] = (201, 157, 72)
        vis = np.where(t[:, :, 3:4] > 0, t[:, :, :3], bg)
        filled = cv2.inpaint(vis, fill.astype(np.uint8) * 255, 2, cv2.INPAINT_TELEA)
        t[fill, :3] = filled[fill]
        t[fill, 3] = 255

    # 1px edge tighten: remove boundary pixels that are desaturated / dark fringe
    a = (t[:, :, 3] > 0).astype(np.uint8)
    er = cv2.erode(a, np.ones((3, 3), np.uint8))
    border = (a > 0) & (er == 0)
    rr, gg, bb = t[:, :, 0].astype(float), t[:, :, 1].astype(float), t[:, :, 2].astype(float)
    sat = np.maximum(np.maximum(rr, gg), bb) - np.minimum(np.minimum(rr, gg), bb)
    # dark or gray fringe on border
    bad_border = border & (((rr + gg + bb) < 220) | (sat < 25))
    # don't strip strong gold border
    strong = (rr > 150) & (gg > 110) & ((rr - bb) > 35)
    t[bad_border & ~strong, 3] = 0
    t[t[:, :, 3] == 0, :3] = 0

    t = scrub_isolated(t, 2)
    t = keep_n_largest(t, 1)
    print("trophy final", int((t[:, :, 3] > 0).sum()), "from", int((pre[:, :, 3] > 12).sum()))
    return t


def clean_arms(pre: np.ndarray) -> np.ndarray:
    a0 = pre.copy()
    ar, ag, ab, aa = [a0[:, :, i].astype(float) for i in range(4)]
    am = aa > 12
    # Tight gold crumbs (trophy shine stuck on fingers)
    gold_c = (
        am
        & (ar > 155)
        & (ag > 110)
        & (ab < 115)
        & ((ar - ab) > 55)
        & ((ag - ab) > 25)
        & ((ar - ag) > 5)
    )
    hair_c = am & (ag > ar + 18) & (ag > ab + 18) & (ag > 100) & (ag < 185)
    print("arms gold crumbs", int(gold_c.sum()), "hair", int(hair_c.sum()))
    a0[gold_c | hair_c, 3] = 0
    a0[gold_c | hair_c, :3] = 0
    a0 = harden_alpha(a0, 36)
    a0 = scrub_isolated(a0, 2)
    a0 = drop_tiny_ccs(a0, 100)
    a0 = keep_n_largest(a0, 2, min_area=100)

    # Edge tighten same way
    a = (a0[:, :, 3] > 0).astype(np.uint8)
    er = cv2.erode(a, np.ones((3, 3), np.uint8))
    border = (a > 0) & (er == 0)
    rr, gg, bb = a0[:, :, 0].astype(float), a0[:, :, 1].astype(float), a0[:, :, 2].astype(float)
    sat = np.maximum(np.maximum(rr, gg), bb) - np.minimum(np.minimum(rr, gg), bb)
    # Only strip very dark/gray border noise, keep cream/peach edge
    bad = border & ((rr + gg + bb) < 180) & (sat < 35)
    a0[bad, 3] = 0
    a0[a0[:, :, 3] == 0, :3] = 0
    a0 = scrub_isolated(a0, 2)
    a0 = keep_n_largest(a0, 2, min_area=100)
    print("arms final", int((a0[:, :, 3] > 0).sum()), "from", int((pre[:, :, 3] > 12).sum()))
    return a0


def clean_head(pre: np.ndarray) -> np.ndarray:
    h = pre.copy()
    hr, hg, hb, ha = [h[:, :, i].astype(float) for i in range(4)]
    hm = ha > 12
    ys, xs = np.where(hm)
    hy1 = int(ys.max())
    chin = hm & (np.arange(1024)[:, None] >= hy1 - 48)
    # Strong metallic gold only (trophy rim crumbs on chin)
    gold_h = (
        chin
        & (hr > 165)
        & (hg > 120)
        & (hb < 110)
        & ((hr - hb) > 60)
        & ((hg - hb) > 30)
        & ((hr - hg) > 5)
    )
    brown_h = (
        chin
        & (hr > 60)
        & (hr < 140)
        & (hg > 40)
        & (hg < 95)
        & (hb < 70)
        & ((hr - hb) > 25)
        & ((hr + hg + hb) < 300)
    )
    print("head chin gold/brown", int(gold_h.sum()), int(brown_h.sum()))
    h[gold_h | brown_h, 3] = 0
    h[gold_h | brown_h, :3] = 0
    h = harden_alpha(h, 32)
    h = scrub_isolated(h, 2)
    h = drop_tiny_ccs(h, 80)
    h = keep_n_largest(h, 1)

    # Chin edge: strip 1px dark/gray fringe only
    a = (h[:, :, 3] > 0).astype(np.uint8)
    er = cv2.erode(a, np.ones((3, 3), np.uint8))
    border = (a > 0) & (er == 0)
    rr, gg, bb = h[:, :, 0].astype(float), h[:, :, 1].astype(float), h[:, :, 2].astype(float)
    sat = np.maximum(np.maximum(rr, gg), bb) - np.minimum(np.minimum(rr, gg), bb)
    # light halo (near-white fringe) OR dark dirt on chin border
    light_halo = border & (rr > 230) & (gg > 230) & (bb > 220) & (sat < 20)
    dark_dirt = border & chin & ((rr + gg + bb) < 200) & (sat < 40)
    h[light_halo | dark_dirt, 3] = 0
    h[h[:, :, 3] == 0, :3] = 0
    h = scrub_isolated(h, 2)
    h = keep_n_largest(h, 1)
    print("head final", int((h[:, :, 3] > 0).sum()), "from", int((pre[:, :, 3] > 12).sum()))
    return h


def paste_bg(arr: np.ndarray, bg: tuple[int, int, int]) -> Image.Image:
    p = Image.new("RGB", (1024, 1024), bg)
    im = Image.fromarray(arr)
    p.paste(im, (0, 0), im)
    return p


def zoom(arr, box, path, bg=(20, 20, 20), scale=5):
    x0, y0, x1, y1 = box
    crop = arr[y0:y1, x0:x1]
    bg_img = np.zeros((crop.shape[0], crop.shape[1], 3), np.uint8)
    bg_img[:] = bg
    m = crop[:, :, 3:4].astype(float) / 255.0
    rgb = (crop[:, :, :3].astype(float) * m + bg_img.astype(float) * (1 - m)).astype(
        np.uint8
    )
    Image.fromarray(rgb).resize(
        (rgb.shape[1] * scale, rgb.shape[0] * scale), Image.Resampling.NEAREST
    ).save(path, quality=95)


def main() -> None:
    trophy0 = np.array(Image.open(DST / "_trophy_pre_cleanup.png").convert("RGBA"))
    arms0 = np.array(Image.open(DST / "_arms_pre_cleanup.png").convert("RGBA"))
    head0 = np.array(Image.open(DST / "_head_pre_cleanup.png").convert("RGBA"))

    trophy = clean_trophy(trophy0, arms0)
    arms = clean_arms(arms0)
    head = clean_head(head0)

    Image.fromarray(trophy).save(DST / "trophy.png")
    Image.fromarray(arms).save(DST / "arms.png")
    Image.fromarray(head).save(DST / "head.png")

    for name, arr in [("trophy", trophy), ("arms", arms), ("head", head)]:
        paste_bg(arr, (20, 20, 20)).save(DST / f"_clean_{name}_D.jpg", quality=92)
        paste_bg(arr, (245, 245, 243)).save(DST / f"_clean_{name}_L.jpg", quality=92)

    for bg, path in [
        ((22, 22, 24), DST / "_cleanup_preview_dark.jpg"),
        ((245, 245, 243), DST / "_cleanup_preview_light.jpg"),
    ]:
        canvas = Image.new("RGB", (1024, 1024), bg)
        for layer in ["body", "head", "trophy", "arms", "crown"]:
            im = Image.open(DST / f"{layer}.png").convert("RGBA")
            canvas.paste(im, (0, 0), im)
        canvas.save(path, quality=92)

    tb = np.where(trophy[:, :, 3] > 0)
    tx0, tx1 = int(tb[1].min()), int(tb[1].max())
    ty0, ty1 = int(tb[0].min()), int(tb[0].max())
    mw = (tx0 + tx1) // 2
    zoom(trophy, (tx0 - 5, ty0 + 30, mw + 40, ty1 - 20), DST / "_zoom_trophy_L_D.jpg")
    zoom(trophy, (mw - 40, ty0 + 30, tx1 + 5, ty1 - 20), DST / "_zoom_trophy_R_D.jpg")
    hb = np.where(head[:, :, 3] > 0)
    hx0, hx1 = int(hb[1].min()), int(hb[1].max())
    hy1 = int(hb[0].max())
    zoom(head, (hx0 + 40, hy1 - 120, hx1 - 40, hy1 + 10), DST / "_zoom_head_chin_D.jpg", scale=6)
    zoom(
        head,
        (hx0 + 40, hy1 - 120, hx1 - 40, hy1 + 10),
        DST / "_zoom_head_chin_L.jpg",
        (245, 245, 243),
        6,
    )
    ab = np.where(arms[:, :, 3] > 0)
    ax0, ax1 = int(ab[1].min()), int(ab[1].max())
    ay0, ay1 = int(ab[0].min()), int(ab[0].max())
    zoom(arms, (ax0 - 5, ay0 - 5, ax1 + 5, ay1 + 5), DST / "_zoom_arms_full_D.jpg", scale=3)

    # QA: soft alpha + multi-CC
    for name, arr, expect_cc in [
        ("head", head, 1),
        ("arms", arms, 2),
        ("trophy", trophy, 1),
    ]:
        soft = int(((arr[:, :, 3] > 0) & (arr[:, :, 3] < 255)).sum())
        num, _, stats, _ = cv2.connectedComponentsWithStats(
            (arr[:, :, 3] > 0).astype(np.uint8), 8
        )
        print(f"QA {name}: soft={soft} CCs={num-1} (expect {expect_cc})")
    print("DONE")


if __name__ == "__main__":
    main()
