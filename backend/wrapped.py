"""
Turn the raw `visits` table into "Browsing Wrapped" style stats:
top sites, busiest hours/days, estimated time spent, streaks, etc.

All timestamps are converted to the machine's local timezone for display,
since that's what a "wrapped" recap should reflect for the user.
"""

from collections import Counter, defaultdict
from dataclasses import dataclass, field
from datetime import datetime, date, timedelta
from typing import Optional

from .store import HistoryStore

# A gap longer than this between two consecutive visits (in the same
# browser+profile) is treated as "you weren't actively browsing", so we
# don't count it toward estimated active time. This is the same trick
# RescueTime-style tools use since browsers don't log session duration.
_SESSION_GAP_CAP_SECONDS = 20 * 60
_MIN_VISIT_CREDIT_SECONDS = 5  # every visit counts for at least this long

_WEEKDAY_NAMES = [
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday",
]


@dataclass
class WrappedStats:
    year: Optional[int]
    total_visits: int = 0
    unique_domains: int = 0
    active_days: int = 0
    longest_streak_days: int = 0
    estimated_active_seconds: float = 0.0
    top_domains: list[tuple[str, int]] = field(default_factory=list)
    top_pages: list[tuple[str, str, int]] = field(default_factory=list)  # (url, title, count)
    visits_by_hour: list[int] = field(default_factory=lambda: [0] * 24)
    visits_by_weekday: list[int] = field(default_factory=lambda: [0] * 7)
    busiest_hour: Optional[int] = None
    busiest_weekday: Optional[str] = None
    busiest_single_day: Optional[tuple[str, int]] = None  # (ISO date, count)
    visits_by_browser: dict[str, int] = field(default_factory=dict)
    first_visit_local: Optional[str] = None
    last_visit_local: Optional[str] = None

    def as_dict(self) -> dict:
        return {
            "year": self.year,
            "total_visits": self.total_visits,
            "unique_domains": self.unique_domains,
            "active_days": self.active_days,
            "longest_streak_days": self.longest_streak_days,
            "estimated_active_hours": round(self.estimated_active_seconds / 3600, 1),
            "top_domains": self.top_domains,
            "top_pages": self.top_pages,
            "visits_by_hour": self.visits_by_hour,
            "visits_by_weekday": dict(zip(_WEEKDAY_NAMES, self.visits_by_weekday)),
            "busiest_hour": self.busiest_hour,
            "busiest_weekday": self.busiest_weekday,
            "busiest_single_day": self.busiest_single_day,
            "visits_by_browser": self.visits_by_browser,
            "first_visit_local": self.first_visit_local,
            "last_visit_local": self.last_visit_local,
        }


def generate_wrapped(
    store: HistoryStore,
    year: Optional[int] = None,
    top_n: int = 10,
) -> WrappedStats:
    """Build a WrappedStats summary. If `year` is given, only visits whose
    local-time year matches are included; otherwise all visits are used."""

    rows = store.conn.execute(
        "SELECT browser, profile, url, domain, title, visit_time_utc FROM visits "
        "ORDER BY visit_time_utc ASC"
    ).fetchall()

    stats = WrappedStats(year=year)
    if not rows:
        return stats

    domain_counter: Counter[str] = Counter()
    page_counter: Counter[tuple[str, str]] = Counter()
    browser_counter: Counter[str] = Counter()
    day_counter: Counter[date] = Counter()
    active_days: set[date] = set()

    # Per (browser, profile) visit timestamps, kept sorted, for the
    # active-time estimate below.
    per_stream_times: dict[tuple[str, str], list[float]] = defaultdict(list)

    kept_local_times: list[datetime] = []

    for row in rows:
        local_dt = datetime.fromtimestamp(row["visit_time_utc"])
        if year is not None and local_dt.year != year:
            continue

        kept_local_times.append(local_dt)
        domain_counter[row["domain"]] += 1
        page_counter[(row["url"], row["title"] or row["url"])] += 1
        browser_counter[row["browser"]] += 1
        day_counter[local_dt.date()] += 1
        active_days.add(local_dt.date())
        stats.visits_by_hour[local_dt.hour] += 1
        stats.visits_by_weekday[local_dt.weekday()] += 1

        stream_key = (row["browser"], row["profile"])
        per_stream_times[stream_key].append(row["visit_time_utc"])

    if not kept_local_times:
        return stats

    stats.total_visits = len(kept_local_times)
    stats.unique_domains = len(domain_counter)
    stats.top_domains = domain_counter.most_common(top_n)
    stats.top_pages = [
        (url, title, count) for (url, title), count in page_counter.most_common(top_n)
    ]
    stats.visits_by_browser = dict(browser_counter)
    stats.active_days = len(active_days)
    stats.longest_streak_days = _longest_streak(active_days)

    busiest_hour_count = max(stats.visits_by_hour)
    if busiest_hour_count:
        stats.busiest_hour = stats.visits_by_hour.index(busiest_hour_count)

    busiest_weekday_count = max(stats.visits_by_weekday)
    if busiest_weekday_count:
        idx = stats.visits_by_weekday.index(busiest_weekday_count)
        stats.busiest_weekday = _WEEKDAY_NAMES[idx]

    if day_counter:
        best_day, best_day_count = day_counter.most_common(1)[0]
        stats.busiest_single_day = (best_day.isoformat(), best_day_count)

    stats.estimated_active_seconds = _estimate_active_seconds(per_stream_times, year)

    stats.first_visit_local = min(kept_local_times).isoformat(sep=" ", timespec="minutes")
    stats.last_visit_local = max(kept_local_times).isoformat(sep=" ", timespec="minutes")

    return stats


