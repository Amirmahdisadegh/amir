"""Market-structure primitives shared by the FTR and Flag Limit detectors.

This is a *pragmatic* codification of RTM concepts (Reading The Market by
Ali Radman). Discretionary price-action patterns cannot be captured
perfectly in code, so the goal here is a deterministic, testable
approximation whose sensitivity is fully driven by `RtmCfg`.

Core objects
------------
Base   : a short run (1..N) of small-bodied candles = a zone origin.
Leg    : a strong impulsive candle (large body) = the move away from a base.
BOS    : Break Of Structure = a candle closing beyond a prior confirmed swing.
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

from ..config import RtmCfg
from ..indicators import candle_metrics, rolling_volume_avg, swing_points
from ..signals import Side, SetupType, Signal, Zone

# Suggested take-profit if no opposing structure is found (in R multiples).
DEFAULT_TP_RR = 2.0
# Stop buffer beyond the far edge of the zone, as a fraction of ATR.
SL_ATR_BUFFER = 0.15


@dataclass
class Base:
    start: int
    end: int
    top: float      # highest high across the base candles
    bottom: float   # lowest low across the base candles

    @property
    def mid(self) -> float:
        return (self.top + self.bottom) / 2.0


@dataclass
class BOS:
    """A break of a prior swing."""
    direction: int      # +1 bullish break (up), -1 bearish break (down)
    level: float        # the swing price that was broken
    swing_index: int    # index of the broken swing
    break_index: int    # index of the candle that closed beyond `level`


@dataclass
class StructureView:
    """Precomputed structure for a dataframe (reused by both detectors)."""
    dfm: pd.DataFrame           # candle metrics added
    bases: list[Base]
    is_high: np.ndarray
    is_low: np.ndarray


# --------------------------------------------------------------------------- #
#  Bases
# --------------------------------------------------------------------------- #
def find_bases(dfm: pd.DataFrame, cfg: RtmCfg) -> list[Base]:
    """Group consecutive small-bodied candles into base zones."""
    body_ratio = dfm["body_ratio"].to_numpy()
    highs = dfm["high"].to_numpy()
    lows = dfm["low"].to_numpy()
    n = len(dfm)

    bases: list[Base] = []
    i = 0
    while i < n:
        if body_ratio[i] <= cfg.base_max_body_ratio:
            j = i
            while (
                j + 1 < n
                and body_ratio[j + 1] <= cfg.base_max_body_ratio
                and (j - i + 1) < cfg.base_max_candles
            ):
                j += 1
            top = float(highs[i : j + 1].max())
            bottom = float(lows[i : j + 1].min())
            bases.append(Base(start=i, end=j, top=top, bottom=bottom))
            i = j + 1
        else:
            i += 1
    return bases


def build_structure(dfm: pd.DataFrame, cfg: RtmCfg) -> StructureView:
    is_high, is_low = swing_points(dfm, cfg.swing_lookback)
    return StructureView(
        dfm=dfm,
        bases=find_bases(dfm, cfg),
        is_high=is_high,
        is_low=is_low,
    )


# --------------------------------------------------------------------------- #
#  Break of structure
# --------------------------------------------------------------------------- #
def latest_bos(view: StructureView, atr_series: pd.Series, cfg: RtmCfg) -> BOS | None:
    """Most recent Break Of Structure whose leg is large enough.

    Bullish: a candle closes above a prior confirmed swing high.
    Bearish: a candle closes below a prior confirmed swing low.
    We scan from the most recent candle backwards and return the first
    qualifying break.
    """
    dfm = view.dfm
    highs = dfm["high"].to_numpy()
    lows = dfm["low"].to_numpy()
    close = dfm["close"].to_numpy()
    atr = atr_series.to_numpy()
    n = len(dfm)

    high_idx = np.flatnonzero(view.is_high)
    low_idx = np.flatnonzero(view.is_low)

    best: BOS | None = None
    # walk break candles newest -> oldest
    for j in range(n - 1, 0, -1):
        a = atr[j]
        if not np.isfinite(a) or a <= 0:
            continue
        min_leg = cfg.min_leg_atr_mult * a

        # bullish break: close above nearest prior swing high below the close
        prior_highs = high_idx[high_idx < j]
        if prior_highs.size:
            p = int(prior_highs[-1])
            level = float(highs[p])
            if close[j] > level and (close[j] - level) >= 0:
                # leg strength measured from swing to break close
                if (close[j] - lows[p:j + 1].min()) >= min_leg:
                    best = BOS(direction=+1, level=level, swing_index=p, break_index=j)
                    break

        # bearish break: close below nearest prior swing low
        prior_lows = low_idx[low_idx < j]
        if prior_lows.size:
            p = int(prior_lows[-1])
            level = float(lows[p])
            if close[j] < level:
                if (highs[p:j + 1].max() - close[j]) >= min_leg:
                    best = BOS(direction=-1, level=level, swing_index=p, break_index=j)
                    break
    return best


# --------------------------------------------------------------------------- #
#  Zone construction from a base
# --------------------------------------------------------------------------- #
def zone_from_base(base: Base, side: Side) -> Zone:
    """Build a demand/supply Zone from a base.

    Demand (LONG): price returns *down* into it -> proximal = top, distal = bottom.
    Supply (SHORT): price returns *up* into it -> proximal = bottom, distal = top.
    """
    if side is Side.LONG:
        return Zone(proximal=base.top, distal=base.bottom,
                    start_index=base.start, end_index=base.end, side=side)
    return Zone(proximal=base.bottom, distal=base.top,
                start_index=base.start, end_index=base.end, side=side)


# --------------------------------------------------------------------------- #
#  Signal construction + quality validation (shared by both detectors)
# --------------------------------------------------------------------------- #
def _nearest_target(view: StructureView, side: Side, entry: float,
                    beyond: float) -> float | None:
    """Take-profit anchor: nearest opposing swing in the continuation zone.

    For a continuation setup after a break at `beyond`, only structure at or
    past the broken level counts as a target — swings *inside* the pullback
    are noise, not resistance/support for the continuation.
    """
    dfm = view.dfm
    if side is Side.LONG:
        idx = np.flatnonzero(view.is_high)
        levels = dfm["high"].to_numpy()[idx]
        cand = levels[(levels > entry) & (levels >= beyond)]
        return float(cand.min()) if cand.size else None
    idx = np.flatnonzero(view.is_low)
    levels = dfm["low"].to_numpy()[idx]
    cand = levels[(levels < entry) & (levels <= beyond)]
    return float(cand.max()) if cand.size else None


def make_signal(
    view: StructureView,
    atr_series: pd.Series,
    cfg: RtmCfg,
    symbol: str,
    timeframe: str,
    zone: Zone,
    setup: SetupType,
    bos: BOS,
) -> Signal | None:
    """Turn a candidate zone into a validated Signal, or None if it fails filters."""
    dfm = view.dfm
    n = len(dfm)
    last = n - 1
    price = float(dfm["close"].iloc[last])
    atr = float(atr_series.iloc[last])
    if not np.isfinite(atr) or atr <= 0:
        return None

    side = zone.side
    entry = zone.proximal

    # --- stop loss: just beyond the distal edge ---
    buf = SL_ATR_BUFFER * atr
    if side is Side.LONG:
        stop = zone.distal - buf
    else:
        stop = zone.distal + buf
    risk = abs(entry - stop)
    if risk <= 0:
        return None

    # --- take profit: nearest opposing structure beyond the broken level ---
    target = _nearest_target(view, side, entry, bos.level)
    if target is None:
        target = entry + DEFAULT_TP_RR * risk if side is Side.LONG else entry - DEFAULT_TP_RR * risk
    reward = abs(target - entry)
    rr = reward / risk

    notes: list[str] = []

    # --- filter: freshness ---
    age = last - zone.end_index
    if age > cfg.zone_freshness_bars:
        return None

    # --- filter: distance from current price to the entry line ---
    dist = abs(price - entry)
    if dist > cfg.max_dist_to_zone_atr * atr:
        return None

    # --- filter: risk / reward floor ---
    if rr < cfg.min_risk_reward:
        return None

    # --- filter: direction sanity (price should not have blown past the zone) ---
    if side is Side.LONG and price < zone.distal:
        return None
    if side is Side.SHORT and price > zone.distal:
        return None

    # --- confirmation-candle volume (scoring, not hard filter) ---
    vol_avg = float(rolling_volume_avg(dfm, 20).iloc[last])
    last_vol = float(dfm["volume"].iloc[last])
    vol_ok = vol_avg > 0 and last_vol >= cfg.confirm_vol_mult * vol_avg
    if vol_ok:
        notes.append("volume-confirmed")

    # --- score: RR + proximity + volume + leg strength + freshness ---
    leg_strength = abs(dfm["close"].iloc[bos.break_index] - bos.level) / atr
    proximity = 1.0 - min(dist / (cfg.max_dist_to_zone_atr * atr), 1.0)
    freshness = 1.0 - min(age / max(cfg.zone_freshness_bars, 1), 1.0)
    score = (
        min(rr / 3.0, 1.0) * 35
        + proximity * 25
        + freshness * 15
        + min(leg_strength / 3.0, 1.0) * 15
        + (10 if vol_ok else 0)
    )

    return Signal(
        symbol=symbol,
        timeframe=timeframe,
        setup=setup,
        side=side,
        entry=round(entry, 8),
        stop_loss=round(stop, 8),
        take_profit=round(target, 8),
        zone=zone,
        price=price,
        atr=atr,
        risk_reward=rr,
        score=score,
        bar_time=int(dfm["timestamp"].iloc[last]),
        notes=notes,
    )
