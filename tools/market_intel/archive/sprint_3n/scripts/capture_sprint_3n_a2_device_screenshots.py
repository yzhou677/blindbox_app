"""Sprint 3N-A.2 — capture Tier C non-blind-box Discover evidence on device (production Firestore catalog)."""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "market_intel"))

import capture_sprint_3j_device_screenshots as market

OUT = REPO / "tools" / "market_intel" / "screenshots" / "sprint_3n_a2"
FIGURE_SEARCH = "400%"
GALLERY_NEEDLE = "MEGA CRYBABY 400%"


def screencap(filename: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    remote = "/sdcard/sprint_3n_a2_cap.png"
    local = OUT / filename
    market.adb("shell", "screencap", "-p", remote)
    market.adb("pull", remote, str(local))
    print(f"saved {local} ({local.stat().st_size} bytes)")


def tap_collection_tab() -> None:
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, "Collection\nTab 2 of 3")
    if pt is None:
        pt = market.find_text_tap(ui, "Collection")
    if pt and pt[1] > 1500:
        market.tap(*pt)
    else:
        market.tap(540, 2250)
    time.sleep(2.5)


def open_add_search() -> None:
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, "Add")
    if pt is None:
        pt = market.find_text_tap(ui, "add", min_y=200)
    if pt is None:
        raise RuntimeError("Add control not found on Collection")
    market.tap(*pt)
    time.sleep(2.0)


def search_catalog(query: str) -> None:
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, "Search", min_y=100)
    if pt is None:
        raise RuntimeError("Catalog search field not found")
    market.tap(*pt)
    time.sleep(0.5)
    market.adb("shell", "input", "text", query.replace(" ", "%s"))
    time.sleep(2.5)


def open_first_search_row(needle: str) -> None:
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, needle, min_y=300)
    if pt is None:
        pt = market.find_text_tap(ui, "CRYBABY", min_y=300)
    if pt is None:
        raise RuntimeError(f"Search row not found for {needle!r}")
    market.tap(*pt)
    time.sleep(2.5)


def capture_discover_tier_c() -> None:
    market.launch_app()
    tap_collection_tab()
    open_add_search()
    search_catalog(FIGURE_SEARCH)
    open_first_search_row("MEGA CRYBABY")
    time.sleep(1.5)
  # Preview sheet — open figure gallery if present
    ui = market.dump_ui()
    pt = market.find_text_tap(ui, GALLERY_NEEDLE, min_y=200)
    if pt is None:
        pt = market.find_text_tap(ui, "Crying in Pink", min_y=200)
    if pt is not None:
        market.tap(*pt)
        time.sleep(2.0)
    screencap("1_discover_tier_c_mega_crybaby_400_gallery.png")
    ui = market.dump_ui()
    has_market = "Market Information" in ui or "Series Avg." in ui or "Market Value" in ui
    print("gallery_has_market_intel_ui=", has_market)


def main() -> None:
    apk = REPO / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
    if apk.exists():
        market.adb("install", "-r", str(apk))
    capture_discover_tier_c()


if __name__ == "__main__":
    main()
