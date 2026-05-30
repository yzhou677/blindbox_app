"""ADB helpers for Market release smoke on a connected Android device."""
import re
import subprocess
import sys
import time


def adb(*args: str) -> str:
    r = subprocess.run(
        ["adb", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe(x1: int, y1: int, x2: int, y2: int, ms: int = 350) -> None:
    adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(ms))


def type_text(text: str) -> None:
    safe = text.replace(" ", "%s")
    adb("shell", "input", "text", safe)


def dump_ui(path: str = "/sdcard/ui.xml") -> str:
    adb("shell", "uiautomator", "dump", path)
    return adb("shell", "cat", path)


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
        print(f"MISS tap: {needle!r}")
        return False
    tap(*pt)
    time.sleep(wait)
    print(f"OK tap: {needle!r} @ {pt}")
    return True


def logcat_market(clear: bool = False) -> list[str]:
    if clear:
        adb("logcat", "-c")
    out = adb("logcat", "-d", "-s", "flutter:I")
    return [l for l in out.splitlines() if "MarketSearch" in l or "MarketPriceSort" in l]


def main() -> int:
    print("=== Market smoke (adb) ===")
    tap_desc("Market", 2.5)
    tap_desc("POP MART", 4.0)
    tap_desc("Load more", 6.0)
    tap_desc("Price", 2.0)
    tap_desc("Load more", 6.0)
    lines = logcat_market()
    print("\n--- recent flutter market logs ---")
    for line in lines[-40:]:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
