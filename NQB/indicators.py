"""
NQB Trading Bot — Technical indicators (pure pandas/numpy, no pandas-ta)
"""

import pandas as pd
import numpy as np
import config as cfg


# ── Helpers ───────────────────────────────────────────────────────────────────

def _ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def _rma(series: pd.Series, period: int) -> pd.Series:
    """Wilder's RMA (used by ATR)."""
    return series.ewm(alpha=1 / period, adjust=False).mean()


def _atr(high: pd.Series, low: pd.Series, close: pd.Series, period: int) -> pd.Series:
    prev_close = close.shift(1)
    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low  - prev_close).abs(),
    ], axis=1).max(axis=1)
    return _rma(tr, period)


def _rsi(series: pd.Series, period: int) -> pd.Series:
    delta = series.diff()
    gain  = delta.clip(lower=0)
    loss  = (-delta).clip(lower=0)
    avg_gain = _rma(gain, period)
    avg_loss = _rma(loss, period)
    rs = avg_gain / avg_loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def _macd(series: pd.Series, fast: int, slow: int, signal: int):
    ema_fast   = _ema(series, fast)
    ema_slow   = _ema(series, slow)
    macd_line  = ema_fast - ema_slow
    signal_line = _ema(macd_line, signal)
    histogram  = macd_line - signal_line
    return macd_line, signal_line, histogram


def _bbands(series: pd.Series, period: int, std_dev: float):
    mid   = series.rolling(period).mean()
    sigma = series.rolling(period).std(ddof=0)
    upper = mid + std_dev * sigma
    lower = mid - std_dev * sigma
    pct   = (series - lower) / (upper - lower).replace(0, np.nan)
    return lower, mid, upper, pct


def _stochrsi(series: pd.Series, rsi_period: int, k: int, d: int) -> tuple:
    rsi   = _rsi(series, rsi_period)
    lo    = rsi.rolling(rsi_period).min()
    hi    = rsi.rolling(rsi_period).max()
    stoch = (rsi - lo) / (hi - lo).replace(0, np.nan) * 100
    k_line = stoch.rolling(k).mean()
    d_line = k_line.rolling(d).mean()
    return k_line, d_line


def _vwap(high: pd.Series, low: pd.Series, close: pd.Series, volume: pd.Series) -> pd.Series:
    typical = (high + low + close) / 3
    cum_tpv = (typical * volume).cumsum()
    cum_vol = volume.cumsum()
    return cum_tpv / cum_vol.replace(0, np.nan)


# ── Main builder ──────────────────────────────────────────────────────────────

