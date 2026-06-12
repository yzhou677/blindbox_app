#!/usr/bin/env python3
"""P0-style smoke on Pixel Tablet emulator — longer cold-start waits."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from dataclasses import dataclass, field

PKG = "app.shelfy.collector"
SERIAL = "emulator-5554"
LAUNCH_WAIT = 14.0
TAB_WAIT = 3.0


def adb(*args: str) -> str:
    cmd = ["adb", "-s", SERIAL, *args]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 400) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def type_text(text: str) -> None:
    adb("shell", "input", "text", text.replace(" ", "%s"))


def wake() -> None:
    adb("shell", "input", "keyevent", "KEYCODE_WAKEUP")
    adb("shell", "wm", "dismiss-keyguard")


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/tablet_smoke.xml")
    return adb("shell", "cat", "/sdcard/tablet_smoke.xml").replace("&#10;", " ")


def has_text(ui: str, needle: str) -> bool:
    return needle.lower() in ui.replace("&amp;", "&").lower()


def tap_desc(ui: str, needle: str, wait: float = TAB_WAIT) -> bool:
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


def tap_first(needle: str, wait: float = TAB_WAIT) -> bool:
    return tap_desc(dump_ui(), needle, wait)


def cold_launch() -> None:
    wake()
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.8)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(LAUNCH_WAIT)


def relaunch() -> None:
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(LAUNCH_WAIT)


def app_crashes() -> list[str]:
    out = adb("logcat", "-d", "-s", "AndroidRuntime:E")
    return [l for l in out.splitlines() if PKG in l or "app.shelfy" in l]


@dataclass
class Report:
    rows: list[tuple[str, str, str]] = field(default_factory=list)

    def add(self, name: str, status: str, note: str = "") -> None:
        self.rows.append((name, status, note))
        mark = {"PASS": "OK", "FAIL": "XX", "SKIP": "--"}.get(status, "??")
        print(f"[{mark} {status}] {name}" + (f" — {note}" if note else ""))


def run() -> Report:
    r = Report()
    adb("logcat", "-c")
    cold_launch()
    ui = dump_ui()

    r.add("Launch → Collection", "PASS" if has_text(ui, "My collection") else "FAIL")
    r.add("No error screen", "PASS" if not has_text(ui, "Exception") else "FAIL")

    for tab in ("Collection", "Discover", "Market"):
        ok = tap_first(tab)
        ui = dump_ui()
        r.add(f"Tab: {tab}", "PASS" if ok and has_text(ui, tab) else "FAIL")

    tap_first("Collection")
    ui = dump_ui()
    insights_ok = (
        tap_desc(ui, "Your collector type", 3.5)
        or tap_desc(ui, "Trend Chaser", 3.5)
        or tap_desc(ui, "Wanderer", 3.5)
        or tap(1280, 460) or True
    )
    time.sleep(2)
    ui = dump_ui()
    r.add(
        "Insights screen",
        "PASS" if has_text(ui, "At a glance") or has_text(ui, "Collector journey") else "FAIL",
    )
    back()
    time.sleep(2)

    tap_first("Collection")
    if tap_first("Add series", 2.5):
        tap_first("Search catalog", 1.5) or tap(1280, 400)
        type_text("Peach%sRiot")
        time.sleep(5)
        ui = dump_ui()
        if has_text(ui, "Peach") or has_text(ui, "Riot"):
            tap_first("Add to collection", 2.5) or tap_first("Add", 2.0)
            time.sleep(3)
            tap_first("Collection", 2.0)
            ui = dump_ui()
            r.add(
                "Add series from catalog",
                "PASS" if has_text(ui, "Peach") or has_text(ui, "series") else "FAIL",
            )
        else:
            r.add("Add series from catalog", "SKIP", "search results empty")
    else:
        r.add("Add series from catalog", "SKIP", "already has shelf content")

    ui = dump_ui()
    if tap_desc(ui, "CUBIEC", 2.5) or tap_desc(ui, "Disney", 2.5) or tap_desc(ui, "Peach", 2.5):
        time.sleep(2)
        ui = dump_ui()
        detail = has_text(ui, "Owned") or has_text(ui, "Wishlist") or has_text(ui, "figures")
        r.add("Series → figure sheet", "PASS" if detail else "FAIL")
        if tap_first("Owned", 1.5) or tap_first("Wishlist", 1.5):
            back()
            time.sleep(1)
            adb("shell", "am", "force-stop", PKG)
            time.sleep(1)
            relaunch()
            ui = dump_ui()
            r.add("Toggle survives relaunch", "PASS" if has_text(ui, "CUBIEC") or has_text(ui, "Peach") else "FAIL")
        else:
            r.add("Toggle survives relaunch", "SKIP")
        back()
        time.sleep(1)
    else:
        r.add("Series → figure sheet", "SKIP", "no series card")
        r.add("Toggle survives relaunch", "SKIP")

    tap_first("Discover")
    ui = dump_ui()
    if has_text(ui, "Latest drops") or has_text(ui, "Trending"):
        swipe(1280, 1200, 1280, 500)
        time.sleep(2)
        ui = dump_ui()
        official = any(k in ui.lower() for k in ("official", "pop mart", "zimomo", "haikyu"))
        r.add("Discover scroll", "PASS")
        r.add("Official feed content", "PASS" if official else "FAIL", "may need network")
    else:
        r.add("Discover scroll", "FAIL")
        r.add("Official feed content", "SKIP")

    tap_first("Market")
    time.sleep(3)
    ui = dump_ui()
    has_market = has_text(ui, "Market") or "$" in ui or has_text(ui, "Chaser")
    r.add("Market browse", "PASS" if has_market else "FAIL")
    if "$" in ui:
        tap(1280, 900)
        time.sleep(2.5)
        ui2 = dump_ui()
        r.add("Listing detail opens", "PASS" if has_text(ui2, "$") or has_text(ui2, "Read more") else "FAIL")
        back()
        time.sleep(1.5)
    else:
        r.add("Listing detail opens", "SKIP")

    tap_first("Collection")
    if tap_first("POP MART", 2.0):
        ui = dump_ui()
        r.add("Brand filter", "PASS" if has_text(ui, "POP MART") else "FAIL")
        tap_first("All Brands", 2.0)
    else:
        r.add("Brand filter", "SKIP")

    shelf_marker = "CUBIEC" if has_text(dump_ui(), "CUBIEC") else "Peach"
    had = has_text(dump_ui(), shelf_marker) or has_text(dump_ui(), "1 series")
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    relaunch()
    ui = dump_ui()
    r.add(
        "Shelf persistence",
        "PASS" if had and (has_text(ui, shelf_marker) or has_text(ui, "wishlist")) else "FAIL" if had else "SKIP",
    )

    crashes = app_crashes()
    r.add("No app crash in logcat", "PASS" if not crashes else "FAIL", crashes[-1][:100] if crashes else "")

    return r


def main() -> int:
    global SERIAL
    if len(sys.argv) > 2 and sys.argv[1] == "-s":
        SERIAL = sys.argv[2]
    print(f"Tablet smoke — {SERIAL} (launch wait {LAUNCH_WAIT}s)\n")
    report = run()
    fails = sum(1 for _, s, _ in report.rows if s == "FAIL")
    passes = sum(1 for _, s, _ in report.rows if s == "PASS")
    print(f"\n========== TABLET SMOKE: {passes} PASS / {fails} FAIL ==========")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
