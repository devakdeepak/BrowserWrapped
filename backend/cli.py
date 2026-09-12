"""
Command-line interface.

Usage:
    python -m browser_wrapped collect [--db PATH]
    python -m browser_wrapped wrapped [--db PATH] [--year YYYY] [--json] [--top N]
    python -m browser_wrapped review  [--db PATH] [--year YYYY] [--json] [--top N]
"""

import argparse
import json
import sys
from pathlib import Path

from .collector import collect_all
from .personality import GeminiError, generate_personality, render_personality
from .store import HistoryStore
from .wrapped import generate_wrapped, render_text_summary

DEFAULT_DB_PATH = Path.home() / ".browser_wrapped" / "history.db"


def _add_db_arg(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--db", type=Path, default=DEFAULT_DB_PATH,
        help=f"Path to the unified sqlite database (default: {DEFAULT_DB_PATH})",
    )


def cmd_collect(args: argparse.Namespace) -> int:
    with HistoryStore(args.db) as store:
        summary = collect_all(store)
        total_inserted = sum(p["inserted"] for p in summary["chrome"] + summary["zen"])
        total_skipped = sum(p["skipped_duplicates"] for p in summary["chrome"] + summary["zen"])

        if not summary["chrome"] and not summary["zen"]:
            print("No Chrome or Zen profiles were found on this machine.")
        else:
            for browser_name in ("chrome", "zen"):
                for entry in summary[browser_name]:
                    print(
                        f"[{browser_name}] {entry['profile']}: "
                        f"+{entry['inserted']} new, {entry['skipped_duplicates']} already stored"
                    )

        for err in summary["errors"]:
            print(f"  ! could not read {err['browser']} profile at {err['path']}: {err['error']}", file=sys.stderr)

        print(f"\nTotal new visits stored: {total_inserted:,} (skipped {total_skipped:,} duplicates)")
        print(f"Database now has {store.total_visits():,} visits total, saved at {args.db}")
    return 0


def cmd_wrapped(args: argparse.Namespace) -> int:
    if not Path(args.db).is_file():
        print(f"No database found at {args.db}. Run `collect` first.", file=sys.stderr)
        return 1

    with HistoryStore(args.db) as store:
        stats = generate_wrapped(store, year=args.year, top_n=args.top)

    if args.json:
        print(json.dumps(stats.as_dict(), indent=2, ensure_ascii=False))
    else:
        print(render_text_summary(stats))
    return 0


def cmd_review(args: argparse.Namespace) -> int:
    """Run `collect` immediately followed by `wrapped`, in one process.

    Meant for callers (like the Flutter app) that just want fresh stats
    with a single subprocess invocation instead of shelling out twice.
    With --json (the normal case for programmatic callers) this prints
    ONLY a single JSON object to stdout, so nothing else in this function
    should ever call print() when args.json is set.
    """
    with HistoryStore(args.db) as store:
        collect_summary = collect_all(store)
        stats = generate_wrapped(store, year=args.year, top_n=args.top)

    if args.json:
        payload = {
            "collect_summary": collect_summary,
            "wrapped": stats.as_dict(),
        }
        print(json.dumps(payload, ensure_ascii=False))
        return 0

    total_inserted = sum(p["inserted"] for p in collect_summary["chrome"] + collect_summary["zen"])
    total_skipped = sum(p["skipped_duplicates"] for p in collect_summary["chrome"] + collect_summary["zen"])
    print(f"Collected {total_inserted:,} new visits (skipped {total_skipped:,} duplicates already stored).")
    for err in collect_summary["errors"]:
        print(f"  ! could not read {err['browser']} profile at {err['path']}: {err['error']}", file=sys.stderr)
    print()
    print(render_text_summary(stats))
    return 0


def cmd_personality(args: argparse.Namespace) -> int:
    if not Path(args.db).is_file():
        print(f"No database found at {args.db}. Run `collect` first.", file=sys.stderr)
        return 1

    with HistoryStore(args.db) as store:
        stats = generate_wrapped(store, year=args.year, top_n=args.top)

    try:
        personality = generate_personality(stats, api_key=args.api_key)
    except GeminiError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(personality.as_dict(), indent=2, ensure_ascii=False))
    else:
        print(render_personality(personality))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="browser_wrapped",
        description="Parse Chrome + Zen browsing history and build a Wrapped-style recap.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_collect = sub.add_parser("collect", help="Scan installed browsers and update the local database")
    _add_db_arg(p_collect)
    p_collect.set_defaults(func=cmd_collect)

    p_wrapped = sub.add_parser("wrapped", help="Generate a Wrapped-style summary from the database")
    _add_db_arg(p_wrapped)
    p_wrapped.add_argument("--year", type=int, default=None, help="Only include this calendar year (local time)")
    p_wrapped.add_argument("--top", type=int, default=10, help="How many top sites/pages to show (default 10)")
    p_wrapped.add_argument("--json", action="store_true", help="Output machine-readable JSON instead of text")
    p_wrapped.set_defaults(func=cmd_wrapped)

    p_review = sub.add_parser(
        "review", help="Run collect + wrapped together in one process (used by the app's Start Review button)"
    )
    _add_db_arg(p_review)
    p_review.add_argument("--year", type=int, default=None, help="Only include this calendar year (local time)")
    p_review.add_argument("--top", type=int, default=10, help="How many top sites/pages to show (default 10)")
    p_review.add_argument("--json", action="store_true", help="Output a single machine-readable JSON object instead of text")
    p_review.set_defaults(func=cmd_review)

    p_personality = sub.add_parser(
        "personality", help="Generate a fun browsing personality read using AI"
    )
    _add_db_arg(p_personality)
    p_personality.add_argument("--year", type=int, default=None, help="Only include this calendar year (local time)")
    p_personality.add_argument("--top", type=int, default=10, help="How many top sites/pages to feed the model (default 10)")
    p_personality.add_argument("--json", action="store_true", help="Output machine-readable JSON instead of text")
    p_personality.add_argument(
        "--api-key", type=str, default=None,
        help="Gemini API key (defaults to GEMINI_API_KEY env var / .env)",
    )
    p_personality.set_defaults(func=cmd_personality)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())