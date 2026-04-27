"""
NQB — Analytics engine

Reads from the SQLite trade database and computes:
  - Win rate by setup type, timeframe, session, grade, confluence reason
  - Best and worst setups
  - Indicator factor correlation with outcomes
  - Weekly performance report
"""
from __future__ import annotations
import json
from collections import defaultdict
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import database as db

NY = ZoneInfo("America/New_York")
MIN_SAMPLE = 3  # minimum trades needed to report a stat


# ── Helpers ───────────────────────────────────────────────────────────────────

def _wr(trades: list[dict]) -> tuple[float, int]:
    """Return (win_rate_pct, sample_size) for a list of completed trades."""
    if not trades:
        return 0.0, 0
    wins = sum(1 for t in trades if t.get("outcome") == "WIN")
    return round(wins / len(trades) * 100, 1), len(trades)


def _group_by(trades: list[dict], key: str) -> dict[str, list[dict]]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for t in trades:
        groups[str(t.get(key, "unknown") or "unknown")].append(t)
    return dict(groups)


# ── Breakdown tables ──────────────────────────────────────────────────────────

def win_rate_table(field: str, trades: list[dict] | None = None) -> list[dict]:
    """
    Return rows: [{field: value, trades: n, wins: n, losses: n, win_rate: %, avg_rr: x}]
    Sorted by win_rate desc.
    """
    if trades is None:
        trades = db.get_completed_trades()
    if not trades:
        return []

    groups = _group_by(trades, field)
    rows = []
    for val, grp in groups.items():
        wr, n = _wr(grp)
        if n < MIN_SAMPLE:
            continue
        wins   = sum(1 for t in grp if t.get("outcome") == "WIN")
        avg_rr = (sum(t.get("pnl_r", 0) or 0 for t in grp) / n)
        rows.append({
            field:      val,
            "trades":   n,
            "wins":     wins,
            "losses":   n - wins,
            "win_rate": wr,
            "avg_rr":   round(avg_rr, 2),
        })
    return sorted(rows, key=lambda r: (r["win_rate"], r["trades"]), reverse=True)


def factor_correlation(trades: list[dict] | None = None) -> list[dict]:
    """
    For each confluence reason (indicator vote note), compute correlation with WIN.
    Returns: [{reason, appearances, win_rate}] sorted by win_rate desc.
    """
    if trades is None:
        trades = db.get_completed_trades()
    if not trades:
        return []

    reason_wins:   dict[str, int] = defaultdict(int)
    reason_total:  dict[str, int] = defaultdict(int)

    for t in trades:
        outcome = t.get("outcome")
        if outcome not in ("WIN", "LOSS"):
            continue
        try:
            reasons = json.loads(t.get("reasons") or "[]")
        except Exception:
            continue
        for r in reasons:
            if not r:
                continue
            key = r[:60]  # truncate for display
            reason_total[key] += 1
            if outcome == "WIN":
                reason_wins[key] += 1

    rows = []
    for reason, total in reason_total.items():
        if total < MIN_SAMPLE:
            continue
        rows.append({
            "reason":     reason,
            "appearances": total,
            "win_rate":   round(reason_wins[reason] / total * 100, 1),
        })
    return sorted(rows, key=lambda r: r["win_rate"], reverse=True)


