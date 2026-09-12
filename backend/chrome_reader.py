"""
Parse Google Chrome's `History` SQLite database.

Chrome timestamps are WebKit/Chrome time: microseconds since
1601-01-01 00:00:00 UTC. We convert those to normal Unix epoch seconds.
"""

import shutil
import sqlite3
import tempfile
from pathlib import Path
from typing import Iterator

from .models import VisitRecord

# Seconds between the Windows FILETIME epoch (1601-01-01) and the Unix
# epoch (1970-01-01).
_WEBKIT_EPOCH_OFFSET_SECONDS = 11_644_473_600

_TRANSITION_CORE_MASK = 0xFF
_TRANSITION_NAMES = {
    0: "link",
    1: "typed",
    2: "auto_bookmark",
    3: "auto_subframe",
    4: "manual_subframe",
    5: "generated",
    6: "auto_toplevel",
    7: "form_submit",
    8: "reload",
    9: "keyword",
    10: "keyword_generated",
}


def webkit_to_unix(webkit_timestamp: int) -> float:
    if not webkit_timestamp:
        return 0.0
    return (webkit_timestamp / 1_000_000) - _WEBKIT_EPOCH_OFFSET_SECONDS


def _snapshot_db(history_path: Path) -> Path:
    """Chrome locks `History` while running, so copy it (and its WAL
    sidecar files, if present) to a temp location before opening."""
    tmp_dir = Path(tempfile.mkdtemp(prefix="browser_wrapped_chrome_"))
    tmp_db = tmp_dir / "History"
    shutil.copy2(history_path, tmp_db)
    for suffix in ("-wal", "-shm"):
        sidecar = history_path.with_name(history_path.name + suffix)
        if sidecar.is_file():
            shutil.copy2(sidecar, tmp_db.with_name(tmp_db.name + suffix))
    return tmp_db


def read_chrome_history(profile_dir: Path, profile_label: str | None = None) -> Iterator[VisitRecord]:
    """Yield a VisitRecord for every visit in a Chrome profile's History db.

    `profile_dir` is the profile folder (e.g. .../User Data/Default), which
    must contain a `History` file.
    """
    history_path = profile_dir / "History"
    if not history_path.is_file():
        return

    label = profile_label or profile_dir.name
    tmp_db = _snapshot_db(history_path)
    try:
        conn = sqlite3.connect(f"file:{tmp_db}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            query = """
                SELECT urls.url AS url,
                       urls.title AS title,
                       visits.visit_time AS visit_time,
                       visits.transition AS transition
                FROM visits
                JOIN urls ON urls.id = visits.url
            """
            # Chrome doesn't track per-visit duration; visit_count on the
            # `urls` row is a running total for that URL, not per-visit.
            counts = dict(
                conn.execute("SELECT id, visit_count FROM urls").fetchall()
            )
            url_id_by_url = {}
            for row in conn.execute("SELECT id, url FROM urls"):
                url_id_by_url[row["id"]] = row["url"]

            for row in conn.execute(query):
                ts = webkit_to_unix(row["visit_time"])
                if ts <= 0:
                    continue
                core_transition = row["transition"] & _TRANSITION_CORE_MASK
                yield VisitRecord(
                    browser="chrome",
                    profile=label,
                    url=row["url"],
                    title=row["title"] or "",
                    visit_time_utc=ts,
                    visit_count=1,  # per-visit weight; aggregate later
                    transition=_TRANSITION_NAMES.get(core_transition, "other"),
                )
        finally:
            conn.close()
    finally:
        shutil.rmtree(tmp_db.parent, ignore_errors=True)
