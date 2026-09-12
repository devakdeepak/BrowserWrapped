"""
Minimal .env loader — no python-dotenv dependency, consistent with the
rest of this project. Reads KEY=VALUE lines from a .env file (if present)
into os.environ, without overwriting variables already set in the shell.
"""

from __future__ import annotations

import os
from pathlib import Path


def load_env(path: str | Path | None = None) -> None:
    """Load a .env file into os.environ. Looks in the current working
    directory by default. Existing environment variables always win."""

    env_path = Path(path) if path else Path.cwd() / ".env"
    if not env_path.is_file():
        return

    for raw_line in env_path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value