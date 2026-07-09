"""Signal & Zone data structures shared by the RTM engine, scanner and risk."""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum


class Side(str, Enum):
    LONG = "long"
    SHORT = "short"


class SetupType(str, Enum):
    FTR = "FTR"                 # Failure To Return
    FLAG_LIMIT = "FlagLimit"    # Flag Limit


@dataclass(frozen=True)
class Zone:
    """A supply/demand price zone (proximal = entry edge, distal = far edge)."""
    proximal: float          # edge price touches first on return (entry line)
    distal: float            # far edge (beyond it the zone is invalidated)
    start_index: int         # candle index where the base begins
    end_index: int           # candle index where the base ends
    side: Side               # LONG => demand zone, SHORT => supply zone

    @property
    def height(self) -> float:
        return abs(self.proximal - self.distal)

    def contains(self, price: float) -> bool:
        lo, hi = sorted((self.proximal, self.distal))
        return lo <= price <= hi


@dataclass
class Signal:
    symbol: str
    timeframe: str
    setup: SetupType
    side: Side
    entry: float                 # suggested entry (zone proximal)
    stop_loss: float
    take_profit: float
    zone: Zone
    price: float                 # last price at detection
    atr: float
    risk_reward: float
    score: float = 0.0           # quality score (higher = better)
    bar_time: int = 0            # timestamp (ms) of the confirmation bar
    created_at: float = field(default_factory=time.time)
    notes: list[str] = field(default_factory=list)

    def dedup_key(self) -> str:
        """Identity for alert de-duplication / cooldown."""
        return f"{self.symbol}|{self.timeframe}|{self.setup.value}|{self.bar_time}"

    def as_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "timeframe": self.timeframe,
            "setup": self.setup.value,
            "side": self.side.value,
            "entry": self.entry,
            "stop_loss": self.stop_loss,
            "take_profit": self.take_profit,
            "price": self.price,
            "atr": self.atr,
            "risk_reward": round(self.risk_reward, 2),
            "score": round(self.score, 2),
            "bar_time": self.bar_time,
            "notes": self.notes,
        }