def indicator_contribution(trades: list[dict] | None = None) -> dict[str, dict]:
    """
    For each indicator, compute:
      {name: {win_rate_when_bullish, win_rate_when_bearish, appearances, contribution_score}}

    contribution_score > 0 means indicator helps; < 0 means it misleads.
    """
    if trades is None:
        trades = db.get_completed_trades()
    if not trades:
        return {}

    stats: dict[str, dict] = defaultdict(lambda: {
        "bull_wins": 0, "bull_total": 0,
        "bear_wins": 0, "bear_total": 0,
    })

    for t in trades:
        outcome = t.get("outcome")
        if outcome not in ("WIN", "LOSS"):
            continue
        direction = t.get("direction", "LONG")
        is_win    = outcome == "WIN"
        try:
            votes = json.loads(t.get("indicator_votes") or "[]")
        except Exception:
            continue

        for v in votes:
            name = v.get("name", "")
            vdir = v.get("direction", "NEUTRAL")
            if vdir == "NEUTRAL":
                continue
            # A vote is "correct" if it agrees with the trade direction
            if direction == "LONG":
                correct = (vdir == "BULL")
            else:
                correct = (vdir == "BEAR")

            if correct:
                stats[name]["bull_wins"]  += 1 if is_win else 0
                stats[name]["bull_total"] += 1
            else:
                stats[name]["bear_wins"]  += 1 if is_win else 0
                stats[name]["bear_total"] += 1

    result = {}
    for name, s in stats.items():
        bt = s["bull_total"]
        brt= s["bear_total"]
        aligned_wr   = round(s["bull_wins"] / bt * 100, 1) if bt else None
        misaligned_wr= round(s["bear_wins"] / brt * 100, 1) if brt else None
        # contribution: how much better than chance (50%) when voting with direction
        contrib = round(((s["bull_wins"] / bt) if bt else 0.5) - 0.5, 3)
        result[name] = {
            "aligned_win_rate":    aligned_wr,
            "misaligned_win_rate": misaligned_wr,
            "aligned_n":           bt,
            "contribution_score":  contrib,
        }
    return result


def best_setups(trades: list[dict] | None = None, top_n: int = 5) -> list[dict]:
    """
    Best setups by composite score = win_rate * log(n+1) (rewards both quality and quantity).
    """
    import math
    if trades is None:
        trades = db.get_completed_trades()

    # Group by (timeframe, session, signal_type)
    groups: dict[str, list[dict]] = defaultdict(list)
    for t in trades:
        key = f"{t.get('timeframe','?')} | {t.get('session','?')} | {t.get('signal_type','?')}"
        groups[key].append(t)

    rows = []
    for setup, grp in groups.items():
        wr, n = _wr(grp)
        if n < MIN_SAMPLE:
            continue
        score = wr * math.log(n + 1)
        avg_r = round(sum(t.get("pnl_r", 0) or 0 for t in grp) / n, 2)
        rows.append({"setup": setup, "trades": n, "win_rate": wr,
                     "avg_r": avg_r, "composite_score": round(score, 1)})

    rows.sort(key=lambda r: r["composite_score"], reverse=True)
    return rows[:top_n]


def worst_setups(trades: list[dict] | None = None, top_n: int = 5) -> list[dict]:
    import math
    if trades is None:
        trades = db.get_completed_trades()

    groups: dict[str, list[dict]] = defaultdict(list)
    for t in trades:
        key = f"{t.get('timeframe','?')} | {t.get('session','?')} | {t.get('signal_type','?')}"
        groups[key].append(t)

    rows = []
    for setup, grp in groups.items():
        wr, n = _wr(grp)
        if n < MIN_SAMPLE:
            continue
        loss_rate = 100 - wr
        score = loss_rate * math.log(n + 1)
        avg_r = round(sum(t.get("pnl_r", 0) or 0 for t in grp) / n, 2)
        rows.append({"setup": setup, "trades": n, "win_rate": wr,
                     "avg_r": avg_r, "avoid_score": round(score, 1)})

    rows.sort(key=lambda r: r["avoid_score"], reverse=True)
    return rows[:top_n]


def expectancy_by(field: str, trades: list[dict] | None = None) -> list[dict]:
    """
    Expectancy = (WR × avg_win_R) − (LR × avg_loss_R), broken down by field.
    Returns rows sorted by expectancy desc.
    """
    if trades is None:
        trades = db.get_completed_trades()
    if not trades:
        return []

    groups = _group_by(trades, field)
    rows = []
    for val, grp in groups.items():
        completed = [t for t in grp if t.get("outcome") in ("WIN", "LOSS")]
        n = len(completed)
        if n < MIN_SAMPLE:
            continue
        wins   = [t for t in completed if t.get("outcome") == "WIN"]
        losses = [t for t in completed if t.get("outcome") == "LOSS"]
        wr = len(wins) / n
        lr = 1.0 - wr
        avg_win_r  = (sum(t.get("pnl_r", 0) or 0 for t in wins)        / len(wins))   if wins   else 0.0
        avg_loss_r = (sum(abs(t.get("pnl_r", 0) or 0) for t in losses) / len(losses)) if losses else 0.0
        exp = round(wr * avg_win_r - lr * avg_loss_r, 3)
        rows.append({
            field:         val,
            "trades":      n,
            "win_rate":    round(wr * 100, 1),
            "avg_win_r":   round(avg_win_r,  2),
            "avg_loss_r":  round(avg_loss_r, 2),
            "expectancy":  exp,
        })
    return sorted(rows, key=lambda r: r["expectancy"], reverse=True)


