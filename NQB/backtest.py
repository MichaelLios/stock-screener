"""
NQB — Walk-forward backtesting engine

Replays historical OHLCV bar-by-bar using the same indicator + signal engine.
Simulates a mechanical entry at each signal bar's close price, exits when
price hits stop loss or target within the next 50 bars.

Results are a rough guide for signal quality — not a rigorous backtest.
Always account for slippage, commissions, and out-of-sample validation.
"""
from __future__ import annotations
import pandas as pd
import numpy as np

import config as cfg
import data as datamod
import indicators
import signals as sig_engine

MIN_BARS  = 210   # EMA-200 warm-up period
LOOKAHEAD = 50    # max bars to wait for stop/target

_PERIOD_MAP = {
    "scalp": "5d",
    "swing": "60d",
    "trend": "2y",
}


def run(tf_key: str = "swing") -> dict:
    tf = cfg.TIMEFRAMES[tf_key]
    df = datamod.fetch(interval=tf["interval"], period=_PERIOD_MAP.get(tf_key, tf["period"]))
    if df is None or df.empty:
        return {"error": "No data available", "trades": [], "stats": {}, "equity_curve": []}

    df = indicators.add_all(df)
    if len(df) < MIN_BARS + 5:
        return {
            "error": f"Not enough bars (need {MIN_BARS + 5}, got {len(df)})",
            "trades": [], "stats": {}, "equity_curve": [],
        }

    # Reset index to positional for slicing; keep datetime for display
    df = df.reset_index()  # datetime becomes a column
    date_col = "datetime" if "datetime" in df.columns else df.columns[0]

    trades = []
    i = MIN_BARS

    while i < len(df) - 1:
        window = df.iloc[:i + 1].set_index(date_col)
        sig    = sig_engine.evaluate(window, tf["label"])

        if "NEUTRAL" in sig.signal or sig.stop_loss == 0 or sig.target == 0:
            i += 1
            continue
        if sig.risk_reward < cfg.RISK_REWARD_MIN:
            i += 1
            continue

        entry   = sig.price
        stop    = sig.stop_loss
        target  = sig.target
        is_long = "BUY" in sig.signal

        outcome = "OPEN"
        exit_i  = min(i + LOOKAHEAD, len(df) - 1)
        for j in range(i + 1, exit_i + 1):
            bar_h = df["high"].iloc[j]
            bar_l = df["low"].iloc[j]
            if is_long:
                if bar_l <= stop:
                    outcome = "LOSS"
                    break
                if bar_h >= target:
                    outcome = "WIN"
                    break
            else:
                if bar_h >= stop:
                    outcome = "LOSS"
                    break
                if bar_l <= target:
                    outcome = "WIN"
                    break

        risk_pts   = abs(entry - stop)
        reward_pts = abs(entry - target)
        rr         = reward_pts / risk_pts if risk_pts > 0 else 0.0
        pnl_r      = rr if outcome == "WIN" else (-1.0 if outcome == "LOSS" else 0.0)

        bar_time = str(df[date_col].iloc[i])[:16]
        trades.append({
            "time":    bar_time,
            "signal":  sig.signal,
            "entry":   round(entry, 1),
            "stop":    round(stop, 1),
            "target":  round(target, 1),
            "rr":      round(rr, 2),
            "outcome": outcome,
            "pnl_r":   round(pnl_r, 2),
        })

        i = j + 1

    return _summarize(trades)


def _summarize(trades: list[dict]) -> dict:
    completed = [t for t in trades if t["outcome"] in ("WIN", "LOSS")]

    if not completed:
        return {
            "trades": trades, "stats": {}, "equity_curve": [],
            "error": "No completed trades in the selected period",
        }

    total  = len(completed)
    wins   = sum(1 for t in completed if t["outcome"] == "WIN")
    losses = total - wins

    win_rate      = wins / total * 100
    avg_rr_wins   = (sum(t["rr"] for t in completed if t["outcome"] == "WIN") / wins
                     if wins else 0.0)
    gross_profit  = sum(t["pnl_r"] for t in completed if t["outcome"] == "WIN")
    gross_loss    = abs(sum(t["pnl_r"] for t in completed if t["outcome"] == "LOSS"))
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else None
    net_r         = sum(t["pnl_r"] for t in completed)

    # Max drawdown in R-multiples
    running  = 0.0
    peak     = 0.0
    max_dd   = 0.0
    curve    = []
    for t in completed:
        running += t["pnl_r"]
        curve.append(round(running, 2))
        if running > peak:
            peak = running
        dd = running - peak
        if dd < max_dd:
            max_dd = dd

    # Win rate by signal type
    by_signal: dict[str, dict] = {}
    for t in completed:
        key = t["signal"]
        if key not in by_signal:
            by_signal[key] = {"trades": 0, "wins": 0}
        by_signal[key]["trades"] += 1
        if t["outcome"] == "WIN":
            by_signal[key]["wins"] += 1
    for key, d in by_signal.items():
        d["win_rate"] = round(d["wins"] / d["trades"] * 100, 1)

    return {
        "trades": trades,
        "equity_curve": curve,
        "by_signal": by_signal,
        "stats": {
            "total_trades":   total,
            "wins":           wins,
            "losses":         losses,
            "win_rate":       round(win_rate, 1),
            "avg_rr":         round(avg_rr_wins, 2),
            "profit_factor":  round(profit_factor, 2) if profit_factor is not None else "∞",
            "max_drawdown_r": round(max_dd, 2),
            "net_r":          round(net_r, 2),
        },
    }
