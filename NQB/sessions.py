"""
NQB — Market session detection (America/New_York)
"""
from datetime import time as dtime, datetime
from zoneinfo import ZoneInfo
import config as cfg

NY = ZoneInfo("America/New_York")


def current_session() -> dict:
    """Return the active trading session for the current New York time."""
    now = datetime.now(NY).time()
    for name, start_hm, end_hm, tradeable, color in cfg.SESSIONS:
        start = dtime(*start_hm)
        end   = dtime(*end_hm)
        if start <= now < end:
            return {"name": name, "tradeable": tradeable, "color": color}
    return {"name": "Overnight / Pre-Market", "tradeable": False, "color": "#4a4a6a"}


def session_for_bar(dt) -> str:
    """Return session name for a given datetime (tz-aware or naive NY time)."""
    if hasattr(dt, "tzinfo") and dt.tzinfo is not None:
        t = dt.astimezone(NY).time()
    else:
        t = dt.time()
    for name, start_hm, end_hm, tradeable, color in cfg.SESSIONS:
        start = dtime(*start_hm)
        end   = dtime(*end_hm)
        if start <= t < end:
            return name
    return "Overnight"
