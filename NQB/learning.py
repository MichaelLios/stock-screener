"""
NQB — Walk-forward weight learning system

Algorithm:
  1. Split all completed trades chronologically: train / test window.
  2. For each indicator, compute its "contribution" on the train set:
       contribution = (win_rate when voting with direction) - 0.50 (baseline)
  3. Bayesian-style update: new_weight = old * (1 + LEARNING_RATE * contribution)
  4. Normalize so all weights sum to 1.0 and each stays within [MIN_W, MAX_W].
  5. Evaluate the new weights on the test set (simulated win-rate change).
  6. Persist update to DB weight_log; cache in-memory.

Anti-overfitting:
  - Minimum sample sizes before any update.
  - Weight change per cycle is capped at DELTA_CAP.
  - Walk-forward: training period is always strictly before test period.
  - Out-of-sample test_wr is logged alongside train_wr.
"""
from __future__ import annotations
import json
import time
from copy import deepcopy

import database as db
import analytics

# Default weights (kept in sync with signals.py defaults)
_DEFAULT_WEIGHTS: dict[str, float] = {
    "trend_ema":   0.20,
    "ema_stack":   0.15,
    "macd":        0.18,
    "rsi":         0.15,
    "bb":          0.10,
    "stoch_rsi":   0.10,
    "vwap":        0.07,
    "rel_volume":  0.05,
}

LEARNING_RATE   = 0.15   # how aggressively weights shift per cycle
DELTA_CAP       = 0.05   # max absolute change per indicator per run
MIN_WEIGHT      = 0.02   # floor
MAX_WEIGHT      = 0.35   # ceiling
MIN_TRAIN_TRADES = 20    # won't update weights with fewer trades
TRAIN_SPLIT      = 0.70  # fraction of data used for training

# In-memory weight cache: (timestamp, weights_dict)
_weight_cache: tuple[float, dict[str, float]] = (0.0, {})
_CACHE_TTL = 600  # re-check DB every 10 min


def get_current_weights() -> dict[str, float]:
    """Return live weights (from DB if available, else defaults)."""
    global _weight_cache
    if time.time() - _weight_cache[0] < _CACHE_TTL and _weight_cache[1]:
        return _weight_cache[1]

    snap = db.get_latest_weight_snapshot()
    weights = snap if snap else deepcopy(_DEFAULT_WEIGHTS)
    _weight_cache = (time.time(), weights)
    return weights


def invalidate_cache() -> None:
    global _weight_cache
    _weight_cache = (0.0, {})


# ── Core learning step ────────────────────────────────────────────────────────

def _compute_contributions(trades: list[dict]) -> dict[str, float]:
    """
    For each indicator: what is its win-rate when voting with the trade direction?
    contribution = that_win_rate - 0.50.
    """
    ind_contrib = analytics.indicator_contribution(trades)
    contributions = {}
    for name in _DEFAULT_WEIGHTS:
        c = ind_contrib.get(name, {}).get("contribution_score", 0.0)
        contributions[name] = c
    return contributions


def _apply_update(old_weights: dict[str, float],
                  contributions: dict[str, float]) -> dict[str, float]:
    new_weights = {}
    for name, old_w in old_weights.items():
        contrib = contributions.get(name, 0.0)
        delta   = LEARNING_RATE * contrib
        # Cap the per-cycle change
        delta   = max(-DELTA_CAP, min(DELTA_CAP, delta))
        raw     = old_w + delta
        new_weights[name] = max(MIN_WEIGHT, min(MAX_WEIGHT, raw))

    # Normalize to sum = 1.0
    total = sum(new_weights.values())
    return {k: round(v / total, 6) for k, v in new_weights.items()}


def _simulate_win_rate(weights: dict[str, float], trades: list[dict]) -> float:
    """
    Simulate win-rate using the given weights on a set of completed trades.
    A trade is "predicted WIN" if the weighted bull/bear score > threshold.
    Returns the actual win-rate for trades that the model predicted correctly.
    """
    if not trades:
        return 0.0

    correct = 0
    for t in trades:
        try:
            votes = json.loads(t.get("indicator_votes") or "[]")
        except Exception:
            continue
        bull = sum(
            weights.get(v["name"], 0) * v["strength"]
            for v in votes if v["direction"] == "BULL"
        ) * 100
        bear = sum(
            weights.get(v["name"], 0) * v["strength"]
            for v in votes if v["direction"] == "BEAR"
        ) * 100
        predicted_long = bull > bear
        actual_long    = t.get("direction") == "LONG"
        actual_win     = t.get("outcome") == "WIN"
        # correctly predicted direction AND it won
        if (predicted_long == actual_long) and actual_win:
            correct += 1

    return round(correct / len(trades) * 100, 1) if trades else 0.0


# ── Walk-forward runner ───────────────────────────────────────────────────────

def run_walk_forward(force: bool = False) -> dict:
    """
    Run one walk-forward weight update cycle.
    Returns dict with results; saves to DB if update happened.
    """
    trades = db.get_completed_trades()
    trades.sort(key=lambda t: t.get("timestamp", ""))  # chronological

    n = len(trades)
    if n < MIN_TRAIN_TRADES:
        return {"status": "skipped",
                "reason": f"Only {n} completed trades — need {MIN_TRAIN_TRADES}"}

    split_idx = int(n * TRAIN_SPLIT)
    train     = trades[:split_idx]
    test      = trades[split_idx:]

    old_weights   = get_current_weights()
    contributions = _compute_contributions(train)
    new_weights   = _apply_update(old_weights, contributions)

    train_wr = _simulate_win_rate(new_weights, train)
    test_wr  = _simulate_win_rate(new_weights, test) if test else train_wr

    # Persist
    for indicator in new_weights:
        db.log_weight_update(
            indicator   = indicator,
            old_w       = old_weights.get(indicator, _DEFAULT_WEIGHTS.get(indicator, 0)),
            new_w       = new_weights[indicator],
            contribution= contributions.get(indicator, 0),
            train_wr    = train_wr,
            test_wr     = test_wr,
        )

    invalidate_cache()

    changes = {
        k: round(new_weights[k] - old_weights.get(k, _DEFAULT_WEIGHTS[k]), 4)
        for k in new_weights
    }

    return {
        "status":        "updated",
        "n_train":        len(train),
        "n_test":         len(test),
        "train_win_rate": train_wr,
        "test_win_rate":  test_wr,
        "contributions":  {k: round(v, 4) for k, v in contributions.items()},
        "weight_changes": changes,
        "new_weights":    new_weights,
    }


def weight_history_table() -> list[dict]:
    """
    Return a summary table of weight evolution from DB.
    {indicator, initial, current, total_change}
    """
    result = {}
    db.init_db()
    import sqlite3
    with db.get_conn() as conn:
        rows = conn.execute("""
            SELECT indicator, old_weight, new_weight, timestamp, test_wr
            FROM weight_log
            ORDER BY timestamp ASC
        """).fetchall()

    for r in rows:
        ind = r["indicator"]
        if ind not in result:
            result[ind] = {"indicator": ind,
                            "initial": round(r["old_weight"], 4),
                            "current": round(r["new_weight"], 4),
                            "last_test_wr": r["test_wr"],
                            "updates": 1}
        else:
            result[ind]["current"]      = round(r["new_weight"], 4)
            result[ind]["last_test_wr"] = r["test_wr"]
            result[ind]["updates"]     += 1

    for ind, d in result.items():
        d["total_change"] = round(d["current"] - d["initial"], 4)

    return list(result.values())
