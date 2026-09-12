"""High-level orchestration: find profiles, parse them, store the results."""

from pathlib import Path
from typing import Optional

from .chrome_reader import read_chrome_history
from .zen_reader import read_zen_history
from .paths import chrome_profile_dirs, zen_profile_dirs
from .store import HistoryStore


def collect_all(
    store: HistoryStore,
    chrome_paths: Optional[list[Path]] = None,
    zen_paths: Optional[list[Path]] = None,
) -> dict:
    """Discover (or use given) profile directories for both browsers,
    parse their history, and insert everything into `store`.

    Returns a summary dict: which profiles were read, and how many new
    vs. already-known visits were found for each.
    """
    summary: dict = {"chrome": [], "zen": [], "errors": []}

    chrome_dirs = chrome_paths if chrome_paths is not None else list(chrome_profile_dirs())
    for profile_dir in chrome_dirs:
        try:
            records = read_chrome_history(profile_dir)
            inserted, skipped = store.insert_visits(records)
            summary["chrome"].append(
                {"profile": profile_dir.name, "path": str(profile_dir),
                 "inserted": inserted, "skipped_duplicates": skipped}
            )
        except Exception as exc:  # keep going even if one profile is unreadable
            summary["errors"].append({"browser": "chrome", "path": str(profile_dir), "error": str(exc)})

    zen_dirs = zen_paths if zen_paths is not None else list(zen_profile_dirs())
    for profile_dir in zen_dirs:
        try:
            records = read_zen_history(profile_dir)
            inserted, skipped = store.insert_visits(records)
            summary["zen"].append(
                {"profile": profile_dir.name, "path": str(profile_dir),
                 "inserted": inserted, "skipped_duplicates": skipped}
            )
        except Exception as exc:
            summary["errors"].append({"browser": "zen", "path": str(profile_dir), "error": str(exc)})

    return summary

