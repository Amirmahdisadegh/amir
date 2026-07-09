"""RTM (Reading The Market) setup detection.

Public entry point: `detect_signals(df, atr_series, cfg, symbol, timeframe)`
which returns a list of validated `Signal` objects combining the FTR and
Flag Limit detectors.
"""
from __future__ import annotations

import pandas as pd

from ..config import RtmCfg
from ..signals import Signal
from . import ftr, flag_limit


def detect_signals(
    df: pd.DataFrame,
    atr_series: "pd.Series",
    cfg: RtmCfg,
    symbol: str,
    timeframe: str,
) -> list[Signal]:
    signals: list[Signal] = []
    signals.extend(ftr.detect(df, atr_series, cfg, symbol, timeframe))
    signals.extend(flag_limit.detect(df, atr_series, cfg, symbol, timeframe))
    return signals


__all__ = ["detect_signals", "ftr", "flag_limit"]
