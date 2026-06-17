"""Capture Sprint 3L By Series trust indicator screenshots on a connected Android device/emulator."""
from __future__ import annotations

import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "market_intel"))

import capture_sprint_3k_device_screenshots as base

OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3l"


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3l_cap.png"
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


def expand_by_series() -> None:
    ui = base.dump_ui()
    pt = base.find_text_tap(ui, "By Series")
    if pt is None:
        for _ in range(4):
            base.swipe(540, 1700, 540, 700, 450)
            time.sleep(0.8)
            ui = base.dump_ui()
            pt = base.find_text_tap(ui, "By Series")
            if pt is not None:
                break
    if pt is None:
        raise RuntimeError("By Series section not found")
    base.tap(*pt)
    time.sleep(1.2)


def wait_for_series_row(*needles: str) -> None:
    deadline = time.time() + 25
    while time.time() < deadline:
        ui = base.dump_ui()
        if all(needle in ui for needle in needles):
            return
        time.sleep(0.8)
    raise RuntimeError(f"Expected {needles!r} on insights")


def capture_figure_backed_series() -> None:
    base.launch_app(clear_data=True)
    base.add_series_from_catalog("Macaron", "Macaron")
    base.open_series_on_collection("Exciting Macaron")
    base.mark_figure_owned("Soymilk")
    base.mark_figure_owned("Lychee Berry")
    base.adb("shell", "input", "keyevent", "4")
    time.sleep(1.5)
    open_collection_insights()
    expand_by_series()
    wait_for_series_row("Exciting Macaron", r"$80")
    time.sleep(0.9)
    screencap("1_by_series_figure_snapshots.png")


def capture_series_estimate_mix() -> None:
    base.launch_app(clear_data=True)
    base.add_series_from_catalog("Hope", "Big Into")
    base.open_series_on_collection("into Energy")
    base.mark_figure_owned("Luck")
    base.mark_figure_owned("Hope")
    base.adb("shell", "input", "keyevent", "4")
    time.sleep(1.5)
    open_collection_insights()
    expand_by_series()
    wait_for_series_row("into Energy", r"~$79")
    time.sleep(0.9)
    screencap("2_by_series_with_estimates.png")


def main() -> None:
    devices = base.adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    print("=== Capturing 1_by_series_figure_snapshots.png ===")
    capture_figure_backed_series()
    print("=== Capturing 2_by_series_with_estimates.png ===")
    capture_series_estimate_mix()
    print("Done.")


if __name__ == "__main__":
    main()
