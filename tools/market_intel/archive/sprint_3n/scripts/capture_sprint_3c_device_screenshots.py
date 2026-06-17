"""Capture Sprint 3C.1 Market Detail Insights on a connected Android device/emulator."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

PKG = "app.shelfy.collector"
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3c"

SCENARIOS = [
    ("1_market_detail_market_value_compact.png", "Luck", "$42 Market Value", "$42"),
    ("2_market_detail_above_market_compact.png", "Soymilk", "above market", "$48"),
    ("3_market_detail_below_market_compact.png", "Lychee Berry", "Below market", "$35"),
    ("4_market_detail_series_estimate_compact.png", "Hope", "Series Estimate", "$40"),
]

DIALOG_FILE = "5_market_data_source_dialog.png"


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
    adb("shell", "uiautomator", "dump", "/sdcard/sprint_3c_ui.xml")
    return adb("shell", "cat", "/sdcard/sprint_3c_ui.xml").replace("&#10;", "\n")


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


def scroll_detail_to_text(needle: str, max_swipes: int = 10) -> bool:
    for _ in range(max_swipes):
        ui = dump_ui()
        if needle in ui:
            return True
        swipe(540, 1900, 540, 850, 420)
        time.sleep(0.85)
    return needle in dump_ui()


def wait_for_detail_text(text: str, timeout_s: float = 18) -> bool:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if scroll_detail_to_text(text, max_swipes=3):
            return True
        time.sleep(0.7)
    return False


def frame_detail_for_capture(verify: str) -> None:
    deadline = time.time() + 20
    while time.time() < deadline:
        ui = dump_ui()
        has_verify = verify in ui
        has_insights = "Market Insights" in ui
        if has_verify and has_insights:
            return
        if has_insights and not has_verify:
            swipe(540, 900, 540, 1100, 280)
            time.sleep(0.6)
            continue
        swipe(540, 1900, 540, 850, 420)
        time.sleep(0.85)
    raise RuntimeError(
        f"Could not frame detail for {verify!r} with Market Insights visible"
    )


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3c_cap.png"
    local = OUT / filename
    adb("shell", "screencap", "-p", remote)
    adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def launch_app() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.4)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)


def capture_scenario(
    filename: str, card_fragment: str, verify: str, sheet_price: str
) -> None:
    launch_app()
    tap_market_tab()
    open_listing_detail(card_fragment, sheet_price)
    if not wait_for_detail_text(verify):
        ui = dump_ui()
        raise RuntimeError(
            f"Expected {verify!r} on detail; "
            f"Market Insights={'Market Insights' in ui}"
        )
    frame_detail_for_capture(verify)
    time.sleep(0.9)
    screencap(filename)
    back()
    time.sleep(0.5)
    back()
    time.sleep(0.8)


def capture_source_dialog() -> None:
    launch_app()
    tap_market_tab()
    open_listing_detail("Luck", "$42")
    if not wait_for_detail_text("$42 Market Value"):
        raise RuntimeError("Luck detail did not load for dialog capture")
    frame_detail_for_capture("$42 Market Value")

    ui = dump_ui()
    info_pt = find_text_tap(ui, "Market data source")
    if info_pt is None:
        info_pt = find_text_tap(ui, "Market Insights")
        if info_pt is not None:
            info_pt = (info_pt[0] + 120, info_pt[1])
    if info_pt is None:
        raise RuntimeError("Could not find Market data source info affordance")
    tap(*info_pt)
    time.sleep(1.2)

    deadline = time.time() + 8
    while time.time() < deadline:
        if "Market Data Source" in dump_ui():
            break
        time.sleep(0.4)
    else:
        raise RuntimeError("Market Data Source dialog did not appear")

    time.sleep(0.5)
    screencap(DIALOG_FILE)


def purge_obsolete_screenshots() -> None:
    if not OUT.exists():
        return
    keep = {name for name, *_ in SCENARIOS} | {DIALOG_FILE}
    for path in OUT.glob("*.png"):
        if path.name not in keep:
            path.unlink()
            print(f"removed obsolete {path.name}")


def main() -> None:
    devices = adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    purge_obsolete_screenshots()

    for filename, card_fragment, verify, sheet_price in SCENARIOS:
        print(f"=== Capturing {filename} ({card_fragment}) ===")
        capture_scenario(filename, card_fragment, verify, sheet_price)

    print(f"=== Capturing {DIALOG_FILE} ===")
    capture_source_dialog()

    print("Done.")


if __name__ == "__main__":
    main()
