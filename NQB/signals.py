"""
NQB Trading Bot — Signal engine

Each indicator votes +/- and a weighted confluence score (0–100) is produced.
A TradeSignal dataclass is returned for each timeframe scan.

Grades:
  A+  STRONG BUY/SELL, confluence score ≥ 80, higher-timeframe confirmed
  A   STRONG BUY/SELL, confluence score ≥ 70, higher-timeframe confirmed
  B   BUY/SELL with HTF confirmation, or STRONG without confirmation
  C   BUY/SELL without HTF confirmation
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import List
import numpy as np
import pandas as pd
import config as cfg


@dataclass
class Vote:
    name: str
    direction: str        # "BULL" | "BEAR" | "NEUTRAL"
    strength: float       # 0–1
    note: str = ""


@dataclass
class TradeSignal:
    timeframe_label: str
    price: float
    bull_score: float
    bear_score: float
    signal: str           # "STRONG BUY" | "BUY" | "NEUTRAL" | "SELL" | "STRONG SELL"
    votes: List[Vote] = field(default_factory=list)
    stop_loss: float = 0.0
    target: float = 0.0
    atr: float = 0.0
    risk_reward: float = 0.0
    grade: str = ""           # "A+" | "A" | "B" | "C" | ""
    mtf_confirmed: bool = False
    # ── Enhanced fields ───────────────────────────────────────────────────────
    stop_type: str = "ATR"          # "STRUCTURE" | "ATR"
    target_type: str = "ATR"        # "LIQUIDITY" | "ATR"
    partial_tp1: float = 0.0        # 1R exit level (50% off here)
    partial_tp2: float = 0.0        # full remaining target
    partial_rr_model: float = 0.0   # expected R using partial TP
    entry_type: str = ""            # "FVG" | "OB" | "VWAP" | "STRUCTURE" | "CHASE"
    confirmed: bool = False         # confirmation candle present
    session: str = ""               # session name when signal fired


# ── Default indicator weights ─────────────────────────────────────────────────
# The learning module (learning.py) may override these at runtime based on
# historical performance.  Call get_weights() to get the live version.
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

# Keep module-level alias for backward compat (backtest.py, display.py)
WEIGHTS = _DEFAULT_WEIGHTS


def get_weights() -> dict[str, float]:
    """Return live weights: learned if available, else defaults."""
    try:
        import learning
        w = learning.get_current_weights()
        if w and abs(sum(w.values()) - 1.0) < 0.02:
            return w
    except Exception:
        pass
    return _DEFAULT_WEIGHTS


def _safe(val) -> float:
    try:
        v = float(val)
        return v if not np.isnan(v) else np.nan
    except Exception:
        return np.nan


def _last(df: pd.DataFrame, col: str) -> float:
    if col not in df.columns:
        return np.nan
    return _safe(df[col].iloc[-1])


def _prev(df: pd.DataFrame, col: str, n: int = 1) -> float:
    if col not in df.columns or len(df) <= n:
        return np.nan
    return _safe(df[col].iloc[-(1 + n)])


def evaluate(df: pd.DataFrame, timeframe_label: str) -> TradeSignal:
    """Score the latest bar and return a TradeSignal (no HTF context)."""
    votes: List[Vote] = []
    price = _last(df, "close")
    atr   = _last(df, "atr")

    # ── 1. Trend (price vs EMA-50 and EMA-200) ───────────────────────────────
    ema_slow  = _last(df, "ema_slow")
    ema_trend = _last(df, "ema_trend")
    slope     = _last(df, "ema_slow_slope")
    if not any(np.isnan(v) for v in [price, ema_slow, ema_trend]):
        bull = (price > ema_slow) and (price > ema_trend) and (slope > 0)
        bear = (price < ema_slow) and (price < ema_trend) and (slope < 0)
        if bull:
            votes.append(Vote("trend_ema", "BULL", 1.0, f"price {price:.0f} > EMA50 {ema_slow:.0f} & EMA200 {ema_trend:.0f}"))
        elif bear:
            votes.append(Vote("trend_ema", "BEAR", 1.0, f"price {price:.0f} < EMA50 {ema_slow:.0f} & EMA200 {ema_trend:.0f}"))
        else:
            bull_pts = sum([price > ema_slow, price > ema_trend, slope > 0])
            bear_pts = sum([price < ema_slow, price < ema_trend, slope < 0])
            if bull_pts > bear_pts:
                votes.append(Vote("trend_ema", "BULL", bull_pts / 3, "mixed bullish trend"))
            elif bear_pts > bull_pts:
                votes.append(Vote("trend_ema", "BEAR", bear_pts / 3, "mixed bearish trend"))
            else:
                votes.append(Vote("trend_ema", "NEUTRAL", 0.0, "no clear trend"))
    else:
        votes.append(Vote("trend_ema", "NEUTRAL", 0.0, "insufficient data"))

    # ── 2. EMA stack ─────────────────────────────────────────────────────────
    ema_fast = _last(df, "ema_fast")
    ema_mid  = _last(df, "ema_mid")
    if not any(np.isnan(v) for v in [ema_fast, ema_mid, ema_slow]):
        if ema_fast > ema_mid > ema_slow:
            votes.append(Vote("ema_stack", "BULL", 1.0, "EMA9 > EMA21 > EMA50"))
        elif ema_fast < ema_mid < ema_slow:
            votes.append(Vote("ema_stack", "BEAR", 1.0, "EMA9 < EMA21 < EMA50"))
        else:
            prev_fast = _prev(df, "ema_fast")
            prev_mid  = _prev(df, "ema_mid")
            if not np.isnan(prev_fast) and not np.isnan(prev_mid):
                if prev_fast < prev_mid and ema_fast > ema_mid:
                    votes.append(Vote("ema_stack", "BULL", 0.9, "EMA9 just crossed above EMA21 (golden cross)"))
                elif prev_fast > prev_mid and ema_fast < ema_mid:
                    votes.append(Vote("ema_stack", "BEAR", 0.9, "EMA9 just crossed below EMA21 (death cross)"))
                else:
                    votes.append(Vote("ema_stack", "NEUTRAL", 0.0, "EMAs converging"))
            else:
                votes.append(Vote("ema_stack", "NEUTRAL", 0.0, "EMA stack mixed"))

    # ── 3. MACD ───────────────────────────────────────────────────────────────
    macd      = _last(df, "macd")
    macd_sig  = _last(df, "macd_signal")
    macd_hist = _last(df, "macd_hist")
    prev_hist = _prev(df, "macd_hist")
    if not any(np.isnan(v) for v in [macd, macd_sig, macd_hist]):
        bull_cross = macd > macd_sig and (not np.isnan(prev_hist) and prev_hist < 0 <= macd_hist)
        bear_cross = macd < macd_sig and (not np.isnan(prev_hist) and prev_hist > 0 >= macd_hist)
        if bull_cross:
            votes.append(Vote("macd", "BULL", 1.0, "MACD bullish crossover"))
        elif bear_cross:
            votes.append(Vote("macd", "BEAR", 1.0, "MACD bearish crossover"))
        elif macd > macd_sig and macd_hist > 0:
            strength = min(abs(macd_hist) / max(abs(macd), 1e-9), 1.0)
            votes.append(Vote("macd", "BULL", max(0.5, strength), f"MACD above signal (hist={macd_hist:.1f})"))
        elif macd < macd_sig and macd_hist < 0:
            strength = min(abs(macd_hist) / max(abs(macd), 1e-9), 1.0)
            votes.append(Vote("macd", "BEAR", max(0.5, strength), f"MACD below signal (hist={macd_hist:.1f})"))
        else:
            votes.append(Vote("macd", "NEUTRAL", 0.0, "MACD inconclusive"))
    else:
        votes.append(Vote("macd", "NEUTRAL", 0.0, "MACD data unavailable"))

    # ── 4. RSI ────────────────────────────────────────────────────────────────
    rsi = _last(df, "rsi")
    if not np.isnan(rsi):
        if rsi <= cfg.RSI_OVERSOLD:
            votes.append(Vote("rsi", "BULL", 1.0, f"RSI oversold ({rsi:.1f})"))
        elif rsi >= cfg.RSI_OVERBOUGHT:
            votes.append(Vote("rsi", "BEAR", 1.0, f"RSI overbought ({rsi:.1f})"))
        elif rsi < 50:
            strength = (50 - rsi) / (50 - cfg.RSI_OVERSOLD)
            votes.append(Vote("rsi", "BEAR", strength * 0.7, f"RSI bearish momentum ({rsi:.1f})"))
        else:
            strength = (rsi - 50) / (cfg.RSI_OVERBOUGHT - 50)
            votes.append(Vote("rsi", "BULL", strength * 0.7, f"RSI bullish momentum ({rsi:.1f})"))
    else:
        votes.append(Vote("rsi", "NEUTRAL", 0.0, "RSI data unavailable"))

    # ── 5. Bollinger Bands ────────────────────────────────────────────────────
    bb_pct   = _last(df, "bb_pct")
    bb_upper = _last(df, "bb_upper")
    bb_lower = _last(df, "bb_lower")
    if not any(np.isnan(v) for v in [bb_pct, bb_upper, bb_lower]):
        if bb_pct <= 0.05:
            votes.append(Vote("bb", "BULL", 1.0, f"price at/below lower BB ({price:.0f} ≈ {bb_lower:.0f})"))
        elif bb_pct >= 0.95:
            votes.append(Vote("bb", "BEAR", 1.0, f"price at/above upper BB ({price:.0f} ≈ {bb_upper:.0f})"))
        elif bb_pct < 0.4:
            votes.append(Vote("bb", "BULL", 0.5, f"price in lower half of BB (pct={bb_pct:.2f})"))
        elif bb_pct > 0.6:
            votes.append(Vote("bb", "BEAR", 0.5, f"price in upper half of BB (pct={bb_pct:.2f})"))
        else:
            votes.append(Vote("bb", "NEUTRAL", 0.0, "price mid-range inside BB"))
    else:
        votes.append(Vote("bb", "NEUTRAL", 0.0, "BB data unavailable"))

    # ── 6. Stochastic RSI ─────────────────────────────────────────────────────
    sk      = _last(df, "stoch_k")
    sd      = _last(df, "stoch_d")
    prev_sk = _prev(df, "stoch_k")
    prev_sd = _prev(df, "stoch_d")
    if not any(np.isnan(v) for v in [sk, sd]):
        bull_cross = sk > sd and (not np.isnan(prev_sk) and not np.isnan(prev_sd) and prev_sk <= prev_sd)
        bear_cross = sk < sd and (not np.isnan(prev_sk) and not np.isnan(prev_sd) and prev_sk >= prev_sd)
        if bull_cross and sk < 20:
            votes.append(Vote("stoch_rsi", "BULL", 1.0, f"StochRSI bullish cross from oversold (K={sk:.1f})"))
        elif bear_cross and sk > 80:
            votes.append(Vote("stoch_rsi", "BEAR", 1.0, f"StochRSI bearish cross from overbought (K={sk:.1f})"))
        elif sk < 20:
            votes.append(Vote("stoch_rsi", "BULL", 0.7, f"StochRSI oversold (K={sk:.1f})"))
        elif sk > 80:
            votes.append(Vote("stoch_rsi", "BEAR", 0.7, f"StochRSI overbought (K={sk:.1f})"))
        elif sk > sd:
            votes.append(Vote("stoch_rsi", "BULL", 0.4, f"StochRSI K > D ({sk:.1f} > {sd:.1f})"))
        elif sk < sd:
            votes.append(Vote("stoch_rsi", "BEAR", 0.4, f"StochRSI K < D ({sk:.1f} < {sd:.1f})"))
        else:
            votes.append(Vote("stoch_rsi", "NEUTRAL", 0.0, "StochRSI neutral"))
    else:
        votes.append(Vote("stoch_rsi", "NEUTRAL", 0.0, "StochRSI data unavailable"))

    # ── 7. VWAP ───────────────────────────────────────────────────────────────
    vwap = _last(df, "vwap")
    if not np.isnan(vwap) and vwap > 0:
        dist_pct = (price - vwap) / vwap * 100
        if price > vwap:
            votes.append(Vote("vwap", "BULL", min(abs(dist_pct) / 0.5, 1.0), f"price above VWAP by {dist_pct:.2f}%"))
        else:
            votes.append(Vote("vwap", "BEAR", min(abs(dist_pct) / 0.5, 1.0), f"price below VWAP by {abs(dist_pct):.2f}%"))
    else:
        votes.append(Vote("vwap", "NEUTRAL", 0.0, "VWAP unavailable (daily TF)"))

    # ── 8. Relative Volume ────────────────────────────────────────────────────
    rel_vol = _last(df, "rel_volume")
    if not np.isnan(rel_vol):
        if rel_vol >= 1.5:
            last_bull = _last(df, "close") > _last(df, "open")
            direction = "BULL" if last_bull else "BEAR"
            votes.append(Vote("rel_volume", direction, min((rel_vol - 1) / 1.0, 1.0),
                              f"relative volume {rel_vol:.1f}x confirms move"))
        else:
            votes.append(Vote("rel_volume", "NEUTRAL", 0.0, f"rel volume {rel_vol:.1f}x (normal)"))
    else:
        votes.append(Vote("rel_volume", "NEUTRAL", 0.0, "volume data unavailable"))

    # ── Score aggregation (uses live learned weights) ─────────────────────────
    live_weights = get_weights()
    bull_score = 0.0
    bear_score = 0.0
    for v in votes:
        w = live_weights.get(v.name, 0.0)
        if v.direction == "BULL":
            bull_score += w * v.strength * 100
        elif v.direction == "BEAR":
            bear_score += w * v.strength * 100

    net = bull_score - bear_score
    if net >= cfg.STRONG_BUY_THRESHOLD:
        signal = "STRONG BUY"
    elif net >= cfg.BUY_THRESHOLD:
        signal = "BUY"
    elif net <= -cfg.STRONG_SELL_THRESHOLD:
        signal = "STRONG SELL"
    elif net <= -cfg.SELL_THRESHOLD:
        signal = "SELL"
    else:
        signal = "NEUTRAL"

    # ── Risk / reward levels ──────────────────────────────────────────────────
    stop = target = rr = 0.0
    if not np.isnan(atr) and atr > 0:
        if "BUY" in signal:
            stop   = price - atr * cfg.ATR_STOP_MULTIPLIER
            target = price + atr * cfg.ATR_TARGET_MULTIPLIER
        elif "SELL" in signal:
            stop   = price + atr * cfg.ATR_STOP_MULTIPLIER
            target = price - atr * cfg.ATR_TARGET_MULTIPLIER
        risk   = abs(price - stop)
        reward = abs(price - target)
        rr = reward / risk if risk > 0 else 0.0

    return TradeSignal(
        timeframe_label=timeframe_label,
        price=price,
        bull_score=round(bull_score, 1),
        bear_score=round(bear_score, 1),
        signal=signal,
        votes=votes,
        stop_loss=round(stop, 2),
        target=round(target, 2),
        atr=round(atr, 2) if not np.isnan(atr) else 0.0,
        risk_reward=round(rr, 2),
    )


def add_grade(sig: TradeSignal, htf_sig: TradeSignal | None = None) -> TradeSignal:
    """
    Assign a grade to a signal based on confluence score and HTF confirmation.
    Mutates sig in place and returns it.
    """
    confluence = max(sig.bull_score, sig.bear_score)

    # HTF confirmation: directions must agree (STRONG or regular)
    if htf_sig is None:
        mtf = True  # trend TF has no higher frame to check
    else:
        htf_is_bull = "BUY"  in htf_sig.signal and "NEUTRAL" not in htf_sig.signal
        htf_is_bear = "SELL" in htf_sig.signal and "NEUTRAL" not in htf_sig.signal
        sig_is_bull = "BUY"  in sig.signal
        sig_is_bear = "SELL" in sig.signal
        mtf = (sig_is_bull and htf_is_bull) or (sig_is_bear and htf_is_bear)

    sig.mtf_confirmed = mtf

    if "NEUTRAL" in sig.signal:
        sig.grade = ""
    elif "STRONG" in sig.signal and confluence >= 80 and mtf:
        sig.grade = "A+"
    elif "STRONG" in sig.signal and confluence >= 70 and mtf:
        sig.grade = "A"
    elif ("BUY" in sig.signal or "SELL" in sig.signal) and mtf:
        sig.grade = "B"
    else:
        sig.grade = "C"

    return sig


def enhance_signal(sig: TradeSignal, df: pd.DataFrame) -> TradeSignal:
    """
    Upgrade stop/target to structure-based levels and add partial TP.
    Mutates and returns sig.
    """
    if "NEUTRAL" in sig.signal or df is None or len(df) < 20:
        return sig

    is_long = "BUY" in sig.signal
    price   = sig.price
    atr     = sig.atr or 1.0

    # ── Structure-based stop ─────────────────────────────────────────────────
    try:
        import liquidity as liq
        sh, sl = liq.swing_points(df.iloc[-60:], left=3, right=3)

        if is_long and not sl.empty:
            candidates = sl[sl["level"] < price - 0.1 * atr]
            if not candidates.empty:
                struct_stop = float(candidates["level"].iloc[-1]) - 0.15 * atr
                struct_risk = abs(price - struct_stop)
                if struct_risk > 0 and struct_stop > price - 4 * atr:
                    sig.stop_loss = round(struct_stop, 2)
                    sig.stop_type = "STRUCTURE"

        elif not is_long and not sh.empty:
            candidates = sh[sh["level"] > price + 0.1 * atr]
            if not candidates.empty:
                struct_stop = float(candidates["level"].iloc[-1]) + 0.15 * atr
                struct_risk = abs(price - struct_stop)
                if struct_risk > 0 and struct_stop < price + 4 * atr:
                    sig.stop_loss = round(struct_stop, 2)
                    sig.stop_type = "STRUCTURE"
    except Exception:
        pass

    # ── Liquidity-based target ────────────────────────────────────────────────
    try:
        import liquidity as liq
        sh, sl = liq.swing_points(df.iloc[-60:], left=3, right=3)
        risk   = abs(price - sig.stop_loss) if sig.stop_loss else atr * cfg.ATR_STOP_MULTIPLIER

        if is_long and not sh.empty:
            liq_targets = sh[sh["level"] > price + 2.0 * risk]
            if not liq_targets.empty:
                liq_t = float(liq_targets["level"].iloc[0])
                if risk > 0 and abs(liq_t - price) / risk >= cfg.RISK_REWARD_MIN:
                    sig.target      = round(liq_t - 0.1 * atr, 2)
                    sig.target_type = "LIQUIDITY"
        elif not is_long and not sl.empty:
            liq_targets = sl[sl["level"] < price - 2.0 * risk]
            if not liq_targets.empty:
                liq_t = float(liq_targets["level"].iloc[-1])
                if risk > 0 and abs(liq_t - price) / risk >= cfg.RISK_REWARD_MIN:
                    sig.target      = round(liq_t + 0.1 * atr, 2)
                    sig.target_type = "LIQUIDITY"
    except Exception:
        pass

    # ── Enforce minimum 2.5R ──────────────────────────────────────────────────
    risk = abs(price - sig.stop_loss) if sig.stop_loss else atr
    if risk > 0:
        min_dist = risk * cfg.RISK_REWARD_MIN
        if is_long:
            sig.target = max(sig.target or 0, round(price + min_dist, 2))
        else:
            sig.target = min(sig.target or 999999, round(price - min_dist, 2))
        sig.risk_reward = round(abs(price - sig.target) / risk, 2)

    # ── Partial take-profit levels ────────────────────────────────────────────
    risk = abs(price - sig.stop_loss) if sig.stop_loss else atr
    if risk > 0:
        sig.partial_tp1      = round(price + risk * 1.0, 2) if is_long else round(price - risk * 1.0, 2)
        sig.partial_tp2      = sig.target
        sig.partial_rr_model = round(0.5 * 1.0 + 0.5 * sig.risk_reward, 2)

    # ── Entry quality ─────────────────────────────────────────────────────────
    try:
        from filters import check_entry_quality
        eq             = check_entry_quality(sig, df)
        sig.entry_type = eq.entry_type
        sig.confirmed  = eq.confirmed
    except Exception:
        pass

    return sig
