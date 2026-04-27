"""
NQB — Economic calendar / high-impact event warnings
Uses ForexFactory's public JSON feed (no API key required).
Falls back gracefully if offline.
"""
from __future__ import annotations
import time
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
import requests

NY = ZoneInfo("America/New_York")

_CACHE: tuple[float, list] = (0.0, [])
_CACHE_TTL = 3600  # refresh once per hour


def get_upcoming_events(hours_ahead: int = 24) -> list[dict]:
    """Return list of high-impact events within `hours_ahead` hours of now (NY)."""
    global _CACHE
    now_ts = time.time()
    if now_ts - _CACHE[0] < _CACHE_TTL:
        return _filter(_CACHE[1], hours_ahead)

    try:
        resp = requests.get(
            "https://nfs.faireconomy.media/ff_calendar_thisweek.json",
            timeout=5,
            headers={"User-Agent": "NQB/1.0"},
        )
        if resp.status_code != 200:
            _CACHE = (now_ts, [])
            return []
        events = _parse(resp.json())
        _CACHE = (now_ts, events)
        return _filter(events, hours_ahead)
    except Exception:
        return []


def _parse(raw: list) -> list[dict]:
    result = []
    for ev in raw:
        if ev.get("impact", "").lower() != "high":
            continue
        date_str = ev.get("date", "")
        time_str = ev.get("time") or "12:00am"
        try:
            dt = datetime.strptime(f"{date_str} {time_str}", "%m-%d-%Y %I:%M%p")
            dt = dt.replace(tzinfo=NY)
            result.append({"title": ev.get("title", "Unknown"), "dt": dt})
        except Exception:
            continue
    return result


def _filter(events: list, hours_ahead: int) -> list[dict]:
    now     = datetime.now(NY)
    cutoff  = now + timedelta(hours=hours_ahead)
    return [
        {"title": e["title"], "date_str": e["dt"].strftime("%a %b %d  %I:%M %p ET")}
        for e in events
        if now <= e["dt"] <= cutoff
    ]
