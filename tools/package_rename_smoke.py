"""Post package-rename smoke: launch, Firebase feeds, shelf persistence."""
from __future__ import annotations

import re
import subprocess
import sys
import time

SERIAL = sys.argv[2] if len(sys.argv) > 2 and sys.argv[1] == "-s" else None
PKG = "app.shelfy.collector"


def adb(*args: str) -> str:
    cmd = ["adb"] + (["-s", SERIAL] if SERIAL else []) + list(args)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def wake() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")


def dump() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/pkg_smoke.xml")
    return adb("shell", "cat", "/sdcard/pkg_smoke.xml").replace("&#10;", " ")


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


def shelf_has_series(ui: str, needle: str) -> bool:
    return needle.lower() in ui.lower() and "empty shelf" not in ui.lower()


def main() -> int:
    results: list[tuple[str, bool, str]] = []
    wake()
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(10)

    ui = dump()
    results.append(("T1 Cold launch → Collection", "my collection" in ui.lower(), ""))

    for name, x in [("Discover", 540), ("Market", 900), ("Collection", 180)]:
        tap(x, 2250)
        time.sleep(2.5)
        ui = dump()
        results.append((f"T1 Tab {name}", name.lower() in ui.lower(), ""))

    tap(540, 2250)
    time.sleep(5)
    ui = dump()
    latest = "latest drops" in ui.lower()
    adb("shell", "input", "swipe", "540", "1800", "540", "800", "400")
    time.sleep(2)
    ui = dump()
    official = any(k in ui.lower() for k in ("official", "zimomo", "pop mart", "haikyu"))
    results.append(("T2 Latest drops", latest, ""))
    results.append(("T2 Official feed", official, ""))

    tap(180, 2250)
    time.sleep(2)
    ui = dump()
    tap_desc(ui, "Add series", 2.5)
    ui = dump()
    tap_desc(ui, "Search catalog", 1.0) or tap(540, 582)
    time.sleep(0.5)
    adb("shell", "input", "text", "Haikyu")
    time.sleep(5)
    ui = dump()
    if tap_desc(ui, "Add to collection", 2.5):
        time.sleep(3)
        tap(180, 2250)
        time.sleep(2)
        ui = dump()
        added = shelf_has_series(ui, "haikyu")
        results.append(("T3 Add series (Haikyu)", added, ""))
        time.sleep(5)
        adb("shell", "am", "force-stop", PKG)
        time.sleep(1)
        wake()
        adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
        time.sleep(8)
        ui2 = dump()
        persisted = shelf_has_series(ui2, "haikyu")
        results.append(("T3 Shelf survives force-stop", persisted, ""))
    else:
        owned = "in collection" in ui.lower() and "haikyu" in ui.lower()
        results.append(("T3 Add series (Haikyu)", owned, "already on shelf" if owned else "Add CTA missing"))
        results.append(("T3 Shelf survives force-stop", owned, "skipped"))

    fatal = [
        l
        for l in adb("logcat", "-d", "-s", "flutter:E", "AndroidRuntime:E").splitlines()
        if "FATAL" in l
    ]
    results.append(("LOG No fatal crash", not fatal, fatal[-1][:80] if fatal else ""))

    print("\n========== PACKAGE RENAME SMOKE (1.0.0+4) ==========")
    fails = 0
    for name, ok, note in results:
        if not ok:
            fails += 1
        print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {note}" if note else ""))
    print(f"\n{len(results) - fails}/{len(results)} passed")
    print("====================================================\n")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
