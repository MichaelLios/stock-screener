"""
NQB — SQLite trade database
Central store for signals, outcomes, weight history, and paper trades.
"""
from __future__ import annotations
import sqlite3
import json
import os
from datetime import datetime
from zoneinfo import ZoneInfo

NY = ZoneInfo("America/New_York")
DB_PATH = os.path.join(os.path.dirname(__file__), "nqb_trades.db")


# ── Connection ────────────────────────────────────────────────────────────────

def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


# ── Schema ────────────────────────────────────────────────────────────────────

def init_db() -> None:
    with get_conn() as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS signals (
                id               INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp        TEXT NOT NULL,
                timeframe        TEXT NOT NULL,
                session          TEXT,
                signal_type      TEXT NOT NULL,
                direction        TEXT,
                grade            TEXT,
                bull_score       REAL DEFAULT 0,
                bear_score       REAL DEFAULT 0,
                confluence_score REAL DEFAULT 0,
                entry            REAL DEFAULT 0,
                stop_price       REAL DEFAULT 0,
                target           REAL DEFAULT 0,
                rr               REAL DEFAULT 0,
                atr              REAL DEFAULT 0,
                mtf_confirmed    INTEGER DEFAULT 0,
                reasons          TEXT,
                indicator_votes  TEXT,
                paper_trade      INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS outcomes (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                signal_id     INTEGER NOT NULL UNIQUE,
                outcome       TEXT DEFAULT 'OPEN',
                target_hit    INTEGER DEFAULT 0,
                stop_hit      INTEGER DEFAULT 0,
                max_favorable REAL DEFAULT 0,
                max_adverse   REAL DEFAULT 0,
                bars_elapsed  INTEGER DEFAULT 0,
                exit_price    REAL DEFAULT 0,
                pnl_pts       REAL DEFAULT 0,
                pnl_r         REAL DEFAULT 0,
                resolved      INTEGER DEFAULT 0,
                last_checked  TEXT,
                FOREIGN KEY (signal_id) REFERENCES signals(id)
            );

            CREATE TABLE IF NOT EXISTS weight_log (
                id             INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp      TEXT NOT NULL,
                indicator      TEXT NOT NULL,
                old_weight     REAL,
                new_weight     REAL,
                contribution   REAL,
                train_wr       REAL,
                test_wr        REAL,
                notes          TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_sig_ts   ON signals(timestamp);
            CREATE INDEX IF NOT EXISTS idx_sig_paper ON signals(paper_trade);
            CREATE INDEX IF NOT EXISTS idx_out_sig   ON outcomes(signal_id);
            CREATE INDEX IF NOT EXISTS idx_out_open  ON outcomes(resolved);
        """)


# ── Writes ────────────────────────────────────────────────────────────────────

def log_signal(sig, session: str, paper: bool = False) -> int:
    """Insert a signal and an open outcome stub. Returns the signal id."""
    init_db()
    now       = datetime.now(NY).strftime("%Y-%m-%dT%H:%M:%S")
    direction = "LONG" if "BUY" in sig.signal else ("SHORT" if "SELL" in sig.signal else "NEUTRAL")
    votes     = json.dumps([
        {"name": v.name, "direction": v.direction,
         "strength": round(v.strength, 3), "note": v.note}
        for v in sig.votes
    ])
    reasons   = json.dumps([v.note for v in sig.votes if v.direction != "NEUTRAL"])
    conf      = round(max(sig.bull_score, sig.bear_score), 1)

    with get_conn() as conn:
        cur = conn.execute("""
            INSERT INTO signals
              (timestamp, timeframe, session, signal_type, direction, grade,
               bull_score, bear_score, confluence_score, entry, stop_price,
               target, rr, atr, mtf_confirmed, reasons, indicator_votes, paper_trade)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (now, sig.timeframe_label, session, sig.signal, direction,
              getattr(sig, "grade", ""), sig.bull_score, sig.bear_score, conf,
              sig.price, sig.stop_loss, sig.target, sig.risk_reward, sig.atr,
              1 if getattr(sig, "mtf_confirmed", False) else 0,
              reasons, votes, 1 if paper else 0))
        sid = cur.lastrowid
        conn.execute(
            "INSERT INTO outcomes (signal_id, last_checked) VALUES (?,?)",
            (sid, now),
        )
    return sid


def resolve_outcome(signal_id: int, outcome: str, exit_price: float,
                    max_fav: float, max_adv: float, bars: int) -> None:
    init_db()
    now = datetime.now(NY).strftime("%Y-%m-%dT%H:%M:%S")
    with get_conn() as conn:
        row = conn.execute(
            "SELECT entry, stop_price, rr FROM signals WHERE id=?", (signal_id,)
        ).fetchone()
        if not row:
            return
        entry, stop, rr = row["entry"], row["stop_price"], row["rr"]
        risk = abs(entry - stop) if stop else 1
        pnl_pts = exit_price - entry if outcome == "WIN" else stop - entry
        # flip for shorts
        if conn.execute(
            "SELECT direction FROM signals WHERE id=?", (signal_id,)
        ).fetchone()["direction"] == "SHORT":
            pnl_pts = -pnl_pts
        pnl_r = pnl_pts / risk if risk else 0

        conn.execute("""
            UPDATE outcomes SET
              outcome=?, target_hit=?, stop_hit=?, max_favorable=?,
              max_adverse=?, bars_elapsed=?, exit_price=?,
              pnl_pts=?, pnl_r=?, resolved=1, last_checked=?
            WHERE signal_id=?
        """, (outcome,
              1 if outcome == "WIN" else 0,
              1 if outcome == "LOSS" else 0,
              round(max_fav, 2), round(max_adv, 2), bars,
              round(exit_price, 2), round(pnl_pts, 2), round(pnl_r, 2),
              now, signal_id))


def update_outcome_progress(signal_id: int, max_fav: float,
                             max_adv: float, bars: int) -> None:
    """Update MFE/MAE for an open trade without resolving it."""
    now = datetime.now(NY).strftime("%Y-%m-%dT%H:%M:%S")
    with get_conn() as conn:
        conn.execute("""
            UPDATE outcomes SET max_favorable=?, max_adverse=?,
              bars_elapsed=?, last_checked=?
            WHERE signal_id=? AND resolved=0
        """, (round(max_fav, 2), round(max_adv, 2), bars, now, signal_id))


def log_weight_update(indicator: str, old_w: float, new_w: float,
                      contribution: float, train_wr: float,
                      test_wr: float, notes: str = "") -> None:
    init_db()
    now = datetime.now(NY).strftime("%Y-%m-%dT%H:%M:%S")
    with get_conn() as conn:
        conn.execute("""
            INSERT INTO weight_log
              (timestamp, indicator, old_weight, new_weight, contribution,
               train_wr, test_wr, notes)
            VALUES (?,?,?,?,?,?,?,?)
        """, (now, indicator, old_w, new_w, contribution, train_wr, test_wr, notes))


# ── Reads ─────────────────────────────────────────────────────────────────────

def get_open_outcomes() -> list[dict]:
    init_db()
    with get_conn() as conn:
        rows = conn.execute("""
            SELECT o.id AS outcome_id, o.signal_id, o.max_favorable, o.max_adverse,
                   o.bars_elapsed,
                   s.timestamp, s.entry, s.stop_price, s.target, s.direction,
                   s.signal_type, s.timeframe, s.rr, s.paper_trade, s.session
            FROM outcomes o
            JOIN signals s ON o.signal_id = s.id
            WHERE o.resolved = 0 AND s.signal_type NOT LIKE '%NEUTRAL%'
            ORDER BY s.timestamp DESC
        """).fetchall()
    return [dict(r) for r in rows]


def get_completed_trades(paper_only: bool = False,
                          live_only: bool = False,
                          limit: int = 2000) -> list[dict]:
    init_db()
    filter_sql = ""
    if paper_only:
        filter_sql = "AND s.paper_trade = 1"
    elif live_only:
        filter_sql = "AND s.paper_trade = 0"

    with get_conn() as conn:
        rows = conn.execute(f"""
            SELECT s.id, s.timestamp, s.timeframe, s.session, s.signal_type,
                   s.direction, s.grade, s.bull_score, s.bear_score,
                   s.confluence_score, s.entry, s.stop_price, s.target,
                   s.rr, s.atr, s.mtf_confirmed, s.reasons, s.indicator_votes,
                   s.paper_trade,
                   o.outcome, o.max_favorable, o.max_adverse,
                   o.bars_elapsed, o.pnl_pts, o.pnl_r
            FROM signals s
            JOIN outcomes o ON o.signal_id = s.id
            WHERE o.resolved = 1 {filter_sql}
            ORDER BY s.timestamp DESC
            LIMIT ?
        """, (limit,)).fetchall()
    return [dict(r) for r in rows]


def get_latest_weight_snapshot() -> dict[str, float] | None:
    """Return the most recent weight update as {indicator: weight}."""
    init_db()
    with get_conn() as conn:
        rows = conn.execute("""
            SELECT indicator, new_weight
            FROM weight_log
            WHERE timestamp = (SELECT MAX(timestamp) FROM weight_log)
        """).fetchall()
    if not rows:
        return None
    return {r["indicator"]: r["new_weight"] for r in rows}


def get_all_signals(limit: int = 500) -> list[dict]:
    init_db()
    with get_conn() as conn:
        rows = conn.execute("""
            SELECT s.*, o.outcome, o.pnl_r, o.resolved
            FROM signals s
            LEFT JOIN outcomes o ON o.signal_id = s.id
            ORDER BY s.timestamp DESC
            LIMIT ?
        """, (limit,)).fetchall()
    return [dict(r) for r in rows]
