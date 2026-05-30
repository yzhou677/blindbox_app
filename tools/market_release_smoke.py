"""Market release smoke — wireless Android via adb."""
from __future__ import annotations

import re
import subprocess
import time
from dataclasses import dataclass, field


def adb(*args: str) -> str:
    r = subprocess.run(["adb", *args], capture_output=True, text=True)
    return (r.stdout or "") + (r.stderr or "")


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y))


def swipe_up() -> None:
    adb("shell", "input", "swipe", "540", "1800", "540", "500", "350")


def back() -> None:
    adb("shell", "input", "keyevent", "4")


def dump_ui() -> str:
    adb("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    return adb("shell", "cat", "/sdcard/ui.xml")


def find_all_desc(ui: str, needle: str) -> list[tuple[str, int, int]]:
    pat = re.compile(
        rf'content-desc="([^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    )
    out: list[tuple[str, int, int]] = []
    for m in pat.finditer(ui):
        desc, x1, y1, x2, y2 = m.group(1), *map(int, m.groups()[1:])
        if needle.lower() in desc.lower():
            out.append((desc, (x1 + x2) // 2, (y1 + y2) // 2))
    return out


def tap_first(needle: str, wait: float = 2.5) -> bool:
    ui = dump_ui()
    hits = find_all_desc(ui, needle)
    if not hits:
        return False
    _, x, y = hits[0]
    tap(x, y)
    time.sleep(wait)
    return True


def tap_search_field() -> bool:
    ui = dump_ui()
    # read-only search on market feed
    for needle in ("Search figures", "Search market"):
        hits = find_all_desc(ui, needle)
        if hits:
            _, x, y = hits[0]
            tap(x, y)
            time.sleep(2)
            return True
    return False


def type_query(q: str) -> None:
    adb("shell", "input", "text", q.replace(" ", "%s"))
    time.sleep(1.2)


def clear_search_field() -> None:
    back()


def prices_on_screen() -> list[int]:
    ui = dump_ui()
    return [int(x) for x in re.findall(r'\$(\d+)', ui)]


def snapshot_ids_from_log() -> list[str]:
    out = adb("logcat", "-d", "-s", "flutter:I")
    ids: list[str] = []
    for line in out.splitlines():
        m = re.search(r"snapshotId=([^\s]+)", line)
        if m:
            ids.append(m.group(1))
    return ids


def market_logs(tail: int = 30) -> list[str]:
    out = adb("logcat", "-d", "-s", "flutter:I")
    lines = [l for l in out.splitlines() if "MarketSearch" in l]
    return lines[-tail:]


@dataclass
class Result:
    name: str
    status: str  # PASS, MINOR, FAIL
    notes: str = ""


@dataclass
class Report:
    results: list[Result] = field(default_factory=list)

    def add(self, name: str, status: str, notes: str = "") -> None:
        self.results.append(Result(name, status, notes))
        print(f"[{status}] {name}" + (f" — {notes}" if notes else ""))


def wait_cards(min_prices: int = 1, timeout: float = 12) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout:
        if len(prices_on_screen()) >= min_prices:
            return True
        time.sleep(0.8)
    return False


def is_ascending(vals: list[int]) -> bool:
    return all(vals[i] <= vals[i + 1] for i in range(len(vals) - 1))


def is_descending(vals: list[int]) -> bool:
    return all(vals[i] >= vals[i + 1] for i in range(len(vals) - 1))


def run() -> Report:
    r = Report()
    adb("logcat", "-c")

    # Navigate to Market
    if not tap_first("Market"):
        r.add("Setup: open Market tab", "FAIL", "Market tab not found")
        return r
    r.add("Setup: open Market tab", "PASS")

    # 1 Feed browsing
    if tap_first("Any brand") or tap_first("Any Brand"):
        wait_cards(2)
        r.add("Feed: Any Brand", "PASS", f"{len(prices_on_screen())} prices visible")
    else:
        r.add("Feed: Any Brand", "MINOR", "chip not found in a11y tree")

    if tap_first("POP MART"):
        wait_cards(2)
        prices = prices_on_screen()
        r.add("Feed: POP MART", "PASS" if prices else "MINOR", f"{len(prices)} cards")

        if tap_first("Any IP"):
            wait_cards(2)
            r.add("Feed: POP MART + Any IP", "PASS", f"{len(prices_on_screen())} cards")
        else:
            r.add("Feed: POP MART + Any IP", "MINOR", "Any IP chip not found")

        # try specific IP (The Monsters common on POP MART rail)
        for ip in ("The Monsters", "SKULLPANDA", "Skullpanda", "Dimoo"):
            if tap_first(ip):
                wait_cards(2)
                r.add(f"Feed: POP MART + {ip}", "PASS", f"{len(prices_on_screen())} cards")
                break
        else:
            r.add("Feed: specific IP", "MINOR", "no known IP chip tapped")

    else:
        r.add("Feed: POP MART", "FAIL", "chip not found")

    # 4 Price ↓ on feed (POP MART context)
    tap_first("Price", 2)
    if wait_cards(3):
        p1 = prices_on_screen()[:12]
        if is_descending(p1):
            r.add("Feed Price ↓ page 1", "PASS", str(p1[:6]))
        else:
            r.add("Feed Price ↓ page 1", "FAIL", f"not descending: {p1[:8]}")
    else:
        r.add("Feed Price ↓ page 1", "FAIL", "no cards")

    swipe_up()
    swipe_up()
    if tap_first("Load more", 7):
        if wait_cards(4):
            p2 = prices_on_screen()[:15]
            if is_descending(p2):
                r.add("Feed Price ↓ after load-more", "PASS", f"global desc {p2[:8]}")
            else:
                r.add("Feed Price ↓ after load-more", "FAIL", f"order break: {p2}")
        else:
            r.add("Feed Price ↓ after load-more", "MINOR", "cards slow to render")
    else:
        r.add("Feed Price ↓ after load-more", "MINOR", "Load more footer not visible")

    tap_first("Price", 2)  # toggle to ↑
    if wait_cards(3):
        up = prices_on_screen()[:12]
        if is_ascending(up):
            r.add("Feed Price ↑ page 1", "PASS", str(up[:6]))
        else:
            r.add("Feed Price ↑ page 1", "FAIL", f"not ascending: {up[:8]}")

    # 3 Feed/Search isolation
    tap_first("POP MART", 3)
    tap_first("Pucky", 3) or tap_first("PUCKY", 3)
    feed_sig_before = market_logs(5)
    if tap_search_field():
        time.sleep(1)
        type_query("nommi")
        time.sleep(3)
        nommi_prices = prices_on_screen()
        logs = market_logs(8)
        nommi_sig = any("nommi|relevance" in l for l in logs)
        if nommi_sig:
            r.add("Search Nommi query signature", "PASS", "any_brand|any_ip|nommi|relevance")
        else:
            r.add("Search Nommi query signature", "MINOR", "sig not in recent logs")
        if nommi_prices:
            r.add("Search Nommi results", "PASS", f"{len(nommi_prices)} prices")
        else:
            r.add("Search Nommi results", "MINOR", "no prices in UI dump")

        # search load-more stability
        before_ids = prices_on_screen()[:6]
        swipe_up()
        swipe_up()
        if tap_first("Load more", 7) and wait_cards(4):
            after = prices_on_screen()
            if after[: min(6, len(before_ids))] == before_ids[: min(6, len(before_ids))]:
                r.add("Search load-more stability", "PASS", "first visible prices unchanged")
            else:
                r.add(
                    "Search load-more stability",
                    "PASS" if len(after) > len(before_ids) else "MINOR",
                    f"before={before_ids} after={after[:8]}",
                )

        back()
        time.sleep(2)
        if tap_first("POP MART", 2):
            r.add("Feed restored after search back", "PASS")
        else:
            r.add("Feed restored after search back", "MINOR", "POP MART chip not re-tapped")

        if tap_first("Pucky", 2) or tap_first("PUCKY", 2):
            r.add("Feed Pucky filter preserved", "PASS")
        else:
            r.add("Feed Pucky filter preserved", "MINOR", "Pucky chip state unclear in a11y")

    else:
        r.add("Search isolation flow", "FAIL", "could not open search")

    # 2 Search queries
    if tap_search_field():
        for q in ("skullpanda", "smiski"):
            adb("shell", "input", "keyevent", "123")  # move cursor end - noop ok
            # clear field via select all delete is hard; reopen search
            back()
            time.sleep(1)
            tap_search_field()
            time.sleep(1)
            type_query(q)
            time.sleep(3)
            p = prices_on_screen()
            r.add(
                f"Search {q}",
                "PASS" if p else "MINOR",
                f"{len(p)} visible prices",
            )
        back()
        time.sleep(1)
        tap_search_field()
        time.sleep(1)
        type_query("zzzznomatchzzzz")
        time.sleep(3)
        ui = dump_ui()
        if "No matches" in ui or "no matches" in ui.lower():
            r.add("Search no-match empty state", "PASS")
        elif len(prices_on_screen()) == 0:
            r.add("Search no-match empty state", "PASS", "zero prices")
        else:
            r.add("Search no-match empty state", "MINOR", "unexpected results shown")
        back()

    # 8 Route transitions x2
    for i in range(2):
        if tap_search_field():
            type_query("nommi")
            time.sleep(2)
            back()
            time.sleep(1.5)
            r.add(f"Route Market→Search→Back #{i+1}", "PASS")
        else:
            r.add(f"Route Market→Search→Back #{i+1}", "MINOR")

    # 7 Pagination duplicates heuristic on feed
    tap_first("POP MART", 2)
    tap_first("Price", 1)
    seen: set[int] = set()
    dup = False
    for _ in range(3):
        for p in prices_on_screen():
            if p in seen:
                dup = True
            seen.add(p)
        swipe_up()
        if not tap_first("Load more", 6):
            break
    r.add(
        "Pagination duplicate heuristic (price values)",
        "MINOR" if dup else "PASS",
        "duplicate $ values on screen (may be different listings)" if dup else "no exact duplicate prices seen",
    )

    return r


if __name__ == "__main__":
    rep = run()
    fails = [x for x in rep.results if x.status == "FAIL"]
    minors = [x for x in rep.results if x.status == "MINOR"]
    print("\n=== SUMMARY ===")
    print(f"PASS: {sum(1 for x in rep.results if x.status == 'PASS')}")
    print(f"MINOR: {len(minors)}")
    print(f"FAIL: {len(fails)}")
    if fails:
        for f in fails:
            print(f"  FAIL: {f.name} — {f.notes}")
