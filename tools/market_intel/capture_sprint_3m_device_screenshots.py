"""Capture Sprint 3M-B Shelf Value info sheet screenshots on a connected Android device/emulator."""
from __future__ import annotations

import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "market_intel"))

import capture_sprint_3k_device_screenshots as base

OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3m"


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3m_cap.png"
    local = OUT / filename
    base.adb("shell", "screencap", "-p", remote)
    base.adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def open_collection_insights() -> None:
    base.tap_collection_tab()
    time.sleep(1.5)
    ui = base.dump_ui()
    pt = base.find_text_tap(ui, "Collection insights")
    if pt is None:
        pt = base.find_text_tap(ui, "Collection Insights")
    if pt is None:
        raise RuntimeError("Collection insights entry not found")
    base.tap(*pt)
    time.sleep(2.5)


def wait_for_shelf_value() -> None:
    deadline = time.time() + 25
    while time.time() < deadline:
        ui = base.dump_ui()
        if "Shelf Value" in ui and "includes estimates" in ui:
            return
        time.sleep(0.8)
    raise RuntimeError("Shelf Value section not found on insights")


def tap_shelf_value_info() -> None:
    ui = base.dump_ui()
    pt = base.find_text_tap(ui, "How shelf value is calculated")
    if pt is None:
        shelf = base.find_text_tap(ui, "Shelf Value")
        if shelf is None:
            raise RuntimeError("Shelf Value header not found")
        tap_x = shelf[0] + 120
        tap_y = shelf[1]
        base.tap(tap_x, tap_y)
    else:
        base.tap(*pt)
    time.sleep(1.2)


def wait_for_sheet() -> None:
    deadline = time.time() + 15
    while time.time() < deadline:
        ui = base.dump_ui()
        if "Figure Snapshot" in ui and "Series Estimate" in ui:
            return
        time.sleep(0.6)
    raise RuntimeError("Shelf value info sheet did not open")


def setup_shelf_with_estimates() -> None:
    base.launch_app(clear_data=True)
    base.add_series_from_catalog("Hope", "Big Into")
    base.open_series_on_collection("into Energy")
    base.mark_figure_owned("Luck")
    base.mark_figure_owned("Hope")
    base.adb("shell", "input", "keyevent", "4")
    time.sleep(1.5)
    open_collection_insights()
    wait_for_shelf_value()


def capture_light_mode() -> None:
    setup_shelf_with_estimates()
    time.sleep(0.9)
    screencap("1_shelf_value_with_info_icon.png")
    tap_shelf_value_info()
    wait_for_sheet()
    time.sleep(0.9)
    screencap("2_shelf_value_info_sheet.png")
    base.adb("shell", "input", "keyevent", "4")
    time.sleep(1.0)


def capture_dark_mode_sheet() -> None:
    base.launch_app(clear_data=False)
    base.adb("shell", "cmd", "uimode", "night", "yes")
    time.sleep(1.0)
    setup_shelf_with_estimates()
    tap_shelf_value_info()
    wait_for_sheet()
    time.sleep(0.9)
    screencap("3_shelf_value_info_sheet_dark.png")
    base.adb("shell", "cmd", "uimode", "night", "no")
    time.sleep(0.5)


def main() -> None:
    devices = base.adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    print("=== Capturing 1_shelf_value_with_info_icon.png ===")
    capture_light_mode()
    print("=== Capturing 3_shelf_value_info_sheet_dark.png ===")
    capture_dark_mode_sheet()
    print("Done.")


if __name__ == "__main__":
    main()
