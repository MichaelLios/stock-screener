"""
NQB — Trade journal (append-only CSV)
Auto-logs every A / A+ signal. Outcome and P&L can be filled in later
by editing the CSV or via the Trade Journal tab in the dashboard.
"""
from __future__ import annotations
import csv
import os
from datetime import datetime
from zoneinfo import ZoneInfo
import config as cfg
from signals import TradeSignal

NY = ZoneInfo("America/New_York")

FIELDS = [
    "time_ny", "timeframe", "direction", "grade",
    "entry", "stop", "target", "rr", "confluence_score",
    "reasons", "outcome", "pnl_pts",
]


def _ensure_header() -> None:
    if not os.path.exists(cfg.JOURNAL_CSV):
        with open(cfg.JOURNAL_CSV, "w", newline="") as f:
            csv.DictWriter(f, fieldnames=FIELDS).writeheader()


def log_signal(sig: TradeSignal) -> None:
    """Append a new signal to the journal CSV."""
    _ensure_header()
    direction  = "LONG"  if "BUY"  in sig.signal else "SHORT"
    bull_votes = [v.note for v in sig.votes if v.direction == "BULL"]
    bear_votes = [v.note for v in sig.votes if v.direction == "BEAR"]
    reasons    = " | ".join(bull_votes if "BUY" in sig.signal else bear_votes)[:300]
    confluence = round(max(sig.bull_score, sig.bear_score), 1)

    row = {
        "time_ny":          datetime.now(NY).strftime("%Y-%m-%d %H:%M"),
        "timeframe":        sig.timeframe_label,
        "direction":        direction,
        "grade":            getattr(sig, "grade", ""),
        "entry":            round(sig.price, 2),
        "stop":             round(sig.stop_loss, 2),
        "target":           round(sig.target, 2),
        "rr":               round(sig.risk_reward, 2),
        "confluence_score": confluence,
        "reasons":          reasons,
        "outcome":          "",
        "pnl_pts":          "",
    }
    with open(cfg.JOURNAL_CSV, "a", newline="") as f:
        csv.DictWriter(f, fieldnames=FIELDS).writerow(row)


def load_journal() -> list[dict]:
    """Return all journal entries as a list of dicts."""
    _ensure_header()
    with open(cfg.JOURNAL_CSV, newline="") as f:
        return list(csv.DictReader(f))


def save_journal(rows: list[dict]) -> None:
    """Overwrite the journal with a new set of rows (for editing outcomes)."""
    with open(cfg.JOURNAL_CSV, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in FIELDS})
