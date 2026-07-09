"""Technical primitives used by the RTM engine.

Everything operates on a pandas DataFrame with columns:
    ['timestamp', 'open', 'high', 'low', 'close', 'volume']
indexed 0..n-1 in chronological order (oldest first).
"""
from __future__ import annotations

import numpy as np
import pandas as pd

OHLCV_COLS = ["timestamp", "open", "high", "low", "close", "volume"]


def to_dataframe(ohlcv: list[list[float]]) -> pd.DataFrame:
    """Convert a ccxt OHLCV array into a typed DataFrame."""
    df = pd.DataFrame(ohlcv, columns=OHLCV_COLS)
    for c in ["open", "high", "low", "close", "volume"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df["timestamp"] = df["timestamp"].astype("int64")
    return df.dropna().reset_index(drop=True)


def true_range(df: pd.DataFrame) -> pd.Series:
    high, low, close = df["high"], df["low"], df["close"]
    prev_close = close.shift(1)
    tr = pd.concat(
        [high - low, (high - prev_close).abs(), (low - prev_close).abs()],
        axis=1,
    ).max(axis=1)
    return tr


def atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """Wilder's ATR."""
    tr = true_range(df)
    return tr.ewm(alpha=1 / period, adjust=False, min_periods=period).mean()


def candle_metrics(df: pd.DataFrame) -> pd.DataFrame:
    """Add body / range / body_ratio / direction columns (non-mutating)."""
    out = df.copy()
    rng = (out["high"] - out["low"]).replace(0, np.nan)
    out["range"] = rng
    out["body"] = (out["close"] - out["open"]).abs()
    out["body_ratio"] = (out["body"] / rng).fillna(0.0)
    out["direction"] = np.sign(out["close"] - out["open"]).astype(int)  # 1 up, -1 down
    return out


def swing_points(df: pd.DataFrame, lookback: int = 2) -> tuple[np.ndarray, np.ndarray]:
    """Return boolean arrays (is_swing_high, is_swing_low).

    A pivot high at i requires high[i] to be the strict max of the window
    [i-lookback, i+lookback]; symmetric for pivot lows.
    """
    highs = df["high"].to_numpy()
    lows = df["low"].to_numpy()
    n = len(df)
    is_high = np.zeros(n, dtype=bool)
    is_low = np.zeros(n, dtype=bool)

    for i in range(lookback, n - lookback):
        window_h = highs[i - lookback : i + lookback + 1]
        window_l = lows[i - lookback : i + lookback + 1]
        if highs[i] == window_h.max() and (window_h == highs[i]).sum() == 1:
            is_high[i] = True
        if lows[i] == window_l.min() and (window_l == lows[i]).sum() == 1:
            is_low[i] = True
    return is_high, is_low


def rolling_volume_avg(df: pd.DataFrame, period: int = 20) -> pd.Series:
    return df["volume"].rolling(period, min_periods=1).mean()


def ema(series: pd.Series, period: int) -> pd.Series:
    """Exponential moving average."""
    return series.ewm(span=period, adjust=False, min_periods=1).mean()


def rsi(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """Wilder's RSI (0-100)."""
    delta = df["close"].diff()
    gain = delta.clip(lower=0)
    loss = -delta.clip(upper=0)
    avg_gain = gain.ewm(alpha=1 / period, adjust=False, min_periods=period).mean()
    avg_loss = loss.ewm(alpha=1 / period, adjust=False, min_periods=period).mean()
    # avg_loss == 0 with gains -> rs = +inf -> RSI = 100 (correct);
    # 0/0 (flat) -> NaN -> treated as neutral 50 below.
    rs = avg_gain / avg_loss
    out = 100 - (100 / (1 + rs))
    return out.fillna(50.0)


def trend_bias(close: pd.Series, ema_period: int = 50, slope_lookback: int = 5) -> int:
    """Directional bias from an EMA: +1 up, -1 down, 0 mixed/flat.

    Up   = price above the EMA AND the EMA rising.
    Down = price below the EMA AND the EMA falling.
    """
    if len(close) < ema_period:
        return 0
    e = ema(close, ema_period)
    price = close.iloc[-1]
    now, prev = e.iloc[-1], e.iloc[-min(slope_lookback, len(e))]
    rising, falling = now > prev, now < prev
    if price > now and rising:
        return +1
    if price < now and falling:
        return -1
    return 0
