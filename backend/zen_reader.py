"""
Parse Zen Browser's `places.sqlite` database.

Zen is Firefox-based, so it uses Firefox's Places schema. Timestamps
(`visit_date`, `last_visit_date`) are stored as microseconds since the
Unix epoch (UTC) -- much simpler than Chrome's WebKit epoch.
"""

import shutil
import sqlite3
import tempfile
from pathlib import Path
from typing import Iterator

from .models import VisitRecord

_VISIT_TYPE_NAMES = {
    1: "link",
    2: "typed",
    3: "bookmark",
    4: "embed",
    5: "redirect_permanent",
    6: "redirect_temporary",
    7: "download",
    8: "framed_link",
    9: "reload",
}


def _snapshot_db(places_path: Path) -> Path:
    """Firefox/Zen locks places.sqlite while running, so copy it (and its
    WAL sidecar) to a temp location before opening read-only."""
    tmp_dir = Path(tempfile.mkdtemp(prefix="browser_wrapped_zen_"))
    tmp_db = tmp_dir / "places.sqlite"
    shutil.copy2(places_path, tmp_db)
    for suffix in ("-wal", "-shm"):
        sidecar = places_path.with_name(places_path.name + suffix)
        if sidecar.is_file():
            shutil.copy2(sidecar, tmp_db.with_name(tmp_db.name + suffix))
    return tmp_db


def read_zen_history(profile_dir: Path, profile_label: str | None = None) -> Iterator[VisitRecord]:
    """Yield a VisitRecord for every visit in a Zen profile's places.sqlite.

    `profile_dir` is the profile folder that must contain `places.sqlite`.
    """
    places_path = profile_dir / "places.sqlite"
    if not places_path.is_file():
        return

    label = profile_label or profile_dir.name
    tmp_db = _snapshot_db(places_path)
    try:
        conn = sqlite3.connect(f"file:{tmp_db}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        try:
            query = """
                SELECT moz_places.url AS url,
                       moz_places.title AS title,
                       moz_historyvisits.visit_date AS visit_date,
                       moz_historyvisits.visit_type AS visit_type
                FROM moz_historyvisits
                JOIN moz_places ON moz_places.id = moz_historyvisits.place_id
            """
            for row in conn.execute(query):
                if not row["visit_date"]:
                    continue
                ts = row["visit_date"] / 1_000_000  # microseconds -> seconds
                yield VisitRecord(
                    browser="zen",
                    profile=label,
                    url=row["url"],
                    title=row["title"] or "",
                    visit_time_utc=ts,
                    visit_count=1,  # per-visit weight; aggregate later
                    transition=_VISIT_TYPE_NAMES.get(row["visit_type"], "other"),
                )
        finally:
            conn.close()
    finally:
        shutil.rmtree(tmp_db.parent, ignore_errors=True)