def max_drawdown_r(trades: list[dict]) -> float:
    """Maximum peak-to-trough drawdown in R from the running equity curve."""
    if not trades:
        return 0.0
    equity, peak, dd = 0.0, 0.0, 0.0
    for t in trades:
        equity += t.get("pnl_r", 0) or 0
        if equity > peak:
            peak = equity
        drawdown = peak - equity
        if drawdown > dd:
            dd = drawdown
    return round(dd, 2)


def overall_stats(trades: list[dict] | None = None) -> dict:
    if trades is None:
        trades = db.get_completed_trades()
    if not trades:
        return {}

    completed = [t for t in trades if t.get("outcome") in ("WIN", "LOSS")]
    n      = len(trades)
    wins   = sum(1 for t in trades if t.get("outcome") == "WIN")
    losses = sum(1 for t in trades if t.get("outcome") == "LOSS")
    wr, _  = _wr(trades)
    net_r  = sum(t.get("pnl_r", 0) or 0 for t in trades)
    gp     = sum(t.get("pnl_r", 0) or 0 for t in trades if t.get("outcome") == "WIN")
    gl     = abs(sum(t.get("pnl_r", 0) or 0 for t in trades if t.get("outcome") == "LOSS"))
    pf     = round(gp / gl, 2) if gl > 0 else None
    avg_mfe = round(sum(t.get("max_favorable", 0) or 0 for t in trades) / n, 1) if n else 0
    avg_mae = round(sum(t.get("max_adverse",   0) or 0 for t in trades) / n, 1) if n else 0
    dd     = max_drawdown_r(trades)

    # Expectancy
    c_wins   = [t for t in completed if t.get("outcome") == "WIN"]
    c_losses = [t for t in completed if t.get("outcome") == "LOSS"]
    nc = len(completed)
    if nc > 0:
        wr_frac = len(c_wins) / nc
        lr_frac = 1.0 - wr_frac
        avg_wr  = (sum(t.get("pnl_r", 0) or 0 for t in c_wins) / len(c_wins)) if c_wins else 0
        avg_lr  = (sum(abs(t.get("pnl_r", 0) or 0) for t in c_losses) / len(c_losses)) if c_losses else 0
        expectancy = round(wr_frac * avg_wr - lr_frac * avg_lr, 3)
    else:
        expectancy = None

    avg_r_per_trade = round(net_r / n, 2) if n else 0

    return {
        "total":           n,
        "wins":            wins,
        "losses":          losses,
        "win_rate":        wr,
        "net_r":           round(net_r, 2),
        "profit_factor":   pf,
        "avg_mfe_pts":     avg_mfe,
        "avg_mae_pts":     avg_mae,
        "max_drawdown_r":  dd,
        "expectancy":      expectancy,
        "avg_r_per_trade": avg_r_per_trade,
    }


# ── Weekly report ─────────────────────────────────────────────────────────────

