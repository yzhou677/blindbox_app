#!/usr/bin/env python3
"""Capture Play Store tablet screenshots on Pixel Tablet emulator (Android 15)."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
PKG = "app.shelfy.collector"
SERIAL = "emulator-5554"
OUT_10 = REPO / "assets" / "play_store" / "screenshots" / "tablet_10"
OUT_7 = REPO / "assets" / "play_store" / "screenshots" / "tablet_7"

# Play 10": shortest side >= 1200. Pixel Tablet landscape = 2560x1600.
# Play 7": shortest side >= 1080. Export 1920x1080 landscape from capture.
TABLET_7_SIZE = (1920, 1080)


def adb(*args: str) -> str:
    cmd = ["adb", "-s", SERIAL, *args]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 400) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def dump() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/play_ss.xml")
    return adb("shell", "cat", "/sdcard/play_ss.xml").replace("&#10;", " ")


def tap_desc(ui: str, needle: str, wait: float = 2.0) -> bool:
    pat = re.compile(
        rf'content-desc="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    m = pat.search(ui)
    if not m:
        return False
    x1, y1, x2, y2 = map(int, m.groups()[1:])
    tap((x1 + x2) // 2, (y1 + y2) // 2)
    time.sleep(wait)
    return True


def launch() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(12)


def screencap(name: str) -> Path:
    raw = OUT_10 / f"{name}.png"
    adb("shell", "screencap", "-p", "/sdcard/ss.png")
    adb("pull", "/sdcard/ss.png", str(raw))
    # 10" native (2560x1600)
    img = Image.open(raw).convert("RGB")
    w, h = img.size
    if w < 1200 or h < 1200:
        raise RuntimeError(f"Capture {name} too small for 10-inch tablet: {w}x{h}")
    # 7" export: landscape 1920x1080
    out7 = OUT_7 / f"{name}.png"
    fitted = img.resize(TABLET_7_SIZE, Image.Resampling.LANCZOS)
    fitted.save(out7, format="PNG", optimize=True)
    img.save(raw, format="PNG", optimize=True)
    return raw


def seed_shelf() -> None:
    ui = dump()
    if "empty shelf" not in ui.lower() and ("collected" in ui.lower() or "series" in ui.lower()):
        return
    if not tap_desc(ui, "Add series", 2.5):
        tap_desc(dump(), "Add series", 2.5)
    ui = dump()
    tap_desc(ui, "Search catalog", 1.0) or tap(1280, 400)
    time.sleep(0.5)
    adb("shell", "input", "text", "Peach%sRiot")
    time.sleep(5)
    ui = dump()
    if tap_desc(ui, "Add to collection", 2.5):
        time.sleep(3)
    tap(200, 200)  # dismiss scrim if sheet open
    time.sleep(1)
    tap_desc(dump(), "Collection", 2.0) or tap(427, 1520)


def nav_collection() -> None:
    tap_desc(dump(), "Collection", 2.0) or tap(427, 1520)
    time.sleep(2)


def nav_insights() -> None:
    nav_collection()
    ui = dump()
    if not (
        tap_desc(ui, "Your collector type", 3.0)
        or tap_desc(ui, "Trend Chaser", 3.0)
        or tap_desc(ui, "Reveal collector type", 3.0)
    ):
        tap(1280, 520)
        time.sleep(3)
    time.sleep(2)
    if tap_desc(dump(), "Reveal collector type", 4.0):
        time.sleep(2.5)


def nav_discover() -> None:
    tap_desc(dump(), "Discover", 2.5) or tap(1280, 1520)
    time.sleep(4)
    swipe(1280, 1200, 1280, 500)
    time.sleep(2)


def nav_market() -> None:
    tap_desc(dump(), "Market", 2.5) or tap(2133, 1520)
    time.sleep(4)


def nav_figure_detail() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(8)
    nav_collection()
    ui = dump()
    if not (
        tap_desc(ui, "CUBIEC", 2.5)
        or tap_desc(ui, "Disney", 2.5)
        or tap_desc(ui, "POP CUBE", 2.5)
    ):
        tap(1280, 900)
        time.sleep(2.5)
    ui = dump()
    # Series figures sheet — tap first figure thumb
    if not tap_desc(ui, "Owned", 1.5):
        tap(700, 750)
        time.sleep(2.5)
    ui = dump()
    if "gallery" not in ui.lower():
        tap(900, 650)
        time.sleep(2.5)


def main() -> int:
    OUT_10.mkdir(parents=True, exist_ok=True)
    OUT_7.mkdir(parents=True, exist_ok=True)
    adb("shell", "settings", "put", "system", "show_angle_in_use_dialog_box", "0")
    adb("shell", "settings", "put", "global", "development_settings_enabled", "0")

    launch()
    seed_shelf()

    shots = [
        ("01_collection", nav_collection),
        ("02_insights", nav_insights),
        ("03_discover", nav_discover),
        ("04_market", nav_market),
        ("05_figure_detail", nav_figure_detail),
    ]

    for name, nav in shots:
        print(f"Capturing {name}…")
        nav()
        time.sleep(2)
        path = screencap(name)
        print(f"  10\": {path} ({Image.open(path).size})")
        print(f"  7\":  {OUT_7 / (name + '.png')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
