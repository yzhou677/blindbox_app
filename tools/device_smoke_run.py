import re
import subprocess
import sys
import time

ENC = "utf-8"


def adb(*args):
    return subprocess.run(
        ["adb", *args], capture_output=True, text=True, encoding=ENC, errors="replace"
    ).stdout or ""


def tap(x, y):
    adb("shell", "input", "tap", str(x), str(y))


def ui():
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return adb("shell", "cat", "/sdcard/ui.xml")


def tap_desc(sub, wait=2.5):
    hits = re.findall(
        rf'content-desc="([^"]*{re.escape(sub)}[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',
        ui(),
        re.I,
    )
    if not hits:
        return False
    x1, y1, x2, y2 = map(int, hits[0][1:])
    tap((x1 + x2) // 2, (y1 + y2) // 2)
    time.sleep(wait)
    return True


def prices():
    s = ui()
    return [int(x) for x in re.findall(r'text="\$(\d+)"', s)]


def logs():
    out = adb("logcat", "-d", "-s", "flutter:I")
    return [l for l in out.splitlines() if "MarketSearch" in l]


def ok(name, cond, detail=""):
    status = "PASS" if cond else "FAIL"
    print(f"{status}\t{name}\t{detail}")
    return cond


print("=== DEVICE SMOKE ===")
tap(900, 2250)
time.sleep(3)
ok("Market tab", "Market" in ui())

tap_desc("POP MART", 5)
p_pop = prices()
ok("POP MART results", len(p_pop) >= 3, f"prices={p_pop[:8]}")

tap_desc("Price", 2)
p_desc = prices()
ok("Feed Price toggle", len(p_desc) >= 3, f"prices={p_desc[:8]}")
if len(p_desc) >= 3:
    ok("Feed Price desc local", p_desc == sorted(p_desc, reverse=True), str(p_desc[:10]))

tap(540, 2078)
time.sleep(7)
p_after = prices()
ok("Load more rendered", len(p_after) >= len(p_desc), f"before={len(p_desc)} after={len(p_after)}")
if len(p_after) >= 4:
    ok("Feed global desc after load-more", p_after == sorted(p_after, reverse=True), str(p_after[:12]))

# Search Nommi
tap_desc("Search figures", 2)
adb("shell", "input", "text", "nommi")
time.sleep(3)
nommi = prices()
sig = any("nommi|relevance" in l for l in logs())
ok("Search Nommi results", len(nommi) >= 1, f"prices={nommi[:6]}")
ok("Search Nommi relevance sig", sig, logs()[-3:] if logs() else "no logs")

before = nommi[:4]
tap(540, 2078)
time.sleep(7)
after = prices()
ok("Search append load-more", len(after) >= len(before), f"before={before} after={after[:8]}")
if before and after:
    ok("Search top cards stable", after[: len(before)] == before, f"{before} -> {after[:len(before)]}")

adb("shell", "input", "keyevent", "4")
time.sleep(2)
ok("Back to feed", tap_desc("POP MART", 2), "")
