"""
Locate browser profile directories on Windows and Linux.

Chrome and Zen store their data in different places on each OS, and each
can have multiple profiles. This module finds every plausible profile
directory so the parsers can decide which ones actually contain a usable
history database.
"""

import os
import platform
from pathlib import Path
from typing import Iterator


def _is_windows() -> bool:
    return platform.system() == "Windows"


def chrome_profile_dirs() -> Iterator[Path]:
    """Yield every Chrome/Chromium 'User Data' profile dir that exists.

    Each yielded path is a profile directory (e.g. ".../Default",
    ".../Profile 1") that should contain a `History` sqlite file.
    """
    candidates: list[Path] = []

    if _is_windows():
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            candidates.append(Path(local_appdata) / "Google" / "Chrome" / "User Data")
            candidates.append(Path(local_appdata) / "Chromium" / "User Data")
    else:
        home = Path.home()
        candidates.append(home / ".config" / "google-chrome")
        candidates.append(home / ".config" / "chromium")
        # Flatpak install
        candidates.append(
            home / ".var" / "app" / "com.google.Chrome" / "config" / "google-chrome"
        )

    for user_data_dir in candidates:
        if not user_data_dir.is_dir():
            continue
        for entry in user_data_dir.iterdir():
            if not entry.is_dir():
                continue
            if entry.name == "Default" or entry.name.startswith("Profile "):
                if (entry / "History").is_file():
                    yield entry


def zen_profile_dirs() -> Iterator[Path]:
    """Yield every Zen Browser profile dir that exists.

    Zen is Firefox-based and uses the same `profiles.ini` + salted profile
    folder layout as Firefox, just under its own app-data directory.
    Each yielded path should contain a `places.sqlite` file.
    """
    roots: list[Path] = []

    if _is_windows():
        appdata = os.environ.get("APPDATA")
        if appdata:
            roots.append(Path(appdata) / "zen")
    else:
        home = Path.home()
        roots.append(home / ".zen")
        roots.append(home / ".var" / "app" / "app.zen_browser.zen" / ".zen")

    for root in roots:
        if not root.is_dir():
            continue

        profiles_ini = root / "profiles.ini"
        found_via_ini = False
        if profiles_ini.is_file():
            for path in _profiles_from_ini(root, profiles_ini):
                if (path / "places.sqlite").is_file():
                    found_via_ini = True
                    yield path

        if not found_via_ini:
            # Fall back to scanning every subfolder for a places.sqlite,
            # in case profiles.ini is missing or unparseable.
            for entry in root.glob("*"):
                if entry.is_dir() and (entry / "places.sqlite").is_file():
                    yield entry


def _profiles_from_ini(root: Path, profiles_ini: Path) -> Iterator[Path]:
    """Minimal profiles.ini parser (avoids pulling in configparser quirks
    around Firefox's ini format, which sometimes has duplicate-ish keys)."""
    current_path = None
    current_is_relative = True
    for raw_line in profiles_ini.read_text(errors="ignore").splitlines():
        line = raw_line.strip()
        if line.startswith("["):
            if current_path is not None:
                yield (root / current_path) if current_is_relative else Path(current_path)
            current_path = None
            current_is_relative = True
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip().lower()
        value = value.strip()
        if key == "path":
            current_path = value
        elif key == "isrelative":
            current_is_relative = value == "1"
    if current_path is not None:
        yield (root / current_path) if current_is_relative else Path(current_path)
