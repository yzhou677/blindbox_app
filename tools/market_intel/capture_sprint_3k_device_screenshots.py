"""Capture Sprint 3K collection trust label screenshots on a connected Android device/emulator."""
from __future__ import annotations

import re
import subprocess
import time
from pathlib import Path

PKG = "app.shelfy.collector"
REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3k"

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


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/sprint_3k_ui.xml")
    return adb("shell", "cat", "/sdcard/sprint_3k_ui.xml").replace("&#10;", "\n")


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


def launch_app(clear_data: bool = False) -> None:
    if clear_data:
        adb("shell", "pm", "clear", PKG)
        time.sleep(1.0)
    else:
        adb("shell", "am", "force-stop", PKG)
        time.sleep(0.4)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3k_cap.png"
    local = OUT / filename
    adb("shell", "screencap", "-p", remote)
    adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def tap_collection_tab() -> None:
    ui = dump_ui()
    pt = find_text_tap(ui, "Collection\nTab 1 of 3")
    if pt is None:
        pt = find_text_tap(ui, "Collection")
    if pt and pt[1] > 1800:
        tap(*pt)
        time.sleep(2.5)
        return
    tap(180, 2250)
    time.sleep(2.5)


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


def add_series_from_catalog(search_query: str, row_needle: str) -> None:
    tap_discover_tab()
    ui = dump_ui()
    pt = find_text_tap(ui, "figures, series") or find_text_tap(ui, "Search catalog")
    if pt is None:
        tap(540, 320)
    else:
        tap(*pt)
    time.sleep(2.5)

    ui = dump_ui()
    pt = find_text_tap(ui, "figures, series") or find_text_tap(ui, "Search catalog")
    if pt is None:
        tap(540, 220)
    else:
        tap(*pt)
    time.sleep(0.6)
    adb("shell", "input", "text", search_query.replace(" ", "%s"))
    time.sleep(2.5)

    ui = dump_ui()
    pt = find_catalog_series_row_tap(ui, row_needle)
    if pt is None:
        pat = re.compile(
            rf'content-desc="[^"]*Big [Ii]nto Energy[^"]*"[^>]*bounds="{_BOUNDS}"'
        )
        m = pat.search(ui)
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            pt = bounds_center(x1, y1, x2, y2)
    if pt is None:
        raise RuntimeError(f"Catalog row not found for {row_needle!r}")
    tap(*pt)
    time.sleep(2.5)

    ui = dump_ui()
    pt = find_text_tap(ui, "Add to shelf") or find_text_tap(ui, "Add to collection")
    if pt is None:
        pt = find_text_tap(ui, "Add to my collection")
    if pt is None:
        raise RuntimeError("Add to shelf CTA not found on preview sheet")
    tap(*pt)
    time.sleep(2.5)
    dismiss_catalog_routes()


def dismiss_catalog_routes() -> None:
    for _ in range(4):
        ui = dump_ui()
        if "My collection" in ui:
            return
        if "Collection\nTab 1 of 3" in ui and "Search catalog" not in ui:
            return
        adb("shell", "input", "keyevent", "4")
        time.sleep(1.2)


def open_series_on_collection(series_needle: str) -> None:
    tap_collection_tab()
    time.sleep(1.5)
    swipe(540, 600, 540, 1400, 300)
    time.sleep(0.8)
    ui = dump_ui()
    pt = find_text_tap(ui, series_needle, min_y=650)
    if pt is None:
        for _ in range(4):
            swipe(540, 1700, 540, 700, 450)
            time.sleep(0.8)
            ui = dump_ui()
            pt = find_text_tap(ui, series_needle, min_y=650)
            if pt is not None:
                break
    if pt is None:
        raise RuntimeError(f"Series card not found: {series_needle!r}")
    tap(*pt)
    time.sleep(2.5)


def mark_figure_owned(figure_name: str, taps: int = 2) -> None:
    ui = dump_ui()
    pat = re.compile(
        rf'content-desc="tap\s*{re.escape(figure_name)}[^"]*"[^>]*bounds="{_BOUNDS}"'
    )
    m = pat.search(ui)
    if not m:
        pt = find_text_tap(ui, figure_name, min_y=400)
        if pt is None:
            raise RuntimeError(f"Figure row not found: {figure_name!r}")
        tap_x, tap_y = pt
    else:
        x1, y1, x2, y2 = map(int, m.groups())
        tap_x = (x1 + x2) // 2
        tap_y = y2 - 36
    for _ in range(taps):
        tap(tap_x, tap_y)
        time.sleep(0.6)


def wait_for_text(verify: str, timeout_s: float = 20) -> bool:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        if verify in dump_ui():
            return True
        time.sleep(0.7)
    return False


def capture_collection_home(filename: str, verify: str, *, forbid: str | None = None) -> None:
    tap_collection_tab()
    swipe(540, 800, 540, 1600, 300)
    time.sleep(1.0)
    deadline = time.time() + 25
    ok = False
    while time.time() < deadline:
        ui = dump_ui()
        if verify in ui and (forbid is None or forbid not in ui):
            ok = True
            break
        time.sleep(0.8)
    if not ok:
        raise RuntimeError(f"Expected {verify!r} on Collection home (forbid={forbid!r})")
    time.sleep(0.9)
    screencap(filename)


def capture_without_estimates() -> None:
    launch_app(clear_data=True)
    add_series_from_catalog("Macaron", "Macaron")
    open_series_on_collection("Exciting Macaron")
    mark_figure_owned("Soymilk")
    adb("shell", "input", "keyevent", "4")
    time.sleep(2.0)
    capture_collection_home(
        "1_collection_without_estimates.png",
        "Based on 1 of",
        forbid="includes estimates",
    )


def add_big_into_energy_from_discover() -> None:
    tap_discover_tab()
    pt: tuple[int, int] | None = None
    for _ in range(10):
        ui = dump_ui()
        pt = find_catalog_series_row_tap(ui, "Big Into")
        if pt is None:
            pt = find_text_tap(ui, "Big Into", min_y=450)
        if pt is not None:
            break
        swipe(540, 1400, 540, 700, 400)
        time.sleep(0.8)
    if pt is None:
        raise RuntimeError("Big Into Energy release not found on Discover")
    tap(*pt)
    time.sleep(2.5)

    ui = dump_ui()
    pt = (
        find_text_tap(ui, "Add to collection")
        or find_text_tap(ui, "Add to my collection")
        or find_text_tap(ui, "Add to shelf")
    )
    if pt is None:
        raise RuntimeError("Save CTA not found on release detail")
    tap(*pt)
    time.sleep(2.5)
    dismiss_catalog_routes()


def capture_with_estimates() -> None:
    launch_app(clear_data=True)
    add_series_from_catalog("Hope", "Big Into")
    open_series_on_collection("into Energy")
    mark_figure_owned("Luck")
    mark_figure_owned("Hope")
    adb("shell", "input", "keyevent", "4")
    time.sleep(2.0)
    capture_collection_home(
        "2_collection_with_estimates.png",
        "includes estimates",
    )


def main() -> None:
    devices = adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    print("=== Capturing 1_collection_without_estimates.png ===")
    capture_without_estimates()
    print("=== Capturing 2_collection_with_estimates.png ===")
    capture_with_estimates()
    print("Done.")


if __name__ == "__main__":
    main()
