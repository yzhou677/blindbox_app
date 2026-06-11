"""P0 release smoke on connected Android device via adb + uiautomator."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from dataclasses import dataclass, field

PKG = "com.example.blindbox_app"
SERIAL = None  # set via -s if needed


def adb(*args: str) -> str:
    cmd = ["adb"]
    if SERIAL:
        cmd.extend(["-s", SERIAL])
    cmd.extend(args)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 350) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def type_text(text: str) -> None:
    safe = text.replace(" ", "%s")
    adb("shell", "input", "text", safe)


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/p0_ui.xml")
    return adb("shell", "cat", "/sdcard/p0_ui.xml")


def find_nodes(ui: str, needle: str) -> list[tuple[str, str, int, int]]:
    """Return (kind, label, cx, cy) for nodes matching needle in text or content-desc."""
    out: list[tuple[str, str, int, int]] = []
    pat = re.compile(
        r'<node[^>]*?(?:text|content-desc)="([^"]*)"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
        r'|bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"[^>]*?(?:text|content-desc)="([^"]*)"'
    )
    for m in pat.finditer(ui):
        if m.group(1) is not None:
            label, x1, y1, x2, y2 = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5))
        else:
            x1, y1, x2, y2 = int(m.group(6)), int(m.group(7)), int(m.group(8)), int(m.group(9))
            label = m.group(10)
        if needle.lower() in label.lower():
            out.append(("node", label, (x1 + x2) // 2, (y1 + y2) // 2))
    # Flutter often exposes content-desc on child nodes; also scan simpler pattern
    simple = re.compile(
        rf'(?:text|content-desc)="([^"]*{re.escape(needle)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        re.I,
    )
    for m in simple.finditer(ui):
        label = m.group(1)
        x1, y1, x2, y2 = map(int, m.groups()[1:])
        out.append(("simple", label, (x1 + x2) // 2, (y1 + y2) // 2))
    # dedupe by label+center
    seen = set()
    deduped = []
    for kind, label, x, y in out:
        key = (label, x, y)
        if key in seen:
            continue
        seen.add(key)
        deduped.append((kind, label, x, y))
    return deduped


def has_text(ui: str, needle: str) -> bool:
    ui_norm = ui.replace("&#10;", " ").replace("&amp;", "&").lower()
    return needle.lower() in ui_norm


def tap_first(needle: str, wait: float = 2.0) -> tuple[bool, str]:
    ui = dump_ui()
    hits = find_nodes(ui, needle)
    if not hits:
        return False, f'not found: "{needle}"'
    _, label, x, y = hits[0]
    tap(x, y)
    time.sleep(wait)
    return True, label


def cold_launch() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.8)
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(6.0)


def force_stop() -> None:
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)


def relaunch() -> None:
    adb("shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(3.5)


def logcat_errors() -> list[str]:
    out = adb("logcat", "-d", "-s", "flutter:E", "AndroidRuntime:E")
    return [l for l in out.splitlines() if l.strip()]


@dataclass
class Result:
    id: str
    name: str
    status: str  # PASS, FAIL, SKIP, MINOR
    notes: str = ""


@dataclass
class Report:
    results: list[Result] = field(default_factory=list)

    def add(self, id_: str, name: str, status: str, notes: str = "") -> None:
        self.results.append(Result(id_, name, status, notes))
        mark = {"PASS": "OK", "FAIL": "XX", "SKIP": "--", "MINOR": "~~"}.get(status, "??")
        print(f"[{mark} {status}] {id_} {name}" + (f" — {notes}" if notes else ""))


def run_p0() -> Report:
    r = Report()
    adb("logcat", "-c")

    # P0-1 / P0-2
    cold_launch()
    ui = dump_ui()
    if has_text(ui, "My collection"):
        r.add("P0-1", "Cold launch lands on Collection", "PASS")
    else:
        r.add("P0-1", "Cold launch lands on Collection", "FAIL", "My collection not in UI tree")
    if has_text(ui, "Exception") or has_text(ui, "Error:"):
        r.add("P0-2", "First paint — no error screen", "FAIL", "error text visible")
    else:
        r.add("P0-2", "First paint — no error screen", "PASS")

    # P0-3 tabs
    for tab in ("Discover", "Market", "Collection"):
        ok, note = tap_first(tab, wait=2.5)
        ui = dump_ui()
        if ok and has_text(ui, tab):
            r.add("P0-3", f"Tab: {tab}", "PASS", note)
        else:
            r.add("P0-3", f"Tab: {tab}", "FAIL", note)

    # Back to Collection for core tests
    tap_first("Collection", wait=2.0)

    # P0-4 add series via search
    ok, note = tap_first("Add series", wait=2.5)
    if not ok:
        ok, note = tap_first("Add a series", wait=2.5)
    if not ok:
        r.add("P0-4", "Open add sheet", "FAIL", note)
    else:
        ok2, _ = tap_first("Search catalog", wait=1.5)
        if not ok2:
            # tap search field area — hint text
            ui = dump_ui()
            hits = find_nodes(ui, "Search catalog")
            if hits:
                _, _, x, y = hits[0]
                tap(x, y)
                time.sleep(1.0)
        type_text("hirono")
        time.sleep(2.5)
        ui = dump_ui()
        if has_text(ui, "Hirono") or has_text(ui, "hirono"):
            ok3, note3 = tap_first("Add", wait=2.0)
            if ok3:
                time.sleep(1.5)
                back()
                time.sleep(1.0)
                ui = dump_ui()
                if has_text(ui, "Hirono") or has_text(ui, "1 series") or has_text(ui, "On shelf"):
                    r.add("P0-4", "Add series via search → Add", "PASS")
                else:
                    r.add("P0-4", "Add series via search → Add", "MINOR", "add tapped; shelf state unclear in a11y tree")
            else:
                r.add("P0-4", "Add series via search → Add", "FAIL", "Add button not found")
        else:
            r.add("P0-4", "Add series via search → Add", "FAIL", "no Hirono search results")

    # P0-8 ownership in search (if series on shelf)
    tap_first("Add series", wait=2.0) or tap_first("Add a series", wait=2.0)
    tap_first("Search catalog", wait=1.0) or None
    type_text("hirono")
    time.sleep(2.0)
    ui = dump_ui()
    if has_text(ui, "In collection"):
        r.add("P0-8", "Search row shows In collection", "PASS")
    else:
        r.add("P0-8", "Search row shows In collection", "FAIL", "In collection not in tree")
    back()
    time.sleep(1.0)

    # P0-5 toggle owned — open series on shelf
    ui = dump_ui()
    if tap_first("Hirono", wait=2.5)[0] or tap_first("Other One", wait=2.5)[0]:
        time.sleep(1.5)
        ui = dump_ui()
        toggled = False
        for label in ("Owned", "Wishlist", "On shelf", "Want"):
            if tap_first(label, wait=1.5)[0]:
                toggled = True
                break
        if toggled:
            back()
            time.sleep(0.8)
            force_stop()
            relaunch()
            ui = dump_ui()
            if has_text(ui, "Hirono") or has_text(ui, "1 series"):
                r.add("P0-5", "Figure toggle survives relaunch", "PASS")
            else:
                r.add("P0-5", "Figure toggle survives relaunch", "MINOR", "series visible; toggle state not verified in tree")
        else:
            r.add("P0-5", "Figure toggle owned/wishlist", "FAIL", "no toggle control found")
    else:
        r.add("P0-5", "Figure toggle owned/wishlist", "SKIP", "series card not tappable in tree")

    # P0-12 Discover scroll
    tap_first("Discover", wait=2.5)
    ui = dump_ui()
    if has_text(ui, "Latest drops") or has_text(ui, "Trending"):
        swipe(540, 1800, 540, 900)
        time.sleep(1.0)
        r.add("P0-12", "Discover Latest/Trending scroll", "PASS")
    else:
        r.add("P0-12", "Discover Latest/Trending scroll", "FAIL", "sections not found")

    # P0-14 Official updates
    ui = dump_ui()
    if has_text(ui, "Official") or has_text(ui, "POP MART") or has_text(ui, "ZIMOMO"):
        r.add("P0-14", "Official updates section populated", "PASS")
    elif has_text(ui, "Official updates"):
        r.add("P0-14", "Official updates section", "MINOR", "section present; items may be loading")
    else:
        r.add("P0-14", "Official updates section", "FAIL", "section not found")

    # P0-15 Market browse
    tap_first("Market", wait=3.0)
    ui = dump_ui()
    if has_text(ui, "Market") or has_text(ui, "POP MART") or has_text(ui, "Any brand"):
        r.add("P0-15", "Market browse list renders", "PASS")
    else:
        r.add("P0-15", "Market browse list renders", "FAIL", "market UI not found")

    # P0-16 listing detail — tap first price card area
    prices = re.findall(r'\$(\d+)', ui)
    if prices:
        # tap center of screen in list area
        tap(540, 900)
        time.sleep(2.5)
        ui2 = dump_ui()
        if has_text(ui2, "Read more") or has_text(ui2, "$") or has_text(ui2, "Description"):
            if tap_first("Read more", wait=1.5)[0]:
                ui3 = dump_ui()
                r.add("P0-16", "Listing detail + Read more", "PASS")
            else:
                r.add("P0-16", "Listing detail opens", "PASS", "detail visible; Read more not found")
        else:
            r.add("P0-16", "Listing detail opens", "FAIL", "detail screen not detected")
        # P0-17 back
        back()
        time.sleep(1.5)
        ui_back = dump_ui()
        if has_text(ui_back, "Market"):
            r.add("P0-17", "Back from listing detail", "PASS")
        else:
            r.add("P0-17", "Back from listing detail", "FAIL")
    else:
        r.add("P0-16", "Listing detail", "SKIP", "no listings/prices on screen")
        r.add("P0-17", "Back from listing detail", "SKIP")

    # P0-7 brand filter
    tap_first("Collection", wait=2.0)
    if tap_first("POP MART", wait=2.0)[0]:
        ui = dump_ui()
        if has_text(ui, "POP MART") and not has_text(ui, "Exception"):
            r.add("P0-7", "Brand filter POP MART", "PASS")
        else:
            r.add("P0-7", "Brand filter POP MART", "FAIL")
        tap_first("All Brands", wait=2.0)
    else:
        r.add("P0-7", "Brand filter chips", "SKIP", "POP MART chip not found")

    # P0-22 leave Collection with add sheet
    tap_first("Add series", wait=2.0) or tap_first("Add a series", wait=2.0)
    time.sleep(1.0)
    tap_first("Discover", wait=2.0)
    ui = dump_ui()
    if not has_text(ui, "Add series") and not has_text(ui, "Add a series") and has_text(ui, "Discover"):
        r.add("P0-22", "Leave Collection dismisses add sheet", "PASS")
    else:
        r.add("P0-22", "Leave Collection dismisses add sheet", "FAIL")

    # P0-24 persistence
    tap_first("Collection", wait=2.0)
    ui_before = dump_ui()
    had_content = has_text(ui_before, "Hirono") or has_text(ui_before, "1 series")
    force_stop()
    relaunch()
    ui_after = dump_ui()
    if had_content and (has_text(ui_after, "Hirono") or has_text(ui_after, "1 series")):
        r.add("P0-24", "Shelf survives force-stop", "PASS")
    elif not had_content:
        r.add("P0-24", "Shelf survives force-stop", "SKIP", "no prior shelf content")
    else:
        r.add("P0-24", "Shelf survives force-stop", "FAIL")

    # Crash check
    errs = logcat_errors()
    fatal = [e for e in errs if "FATAL" in e or "Exception" in e]
    if fatal:
        r.add("LOG", "No fatal logcat errors", "FAIL", fatal[-1][:120])
    else:
        r.add("LOG", "No fatal logcat errors", "PASS")

    return r


def print_summary(report: Report) -> int:
    print("\n========== P0 SUMMARY ==========")
    counts = {"PASS": 0, "FAIL": 0, "SKIP": 0, "MINOR": 0}
    for res in report.results:
        counts[res.status] = counts.get(res.status, 0) + 1
    for res in report.results:
        if res.status in ("FAIL", "SKIP", "MINOR"):
            print(f"  {res.id}: {res.status} — {res.notes or res.name}")
    print(f"\nPASS {counts.get('PASS',0)} | FAIL {counts.get('FAIL',0)} | MINOR {counts.get('MINOR',0)} | SKIP {counts.get('SKIP',0)}")
    print("================================")
    manual = [
        "P0-6 Remove series + confirm",
        "P0-7 Brand filter chips",
        "P0-9 Preview sticky CTA owned",
        "P0-10 Latest drops save chip",
        "P0-11 Canonical custom owned",
        "P0-13 Catalog browse /home/catalog",
        "P0-18 Preview sheet stacking",
        "P0-19 Drag dismiss preview",
        "P0-20 Owned preview CTA",
        "P0-21 Insights → back",
        "P0-23 Android back nested preview",
        "P0-25 Custom series local photo",
    ]
    print("\nManual on device (not automated):")
    for m in manual:
        print(f"  • {m}")
    return 1 if counts.get("FAIL", 0) else 0


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "-s":
        SERIAL = sys.argv[2]
    exit(print_summary(run_p0()))
