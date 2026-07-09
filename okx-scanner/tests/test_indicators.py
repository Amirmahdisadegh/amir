import numpy as np
import pandas as pd

from okx_scanner.indicators import (
    atr, candle_metrics, ema, rsi, swing_points, to_dataframe, true_range,
    trend_bias,
)
import pandas as pd


def _ohlcv(rows):
    # rows: list of (o,h,l,c,v) -> ccxt-style [ts,o,h,l,c,v]
    return [[i * 1000, o, h, l, c, v] for i, (o, h, l, c, v) in enumerate(rows)]


def test_to_dataframe_types():
    df = to_dataframe(_ohlcv([(1, 2, 0.5, 1.5, 100)]))
    assert list(df.columns) == ["timestamp", "open", "high", "low", "close", "volume"]
    assert df["close"].iloc[0] == 1.5


def test_true_range_and_atr_positive():
    rows = [(10, 11, 9, 10.5, 100)] * 30
    df = to_dataframe(_ohlcv(rows))
    tr = true_range(df)
    assert (tr.dropna() >= 0).all()
    a = atr(df, 14)
    assert a.iloc[-1] > 0


def test_candle_metrics_body_ratio():
    # doji-ish: tiny body, big range -> low body_ratio
    df = to_dataframe(_ohlcv([(10, 12, 8, 10.1, 5)]))
    m = candle_metrics(df)
    assert m["body_ratio"].iloc[0] < 0.1
    assert m["direction"].iloc[0] == 1  # close > open


def test_swing_points_detects_peak():
    # a clear peak at index 3
    highs = [1, 2, 3, 5, 3, 2, 1]
    rows = [(h, h + 0.1, h - 0.1, h, 1) for h in highs]
    df = to_dataframe(_ohlcv(rows))
    is_high, is_low = swing_points(df, lookback=2)
    assert is_high[3]
    assert not is_high[0]


def test_ema_tracks_series():
    s = pd.Series([1.0] * 50)
    assert abs(ema(s, 10).iloc[-1] - 1.0) < 1e-9


def test_rsi_bounds():
    # steadily rising close -> RSI high (near 100)
    rows = [(i, i + 0.5, i - 0.5, i + 0.4, 1) for i in range(1, 40)]
    df = to_dataframe(_ohlcv(rows))
    r = rsi(df, 14).iloc[-1]
    assert 0 <= r <= 100
    assert r > 70  # strong uptrend


def test_trend_bias_up_and_down():
    up = pd.Series([float(i) for i in range(1, 80)])
    assert trend_bias(up, 50) == 1
    down = pd.Series([float(i) for i in range(80, 1, -1)])
    assert trend_bias(down, 50) == -1
