"""
Unified local SQLite database that holds normalized visit records from
every browser/profile we've collected from. Safe to re-run: re-importing
the same browser history will not create duplicate rows.
"""

import sqlite3
from pathlib import Path
from typing import Iterable

from .models import VisitRecord

SCHEMA = """
CREATE TABLE IF NOT EXISTS visits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    browser TEXT NOT NULL,
    profile TEXT NOT NULL,
    url TEXT NOT NULL,
    domain TEXT NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    visit_time_utc REAL NOT NULL,
    transition TEXT NOT NULL DEFAULT '',
    UNIQUE(browser, profile, url, visit_time_utc)
);

CREATE INDEX IF NOT EXISTS idx_visits_time ON visits(visit_time_utc);
CREATE INDEX IF NOT EXISTS idx_visits_domain ON visits(domain);
CREATE INDEX IF NOT EXISTS idx_visits_browser ON visits(browser);

CREATE TABLE IF NOT EXISTS domain_categories (
    domain TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    classified_at REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS user_personas (
    year_key TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    tagline TEXT NOT NULL DEFAULT '',
    description TEXT NOT NULL,
    generated_at REAL NOT NULL,
    source_stats TEXT NOT NULL DEFAULT ''
);
"""


class HistoryStore:
    def __init__(self, db_path: Path | str):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(self.db_path)
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(SCHEMA)

    def close(self) -> None:
        self.conn.close()

    def __enter__(self) -> "HistoryStore":
        return self

    def __exit__(self, *exc_info) -> None:
        self.close()

    def insert_visits(self, records: Iterable[VisitRecord]) -> tuple[int, int]:
        """Insert records, skipping ones already present. Returns
        (inserted_count, skipped_duplicate_count)."""
        inserted = 0
        skipped = 0
        cur = self.conn.cursor()
        for r in records:
            cur.execute(
                """
                INSERT OR IGNORE INTO visits
                    (browser, profile, url, domain, title, visit_time_utc, transition)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (r.browser, r.profile, r.url, r.domain, r.title, r.visit_time_utc, r.transition),
            )
            if cur.rowcount:
                inserted += 1
            else:
                skipped += 1
        self.conn.commit()
        return inserted, skipped

    def total_visits(self) -> int:
        return self.conn.execute("SELECT COUNT(*) FROM visits").fetchone()[0]

    def date_range(self) -> tuple[float | None, float | None]:
        row = self.conn.execute(
            "SELECT MIN(visit_time_utc), MAX(visit_time_utc) FROM visits"
        ).fetchone()
        return row[0], row[1]

    def distinct_domains(self) -> list[str]:
        rows = self.conn.execute(
            "SELECT DISTINCT domain FROM visits WHERE domain != '' ORDER BY domain"
        ).fetchall()
        return [r[0] for r in rows]

    def uncategorized_domains(self) -> list[str]:
        rows = self.conn.execute(
            """
            SELECT DISTINCT v.domain FROM visits v
            LEFT JOIN domain_categories c ON c.domain = v.domain
            WHERE v.domain != '' AND c.domain IS NULL
            ORDER BY v.domain
            """
        ).fetchall()
        return [r[0] for r in rows]

    def upsert_categories(self, mapping: dict[str, str], classified_at: float) -> None:
        cur = self.conn.cursor()
        cur.executemany(
            """
            INSERT INTO domain_categories (domain, category, classified_at)
            VALUES (?, ?, ?)
            ON CONFLICT(domain) DO UPDATE SET
                category = excluded.category,
                classified_at = excluded.classified_at
            """,
            [(domain, category, classified_at) for domain, category in mapping.items()],
        )
        self.conn.commit()

    def domain_to_category_map(self) -> dict[str, str]:
        rows = self.conn.execute("SELECT domain, category FROM domain_categories").fetchall()
        return {r["domain"]: r["category"] for r in rows}

    def get_persona(self, year_key: str) -> dict | None:
        """Return the cached persona for a given year key ("all" or a
        4-digit year as a string), or None if none has been generated yet."""
        row = self.conn.execute(
            """
            SELECT year_key, title, tagline, description, generated_at, source_stats
            FROM user_personas WHERE year_key = ?
            """,
            (year_key,),
        ).fetchone()
        return dict(row) if row is not None else None

    def upsert_persona(
        self,
        year_key: str,
        title: str,
        tagline: str,
        description: str,
        generated_at: float,
        source_stats: str,
    ) -> None:
        self.conn.execute(
            """
            INSERT INTO user_personas (year_key, title, tagline, description, generated_at, source_stats)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(year_key) DO UPDATE SET
                title = excluded.title,
                tagline = excluded.tagline,
                description = excluded.description,
                generated_at = excluded.generated_at,
                source_stats = excluded.source_stats
            """,
            (year_key, title, tagline, description, generated_at, source_stats),
        )
        self.conn.commit()