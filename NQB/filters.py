"""
NQB — Strict trade filter engine

Evaluates every signal against a configurable set of quality gates.
Returns a FilterResult explaining whether the signal is tradeable.

Hard filters (return NO TRADE):
  grade_filter        — grade not in allowed list
  rr_filter           — R:R below minimum
  session_limit       — too many trades already this session
  daily_loss_limit    — daily loss R exceeds cap
  lunch_block         — 11:30–13:30 ET (configurable)
  news_block          — high-impact event within 2 hours
  volatility_block    — ATR ratio below minimum
  choppy_block        — ADX below threshold / CHOPPY regime
  htf_conflict        — lower-TF direction conflicts with higher-TF bias
  entry_quality       — no valid pullback / no confirmation candle

Soft warnings (display in dashboard, do not block):
  low_volume          — relative volume < 0.7
  extended_session    — After Hours or Pre-Market
  session_mismatch    — strategy type not ideal for this session

User settings override all thresholds via FilterSettings.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import time as dtime, datetime
from zoneinfo import ZoneInfo

import numpy as np
import pandas as pd

import config as cfg

NY = ZoneInfo("America/New_York")


# ── Settings dataclass ────────────────────────────────────────────────────────

@dataclass
class FilterSettings:
    allowed_grades:         list[str] = field(default_factory=lambda: ["A+", "A"])
    min_rr:                 float     = 2.5
    max_trades_per_session: int       = 2
    max_daily_loss_r:       float     = 3.0
    max_losing_per_day:     int       = 2
    min_atr_ratio:          float     = 0.60
    min_adx:                float     = 18.0
    block_lunch:            bool      = True
    lunch_start:            tuple     = (11, 30)
    lunch_end:              tuple     = (13, 30)
    block_news_window_h:    float     = 1.5
    require_htf_alignment:  bool      = True
    require_pullback:       bool      = True
    require_confirmation:   bool      = True
    htf_override_score:     float     = 88.0  # if score >= this, allow even with HTF conflict


_DEFAULT_SETTINGS = FilterSettings()


# ── Result ────────────────────────────────────────────────────────────────────

@dataclass
class FilterResult:
    allowed:     bool
    reason:      str               # "No Trade — choppy market"
    warnings:    list[str] = field(default_factory=list)
    tags:        list[str] = field(default_factory=list)   # which checks ran


# ── Entry quality helpers ─────────────────────────────────────────────────────

@dataclass
class EntryQuality:
    valid:       bool
    entry_type:  str    # "FVG" | "OB" | "VWAP" | "STRUCTURE" | "CHASE"
    confirmed:   bool   # confirmation candle present
    reason:      str


def check_entry_quality(sig, df: pd.DataFrame) -> EntryQuality:
    """
    Check whether price is in a valid entry zone (not chasing) and whether
    the last candle confirms direction.
    """
    if df is None or len(df) < 3:
        return EntryQuality(True, "UNKNOWN", True, "")

    last  = df.iloc[-1]
    prev  = df.iloc[-2]
    price = float(last["close"])
    atr   = float(last["atr"]) if "atr" in df.columns else 0.0
    is_long = "BUY" in sig.signal

    # ── Confirmation candle ─────────────────────────────────────────────────
    bar_range = float(last["high"]) - float(last["low"])
    if bar_range > 0:
        if is_long:
            close_pct = (price - float(last["low"])) / bar_range
            confirmed = close_pct >= 0.60  # closed in top 40% of range
        else:
            close_pct = (float(last["high"]) - price) / bar_range
            confirmed = close_pct >= 0.60  # closed in bottom 40% of range
    else:
        confirmed = False

    # ── Pullback / entry zone checks ────────────────────────────────────────

    # 1. FVG zone
    fvg_bull_low  = float(last.get("fvg_bull_low",  np.nan) or np.nan) if "fvg_bull_low"  in df.columns else np.nan
    fvg_bull_high = float(last.get("fvg_bull_high", np.nan) or np.nan) if "fvg_bull_high" in df.columns else np.nan
    fvg_bear_low  = float(last.get("fvg_bear_low",  np.nan) or np.nan) if "fvg_bear_low"  in df.columns else np.nan
    fvg_bear_high = float(last.get("fvg_bear_high", np.nan) or np.nan) if "fvg_bear_high" in df.columns else np.nan

    if is_long and not np.isnan(fvg_bull_low) and fvg_bull_low <= price <= fvg_bull_high:
        return EntryQuality(True, "FVG", confirmed, "price inside bullish FVG")
    if not is_long and not np.isnan(fvg_bear_low) and fvg_bear_low <= price <= fvg_bear_high:
        return EntryQuality(True, "FVG", confirmed, "price inside bearish FVG")

    # 2. VWAP proximity
    vwap = float(last.get("vwap", 0) or 0) if "vwap" in df.columns else 0.0
    if vwap > 0 and atr > 0:
        if abs(price - vwap) <= 0.3 * atr:
            return EntryQuality(True, "VWAP", confirmed, "price near VWAP")

    # 3. Order-block proximity (reuse bb_mid as a proxy for mean)
    bb_mid = float(last.get("bb_mid", 0) or 0) if "bb_mid" in df.columns else 0.0
    ema_mid = float(last.get("ema_mid", 0) or 0) if "ema_mid" in df.columns else 0.0
    if atr > 0 and ema_mid > 0:
        if abs(price - ema_mid) <= 0.4 * atr:
            return EntryQuality(True, "STRUCTURE", confirmed, "price near EMA21 structure")

    # 4. Pullback check — has price retraced from recent extreme?
    n_bars = min(10, len(df))
    if is_long:
        recent_high = float(df["high"].iloc[-n_bars:].max())
        pullback    = recent_high - price
        if pullback >= 0.25 * atr:
            return EntryQuality(True, "STRUCTURE", confirmed, f"pulled back {pullback:.1f} pts from recent high")
        # Chase: price is at or very near the recent high
        return EntryQuality(False, "CHASE", confirmed, "no pullback — avoid chasing breakout")
    else:
        recent_low = float(df["low"].iloc[-n_bars:].min())
        bounce     = price - recent_low
        if bounce >= 0.25 * atr:
            return EntryQuality(True, "STRUCTURE", confirmed, f"bounced {bounce:.1f} pts from recent low")
        return EntryQuality(False, "CHASE", confirmed, "no pullback — avoid chasing breakdown")


# ── Session trade counter ─────────────────────────────────────────────────────

def _session_trade_count() -> int:
    """Count A/A+ trades logged to DB in the current session window."""
    try:
        import database as db
        from datetime import timedelta
        now     = datetime.now(NY)
        sess_start = now.replace(hour=0, minute=0, second=0)  # midnight fallback
        for name, start_hm, end_hm, _, _ in cfg.SESSIONS:
            s = now.replace(hour=start_hm[0], minute=start_hm[1], second=0)
            e = now.replace(hour=end_hm[0],   minute=end_hm[1],   second=0)
            if s <= now < e:
                sess_start = s
                break
        trades = db.get_all_signals(limit=50)
        return sum(
            1 for t in trades
            if t.get("timestamp", "") >= sess_start.strftime("%Y-%m-%dT%H:%M:%S")
            and t.get("grade") in ("A+", "A")
            and t.get("paper_trade", 0) == 0
        )
    except Exception:
        return 0


def _daily_loss_r() -> float:
    """Return total R lost today from the DB outcomes."""
    try:
        import database as db
        from datetime import timedelta
        today = datetime.now(NY).strftime("%Y-%m-%d")
        trades = db.get_completed_trades()
        return abs(sum(
            t.get("pnl_r", 0) or 0
            for t in trades
            if t.get("timestamp", "").startswith(today)
            and t.get("outcome") == "LOSS"
        ))
    except Exception:
        return 0.0


def _losing_trades_today() -> int:
    try:
        import database as db
        today = datetime.now(NY).strftime("%Y-%m-%d")
        trades = db.get_completed_trades()
        return sum(
            1 for t in trades
            if t.get("timestamp", "").startswith(today)
            and t.get("outcome") == "LOSS"
        )
    except Exception:
        return 0


# ── Main filter ───────────────────────────────────────────────────────────────

def evaluate(sig, df: pd.DataFrame | None, context,
             settings: FilterSettings | None = None) -> FilterResult:
    """
    Run all filters against a signal.
    sig: TradeSignal
    df: OHLCV + indicators for the signal's timeframe
    context: MarketContext
    """
    s    = settings or _DEFAULT_SETTINGS
    tags = []
    warnings = []
    now  = datetime.now(NY).time()

    # ── 1. Grade filter ───────────────────────────────────────────────────────
    tags.append("grade")
    grade = getattr(sig, "grade", "") or ""
    if grade not in s.allowed_grades:
        return FilterResult(False,
            f"No Trade — grade {grade or 'ungraded'} not in allowed list "
            f"({', '.join(s.allowed_grades)})", warnings, tags)

    # ── 2. R:R filter ─────────────────────────────────────────────────────────
    tags.append("rr")
    if sig.risk_reward < s.min_rr:
        return FilterResult(False,
            f"No Trade — R:R {sig.risk_reward:.2f}× below minimum {s.min_rr:.1f}×",
            warnings, tags)

    # ── 3. Lunch block ────────────────────────────────────────────────────────
    tags.append("lunch")
    if s.block_lunch:
        ls = dtime(*s.lunch_start)
        le = dtime(*s.lunch_end)
        if ls <= now < le:
            return FilterResult(False,
                f"No Trade — lunch chop hours "
                f"({s.lunch_start[0]:02d}:{s.lunch_start[1]:02d}–"
                f"{s.lunch_end[0]:02d}:{s.lunch_end[1]:02d} ET)",
                warnings, tags)

    # ── 4. News block ─────────────────────────────────────────────────────────
    tags.append("news")
    try:
        import news as news_mod
        events = news_mod.get_upcoming_events(hours_ahead=s.block_news_window_h)
        if events:
            return FilterResult(False,
                f"No Trade — news risk: {events[0]['title']} at {events[0]['date_str']}",
                warnings, tags)
    except Exception:
        pass

    # ── 5. Volatility block ───────────────────────────────────────────────────
    tags.append("volatility")
    if context is not None:
        if context.atr_ratio < s.min_atr_ratio:
            return FilterResult(False,
                f"No Trade — low volatility (ATR {context.atr_ratio:.2f}× avg, "
                f"need ≥{s.min_atr_ratio:.2f}×)",
                warnings, tags)

    # ── 6. Choppy / low-ADX block ─────────────────────────────────────────────
    tags.append("regime")
    if context is not None:
        if context.regime == "CHOPPY":
            return FilterResult(False,
                f"No Trade — choppy market (ADX {context.adx:.0f}, "
                f"no clear structure)", warnings, tags)
        if context.regime == "LOW_VOL":
            return FilterResult(False,
                "No Trade — low volatility compression (ATR below threshold)",
                warnings, tags)
        if context.adx < s.min_adx and context.regime not in ("TRENDING_BULL", "TRENDING_BEAR"):
            return FilterResult(False,
                f"No Trade — insufficient trend strength (ADX {context.adx:.0f} "
                f"< {s.min_adx:.0f})",
                warnings, tags)

    # ── 7. HTF bias conflict ──────────────────────────────────────────────────
    tags.append("htf")
    if s.require_htf_alignment and context is not None:
        htf_bias  = context.htf_bias
        sig_is_long  = "BUY"  in sig.signal and "NEUTRAL" not in sig.signal
        sig_is_short = "SELL" in sig.signal and "NEUTRAL" not in sig.signal
        confluence   = max(sig.bull_score, sig.bear_score)
        strong_enough = confluence >= s.htf_override_score

        if htf_bias == "BEAR" and sig_is_long and not strong_enough:
            return FilterResult(False,
                f"No Trade — HTF bias is BEARISH; only STRONG longs with score "
                f"≥{s.htf_override_score:.0f} allowed (score: {confluence:.0f})",
                warnings, tags)
        if htf_bias == "BULL" and sig_is_short and not strong_enough:
            return FilterResult(False,
                f"No Trade — HTF bias is BULLISH; only STRONG shorts with score "
                f"≥{s.htf_override_score:.0f} allowed (score: {confluence:.0f})",
                warnings, tags)

    # ── 8. Session trade limit ────────────────────────────────────────────────
    tags.append("session_limit")
    sess_count = _session_trade_count()
    if sess_count >= s.max_trades_per_session:
        return FilterResult(False,
            f"No Trade — max {s.max_trades_per_session} trades per session reached "
            f"({sess_count} so far)",
            warnings, tags)

    # ── 9. Daily loss limit ───────────────────────────────────────────────────
    tags.append("daily_limit")
    daily_loss = _daily_loss_r()
    if daily_loss >= s.max_daily_loss_r:
        return FilterResult(False,
            f"No Trade — daily loss limit reached ({daily_loss:.1f}R of "
            f"{s.max_daily_loss_r:.1f}R max)",
            warnings, tags)
    losing_today = _losing_trades_today()
    if losing_today >= s.max_losing_per_day:
        return FilterResult(False,
            f"No Trade — max losing trades today reached ({losing_today})",
            warnings, tags)

    # ── 10. Entry quality ─────────────────────────────────────────────────────
    tags.append("entry_quality")
    if s.require_pullback and df is not None and "NEUTRAL" not in sig.signal:
        eq = check_entry_quality(sig, df)
        if s.require_pullback and not eq.valid:
            return FilterResult(False,
                f"No Trade — {eq.reason}",
                warnings, tags)
        if s.require_confirmation and not eq.confirmed:
            warnings.append(f"Weak confirmation candle ({eq.reason})")

    # ── Soft warnings (don't block) ───────────────────────────────────────────
    if context is not None:
        if context.regime == "RANGING":
            warnings.append("Market is RANGING — mean-reversion setups only")
        if context.regime == "VOLATILE":
            warnings.append("Elevated volatility — widen stops or reduce size")
        if context.atr_ratio < 0.8:
            warnings.append("ATR below average — lower momentum than usual")

    rel_vol = float(df["rel_volume"].iloc[-1]) if df is not None and "rel_volume" in df.columns else 1.0
    if not (rel_vol != rel_vol) and rel_vol < 0.7:  # NaN-safe
        warnings.append(f"Low relative volume ({rel_vol:.1f}×) — low conviction")

    return FilterResult(True, "", warnings, tags)
