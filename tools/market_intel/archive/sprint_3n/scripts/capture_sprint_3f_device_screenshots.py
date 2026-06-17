"""Capture Sprint 3F Market Insights purchase context on a connected Android device/emulator."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

PKG = "app.shelfy.collector"
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3f"

SCENARIOS = [
    (
        "1_market_insights_above_market.png",
        "Soymilk",
        "▲ 14% above market",
        "$48",
        False,
    ),
    (
        "2_market_insights_below_market.png",
        "Lychee Berry",
        "✓ Below market",
        "$35",
        False,
    ),
    (
        "3_market_insights_at_market.png",
        "Luck",
        "≈ At market",
        "$42",
        False,
    ),
    (
        "4_market_insights_series_estimate.png",
        "Hope",
        "Using Series Estimate",
        "$40",
        False,
    ),
    (
        "5_market_insights_dark_mode.png",
        "Luck",
        "≈ At market",
        "$42",
        True,
    ),
]


def adb(*args: str) -> str:
    r = subprocess.run(
        ["adb", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 350) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/sprint_3f_ui.xml")
    return adb("shell", "cat", "/sdcard/sprint_3f_ui.xml").replace("&#10;", "\n")


_BOUNDS = r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"


def bounds_center(x1: int, y1: int, x2: int, y2: int) -> tuple[int, int]:
    return (x1 + x2) // 2, (y1 + y2) // 2


def find_card_center(ui: str, figure_name: str) -> tuple[int, int] | None:
    pat = re.compile(
        rf'content-desc="{re.escape(figure_name)}\n[^"]*"[^>]*bounds="{_BOUNDS}"'
    )
    m = pat.search(ui)
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return bounds_center(x1, y1, x2, y2)


def find_text_tap(ui: str, needle: str, min_y: int = 0) -> tuple[int, int] | None:
    pat = re.compile(
        rf'(?:text|content-desc)="[^"]*{re.escape(needle)}[^"]*"[^>]*bounds="{_BOUNDS}"'
    )
    best: tuple[int, int] | None = None
    for m in pat.finditer(ui):
        x1, y1, x2, y2 = map(int, m.groups())
        center = bounds_center(x1, y1, x2, y2)
        if center[1] >= min_y:
            best = center
    return best


def tap_market_tab() -> None:
    ui = dump_ui()
    pt = find_text_tap(ui, "Market\nTab 3 of 3")
    if pt is None:
        pt = find_text_tap(ui, "Market")
    if pt and pt[1] > 1800:
        tap(*pt)
        time.sleep(2.5)
        return
    tap(900, 2250)
    time.sleep(2.5)


def scroll_feed_until(figure_name: str, max_swipes: int = 16) -> tuple[int, int] | None:
    for _ in range(max_swipes):
        ui = dump_ui()
        pt = find_card_center(ui, figure_name)
        if pt is not None:
            return pt
        swipe(540, 1700, 540, 700, 450)
        time.sleep(0.85)
    return None


def open_listing_detail(card_fragment: str, sheet_price: str) -> None:
    pt = scroll_feed_until(card_fragment)
    if pt is None:
        raise RuntimeError(f"Could not find market card for {card_fragment!r}")
    tap(*pt)
    time.sleep(2.0)

    deadline = time.time() + 10
    sheet_pt: tuple[int, int] | None = None
    while time.time() < deadline:
        ui = dump_ui()
        sheet_pt = find_text_tap(ui, sheet_price, min_y=400)
        if sheet_pt is not None:
            break
        time.sleep(0.6)

    if sheet_pt is None:
        raise RuntimeError(
            f"Sheet did not show price {sheet_price!r} after tapping {card_fragment!r}"
        )
    tap(*sheet_pt)
    time.sleep(2.5)


def open_insights_from_detail() -> None:
    if not scroll_detail_to_text("Market Insights", max_swipes=8):
        raise RuntimeError("Market Insights row not found on detail")
    ui = dump_ui()
    pt = find_text_tap(ui, "Market Insights")
    if pt is None:
        raise RuntimeError("Market Insights navigation row not found")
    tap(*pt)
    time.sleep(2.5)


def scroll_detail_to_text(needle: str, max_swipes: int = 10) -> bool:
    for _ in range(max_swipes):
        ui = dump_ui()
        if needle in ui:
            return True
        swipe(540, 1900, 540, 850, 420)
        time.sleep(0.85)
    return needle in dump_ui()


def wait_for_insights_screen(verify: str, timeout_s: float = 18) -> bool:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if verify in dump_ui():
            return True
        time.sleep(0.7)
    return False


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3f_cap.png"
    local = OUT / filename
    adb("shell", "screencap", "-p", remote)
    adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def launch_app() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.4)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)


def set_dark_mode(enabled: bool) -> None:
    mode = "yes" if enabled else "no"
    adb("shell", "cmd", "uimode", "night", mode)
    time.sleep(1.5)


def capture_scenario(
    filename: str,
    card_fragment: str,
    verify: str,
    sheet_price: str,
    dark_mode: bool,
) -> None:
    if dark_mode:
        set_dark_mode(True)
    launch_app()
    tap_market_tab()
    open_listing_detail(card_fragment, sheet_price)
    open_insights_from_detail()
    if not wait_for_insights_screen(verify):
        raise RuntimeError(f"Expected {verify!r} on insights screen")
    time.sleep(0.9)
    screencap(filename)
    if dark_mode:
        set_dark_mode(False)


def main() -> None:
    devices = adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    for filename, card, verify, price, dark in SCENARIOS:
        print(f"=== Capturing {filename} ({card}) ===")
        capture_scenario(filename, card, verify, price, dark)

    print("Done.")


if __name__ == "__main__":
    main()
