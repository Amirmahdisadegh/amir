"""Flag Limit.

Idea: a base candle (small consolidation / "flag") that sits right at the
level being broken — the *limit* of the move. When price returns to that
flag-limit base it is a high-probability continuation entry. In code: a
base whose range touches the broken structure level within a small ATR
tolerance.
"""
from __future__ import annotations

import pandas as pd

from ..config import RtmCfg
from ..indicators import candle_metrics
from ..signals import Side, SetupType, Signal
from . import structure as st

# how close (in ATR) the base must sit to the broken level to be a flag-limit
LEVEL_TOLERANCE_ATR = 0.5


def _flag_limit_base(
    view: st.StructureView, bos: st.BOS, atr: float
) -> st.Base | None:
    tol = LEVEL_TOLERANCE_ATR * atr
    lo = bos.level - tol
    hi = bos.level + tol

    candidates = []
    for b in view.bases:
        if b.end >= bos.break_index:
            continue
        # base overlaps the [lo, hi] band around the broken level?
        if b.bottom <= hi and b.top >= lo:
            candidates.append(b)
    if not candidates:
        return None
    # closest to the break, then closest to the level
    return max(candidates, key=lambda b: (b.end, -abs(b.mid - bos.level)))


def detect(
    df: pd.DataFrame,
    atr_series: pd.Series,
    cfg: RtmCfg,
    symbol: str,
    timeframe: str,
    htf_bias: int = 0,
) -> list[Signal]:
    if len(df) < 30:
        return []

    dfm = candle_metrics(df)
    view = st.build_structure(dfm, cfg)
    bos = st.latest_bos(view, atr_series, cfg)
    if bos is None:
        return []

    atr_last = float(atr_series.iloc[-1])
    if atr_last <= 0:
        return []

    base = _flag_limit_base(view, bos, atr_last)
    if base is None:
        return []

    side = Side.LONG if bos.direction == +1 else Side.SHORT
    zone = st.zone_from_base(base, side)
    sig = st.make_signal(view, atr_series, cfg, symbol, timeframe, zone,
                         SetupType.FLAG_LIMIT, bos, htf_bias)
    return [sig] if sig else []
