"""Capture Sprint 3M-C valuation transparency screenshots on a connected Android device/emulator."""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "market_intel"))

import capture_sprint_3j_device_screenshots as market
import capture_sprint_3m_device_screenshots as insights

OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3m_c"

DART_DEFINES = [
    "--dart-define=MARKET_GATEWAY_EBAY=false",
    "--dart-define=MARKET_FIXTURE_SOURCE=true",
]


def build_and_install() -> None:
    print("Building debug APK with market fixture source…")
    cmd = "flutter build apk --debug " + " ".join(DART_DEFINES)
    subprocess.run(cmd, cwd=REPO, check=True, shell=True)
    apk = REPO / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
    market.adb("install", "-r", str(apk))
    print("Installed fixture build.")


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3m_c_cap.png"
    local = OUT / filename
    market.adb("shell", "screencap", "-p", remote)
    market.adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def tap_series_avg_info() -> None:
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, "About series average pricing")
    if pt is None:
        delta = market.find_text_tap(ui, "above series avg.")
        if delta is None:
            delta = market.find_text_tap(ui, "series avg.")
        if delta is None:
            raise RuntimeError("Series avg delta not found on detail")
        market.tap(delta[0] + 200, delta[1])
    else:
        market.tap(*pt)
    time.sleep(1.2)


def open_tier_b_detail() -> None:
    market.launch_app()
    market.tap_market_tab()
    market.open_listing_detail("Hope", "$40")


def capture_tier_b_detail_with_icon() -> None:
    open_tier_b_detail()
    if not market.scroll_detail_to_text("above series avg.", max_swipes=6):
        raise RuntimeError("Expected series avg delta on Tier B detail")
    market.assert_text_absent("Market Insights")
    time.sleep(0.9)
    screencap("1_market_detail_tier_b_with_info_icon.png")


def capture_tier_b_series_avg_sheet() -> None:
    open_tier_b_detail()
    if not market.scroll_detail_to_text("above series avg.", max_swipes=6):
        raise RuntimeError("Expected series avg delta on Tier B detail")
    tap_series_avg_info()
    deadline = time.time() + 15
    while time.time() < deadline:
        if "About series average pricing" in market.dump_ui():
            break
        time.sleep(0.6)
    else:
        raise RuntimeError("Series average info sheet did not open")
    time.sleep(0.9)
    screencap("2_market_detail_series_avg_info_sheet.png")


def capture_shelf_value_sheet() -> None:
    insights.setup_shelf_with_estimates()
    insights.tap_shelf_value_info()
    deadline = time.time() + 15
    while time.time() < deadline:
        if "About shelf value" in market.dump_ui():
            break
        time.sleep(0.6)
    else:
        raise RuntimeError("About shelf value sheet did not open")
    time.sleep(0.9)
    screencap("3_shelf_value_about_sheet.png")


def capture_shelf_value_header() -> None:
    insights.setup_shelf_with_estimates()
    time.sleep(0.9)
    screencap("4_shelf_value_with_info_icon.png")


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Skip flutter build (use installed APK)",
    )
    args = parser.parse_args()

    devices = market.adb("devices").strip().splitlines()[1:]
    if not any("\tdevice" in line for line in devices):
        raise SystemExit("No adb device connected")

    if not args.skip_build:
        build_and_install()

    print("=== Capturing 1_market_detail_tier_b_with_info_icon.png ===")
    capture_tier_b_detail_with_icon()
    print("=== Capturing 2_market_detail_series_avg_info_sheet.png ===")
    capture_tier_b_series_avg_sheet()
    print("=== Capturing 4_shelf_value_with_info_icon.png ===")
    capture_shelf_value_header()
    print("=== Capturing 3_shelf_value_about_sheet.png ===")
    capture_shelf_value_sheet()
    print("Done.")


if __name__ == "__main__":
    main()
