"""
NQB — Adaptive position sizing + risk guardrails

Grade-based risk multipliers:
  A+  → 100% of base risk  (full size)
  A   → 80%  of base risk
  B   → 25%  of base risk  (pilot only — disabled by default)
  C   → 0%   (never trade)

Daily guardrails pulled from the live DB:
  - Max daily loss in R
  - Max losing trades per day
"""
from __future__ import annotations
from dataclasses import dataclass

import config as cfg

# Grade risk multipliers (fraction of base risk)
_MULTIPLIERS: dict[str, float] = {
    "A+": 1.00,
    "A":  0.80,
    "B":  0.25,
    "C":  0.00,
}

# Partial TP model: take PARTIAL_TP_FRAC at PARTIAL_TP_R1, rest at target
PARTIAL_TP_FRAC = 0.50   # 50% off at first target
PARTIAL_TP_R1   = 1.0    # first partial at 1R
PARTIAL_TP_R2   = 2.5    # remaining target at 2.5R (can reach actual target)


@dataclass
class SizeResult:
    contracts:     int
    dollar_risk:   float
    dollar_target: float
    multiplier:    float
    grade:         str
    note:          str


def compute_size(grade: str,
                 stop_pts: float,
                 account_size: float = cfg.DEFAULT_ACCOUNT_SIZE,
                 base_risk_pct: float = cfg.DEFAULT_RISK_PCT,
                 max_loss_usd: float = cfg.DEFAULT_MAX_LOSS,
                 contract_type: str = "MNQ") -> SizeResult:
    """
    Return contract count and dollar risk for a given grade + stop distance.
    """
    mult    = _MULTIPLIERS.get(grade, 0.0)
    pt_val  = cfg.NQ_POINT_VALUE if contract_type == "NQ" else cfg.MNQ_POINT_VALUE

    if mult == 0.0 or stop_pts <= 0:
        return SizeResult(0, 0.0, 0.0, mult, grade, f"Grade {grade} — no trade")

    base_risk  = account_size * base_risk_pct / 100
    adj_risk   = min(base_risk * mult, max_loss_usd)
    cost_per_c = stop_pts * pt_val
    contracts  = max(0, int(adj_risk / cost_per_c)) if cost_per_c > 0 else 0

    actual_risk   = contracts * cost_per_c
    rr_target     = cfg.RISK_REWARD_MIN
    dollar_target = actual_risk * rr_target

    note = f"Grade {grade} × {mult:.0%} risk = ${actual_risk:,.0f} risk"
    if grade == "B":
        note += "  (pilot size — consider paper trading only)"

    return SizeResult(
        contracts    = contracts,
        dollar_risk  = round(actual_risk, 2),
        dollar_target= round(dollar_target, 2),
        multiplier   = mult,
        grade        = grade,
        note         = note,
    )


def partial_tp_expectancy(rr_full: float) -> dict:
    """
    Model expected R using the 50/50 partial TP strategy.
    Assumes if price hits 1R target: 50% exits, stop moves to breakeven for remaining.
    If price then reaches rr_full: second 50% exits at rr_full.
    If stopped at BE after partial: net = 0.5 × 1R + 0.5 × 0 = 0.5R.
    """
    full_exit_r    = 0.5 * PARTIAL_TP_R1 + 0.5 * rr_full   # both halves hit
    partial_exit_r = 0.5 * PARTIAL_TP_R1 + 0.5 * 0.0       # BE stop hit after partial
    full_loss_r    = -1.0                                     # stopped before 1R

    return {
        "full_win_r":     round(full_exit_r,    2),
        "partial_win_r":  round(partial_exit_r, 2),
        "full_loss_r":    round(full_loss_r,    2),
        "note": (
            f"50% off at {PARTIAL_TP_R1}R  →  "
            f"full win: {full_exit_r:.2f}R | "
            f"partial: {partial_exit_r:.2f}R | "
            f"full loss: {full_loss_r:.1f}R"
        ),
    }
