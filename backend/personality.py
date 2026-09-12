"""
Turns your aggregate browsing stats (see wrapped.py) into a fun,
Spotify-Wrapped-style "personality" read using the Gemini API.

Unlike per-domain classification, this makes exactly ONE API call per
run: it hands the model your top sites/pages and time-of-day patterns,
and asks for a short archetype + description + traits back as JSON.

Requires a Gemini API key, passed via --api-key or the GEMINI_API_KEY
environment variable. Get one at https://aistudio.google.com/apikey
"""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Optional

from .wrapped import WrappedStats

GEMINI_MODEL = "gemini-3.5-flash"
OPENROUTER_MODEL = "openai/gpt-4o-mini"
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)

_RESPONSE_SCHEMA = {
    "type": "OBJECT",
    "properties": {
        "archetype": {
            "type": "STRING",
            "description": "A short, punchy 2-4 word persona name, e.g. 'The Midnight Researcher'.",
        },
        "tagline": {
            "type": "STRING",
            "description": "One catchy sentence summarizing this person's browsing vibe.",
        },
        "description": {
            "type": "STRING",
            "description": "A friendly 3-5 sentence paragraph describing their browsing personality, "
                            "referencing specific patterns from the data.",
        },
        "traits": {
            "type": "ARRAY",
            "items": {"type": "STRING"},
            "description": "3-5 short trait tags, e.g. 'Night Owl', 'Deep Diver', 'Tab Hoarder'.",
        },
    },
    "required": ["archetype", "tagline", "description", "traits"],
}


@dataclass
class BrowsingPersonality:
    archetype: str
    tagline: str
    description: str
    traits: list[str] = field(default_factory=list)

    def as_dict(self) -> dict:
        return {
            "archetype": self.archetype,
            "tagline": self.tagline,
            "description": self.description,
            "traits": self.traits,
        }


class GeminiError(RuntimeError):
    pass


def _build_prompt(stats: WrappedStats) -> str:
    top_domains = ", ".join(f"{d} ({c} visits)" for d, c in stats.top_domains[:15])
    top_pages = "\n".join(
        f"- {title or url} ({count} visits)" for url, title, count in stats.top_pages[:10]
    )
    hours = stats.estimated_active_seconds / 3600

    return f"""You're analyzing someone's web browsing history to create a fun,
"Spotify Wrapped"-style personality profile. Be playful and specific — reference
actual patterns in the data, don't just write generic horoscope text.

Data:
- Total page visits: {stats.total_visits}
- Unique sites visited: {stats.unique_domains}
- Estimated active browsing time: {hours:.1f} hours
- Days with activity: {stats.active_days}, longest streak: {stats.longest_streak_days} days
- Busiest hour of day: {stats.busiest_hour}
- Busiest day of week: {stats.busiest_weekday}
- Top sites: {top_domains or "none"}
- Top pages:
{top_pages or "none"}

Based on this, invent a fun browsing "archetype" for this person, a catchy
tagline, a short description, and a handful of trait tags."""


def _call_gemini(prompt: str, api_key: str) -> dict:
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": _RESPONSE_SCHEMA,
        },
    }

    url = GEMINI_URL.format(model=GEMINI_MODEL)
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise GeminiError(f"Gemini API error {e.code}: {detail}") from e
    except urllib.error.URLError as e:
        raise GeminiError(f"Could not reach Gemini API: {e.reason}") from e

    try:
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return json.loads(text)
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        raise GeminiError(f"Unexpected Gemini response shape: {data}") from e


def _call_openrouter(prompt: str, api_key: str) -> dict:
    """Use OpenRouter as a provider fallback when Gemini is unavailable."""
    body = {
        "model": OPENROUTER_MODEL,
        "messages": [
            {"role": "system", "content": "Return only valid JSON matching the requested fields."},
            {"role": "user", "content": prompt},
        ],
        "response_format": {"type": "json_object"},
    }
    req = urllib.request.Request(
        OPENROUTER_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
            "HTTP-Referer": "https://github.com/debuku/BrowserWrapped",
            "X-Title": "Browser Wrapped",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        text = data["choices"][0]["message"]["content"]
        return json.loads(text)
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise GeminiError(f"OpenRouter API error {e.code}: {detail}") from e
    except (urllib.error.URLError, KeyError, IndexError, json.JSONDecodeError) as e:
        raise GeminiError(f"Unexpected OpenRouter response: {e}") from e


def _local_personality(stats: WrappedStats) -> BrowsingPersonality:
    """Provide a useful result without requiring an AI provider."""
    top_site = stats.top_domains[0][0] if stats.top_domains else "the web"
    return BrowsingPersonality(
        archetype="The Curious Explorer",
        tagline=f"You kept coming back to {top_site}.",
        description=(
            f"You visited {stats.total_visits:,} pages across {stats.unique_domains:,} sites. "
            "Your browsing shows a steady appetite for discovery and learning. "
            "This offline summary is based on your locally collected history."
        ),
        traits=["Curious", "Consistent", "Always Exploring"],
    )


def generate_personality(
    stats: WrappedStats,
    api_key: Optional[str] = None,
) -> BrowsingPersonality:
    if stats.total_visits == 0:
        raise GeminiError("No browsing history to analyze — run `collect` first.")

    prompt = _build_prompt(stats)
    gemini_key = api_key or os.environ.get("GEMINI_API_KEY")
    openrouter_key = os.environ.get("OPENROUTER_API_KEY")

    if not gemini_key and not openrouter_key:
        return _local_personality(stats)

    try:
        if gemini_key:
            result = _call_gemini(prompt, gemini_key)
        else:
            result = _call_openrouter(prompt, openrouter_key)  # type: ignore[arg-type]
    except GeminiError:
        if not openrouter_key or (gemini_key and openrouter_key == gemini_key):
            return _local_personality(stats)
        try:
            result = _call_openrouter(prompt, openrouter_key)
        except GeminiError:
            return _local_personality(stats)

    return BrowsingPersonality(
        archetype=result.get("archetype", "Unknown"),
        tagline=result.get("tagline", ""),
        description=result.get("description", ""),
        traits=result.get("traits", []),
    )


def render_personality(p: BrowsingPersonality) -> str:
    lines = [p.archetype, "=" * len(p.archetype), p.tagline, ""]
    lines.append(p.description)
    if p.traits:
        lines.append("")
        lines.append("Traits: " + " · ".join(p.traits))
    return "\n".join(lines)

