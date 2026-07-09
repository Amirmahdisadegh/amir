import numpy as np
import pandas as pd

from okx_scanner.indicators import (
    atr, candle_metrics, swing_points, to_dataframe, true_range,
)


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