def generate_grouped_stats(
    store: HistoryStore,
    year: Optional[int] = None,
) -> list[dict]:
    """Roll up visits by AI-assigned category (see categorize.py). Domains
    that haven't been classified yet fall under "Uncategorized" — run the
    `categorize` command first to fill those in."""

    category_map = store.domain_to_category_map()

    rows = store.conn.execute(
        "SELECT domain, visit_time_utc FROM visits ORDER BY visit_time_utc ASC"
    ).fetchall()

    counts: Counter[str] = Counter()
    for row in rows:
        local_dt = datetime.fromtimestamp(row["visit_time_utc"])
        if year is not None and local_dt.year != year:
            continue
        category = category_map.get(row["domain"], "Uncategorized")
        counts[category] += 1

    total = sum(counts.values())
    if total == 0:
        return []

    return [
        {
            "category": category,
            "visits": count,
            "percent": round(100 * count / total, 1),
        }
        for category, count in counts.most_common()
    ]


def render_grouped_summary(groups: list[dict]) -> str:
    if not groups:
        return "No browsing history found."

    lines = ["Browsing by Category", "=" * 21]
    for g in groups:
        lines.append(f"  {g['category']:<22} {g['visits']:>6,} visits  ({g['percent']}%)")
    return "\n".join(lines)


def _longest_streak(active_days: set[date]) -> int:
    if not active_days:
        return 0
    ordered = sorted(active_days)
    longest = current = 1
    for prev, curr in zip(ordered, ordered[1:]):
        if curr - prev == timedelta(days=1):
            current += 1
            longest = max(longest, current)
        else:
            current = 1
    return longest


def _estimate_active_seconds(
    per_stream_times: dict[tuple[str, str], list[float]],
    year: Optional[int],
) -> float:
    """Estimate time actively browsing by summing gaps between consecutive
    visits within each browser+profile stream, capping any gap at
    _SESSION_GAP_CAP_SECONDS so idle tabs left open don't inflate the total.
    """
    total = 0.0
    for times in per_stream_times.values():
        times = sorted(times)
        for prev, curr in zip(times, times[1:]):
            gap = curr - prev
            if gap <= 0:
                continue
            total += min(gap, _SESSION_GAP_CAP_SECONDS)
        total += _MIN_VISIT_CREDIT_SECONDS * len(times)
    return total


def render_text_summary(stats: WrappedStats) -> str:
    """Render a friendly plain-text recap, good for printing to a terminal."""
    if stats.total_visits == 0:
        label = f" for {stats.year}" if stats.year else ""
        return f"No browsing history found{label}."

    lines = []
    title = f"Your Browsing Wrapped{f' — {stats.year}' if stats.year else ''}"
    lines.append(title)
    lines.append("=" * len(title))
    lines.append(f"Total page visits: {stats.total_visits:,}")
    lines.append(f"Unique sites visited: {stats.unique_domains:,}")
    lines.append(f"Days with any browsing activity: {stats.active_days:,}")
    lines.append(f"Longest daily streak: {stats.longest_streak_days} day(s)")
    hours = stats.estimated_active_seconds / 3600
    lines.append(f"Estimated active browsing time: ~{hours:,.1f} hours")
    if stats.busiest_hour is not None:
        lines.append(f"Busiest hour of day: {stats.busiest_hour:02d}:00–{stats.busiest_hour:02d}:59")
    if stats.busiest_weekday:
        lines.append(f"Busiest day of week: {stats.busiest_weekday}")
    if stats.busiest_single_day:
        d, count = stats.busiest_single_day
        lines.append(f"Busiest single day: {d} ({count:,} visits)")

    if stats.visits_by_browser:
        breakdown = ", ".join(f"{b}: {c:,}" for b, c in stats.visits_by_browser.items())
        lines.append(f"Visits by browser: {breakdown}")

    lines.append("")
    lines.append("Top sites:")
    for i, (domain, count) in enumerate(stats.top_domains, start=1):
        lines.append(f"  {i:>2}. {domain or '(unknown)'} — {count:,} visits")

    lines.append("")
    lines.append("Top pages:")
    for i, (url, title, count) in enumerate(stats.top_pages, start=1):
        shown_title = title if title and title != url else url
        lines.append(f"  {i:>2}. {shown_title} — {count:,} visits")
        lines.append(f"      {url}")

    return "\n".join(lines)
