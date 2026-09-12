"""
locator.py

Finds browser history database files on disk for the current user,
across Windows, macOS, and Linux, for Chrome, Edge, and Firefox.

Each browser may have multiple profiles (Default, Profile 1, Profile 2, ...
for Chromium-based browsers; arbitrarily-named dirs for Firefox), so this
returns a list of candidates rather than a single path.
"""

import os
import platform
import glob
from dataclasses import dataclass
from typing import List


@dataclass
class BrowserSource:
    browser: str        # 'chrome' | 'edge' | 'firefox'
    profile: str         # profile directory name
    path: str            # full path to the History / places.sqlite file


def _chromium_profiles(base_dir: str, browser_name: str) -> List[BrowserSource]:
    sources = []
    if not os.path.isdir(base_dir):
        return sources
    for entry in os.listdir(base_dir):  
        profile_dir = os.path.join(base_dir, entry)
        if not os.path.isdir(profile_dir):
            continue
        # Chromium profile dirs are named "Default", "Profile 1", "Profile 2", ...
        if entry == "Default" or entry.startswith("Profile "):
            history_path = os.path.join(profile_dir, "History")
            if os.path.isfile(history_path):
                sources.append(BrowserSource(browser_name, entry, history_path))
    return sources


def _firefox_profiles(base_dir: str) -> List[BrowserSource]:
    sources = []
    if not os.path.isdir(base_dir):
        return sources
    for places_path in glob.glob(os.path.join(base_dir, "*", "places.sqlite")):
        profile_dir = os.path.basename(os.path.dirname(places_path))
        sources.append(BrowserSource("firefox", profile_dir, places_path))
    return sources


def find_browser_sources() -> List[BrowserSource]:
    """
    Returns every discoverable (browser, profile, history_file) triple for
    the current OS user. Missing browsers/profiles are simply skipped -
    it's normal for most of these paths not to exist on a given machine.
    """
    system = platform.system()
    home = os.path.expanduser("~")
    sources: List[BrowserSource] = []

    if system == "Windows":
        local_app_data = os.environ.get("LOCALAPPDATA", os.path.join(home, "AppData", "Local"))
        app_data = os.environ.get("APPDATA", os.path.join(home, "AppData", "Roaming"))

        sources += _chromium_profiles(
            os.path.join(local_app_data, "Google", "Chrome", "User Data"), "chrome")
        sources += _chromium_profiles(
            os.path.join(local_app_data, "Microsoft", "Edge", "User Data"), "edge")
        sources += _firefox_profiles(
            os.path.join(app_data, "Mozilla", "Firefox", "Profiles"))

    elif system == "Darwin":  # macOS
        sources += _chromium_profiles(
            os.path.join(home, "Library", "Application Support", "Google", "Chrome"), "chrome")
        sources += _chromium_profiles(
            os.path.join(home, "Library", "Application Support", "Microsoft Edge"), "edge")
        sources += _firefox_profiles(
            os.path.join(home, "Library", "Application Support", "Firefox", "Profiles"))
        # Safari uses a different schema (History.db) - not handled here yet.

    else:  # assume Linux
        sources += _chromium_profiles(
            os.path.join(home, ".config", "google-chrome"), "chrome")
        sources += _chromium_profiles(
            os.path.join(home, ".config", "microsoft-edge"), "edge")
        sources += _firefox_profiles(
            os.path.join(home, ".mozilla", "firefox"))

    return sources
