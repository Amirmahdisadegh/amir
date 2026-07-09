"""FTR — Failure To Return.

Idea: after a Break Of Structure, price pulls back but *fails to return*
into the broken level, forming a fresh continuation zone (the last base
that held on the correct side of the broken level). Entry is a limit at
that zone when price revisits it.
"""
from __future__ import annotations

import pandas as pd

from ..config import RtmCfg
from ..indicators import candle_metrics
from ..signals import Side, SetupType, Signal
from . import structure as st


def _ftr_base(view: st.StructureView, bos: st.BOS) -> st.Base | None:
    """Pick the base that failed to return across the broken level."""
    if bos.direction == +1:  # bullish -> demand base above the broken high
        held = [b for b in view.bases if b.end < bos.break_index and b.bottom >= bos.level]
        if held:
            return max(held, key=lambda b: b.end)
        # fall back to the last base before the break
        prior = [b for b in view.bases if b.end < bos.break_index]
        return max(prior, key=lambda b: b.end) if prior else None

    # bearish -> supply base below the broken low
    held = [b for b in view.bases if b.end < bos.break_index and b.top <= bos.level]
    if held:
        return max(held, key=lambda b: b.end)
    prior = [b for b in view.bases if b.end < bos.break_index]
    return max(prior, key=lambda b: b.end) if prior else None


def detect(
    df: pd.DataFrame,
    atr_series: pd.Series,
    cfg: RtmCfg,
    symbol: str,
    timeframe: str,
) -> list[Signal]:
    if len(df) < 30:
        return []

    dfm = candle_metrics(df)
    view = st.build_structure(dfm, cfg)
    bos = st.latest_bos(view, atr_series, cfg)
    if bos is None:
        return []

    base = _ftr_base(view, bos)
    if base is None:
        return []

    side = Side.LONG if bos.direction == +1 else Side.SHORT
    zone = st.zone_from_base(base, side)
    sig = st.make_signal(view, atr_series, cfg, symbol, timeframe, zone, SetupType.FTR, bos)
    return [sig] if sig else []
