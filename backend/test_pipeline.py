"""Builds fake Chrome `History` and Zen `places.sqlite` files with a
realistic schema, then runs the real collector + wrapped generator against
them to sanity-check the whole pipeline end to end."""

import shutil
import sqlite3
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from browser_wrapped.chrome_reader import read_chrome_history
from browser_wrapped.zen_reader import read_zen_history
from browser_wrapped.store import HistoryStore
from browser_wrapped.collector import collect_all
from browser_wrapped.wrapped import generate_wrapped, render_text_summary

TEST_ROOT = Path("/tmp/bw_test")
if TEST_ROOT.exists():
    shutil.rmtree(TEST_ROOT)
TEST_ROOT.mkdir(parents=True)

WEBKIT_EPOCH_OFFSET = 11_644_473_600


def to_webkit(dt: datetime) -> int:
    return int((dt.timestamp() + WEBKIT_EPOCH_OFFSET) * 1_000_000)


# ---------------------------------------------------------------------
# Build a fake Chrome profile
# ---------------------------------------------------------------------
chrome_profile = TEST_ROOT / "chrome" / "Default"
chrome_profile.mkdir(parents=True)
chrome_db = chrome_profile / "History"

conn = sqlite3.connect(chrome_db)
conn.executescript("""
CREATE TABLE urls(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER,
                   typed_count INTEGER, last_visit_time INTEGER, hidden INTEGER);
CREATE TABLE visits(id INTEGER PRIMARY KEY, url INTEGER, visit_time INTEGER,
                     from_visit INTEGER, transition INTEGER, segment_id INTEGER,
                     visit_duration INTEGER);
""")

now = datetime.now()
sites = [
    ("https://news.ycombinator.com/", "Hacker News", 0),   # link
    ("https://github.com/", "GitHub", 1),                  # typed
    ("https://docs.python.org/3/", "Python Docs", 0),
    ("https://www.reddit.com/r/python", "r/python", 0),
]
url_ids = {}
uid = 1
for url, title, _ in sites:
    conn.execute("INSERT INTO urls(id, url, title, visit_count, typed_count, last_visit_time, hidden) "
                 "VALUES (?,?,?,?,?,?,0)", (uid, url, title, 5, 1, to_webkit(now)))
    url_ids[url] = uid
    uid += 1

vid = 1
for day_offset in range(5):
    day = now - timedelta(days=day_offset)
    for i, (url, title, transition) in enumerate(sites):
        visit_time = day.replace(hour=9 + i, minute=0, second=0, microsecond=0)
        conn.execute(
            "INSERT INTO visits(id, url, visit_time, from_visit, transition, segment_id, visit_duration) "
            "VALUES (?,?,?,0,?,0,0)",
            (vid, url_ids[url], to_webkit(visit_time), transition),
        )
        vid += 1
conn.commit()
conn.close()

# ---------------------------------------------------------------------
# Build a fake Zen (Firefox-schema) profile
# ---------------------------------------------------------------------
zen_profile = TEST_ROOT / "zen" / "abc123.default"
zen_profile.mkdir(parents=True)
zen_db = zen_profile / "places.sqlite"

conn = sqlite3.connect(zen_db)
conn.executescript("""
CREATE TABLE moz_places(id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER,
                         last_visit_date INTEGER);
CREATE TABLE moz_historyvisits(id INTEGER PRIMARY KEY, from_visit INTEGER, place_id INTEGER,
                                visit_date INTEGER, visit_type INTEGER);
""")

zen_sites = [
    ("https://www.youtube.com/", "YouTube", 1),
    ("https://mail.proton.me/", "Proton Mail", 2),
    ("https://news.ycombinator.com/", "Hacker News", 1),
]
place_ids = {}
pid = 1
for url, title, _ in zen_sites:
    conn.execute("INSERT INTO moz_places(id, url, title, visit_count, last_visit_date) VALUES (?,?,?,?,?)",
                 (pid, url, title, 3, int(now.timestamp() * 1_000_000)))
    place_ids[url] = pid
    pid += 1

vid = 1
for day_offset in range(3):
    day = now - timedelta(days=day_offset)
    for i, (url, title, vtype) in enumerate(zen_sites):
        visit_time = day.replace(hour=20 + i if 20 + i < 24 else 23, minute=15, second=0, microsecond=0)
        conn.execute(
            "INSERT INTO moz_historyvisits(id, from_visit, place_id, visit_date, visit_type) VALUES (?,0,?,?,?)",
            (vid, place_ids[url], int(visit_time.timestamp() * 1_000_000), vtype),
        )
        vid += 1
conn.commit()
conn.close()

# ---------------------------------------------------------------------
# Run the real readers directly first (unit-level check)
# ---------------------------------------------------------------------
chrome_records = list(read_chrome_history(chrome_profile))
zen_records = list(read_zen_history(zen_profile))
print(f"Chrome reader parsed {len(chrome_records)} visits")
print(f"Zen reader parsed {len(zen_records)} visits")
assert len(chrome_records) == 5 * len(sites), "chrome reader count mismatch"
assert len(zen_records) == 3 * len(zen_sites), "zen reader count mismatch"
assert chrome_records[0].domain in ("news.ycombinator.com", "github.com", "docs.python.org", "reddit.com")
assert zen_records[0].transition in ("link", "typed")

# ---------------------------------------------------------------------
# Run the full collector -> store -> wrapped pipeline
# ---------------------------------------------------------------------
db_path = TEST_ROOT / "unified_history.db"
with HistoryStore(db_path) as store:
    summary = collect_all(
        store,
        chrome_paths=[chrome_profile],
        zen_paths=[zen_profile],
    )
    print("\nCollector summary:", summary)

    # Re-run collection to make sure de-duplication works (should insert 0 new)
    summary2 = collect_all(store, chrome_paths=[chrome_profile], zen_paths=[zen_profile])
    total_inserted_second_run = sum(p["inserted"] for p in summary2["chrome"] + summary2["zen"])
    assert total_inserted_second_run == 0, f"expected 0 new on re-run, got {total_inserted_second_run}"
    print("De-dupe check passed: second collect run inserted 0 new rows.")

    print(f"\nTotal visits in store: {store.total_visits()}")

    stats = generate_wrapped(store, year=None, top_n=5)
    print("\n" + render_text_summary(stats))

print("\nALL CHECKS PASSED")
