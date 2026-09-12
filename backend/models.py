"""Shared data model used by every browser-specific parser."""

from dataclasses import dataclass
from urllib.parse import urlparse


@dataclass
class VisitRecord:
    """One normalized page visit, regardless of which browser it came from."""

    browser: str          # "chrome" or "zen"
    profile: str           # profile folder name, e.g. "Default", "Profile 1"
    url: str
    title: str
    visit_time_utc: float   # unix epoch seconds (UTC), fractional
    visit_count: int        # browser's own running visit count for that URL
    transition: str = ""    # link / typed / reload / etc. (best effort)

    @property
    def domain(self) -> str:
        try:
            netloc = urlparse(self.url).netloc
            return netloc.lower().removeprefix("www.")
        except Exception:
            return ""

    def dedupe_key(self) -> tuple:
        # Rounded to the second so trivial float jitter doesn't create dupes
        return (self.browser, self.profile, self.url, round(self.visit_time_utc))