def weekly_report(paper_only: bool = True) -> str:
    """Generate a plain-text weekly learning report."""
    cutoff = datetime.now(NY) - timedelta(days=7)
    all_trades = db.get_completed_trades(paper_only=paper_only)
    week_trades = [t for t in all_trades
                   if t.get("timestamp", "") >= cutoff.strftime("%Y-%m-%dT%H:%M:%S")]

    if not week_trades:
        return "No completed trades in the last 7 days."

    lines = []
    now_str = datetime.now(NY).strftime("%B %d, %Y")
    mode = "Paper" if paper_only else "All"
    lines.append(f"═══ NQB Weekly Learning Report ({mode} Trades) — {now_str} ═══\n")

    stats = overall_stats(week_trades)
    lines.append(f"PERFORMANCE SUMMARY (last 7 days)")
    lines.append(f"  Trades completed : {stats.get('total', 0)}")
    lines.append(f"  Win rate         : {stats.get('win_rate', 0)}%  "
                 f"({stats.get('wins', 0)}W / {stats.get('losses', 0)}L)")
    lines.append(f"  Net R            : {stats.get('net_r', 0)}")
    lines.append(f"  Profit factor    : {stats.get('profit_factor') or 'N/A'}")
    lines.append(f"  Avg MFE          : {stats.get('avg_mfe_pts', 0)} pts")
    lines.append(f"  Avg MAE          : {stats.get('avg_mae_pts', 0)} pts\n")

    # Session breakdown
    sess_rows = win_rate_table("session", week_trades)
    if sess_rows:
        lines.append("SESSION PERFORMANCE")
        for r in sess_rows:
            lines.append(f"  {r['session']:<18} {r['win_rate']}%  ({r['trades']} trades)")
        lines.append("")

    # Grade breakdown
    grade_rows = win_rate_table("grade", week_trades)
    if grade_rows:
        lines.append("GRADE PERFORMANCE")
        for r in grade_rows:
            lines.append(f"  Grade {r['grade']:<4}  {r['win_rate']}%  ({r['trades']} trades)")
        lines.append("")

    # Best setups
    best = best_setups(week_trades, top_n=3)
    if best:
        lines.append("BEST SETUPS THIS WEEK")
        for s in best:
            lines.append(f"  ✓  {s['setup']}  →  {s['win_rate']}% WR  ({s['trades']} trades)")
        lines.append("")

    # Worst setups
    worst = worst_setups(week_trades, top_n=3)
    if worst:
        lines.append("SETUPS TO AVOID")
        for s in worst:
            lines.append(f"  ✗  {s['setup']}  →  {s['win_rate']}% WR  ({s['trades']} trades)")
        lines.append("")

    # Factor analysis
    factors = factor_correlation(week_trades)
    if factors:
        best_f  = factors[:3]
        worst_f = factors[-3:] if len(factors) >= 3 else []
        if best_f:
            lines.append("MOST HELPFUL CONFLUENCE FACTORS")
            for f in best_f:
                lines.append(f"  +  {f['reason'][:55]:<55}  {f['win_rate']}%  (n={f['appearances']})")
            lines.append("")
        if worst_f:
            lines.append("LEAST RELIABLE FACTORS")
            for f in worst_f:
                lines.append(f"  –  {f['reason'][:55]:<55}  {f['win_rate']}%  (n={f['appearances']})")
            lines.append("")

    # Recommendations
    lines.append("BOT RECOMMENDATIONS")
    recs = _generate_recommendations(week_trades, sess_rows, grade_rows)
    for rec in recs:
        lines.append(f"  → {rec}")

    lines.append("\n" + "─" * 60)
    lines.append("This report is generated from backtested/paper trade data.")
    lines.append("It is not financial advice.")
    return "\n".join(lines)


def _generate_recommendations(trades, sess_rows, grade_rows) -> list[str]:
    recs = []
    if not trades:
        return ["Accumulate more paper trades to generate recommendations."]

    # Session advice
    for r in sess_rows:
        if r["win_rate"] < 40 and r["trades"] >= MIN_SAMPLE:
            recs.append(f"Consider skipping {r['session']} signals (only {r['win_rate']}% WR).")
        elif r["win_rate"] >= 65 and r["trades"] >= MIN_SAMPLE:
            recs.append(f"Focus on {r['session']} — strongest win rate at {r['win_rate']}%.")

    # Grade advice
    for r in grade_rows:
        if r["win_rate"] >= 65 and r["trades"] >= MIN_SAMPLE:
            recs.append(f"Grade {r['grade']} setups are performing well ({r['win_rate']}% WR).")
        elif r["win_rate"] < 45 and r["trades"] >= MIN_SAMPLE:
            recs.append(f"Grade {r['grade']} setups are underperforming — raise filters.")

    if not recs:
        recs.append("Keep collecting data — need more trades for statistically meaningful advice.")

    return recs
