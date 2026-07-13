#!/usr/bin/env python3
"""Capture polished Play Store tablet screenshots on Pixel Tablet (landscape 2560x1600)."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
PKG = "app.shelfy.collector"
SERIAL = "emulator-5554"
OUT_10 = REPO / "assets" / "play_store" / "screenshots" / "tablet_10"
OUT_7 = REPO / "assets" / "play_store" / "screenshots" / "tablet_7"

# Pixel Tablet landscape
W, H = 2560, 1600
TABLET_7_SIZE = (1920, 1080)

# Bottom nav centers (landscape)
NAV_COLLECTION = (427, 1520)
NAV_DISCOVER = (1280, 1520)
NAV_MARKET = (2133, 1520)

SEED_SERIES = (
    "Peach Riot",
    "Macaron",
    "Hirono",
    "PUCKY",
)


def adb(*args: str) -> str:
    cmd = ["adb", "-s", SERIAL, *args]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def dismiss_overlays() -> None:
    """Close sheets only — never tap launcher/home coordinates."""
    for _ in range(3):
        ui = dump()
        lowered = ui.lower()
        if "add a series" not in lowered and "latest releases" not in lowered:
            return
        back()
        time.sleep(0.8)


def ensure_shelfy_foreground() -> None:
    fg = adb("shell", "dumpsys", "activity", "activities")
    if PKG not in fg:
        launch(wait_seconds=10)
        return
    # Bring task forward without clearing data.
    adb(
        "shell",
        "am",
        "start",
        "-n",
        f"{PKG}/.MainActivity",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
    )
    time.sleep(2.5)


def assert_shelfy_screen(ui: str, label: str) -> None:
    lowered = ui.lower()
    if label == "05_figure_detail":
        if "reveal collector type" in lowered or "collector journey" in lowered:
            raise RuntimeError(f"{label}: still on insights, not figure gallery.")
        if 'content-desc="close"' not in lowered:
            raise RuntimeError(f"{label}: figure gallery not open.")
        return
    if label == "02_insights":
        if any(
            m in lowered
            for m in (
                "collector journey",
                "at a glance",
                "shelf progress",
                "reveal collector type",
            )
        ):
            return
        raise RuntimeError(f"{label}: full insights screen not open.")
    markers = ("my collection", "discover", "market", "collection insights", "chasers", "latest drops")
    if not any(m in lowered for m in markers):
        raise RuntimeError(f"{label}: Shelfy not in foreground (got unrelated screen).")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 450) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def dump() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/play_ss.xml")
    return adb("shell", "cat", "/sdcard/play_ss.xml").replace("&#10;", " ")


def _bounds_center(m: re.Match[str]) -> tuple[int, int]:
    x1, y1, x2, y2 = map(int, m.groups()[-4:])
    return (x1 + x2) // 2, (y1 + y2) // 2


def tap_desc(ui: str, needle: str, wait: float = 2.0) -> bool:
    pat = re.compile(
        rf'content-desc="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    m = pat.search(ui)
    if not m:
        return False
    x, y = _bounds_center(m)
    tap(x, y)
    time.sleep(wait)
    return True


def tap_text(ui: str, needle: str, wait: float = 2.0) -> bool:
    pat = re.compile(
        rf'text="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    for m in pat.finditer(ui):
        x, y = _bounds_center(m)
        tap(x, y)
        time.sleep(wait)
        return True
    return False


def wait_for(needle: str, timeout: float = 20.0, interval: float = 0.8) -> str:
    deadline = time.time() + timeout
    while time.time() < deadline:
        ui = dump()
        if needle.lower() in ui.lower():
            return ui
        time.sleep(interval)
    return dump()


def prep_emulator() -> None:
    adb("shell", "settings", "put", "system", "show_angle_in_use_dialog_box", "0")
    adb("shell", "settings", "put", "global", "development_settings_enabled", "0")
    # Snappier capture; restore manually if needed.
    for scale in ("window_animation_scale", "transition_animation_scale", "animator_duration_scale"):
        adb("shell", "settings", "put", "global", scale, "0")


def clear_shelf() -> None:
    print("Clearing app data for a clean demo shelf…")
    adb("shell", "pm", "clear", PKG)
    time.sleep(2)


def launch(wait_seconds: float = 18.0) -> None:
    adb(
        "shell",
        "am",
        "start",
        "-W",
        "-n",
        f"{PKG}/.MainActivity",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
    )
    time.sleep(wait_seconds)


def open_add_series_sheet() -> None:
    nav_collection()
    ui = dump()
    if not (tap_text(ui, "Add series", 2.5) or tap_desc(ui, "Add series", 2.5)):
        tap(W // 2, H // 2 - 80)
    # Sheet copy is "Add a series"; rows expose "Add to collection".
    wait_for("Add a series", 45)
    wait_for("Add to collection", 45)


def tap_nth_desc(ui: str, needle: str, index: int, wait: float = 2.5) -> bool:
    pat = re.compile(
        rf'content-desc="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    matches = list(pat.finditer(ui))
    if index >= len(matches):
        return False
    x, y = _bounds_center(matches[index])
    tap(x, y)
    time.sleep(wait)
    return True


def close_gallery_and_sheets() -> None:
    for _ in range(5):
        ui = dump()
        lowered = ui.lower()
        if 'content-desc="close"' in lowered:
            back()
            time.sleep(1.0)
            continue
        if "scrim" in lowered and "figures" in lowered:
            back()
            time.sleep(1.0)
            continue
        if " of " in lowered and "close" in lowered:
            back()
            time.sleep(1.0)
            continue
        break
    pop_to_collection_main()


def pop_to_collection_main() -> None:
    """Leave pushed routes (insights, sheets) and land on shelf home."""
    for _ in range(6):
        ui = dump()
        lowered = ui.lower()
        if "my collection" in lowered and "reveal collector type" not in lowered:
            dismiss_overlays()
            return
        if "collection insights" in lowered or "reveal collector type" in lowered:
            back()
            time.sleep(1.2)
            continue
        if "owned" in lowered or "wishlist" in lowered:
            back()
            time.sleep(1.2)
            continue
        dismiss_overlays()
        nav_collection()
        time.sleep(1.5)
        return
    nav_collection()


def count_add_buttons(ui: str) -> int:
    return len(re.findall(r'content-desc="[^"]*Add to (?:my )?collection[^"]*"', ui, re.I))


def add_from_latest_releases(count: int = 4) -> None:
    """Tap the first remaining Add chip on each row — one new series per pass."""
    open_add_series_sheet()
    added = 0
    for attempt in range(count * 4):
        if added >= count:
            break
        ui = dump()
        before = count_add_buttons(ui)
        if before == 0:
            # Sheet may need a nudge / reopen after adds.
            if added > 0:
                break
            open_add_series_sheet()
            continue
        if not (
            tap_nth_desc(ui, "Add to collection", 0)
            or tap_nth_desc(ui, "Add to my collection", 0)
        ):
            print("    warn: no Add to collection control found")
            open_add_series_sheet()
            continue
        time.sleep(4.0)
        ui2 = dump()
        after = count_add_buttons(ui2)
        if after < before or "already in your collection" in ui2.lower():
            added += 1
            print(f"    + series {added}/{count}")
        else:
            print(f"    warn: add did not stick (buttons {before}->{after})")
            # Re-open sheet if it closed without adding.
            if "add a series" not in ui2.lower():
                open_add_series_sheet()
    print(f"  Seeded {added} series from Add sheet.")
    dismiss_overlays()
    pop_to_collection_main()


def seed_shelf() -> None:
    # Prefer explicit activity start — monkey can land on the launcher.
    adb(
        "shell",
        "am",
        "start",
        "-W",
        "-n",
        f"{PKG}/.MainActivity",
        "-a",
        "android.intent.action.MAIN",
        "-c",
        "android.intent.category.LAUNCHER",
    )
    time.sleep(18)
    ensure_shelfy_foreground()
    add_from_latest_releases(4)
    ui = dump()
    if "empty shelf" in ui.lower():
        raise RuntimeError("Shelf seeding failed — collection still empty.")
    print("  Shelf seeded.")


def nav_collection() -> None:
    ui = dump()
    if not tap_desc(ui, "Collection", 2.0):
        tap(*NAV_COLLECTION)
    time.sleep(2.5)


def collapse_insights_if_expanded() -> None:
    ui = dump()
    if "at a glance" in ui.lower() or "your shelf feels" in ui.lower():
        tap_text(ui, "Collection Insights", 1.2) or tap(W // 2, 430)


def nav_collection_shot() -> None:
    ensure_shelfy_foreground()
    pop_to_collection_main()
    collapse_insights_if_expanded()
    for _ in range(3):
        swipe(W // 2, 480, W // 2, 1050, 320)
        time.sleep(0.45)
    # Frame in-progress bucket with multiple series cards.
    for _ in range(2):
        swipe(W // 2, 1250, W // 2, 550, 420)
        time.sleep(0.6)
    time.sleep(1.8)


def nav_insights_shot() -> None:
    ensure_shelfy_foreground()
    close_gallery_and_sheets()
    for _ in range(4):
        swipe(W // 2, 460, W // 2, 1080, 300)
        time.sleep(0.45)
    ui = dump()
    tap_desc(ui, "Insights", 2.0) or tap_desc(ui, "Collection Insights", 2.0) or tap_text(
        ui, "Collection Insights", 2.0
    )
    time.sleep(2)
    ui = dump()
    if not (
        tap_text(ui, "Reveal collector type", 3.5)
        or tap_desc(ui, "Reveal collector type", 3.5)
        or tap_text(ui, "Your collector type", 3.5)
    ):
        # Already revealed — stay on insights panel.
        if "at a glance" not in ui.lower() and "collector journey" not in ui.lower():
            tap(W // 2, 590)
            time.sleep(3)
    # Ceremony settles on identity; nudge so At a glance / Shelf Progress show.
    for _ in range(2):
        swipe(W // 2, 1200, W // 2, 620, 380)
        time.sleep(0.8)
    ui = wait_for("At a glance", 12)
    if "at a glance" not in ui.lower():
        wait_for("Collector journey", 8)
    time.sleep(1.5)


def nav_discover_shot() -> None:
    ensure_shelfy_foreground()
    ui = dump()
    if not tap_desc(ui, "Discover", 2.5):
        tap(*NAV_DISCOVER)
    time.sleep(5)
    # Scroll to top.
    for _ in range(3):
        swipe(W // 2, 420, W // 2, 1100, 280)
        time.sleep(0.5)
    time.sleep(1)
    # Frame: Discover title + search + Latest drops (avoid cutting header).
    swipe(W // 2, 980, W // 2, 760, 280)
    time.sleep(2)


def nav_market_shot() -> None:
    ensure_shelfy_foreground()
    pop_to_collection_main()
    ui = dump()
    if not tap_desc(ui, "Market", 2.5):
        tap(*NAV_MARKET)
    time.sleep(5)
    ui = dump()
    if not tap_desc(ui, "POP MART", 2.0):
        if not tap_text(ui, "POP MART", 2.0):
            swipe(700, 948, 1500, 948, 280)
            time.sleep(0.8)
            ui = dump()
            tap_desc(ui, "POP MART", 2.0) or tap_text(ui, "POP MART", 2.0)
    time.sleep(2.5)
    swipe(W // 2, 1100, W // 2, 680, 350)
    time.sleep(2)


def tap_desc_all(ui: str, needle: str, wait: float = 2.0) -> bool:
    """Tap first content-desc match (series cards use desc, not text)."""
    return tap_desc(ui, needle, wait)


def tap_first_series_card(ui: str) -> bool:
    # Prefer full shelf row semantics ("… Series … 0 / N"), not Brand/IP chips.
    pat = re.compile(
        r'content-desc="([^"]*Series[^"]*\d+\s*/\s*\d+[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    matches = list(pat.finditer(ui))
    if matches:
        x, y = _bounds_center(matches[0])
        tap(x, y)
        time.sleep(3.0)
        return True
    for needle in (
        "Power Chords",
        "Palico Series",
        "Carry the Music",
        "Vinyl Plush",
        "Love Across Galaxies",
        "PIXAR",
        "Wheel of Time",
        "Yuna Nocturne",
    ):
        if tap_desc_all(ui, needle, 3.0):
            return True
    return False


def open_figure_gallery_from_sheet(ui: str) -> None:
    # Figure thumbs expose semantics like: "tap DIMOO as Woody Regular".
    pat_tap = re.compile(
        r'content-desc="(tap [^"]+)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    m = pat_tap.search(ui)
    if m:
        x, y = _bounds_center(m)
        tap(x, y)
        time.sleep(3.5)
        return
    pat = re.compile(
        r'class="android\.widget\.ImageView"[^>]*clickable="true"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
    )
    m = pat.search(ui)
    if m:
        x1, y1, x2, y2 = map(int, m.groups())
        tap((x1 + x2) // 2, (y1 + y2) // 2)
        time.sleep(3.5)
        return
    if tap_desc(ui, "tap", 3.0):
        return
    tap(1280, 636)
    time.sleep(3.5)


def nav_figure_detail_shot() -> None:
    ensure_shelfy_foreground()
    pop_to_collection_main()
    # Reveal a multi-figure series lower on the shelf.
    swipe(W // 2, 1200, W // 2, 600, 420)
    time.sleep(1.5)
    ui = dump()
    if not tap_first_series_card(ui):
        tap(W // 2, 1050)
        time.sleep(3.0)
    ui = wait_for("Regular Figures", 15)
    if "regular figures" not in ui.lower() and "figures" not in ui.lower():
        ui = wait_for("tap ", 10)
    open_figure_gallery_from_sheet(ui)
    wait_for("Close", 12)


def screencap(name: str) -> Path:
    raw = OUT_10 / f"{name}.png"
    adb("shell", "screencap", "-p", "/sdcard/ss.png")
    adb("pull", "/sdcard/ss.png", str(raw))
    img = Image.open(raw).convert("RGB")
    w, h = img.size
    if w < 1200 or h < 1200:
        raise RuntimeError(f"Capture {name} too small for 10-inch tablet: {w}x{h}")
    out7 = OUT_7 / f"{name}.png"
    img.resize(TABLET_7_SIZE, Image.Resampling.LANCZOS).save(out7, format="PNG", optimize=True)
    img.save(raw, format="PNG", optimize=True)
    return raw


def main() -> int:
    OUT_10.mkdir(parents=True, exist_ok=True)
    OUT_7.mkdir(parents=True, exist_ok=True)
    prep_emulator()
    clear_shelf()
    seed_shelf()

    shots = [
        ("01_collection", nav_collection_shot),
        ("05_figure_detail", nav_figure_detail_shot),
        ("02_insights", nav_insights_shot),
        ("03_discover", nav_discover_shot),
        ("04_market", nav_market_shot),
    ]

    for name, nav in shots:
        print(f"Capturing {name}…")
        nav()
        time.sleep(1.5)
        ui = dump()
        assert_shelfy_screen(ui, name)
        path = screencap(name)
        print(f"  10\": {path} ({Image.open(path).size})")
        print(f"  7\":  {OUT_7 / (name + '.png')}")
        if name == "05_figure_detail":
            close_gallery_and_sheets()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
