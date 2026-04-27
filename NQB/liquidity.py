"""
NQB — Liquidity & market structure detection
  - Swing highs / swing lows (pivot points)
  - Equal highs / equal lows (liquidity pools)
  - High-volume nodes (HVN) from a simple volume profile
  - Order blocks (last bullish/bearish candle before an impulse move)
"""

import numpy as np
import pandas as pd


def swing_points(df: pd.DataFrame, left: int = 5, right: int = 5):
    """
    Returns two DataFrames: swing_highs, swing_lows.
    A swing high is a candle whose high is the highest within
    `left` candles before and `right` candles after.
    """
    highs = df["high"]
    lows  = df["low"]
    n     = len(df)

    sh_idx, sl_idx = [], []
    for i in range(left, n - right):
        window_h = highs.iloc[i - left : i + right + 1]
        window_l = lows.iloc[i  - left : i + right + 1]
        if highs.iloc[i] == window_h.max():
            sh_idx.append(i)
        if lows.iloc[i] == window_l.min():
            sl_idx.append(i)

    swing_highs = df.iloc[sh_idx][["high"]].copy()
    swing_highs.columns = ["level"]
    swing_highs["kind"] = "swing_high"

    swing_lows = df.iloc[sl_idx][["low"]].copy()
    swing_lows.columns = ["level"]
    swing_lows["kind"] = "swing_low"

    return swing_highs, swing_lows


def equal_levels(swing_highs: pd.DataFrame, swing_lows: pd.DataFrame,
                 tolerance: float = 0.002):
    """
    Cluster swing points within `tolerance` % of each other.
    Returns a list of dicts: {level, kind, count}.
    """
    results = []

    for frame, kind in [(swing_highs, "EQH"), (swing_lows, "EQL")]:
        if frame.empty:
            continue
        levels = frame["level"].values.copy()
        used   = np.zeros(len(levels), dtype=bool)
        for i in range(len(levels)):
            if used[i]:
                continue
            cluster = [levels[i]]
            for j in range(i + 1, len(levels)):
                if not used[j] and abs(levels[j] - levels[i]) / levels[i] <= tolerance:
                    cluster.append(levels[j])
                    used[j] = True
            used[i] = True
            if len(cluster) >= 2:
                results.append({
                    "level": float(np.mean(cluster)),
                    "kind":  kind,
                    "count": len(cluster),
                })

    return results


def volume_profile(df: pd.DataFrame, bins: int = 40):
    """
    Build a simple volume profile (price × volume histogram).
    Returns a DataFrame with columns: price_mid, volume.
    """
    lo = df["low"].min()
    hi = df["high"].max()
    edges = np.linspace(lo, hi, bins + 1)
    vol_bins = np.zeros(bins)

    for _, row in df.iterrows():
        # distribute bar volume across the price range it spans
        bar_lo = row["low"]
        bar_hi = row["high"]
        bar_vol = row["volume"]
        for b in range(bins):
            overlap = min(edges[b + 1], bar_hi) - max(edges[b], bar_lo)
            if overlap > 0:
                span = bar_hi - bar_lo if bar_hi > bar_lo else 1
                vol_bins[b] += bar_vol * (overlap / span)

    mids = (edges[:-1] + edges[1:]) / 2
    vp = pd.DataFrame({"price_mid": mids, "volume": vol_bins})
    return vp


def high_volume_nodes(vp: pd.DataFrame, top_n: int = 5):
    """Return the top N price levels by volume (HVN)."""
    return vp.nlargest(top_n, "volume").reset_index(drop=True)


def order_blocks(df: pd.DataFrame, impulse_pct: float = 0.003, lookback: int = 60):
    """
    Detect the last bearish candle before a bullish impulse (bullish OB)
    and the last bullish candle before a bearish impulse (bearish OB).
    Returns list of dicts: {top, bottom, kind, index}.
    """
    blocks = []
    close = df["close"].values
    open_ = df["open"].values
    high  = df["high"].values
    low   = df["low"].values
    n     = len(df)

    for i in range(1, min(n - 1, lookback)):
        idx = n - 1 - i  # walk backwards from latest

        # Bullish OB: bearish candle (close < open) followed by strong bullish move
        if close[idx] < open_[idx]:
            future_high = high[idx + 1: idx + 6].max() if idx + 6 <= n else high[idx + 1:].max()
            if (future_high - close[idx]) / close[idx] >= impulse_pct:
                blocks.append({
                    "top":    open_[idx],
                    "bottom": close[idx],
                    "kind":   "bull_ob",
                    "ts":     df.index[idx],
                })

        # Bearish OB: bullish candle followed by strong bearish move
        if close[idx] > open_[idx]:
            future_low = low[idx + 1: idx + 6].min() if idx + 6 <= n else low[idx + 1:].min()
            if (close[idx] - future_low) / close[idx] >= impulse_pct:
                blocks.append({
                    "top":    close[idx],
                    "bottom": open_[idx],
                    "kind":   "bear_ob",
                    "ts":     df.index[idx],
                })

    # Deduplicate: keep only closest OBs to current price
    price = close[-1]
    seen  = {"bull_ob": False, "bear_ob": False}
    deduped = []
    for b in sorted(blocks, key=lambda x: abs(price - (x["top"] + x["bottom"]) / 2)):
        if not seen[b["kind"]]:
            deduped.append(b)
            seen[b["kind"]] = True
        if all(seen.values()):
            break

    return deduped
