"""
NQB — Outcome tracker

On each refresh cycle, fetches bar data for every open trade's timeframe
and walks forward from the signal bar to find:
  - Target hit (WIN) or stop hit (LOSS)
  - Max favorable excursion (MFE)
  - Max adverse excursion (MAE)
  - Timeout after MAX_BARS_OPEN (recorded as OPEN/TIMEOUT)

Designed to run inside the Dash refresh callback so it reuses already-fetched
data where possible.
"""
from __future__ import annotations
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

import pandas as pd

import config as cfg
import data as datamod
import indicators
import database as db

NY = ZoneInfo("America/New_York")
MAX_BARS_OPEN = 100   # after this many bars, expire the outcome as TIMEOUT


def _parse_ts(ts_str: str) -> datetime:
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            dt = datetime.strptime(ts_str, fmt)
            return dt.replace(tzinfo=NY)
        except ValueError:
            continue
    return datetime.now(NY)


def _tf_key_for_label(label: str) -> str:
    for k, v in cfg.TIMEFRAMES.items():
        if v["label"] == label:
            return k
    return "swing"


def _fetch_bars_since(tf_key: str, since_dt: datetime,
                       preloaded: dict[str, pd.DataFrame] | None = None) -> pd.DataFrame | None:
    """Return OHLCV bars for tf_key that come after since_dt."""
    if preloaded and tf_key in preloaded:
        df = preloaded[tf_key]
    else:
        tf = cfg.TIMEFRAMES[tf_key]
        df = datamod.fetch(interval=tf["interval"], period=tf["period"])
        if df is None or df.empty:
            return None

    # Filter to bars strictly after the signal timestamp
    try:
        mask = df.index > since_dt
        return df[mask].copy()
    except Exception:
        return None


def check_all_open(preloaded: dict[str, pd.DataFrame] | None = None) -> list[dict]:
    """
    Check every open outcome against current market data.
    Returns a list of dicts describing what changed.
    preloaded: {tf_key: DataFrame} if caller already fetched data.
    """
    open_trades = db.get_open_outcomes()
    updates = []

    # Group by timeframe to minimise API calls
    by_tf: dict[str, list[dict]] = {}
    for trade in open_trades:
        tf_label = trade.get("timeframe", "1-Hour (Swing)")
        tf_key   = _tf_key_for_label(tf_label)
        by_tf.setdefault(tf_key, []).append(trade)

    for tf_key, trades in by_tf.items():
        tf = cfg.TIMEFRAMES[tf_key]
        if preloaded and tf_key in preloaded:
            df = preloaded[tf_key]
        else:
            df = datamod.fetch(interval=tf["interval"], period=tf["period"])
            if df is None or df.empty:
                continue

        for trade in trades:
            result = _evaluate_trade(trade, df)
            if result:
                updates.append(result)

    return updates


def _evaluate_trade(trade: dict, df: pd.DataFrame) -> dict | None:
    """Walk bars after signal timestamp; return update dict or None."""
    since_dt = _parse_ts(trade["timestamp"])
    entry     = trade["entry"]
    stop      = trade["stop_price"]
    target    = trade["target"]
    is_long   = trade["direction"] == "LONG"
    sig_id    = trade["signal_id"]

    bars_after = df[df.index > since_dt]
    if bars_after.empty:
        return None

    mfe = trade.get("max_favorable", 0.0) or 0.0
    mae = trade.get("max_adverse",   0.0) or 0.0
    bars_count = trade.get("bars_elapsed", 0) or 0
    outcome    = "OPEN"
    exit_price = 0.0

    for bar_idx, (ts, bar) in enumerate(bars_after.iterrows()):
        bar_h = float(bar["high"])
        bar_l = float(bar["low"])
        bars_count += 1

        # Track MFE / MAE
        if is_long:
            fav = bar_h - entry
            adv = entry - bar_l
        else:
            fav = entry - bar_l
            adv = bar_h - entry

        if fav > mfe:
            mfe = fav
        if adv > mae:
            mae = adv

        # Check exit conditions
        if is_long:
            if bar_l <= stop:
                outcome    = "LOSS"
                exit_price = stop
                break
            if bar_h >= target:
                outcome    = "WIN"
                exit_price = target
                break
        else:
            if bar_h >= stop:
                outcome    = "LOSS"
                exit_price = stop
                break
            if bar_l <= target:
                outcome    = "WIN"
                exit_price = target
                break

        if bars_count >= MAX_BARS_OPEN:
            outcome    = "TIMEOUT"
            exit_price = float(bar["close"])
            break

    if outcome != "OPEN":
        db.resolve_outcome(sig_id, outcome, exit_price, mfe, mae, bars_count)
        return {"signal_id": sig_id, "outcome": outcome, "exit_price": exit_price,
                "mfe": mfe, "mae": mae, "bars": bars_count}
    else:
        db.update_outcome_progress(sig_id, mfe, mae, bars_count)
        return None
