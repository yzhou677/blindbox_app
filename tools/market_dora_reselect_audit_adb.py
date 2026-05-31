"""ADB audit: Dora search → listing detail → Market tab reselect. Captures browseSnapshot logs."""
from __future__ import annotations

import re
import subprocess
import sys
import time

PACKAGE = "com.example.blindbox_app"
ACTIVITY = "com.example.blindbox_app/.MainActivity"


def adb(*args: str) -> str:
    r = subprocess.run(
        ["adb", *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return adb("shell", "cat", "/sdcard/ui.xml")


def find_desc(ui: str, needle: str) -> tuple[int, int] | None:
    pat = re.compile(
        rf'content-desc="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    for m in pat.finditer(ui):
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def tap_desc(needle: str, wait: float = 2.0) -> bool:
    ui = dump_ui()
    pt = find_desc(ui, needle)
    if not pt:
        print(f"MISS: {needle!r}")
        return False
    tap(*pt)
    time.sleep(wait)
    print(f"OK tap: {needle!r} @ {pt}")
    return True


def tap_search_field() -> bool:
    ui = dump_ui()
    for needle in ("Search figures", "Search market", "Search"):
        pt = find_desc(ui, needle)
        if pt:
            tap(*pt)
            time.sleep(2)
            print(f"OK search field via {needle!r}")
            return True
    print("MISS: search field")
    return False


def type_query(q: str) -> None:
    adb("shell", "input", "text", q.replace(" ", "%s"))
    time.sleep(0.5)


def wait_prices(timeout: float = 20) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        ui = dump_ui()
        if re.search(r"\$\d+", ui):
            return True
        time.sleep(1)
    return False


def tap_first_price_card() -> bool:
    ui = dump_ui()
    # Tap center of first bounds block containing a $ price in text= or content-desc
    pat = re.compile(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
    for m in pat.finditer(ui):
        x1, y1, x2, y2 = map(int, m.groups())
        chunk = ui[m.start() : m.start() + 800]
        if "$" in chunk or "USD" in chunk:
            cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
            if cy > 400:  # skip nav bar
                tap(cx, cy)
                time.sleep(2)
                print(f"OK tap price card @ ({cx},{cy})")
                return True
    print("MISS: price card")
    return False


def tap_market_tab() -> bool:
    # Bottom nav Market slot (Pixel 7 API 35 emulator) — avoid wrong a11y "Market" matches.
    tap(900, 2253)
    time.sleep(2.5)
    print("OK tap: Market tab @ (900,2253)")
    return True


SNAPSHOT_RE = re.compile(
    r"browseSnapshot\[([^\]]+)\].*?"
    r"activeSig=([^\s]+)\s+"
    r"liveSig=([^\s]+)\s+"
    r"sessionRows=(\d+)\s+"
    r"visibleRows=(\d+)\s+"
    r"(?:sessionTransitioning=(\w+)\s+)?"
    r"overlay=(\w+)\s+"
    r"committed=(\w+)\s+"
    r"immersive=(\w+)\s+"
    r"route=([^\s]+)\s+"
    r"gateway=(\w+)",
)


def fetch_snapshots() -> list[str]:
    out = adb("logcat", "-d")
    return [ln for ln in out.splitlines() if "browseSnapshot[" in ln]


def wait_log_substring(needle: str, timeout: float = 30) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        if needle in adb("logcat", "-d", "-t", "200"):
            return True
        time.sleep(1)
    return False


def main() -> int:
    print("=== Dora reselect audit (adb) ===")
    adb("logcat", "-c")
    # App should already be running (flutter run). Cold start only if needed.
    if "device" not in adb("devices"):
        print("ERROR: no adb device")
        return 1
    adb("shell", "am", "start", "-n", ACTIVITY)
    time.sleep(6)

    if not tap_market_tab():
        return 1
    time.sleep(5)

    if not tap_search_field():
        for y in (380, 450, 520, 600):
            tap(540, y)
            time.sleep(1.5)
            ui = dump_ui()
            if "Search market" in ui or "Search figures" in ui:
                print(f"OK tap: opened search @ (540,{y})")
                break
        else:
            print("WARN: search route may not be open")
    type_query("dora")
    print("Waiting for Dora commit in logs…")
    wait_log_substring("commitQuery", 15)
    wait_log_substring("dora|relevance", 25)
    print("Waiting for Dora results…")
    if not wait_prices(45):
        print("WARN: no $ prices visible after dora")
    time.sleep(3)
    print("--- snapshots after dora commit ---")
    for ln in fetch_snapshots():
        print(ln)

    if not tap_first_price_card():
        return 1
    time.sleep(2.5)
    # Bottom sheet listing row → /market/listing/:id
    tap(540, 1680)
    time.sleep(1.5)
    tap(540, 1520)
    time.sleep(4)
    if not wait_log_substring("listing_detail_opened", 15):
        print("WARN: listing_detail_opened not seen in logcat")
    print("--- snapshots listing/detail ---")
    for ln in fetch_snapshots():
        if "listing" in ln or "detail" in ln:
            print(ln)

    print("--- snapshots before reselect ---")
    for ln in fetch_snapshots():
        if "listing" in ln or "detail" in ln or "before_reselect" in ln:
            print(ln)

    print("Market tab reselect…")
    tap(900, 2253)
    time.sleep(0.6)
    tap(900, 2253)
    time.sleep(10)

    lines = fetch_snapshots()
    print("\n=== ALL browseSnapshot lines ===")
    for ln in lines:
        print(ln)

    print("\n=== PARSED TABLE ===")
    print(
        f"{'phase':<40} {'activeSig':<35} {'liveSig':<35} "
        f"{'overlay':<6} {'committed':<10} {'immersive':<10} "
        f"{'sessionRows':<12} {'visibleRows':<12} {'route'}"
    )
    for ln in lines:
        m = SNAPSHOT_RE.search(ln)
        if not m:
            continue
        phase, active, live, srows, vrows, _, ov, com, imm, route, _gw = m.groups()
        print(
            f"{phase:<40} {active:<35} {live:<35} "
            f"{ov:<6} {com:<10} {imm:<10} {srows:<12} {vrows:<12} {route}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
