"""
NQB — Market regime classifier

Classifies current market conditions into one of five regimes:
  TRENDING_BULL  — strong uptrend, fanned EMAs, ADX > 25
  TRENDING_BEAR  — strong downtrend
  RANGING        — orderly oscillation between support/resistance, ADX 15–25
  CHOPPY         — low ADX, frequent direction changes, no structure
  VOLATILE       — any regime with ATR ratio > 1.8 (elevated volatility)
  LOW_VOL        — ATR ratio < 0.55 (compressed, avoid breakout trades)

Each regime lists which strategy types are suitable.
"""
from __future__ import annotations
from dataclasses import dataclass, field

import numpy as np
import pandas as pd


@dataclass
class MarketContext:
    regime:             str               # one of the keys above
    trend_direction:    str               # "BULL" | "BEAR" | "NEUTRAL"
    adx:                float
    atr_ratio:          float             # current ATR / 20-bar rolling ATR
    volatility_pct:     float             # ATR as % of close price
    suitable_strategies: list[str] = field(default_factory=list)
    description:        str = ""
    htf_bias:           str = "NEUTRAL"   # from HTF signal, used by filter


def classify(df: pd.DataFrame,
             htf_signal_direction: str = "NEUTRAL") -> MarketContext:
    """
    Classify the market regime for the last bar of df.
    df must already have indicators added (add_all called).
    htf_signal_direction: "BULL" | "BEAR" | "NEUTRAL" from the higher TF.
    """
    def last(col: str) -> float:
        if col not in df.columns:
            return np.nan
        v = df[col].iloc[-1]
        return float(v) if not (isinstance(v, float) and np.isnan(v)) else np.nan

    adx       = last("adx")       or 20.0
    atr       = last("atr")       or 1.0
    atr_ratio = last("atr_ratio") or 1.0
    close     = last("close")     or 1.0
    ema_fast  = last("ema_fast")
    ema_mid   = last("ema_mid")
    ema_slow  = last("ema_slow")
    ema_trend = last("ema_trend")
    slope     = last("ema_slow_slope") or 0.0

    vol_pct   = round(atr / close * 100, 3) if close else 0.0

    # ── Trend direction from EMA alignment ───────────────────────────────────
    emas_ok = all(v is not np.nan and not (isinstance(v, float) and np.isnan(v))
                  for v in [ema_fast, ema_mid, ema_slow, ema_trend])
    if emas_ok:
        bull_stack = ema_fast > ema_mid > ema_slow
        bear_stack = ema_fast < ema_mid < ema_slow
        price_above_trend = close > ema_trend
    else:
        bull_stack = bear_stack = price_above_trend = False

    # ── Choppiness: how many times VWAP was crossed in last 20 bars ──────────
    vwap_crosses = 0
    if "vwap" in df.columns and len(df) >= 22:
        recent = df.iloc[-22:].copy()
        above  = recent["close"] > recent["vwap"]
        vwap_crosses = int((above.diff().abs()).sum())

    # ── Classify ─────────────────────────────────────────────────────────────
    trend_dir = "NEUTRAL"
    if bull_stack and price_above_trend and slope > 0:
        trend_dir = "BULL"
    elif bear_stack and not price_above_trend and slope < 0:
        trend_dir = "BEAR"
    elif bull_stack:
        trend_dir = "BULL"
    elif bear_stack:
        trend_dir = "BEAR"

    if atr_ratio < 0.55:
        regime      = "LOW_VOL"
        strategies  = []
        description = "Compressed volatility — breakouts unreliable, wait for expansion"

    elif atr_ratio > 1.8:
        regime      = "VOLATILE"
        strategies  = ["momentum"] if trend_dir != "NEUTRAL" else []
        description = f"Elevated volatility (ATR {atr_ratio:.1f}× avg) — widen stops, reduce size"

    elif adx >= 25 and trend_dir in ("BULL", "BEAR"):
        regime      = f"TRENDING_{trend_dir}"
        strategies  = ["momentum", "breakout", "continuation"]
        description = f"Strong {trend_dir.lower()} trend (ADX {adx:.0f}) — favor {trend_dir.lower()} setups"

    elif adx >= 15 and vwap_crosses <= 3:
        regime      = "RANGING"
        strategies  = ["mean_reversion"]
        description = f"Ranging market (ADX {adx:.0f}) — mean-reversion valid, avoid breakout fades"

    else:
        regime      = "CHOPPY"
        strategies  = []
        description = f"Choppy / no structure (ADX {adx:.0f}, {vwap_crosses} VWAP crosses) — no trade"

    return MarketContext(
        regime             = regime,
        trend_direction    = trend_dir,
        adx                = round(adx, 1),
        atr_ratio          = round(atr_ratio, 2),
        volatility_pct     = vol_pct,
        suitable_strategies= strategies,
        description        = description,
        htf_bias           = htf_signal_direction,
    )
