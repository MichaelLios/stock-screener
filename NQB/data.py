"""
NQB Trading Bot — Data fetching
"""
import yfinance as yf
import pandas as pd
from zoneinfo import ZoneInfo
from config import TICKER

NY = ZoneInfo("America/New_York")


def fetch(interval: str = "5m", period: str = "5d") -> pd.DataFrame:
    """
    Download OHLCV data for NQ futures.
    Returns a clean DataFrame indexed in America/New_York time.
    Returns None on failure.
    """
    try:
        raw = yf.download(
            TICKER,
            interval=interval,
            period=period,
            auto_adjust=True,
            progress=False,
        )
    except Exception as exc:
        print(f"[data] download error: {exc}")
        return None

    if raw is None or raw.empty:
        print("[data] no data returned — market may be closed or ticker invalid")
        return None

    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = [c[0].lower() for c in raw.columns]
    else:
        raw.columns = [c.lower() for c in raw.columns]

    # Normalize index to America/New_York
    if raw.index.tz is None:
        raw.index = raw.index.tz_localize("UTC")
    raw.index = raw.index.tz_convert(NY)
    raw.index.name = "datetime"

    raw = raw.dropna(subset=["close"])
    return raw


def latest_price(df: pd.DataFrame) -> float:
    return float(df["close"].iloc[-1])
