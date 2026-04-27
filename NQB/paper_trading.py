"""
NQB — Paper trading manager

Manages simulated positions tracked in the SQLite database.
Paper trades are identical to live signals but flagged paper_trade=1.

On each refresh cycle, the tracker (tracker.py) automatically resolves
paper trades the same way it resolves live signal outcomes.

The bot also periodically re-trains its ML model and runs walk-forward
weight updates based on completed paper trades.
"""
from __future__ import annotations
from datetime import datetime
from zoneinfo import ZoneInfo

import database as db
import tracker as trk
import learning
import ml_model
import analytics
import sessions as sess_mod

NY = ZoneInfo("America/New_York")

# In-memory toggle — persists for the session only.
# Use a dcc.Store in app.py for UI-side persistence.
_paper_enabled: bool = False


def is_enabled() -> bool:
    return _paper_enabled


def enable() -> None:
    global _paper_enabled
    _paper_enabled = True


def disable() -> None:
    global _paper_enabled
    _paper_enabled = False


def open_trade(sig, session: str = "") -> int:
    """
    Log a new paper trade for sig.
    Returns the signal_id so the UI can track it.
    """
    if not session:
        session = sess_mod.current_session()["name"]
    sid = db.log_signal(sig, session=session, paper=True)
    return sid


def get_open_paper_trades() -> list[dict]:
    """Return all open (unresolved) paper trades from DB."""
    open_all = db.get_open_outcomes()
    return [t for t in open_all if t.get("paper_trade") == 1]


def get_closed_paper_trades(limit: int = 100) -> list[dict]:
    return db.get_completed_trades(paper_only=True, limit=limit)


def refresh_open_trades(preloaded: dict | None = None) -> list[dict]:
    """
    Check all open paper (and live) trades against current bar data.
    Returns list of newly resolved trades.
    preloaded: {tf_key: DataFrame} shared from the dashboard refresh.
    """
    resolved = trk.check_all_open(preloaded=preloaded)
    return resolved


def paper_trade_summary() -> dict:
    """Return quick stats for the paper trading panel."""
    closed = db.get_completed_trades(paper_only=True)
    open_t = get_open_paper_trades()

    if not closed:
        return {"closed": 0, "open": len(open_t), "win_rate": None,
                "net_r": None, "last_update": "never"}

    stats = analytics.overall_stats(closed)
    return {
        "closed":    stats.get("total", 0),
        "open":      len(open_t),
        "win_rate":  stats.get("win_rate"),
        "net_r":     stats.get("net_r"),
        "profit_factor": stats.get("profit_factor"),
    }


def maybe_retrain(force: bool = False) -> dict:
    """
    Opportunistically retrain ML model and update weights.
    Only runs if enough new data has accumulated.
    """
    results = {}

    wf = learning.run_walk_forward(force=force)
    results["walk_forward"] = wf

    ml = ml_model.train_and_save()
    results["ml_model"] = ml

    return results