def add_all(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    close = df["close"]
    high  = df["high"]
    low   = df["low"]
    vol   = df["volume"]

    # EMAs
    df["ema_fast"]  = _ema(close, cfg.EMA_FAST)
    df["ema_mid"]   = _ema(close, cfg.EMA_MID)
    df["ema_slow"]  = _ema(close, cfg.EMA_SLOW)
    df["ema_trend"] = _ema(close, cfg.EMA_TREND)

    # RSI
    df["rsi"] = _rsi(close, cfg.RSI_PERIOD)

    # MACD
    macd, macd_sig, macd_hist = _macd(close, cfg.MACD_FAST, cfg.MACD_SLOW, cfg.MACD_SIGNAL)
    df["macd"]        = macd
    df["macd_signal"] = macd_sig
    df["macd_hist"]   = macd_hist

    # Bollinger Bands
    bb_lower, bb_mid, bb_upper, bb_pct = _bbands(close, cfg.BB_PERIOD, cfg.BB_STD)
    df["bb_lower"] = bb_lower
    df["bb_mid"]   = bb_mid
    df["bb_upper"] = bb_upper
    df["bb_pct"]   = bb_pct

    # ATR
    df["atr"] = _atr(high, low, close, cfg.ATR_PERIOD)

    # Stochastic RSI
    sk, sd = _stochrsi(close, cfg.RSI_PERIOD, cfg.STOCH_K, cfg.STOCH_D)
    df["stoch_k"] = sk
    df["stoch_d"] = sd

    # VWAP
    df["vwap"] = _vwap(high, low, close, vol)

    # Relative volume
    df["vol_sma20"]  = vol.rolling(20).mean()
    df["rel_volume"] = vol / df["vol_sma20"].replace(0, np.nan)

    # EMA-50 slope
    df["ema_slow_slope"] = df["ema_slow"].diff(3) / 3

    # ATR ratio (current vs 20-bar rolling mean — regime signal)
    df["atr_avg20"]   = df["atr"].rolling(20).mean()
    df["atr_ratio"]   = df["atr"] / df["atr_avg20"].replace(0, np.nan)

    # ADX + DI lines (Wilder's, period=14)
    adx_s, pdi, mdi  = _adx(high, low, close, cfg.ATR_PERIOD)
    df["adx"]         = adx_s
    df["plus_di"]     = pdi
    df["minus_di"]    = mdi

    # Fair Value Gaps
    df["fvg_bull_low"]  = np.nan   # price zone to enter a long FVG
    df["fvg_bull_high"] = np.nan
    df["fvg_bear_low"]  = np.nan   # price zone to enter a short FVG
    df["fvg_bear_high"] = np.nan
    _mark_fvgs(df)

    return df


# ── ADX (Wilder's Average Directional Index) ──────────────────────────────────

def _adx(high: pd.Series, low: pd.Series, close: pd.Series,
          period: int = 14) -> tuple[pd.Series, pd.Series, pd.Series]:
    prev_high  = high.shift(1)
    prev_low   = low.shift(1)
    prev_close = close.shift(1)

    up_move   = high - prev_high
    down_move = prev_low - low

    plus_dm  = pd.Series(np.where((up_move > down_move) & (up_move > 0),   up_move,   0.0), index=high.index)
    minus_dm = pd.Series(np.where((down_move > up_move) & (down_move > 0), down_move, 0.0), index=low.index)

    tr = pd.concat([
        high - low,
        (high - prev_close).abs(),
        (low  - prev_close).abs(),
    ], axis=1).max(axis=1)

    atr_s    = _rma(tr, period)
    plus_di  = 100.0 * _rma(plus_dm,  period) / atr_s.replace(0, np.nan)
    minus_di = 100.0 * _rma(minus_dm, period) / atr_s.replace(0, np.nan)

    dx  = 100.0 * (plus_di - minus_di).abs() / (plus_di + minus_di).replace(0, np.nan)
    adx = _rma(dx, period)
    return adx, plus_di, minus_di


# ── Fair Value Gaps ───────────────────────────────────────────────────────────

def _mark_fvgs(df: pd.DataFrame, lookback: int = 50) -> None:
    """
    Mark the most recent unfilled FVG zone per direction on the last bar.
    Bullish FVG: bar[i-1].high < bar[i+1].low  (gap up — buy zone)
    Bearish FVG: bar[i+1].high < bar[i-1].low  (gap down — sell zone)
    Writes NaN for all bars except the latest active FVG.
    """
    n = len(df)
    if n < 3:
        return

    bull_fvg = bear_fvg = None
    start = max(1, n - lookback - 1)

    for i in range(start, n - 1):
        prev_h = df["high"].iloc[i - 1]
        prev_l = df["low"].iloc[i - 1]
        next_l = df["low"].iloc[i + 1]
        next_h = df["high"].iloc[i + 1]

        if next_l > prev_h:            # bullish gap
            # Check if it's been filled by subsequent price
            filled = df["low"].iloc[i + 1:].min() <= prev_h
            if not filled:
                bull_fvg = (prev_h, next_l)

        if next_h < prev_l:            # bearish gap
            filled = df["high"].iloc[i + 1:].max() >= prev_l
            if not filled:
                bear_fvg = (next_h, prev_l)

    if bull_fvg:
        df.iloc[-1, df.columns.get_loc("fvg_bull_low")]  = bull_fvg[0]
        df.iloc[-1, df.columns.get_loc("fvg_bull_high")] = bull_fvg[1]
    if bear_fvg:
        df.iloc[-1, df.columns.get_loc("fvg_bear_low")]  = bear_fvg[0]
        df.iloc[-1, df.columns.get_loc("fvg_bear_high")] = bear_fvg[1]


def get_recent_fvgs(df: pd.DataFrame, lookback: int = 50) -> list[dict]:
    """Return list of {type, low, high} for all unfilled FVGs in last N bars."""
    n   = len(df)
    out = []
    if n < 3:
        return out
    start = max(1, n - lookback - 1)
    for i in range(start, n - 1):
        prev_h = df["high"].iloc[i - 1]
        prev_l = df["low"].iloc[i - 1]
        next_l = df["low"].iloc[i + 1]
        next_h = df["high"].iloc[i + 1]
        if next_l > prev_h:
            filled = df["low"].iloc[i + 1:].min() <= prev_h
            if not filled:
                out.append({"type": "bull", "low": prev_h, "high": next_l, "bar": i})
        if next_h < prev_l:
            filled = df["high"].iloc[i + 1:].max() >= prev_l
            if not filled:
                out.append({"type": "bear", "low": next_h, "high": prev_l, "bar": i})
    return out
