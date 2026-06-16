"""Capture Sprint 3I trust vocabulary screenshots on a connected Android device/emulator."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

PKG = "app.shelfy.collector"
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3i"

_BOUNDS = r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]"


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
    adb("shell", "uiautomator", "dump", "/sdcard/sprint_3i_ui.xml")
    return adb("shell", "cat", "/sdcard/sprint_3i_ui.xml").replace("&#10;", "\n")


def bounds_center(x1: int, y1: int, x2: int, y2: int) -> tuple[int, int]:
    return (x1 + x2) // 2, (y1 + y2) // 2


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


def find_catalog_series_row_tap(ui: str, needle: str) -> tuple[int, int] | None:
    """Prefer search result rows below the query field (y > 550)."""
    pat = re.compile(
        rf'(?:text|content-desc)="[^"]*{re.escape(needle)}[^"]*"[^>]*bounds="{_BOUNDS}"'
    )
    best: tuple[int, int] | None = None
    best_y = -1
    for m in pat.finditer(ui):
        x1, y1, x2, y2 = map(int, m.groups())
        if y1 < 550:
            continue
        center = bounds_center(x1, y1, x2, y2)
        if center[1] > best_y:
            best = center
            best_y = center[1]
    return best


def find_card_center(ui: str, figure_name: str) -> tuple[int, int] | None:
    pat = re.compile(
        rf'content-desc="{re.escape(figure_name)}\n[^"]*"[^>]*bounds="{_BOUNDS}"'
    )
    m = pat.search(ui)
    if not m:
        return None
    x1, y1, x2, y2 = map(int, m.groups())
    return bounds_center(x1, y1, x2, y2)


def launch_app() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.4)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)


def set_dark_mode(enabled: bool) -> None:
    mode = "yes" if enabled else "no"
    adb("shell", "cmd", "uimode", "night", mode)
    time.sleep(1.5)


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3i_cap.png"
    local = OUT / filename
    adb("shell", "screencap", "-p", remote)
    adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def tap_discover_tab() -> None:
    ui = dump_ui()
    pt = find_text_tap(ui, "Discover\nTab 2 of 3")
    if pt is None:
        pt = find_text_tap(ui, "Discover")
    if pt and pt[1] > 1800:
        tap(*pt)
        time.sleep(2.5)
        return
    tap(540, 2250)
    time.sleep(2.5)


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


def scroll_feed_until_card(figure_name: str, max_swipes: int = 16) -> tuple[int, int] | None:
    for _ in range(max_swipes):
        ui = dump_ui()
        pt = find_card_center(ui, figure_name)
        if pt is not None:
            return pt
        swipe(540, 1700, 540, 700, 450)
        time.sleep(0.85)
    return None


def scroll_discover_until_release(needle: str, max_swipes: int = 16) -> tuple[int, int] | None:
    for _ in range(max_swipes):
        ui = dump_ui()
        pt = find_text_tap(ui, needle, min_y=200)
        if pt is not None:
            return pt
        swipe(540, 1700, 540, 700, 450)
        time.sleep(0.85)
    return None


def open_discover_gallery(figure_name: str, search_query: str | None = None) -> None:
    query = search_query or "Big Into"
    tap_discover_tab()
    time.sleep(1.5)

    ui = dump_ui()
    pt = find_text_tap(ui, "figures, series") or find_text_tap(ui, "Search catalog")
    if pt is None:
        tap(540, 320)
    else:
        tap(*pt)
    time.sleep(2.5)

    ui = dump_ui()
    if "Market Information" in ui or figure_name in ui and "Add to shelf" not in ui:
        # Already in figure gallery.
        return

    pt = find_text_tap(ui, "figures, series") or find_text_tap(ui, "Search catalog")
    if pt is None:
        tap(540, 220)
    else:
        tap(*pt)
    time.sleep(0.6)
    adb("shell", "input", "text", query.replace(" ", "%s"))
    time.sleep(2.5)

    ui = dump_ui()
    pt = find_catalog_series_row_tap(ui, "Big Into")
    if pt is None:
        pt = find_catalog_series_row_tap(ui, "Energy")
    if pt is None:
        pt = find_text_tap(ui, figure_name, min_y=550)
    if pt is None:
        raise RuntimeError(f"Could not find catalog search result for {query!r}")
    tap(*pt)
    time.sleep(2.5)

    ui = dump_ui()
    if "Market Information" in ui:
        return

    for _ in range(4):
        figure_pt = find_text_tap(ui, figure_name)
        if figure_pt is not None:
            tap(*figure_pt)
            time.sleep(2.0)
            return
        swipe(540, 1500, 540, 900, 350)
        time.sleep(0.7)
        ui = dump_ui()

    raise RuntimeError(f"Could not find figure {figure_name!r} on preview sheet")


def expand_market_information() -> None:
    ui = dump_ui()
    pt = find_text_tap(ui, "Market Information")
    if pt is None:
        pt = find_text_tap(ui, "▶ Market Information")
    if pt is None:
        raise RuntimeError("Market Information accordion not found")
    tap(*pt)
    time.sleep(1.5)


def open_listing_detail(card_fragment: str, sheet_price: str) -> None:
    pt = scroll_feed_until_card(card_fragment)
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


def scroll_detail_to_text(needle: str, max_swipes: int = 10) -> bool:
    for _ in range(max_swipes):
        ui = dump_ui()
        if needle in ui:
            return True
        swipe(540, 1900, 540, 850, 420)
        time.sleep(0.85)
    return needle in dump_ui()


def open_insights_from_detail() -> None:
    if not scroll_detail_to_text("Market Insights", max_swipes=8):
        raise RuntimeError("Market Insights row not found on detail")
    ui = dump_ui()
    pt = find_text_tap(ui, "Market Insights")
    if pt is None:
        raise RuntimeError("Market Insights navigation row not found")
    tap(*pt)
    time.sleep(2.5)


def wait_for_text(verify: str, timeout_s: float = 18) -> bool:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if verify in dump_ui():
            return True
        time.sleep(0.7)
    return False


def capture_discover(filename: str, figure_name: str, verify: str) -> None:
    launch_app()
    open_discover_gallery(figure_name)
    expand_market_information()
    if not wait_for_text(verify):
        raise RuntimeError(f"Expected {verify!r} on Discover gallery")
    time.sleep(0.9)
    screencap(filename)


def capture_market_detail(filename: str, card: str, price: str, verify: str) -> None:
    launch_app()
    tap_market_tab()
    open_listing_detail(card, price)
    if not scroll_detail_to_text(verify, max_swipes=4):
        raise RuntimeError(f"Expected {verify!r} on market detail")
    time.sleep(0.9)
    screencap(filename)


def capture_market_insights(filename: str, card: str, price: str, verify: str) -> None:
    launch_app()
    tap_market_tab()
    open_listing_detail(card, price)
    open_insights_from_detail()
    if not wait_for_text(verify):
        raise RuntimeError(f"Expected {verify!r} on insights screen")
    time.sleep(0.9)
    screencap(filename)


def capture_dark_tier_b(filename: str) -> None:
    set_dark_mode(True)
    launch_app()
    tap_market_tab()
    open_listing_detail("Hope", "$40")
    open_insights_from_detail()
    if not wait_for_text("Series-Level Estimate"):
        raise RuntimeError("Expected Series-Level Estimate in dark mode")
    time.sleep(0.9)
    screencap(filename)
    set_dark_mode(False)


def main() -> None:
    devices = adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    scenarios = [
        ("1_discover_tier_a.png", lambda: capture_discover(
            "1_discover_tier_a.png", "Luck", "Market Value · $42 · 18 sales")),
        ("2_discover_tier_b.png", lambda: capture_discover(
            "2_discover_tier_b.png", "Hope", "Series Avg. · $37 · 4 sales")),
        ("3_market_detail_tier_a.png", lambda: capture_market_detail(
            "3_market_detail_tier_a.png", "Soymilk", "$48", "▲ 14% above market")),
        ("4_market_detail_tier_b.png", lambda: capture_market_detail(
            "4_market_detail_tier_b.png", "Hope", "$40", "▲ 8% above series avg.")),
        ("5_market_insights_tier_a.png", lambda: capture_market_insights(
            "5_market_insights_tier_a.png", "Luck", "$42", "Market Value")),
        ("6_market_insights_tier_b.png", lambda: capture_market_insights(
            "6_market_insights_tier_b.png", "Hope", "$40", "Series-Level Estimate")),
        ("7_dark_mode_tier_b.png", lambda: capture_dark_tier_b("7_dark_mode_tier_b.png")),
    ]

    for name, fn in scenarios:
        print(f"=== Capturing {name} ===")
        fn()

    print("Done.")


if __name__ == "__main__":
    main()
