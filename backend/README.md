# browser_wrapped

Parses your **Chrome** and **Zen Browser** history, stores it in a unified
local SQLite database, and generates a "Spotify Wrapped"-style recap of
your browsing habits. Works on **Windows** and **Linux**. Pure Python
standard library — no dependencies to install.

## How it works

- `paths.py` finds Chrome's `User Data` profiles and Zen's Firefox-style
  `profiles.ini` profiles on whichever OS you're running.
- `chrome_reader.py` / `zen_reader.py` copy the (often locked-by-the-browser)
  history database to a temp file, open it read-only, and normalize every
  visit into a shared `VisitRecord`.
- `store.py` writes those records into `~/.browser_wrapped/history.db`
  (a database separate from your browsers' own files), with a UNIQUE
  constraint so re-running collection never creates duplicates.
- `wrapped.py` turns the accumulated visits into stats: top sites, top
  pages, busiest hour/day, longest daily streak, and an estimated "active
  browsing time" (gaps between consecutive visits are summed, capped at
  20 minutes each, since browsers don't log session length directly).

## Usage

```bash
# 1. Scan your machine for Chrome + Zen history and import it
python -m browser_wrapped collect

# 2. Generate your recap
python -m browser_wrapped wrapped

# Just one year, more top sites, as JSON (e.g. to feed a web/app frontend)
python -m browser_wrapped wrapped --year 2026 --top 20 --json

# Use a custom database location
python -m browser_wrapped collect --db ./mydata.db
python -m browser_wrapped wrapped --db ./mydata.db
```

Run `collect` periodically (e.g. a scheduled task/cron job) to keep
building up history over time — it's idempotent and only imports new
visits.

## Notes & caveats

- **Close the browser first, or don't worry about it** — the tool copies
  the database before reading, so it works even while Chrome/Zen are
  running, but for the most current data close them first.
- **"Active time" is an estimate.** No mainstream browser logs how long a
  tab was actually viewed, so this tool infers it from the gaps between
  visit timestamps, same approach tools like RescueTime use. Treat it as
  a rough signal, not a stopwatch.
- **Multiple profiles** are all detected and imported automatically,
  tagged by profile name, so a family/shared computer's per-person browsing
  won't be silently merged.
- **Zen Browser paths**: standard Firefox-style layout is assumed
  (`~/.zen/<profile>` on Linux, `%APPDATA%\zen\Profiles\<profile>` on
  Windows, plus a Flatpak fallback on Linux). If your install uses a
  nonstandard location, pass explicit paths via `collect_all(store,
  zen_paths=[Path("...")])` in Python instead of the CLI.
- Only Chrome and Zen are implemented, but `models.VisitRecord` +
  `store.HistoryStore` are generic — adding another Chromium-based browser
  (Edge, Brave) is just pointing `chrome_reader` at a new profile path, and
  another Firefox-based browser is the same for `zen_reader`.

## Files

| File | Purpose |
|---|---|
| `models.py` | `VisitRecord` dataclass shared by all parsers |
| `paths.py` | Locates Chrome/Zen profile directories per OS |
| `chrome_reader.py` | Parses Chrome's `History` (WebKit timestamps) |
| `zen_reader.py` | Parses Zen's `places.sqlite` (Firefox schema) |
| `store.py` | Unified SQLite schema + dedupe-safe inserts |
| `collector.py` | Wires discovery → parsing → storage together |
| `wrapped.py` | Aggregates stats + renders the text recap |
| `cli.py` / `__main__.py` | `python -m browser_wrapped ...` |

## Testing

`test_pipeline.py` (in the project root) builds synthetic Chrome and Zen
SQLite databases with the real schemas, runs the actual readers and
collector against them, and checks the wrapped output — no real browser
data needed to verify the logic works.
