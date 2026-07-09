"""Risk management — the NON-NEGOTIABLE core.

Every rule here is always enforced in live mode; there is no flag to turn
them off:

  1. Position size derives from a fixed % risk of equity and the ATR/zone stop.
  2. A stop loss is mandatory on every plan (a plan without one is rejected).
  3. Total concurrent open positions are capped (across all symbols).
  4. A daily realized-loss limit halts the bot for the rest of the day.
  5. Leverage is capped.

The manager persists its state (open positions + daily PnL) to JSON so a
restart cannot silently reset the daily loss counter.
"""
from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path

from .config import RiskCfg
from .signals import Side, Signal

log = logging.getLogger("okx_scanner.risk")


@dataclass
class PositionPlan:
    symbol: str
    side: Side
    entry: float
    stop_loss: float
    take_profit: float
    size: float            # position size in BASE units
    notional: float        # size * entry (quote)
    risk_amount: float     # quote at risk if stop is hit
    leverage: float
    reason: str = "ok"

    @property
    def is_valid(self) -> bool:
        return self.reason == "ok" and self.size > 0


@dataclass
class OpenPosition:
    symbol: str
    side: str
    entry: float
    stop_loss: float
    take_profit: float
    size: float
    opened_at: str
    status: str = "pending"        # "pending" (order resting) | "open" (filled)


@dataclass
class DailyState:
    day: str                       # ISO date (UTC)
    start_equity: float
    realized_pnl: float = 0.0
    halted: bool = False


@dataclass
class RiskState:
    daily: DailyState
    positions: dict[str, OpenPosition] = field(default_factory=dict)


class RiskRejection(Exception):
    """Raised when a trade cannot be opened under the risk rules."""


class RiskManager:
    def __init__(self, cfg: RiskCfg, state_path: str | Path = "state/risk_state.json"):
        self.cfg = cfg
        self.state_path = Path(state_path)
        self.state = self._load_state()

    # ------------------------------------------------------------------ #
    #  Persistence
    # ------------------------------------------------------------------ #
    def _today(self) -> str:
        return datetime.now(timezone.utc).date().isoformat()

    def _load_state(self) -> RiskState:
        equity = self.cfg.account_equity_usdt
        if self.state_path.exists():
            try:
                raw = json.loads(self.state_path.read_text())
                daily = DailyState(**raw["daily"])
                positions = {
                    k: OpenPosition(**v) for k, v in raw.get("positions", {}).items()
                }
                state = RiskState(daily=daily, positions=positions)
                if state.daily.day != self._today():
                    state = self._roll_new_day(equity)
                return state
            except Exception as e:  # corrupt state -> start fresh, but log loudly
                log.error("could not load risk state (%s); starting fresh", e)
        return RiskState(daily=DailyState(day=self._today(), start_equity=equity))

    def _roll_new_day(self, equity: float) -> RiskState:
        log.info("new trading day — resetting daily loss counter")
        return RiskState(
            daily=DailyState(day=self._today(), start_equity=equity),
            positions=self.state.positions if hasattr(self, "state") else {},
        )

    def save(self) -> None:
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "daily": asdict(self.state.daily),
            "positions": {k: asdict(v) for k, v in self.state.positions.items()},
        }
        self.state_path.write_text(json.dumps(payload, indent=2))

    def _maybe_roll_day(self, equity: float) -> None:
        if self.state.daily.day != self._today():
            self.state = self._roll_new_day(equity)
            self.save()

    # ------------------------------------------------------------------ #
    #  Guards
    # ------------------------------------------------------------------ #
    @property
    def daily_loss_pct(self) -> float:
        d = self.state.daily
        if d.start_equity <= 0:
            return 0.0
        return -min(d.realized_pnl, 0.0) / d.start_equity * 100.0

    def is_halted(self, equity: float | None = None) -> bool:
        if equity is not None:
            self._maybe_roll_day(equity)
        d = self.state.daily
        if d.halted:
            return True
        if self.daily_loss_pct >= self.cfg.daily_loss_limit_pct:
            d.halted = True
            self.save()
            log.warning("DAILY LOSS LIMIT hit (%.2f%%) — bot halted for the day",
                        self.daily_loss_pct)
            return True
        return False

    def _open_count(self) -> int:
        return len(self.state.positions)

    def _open_for_symbol(self, symbol: str) -> int:
        return sum(1 for p in self.state.positions.values() if p.symbol == symbol)

    def can_open(self, symbol: str, equity: float) -> tuple[bool, str]:
        if self.is_halted(equity):
            return False, "daily loss limit reached — halted"
        if self._open_count() >= self.cfg.max_open_positions:
            return False, f"max open positions ({self.cfg.max_open_positions}) reached"
        if self._open_for_symbol(symbol) >= self.cfg.max_positions_per_symbol:
            return False, f"already at per-symbol limit for {symbol}"
        return True, "ok"

    # ------------------------------------------------------------------ #
    #  Sizing
    # ------------------------------------------------------------------ #
    def build_plan(self, signal: Signal, equity: float, atr: float) -> PositionPlan:
        """Compute a fully risk-bounded plan. Never returns without a stop."""
        ok, reason = self.can_open(signal.symbol, equity)
        base_reject = PositionPlan(
            symbol=signal.symbol, side=signal.side, entry=signal.entry,
            stop_loss=signal.stop_loss, take_profit=signal.take_profit,
            size=0.0, notional=0.0, risk_amount=0.0, leverage=0.0,
        )
        if not ok:
            base_reject.reason = reason
            return base_reject

        entry = signal.entry
        # --- enforce an ATR-based minimum stop distance ---
        atr_stop_dist = self.cfg.atr_sl_mult * atr
        signal_stop_dist = abs(entry - signal.stop_loss)
        stop_dist = max(signal_stop_dist, atr_stop_dist)
        if stop_dist <= 0:
            base_reject.reason = "invalid stop distance"
            return base_reject

        if signal.side is Side.LONG:
            stop = entry - stop_dist
            take_profit = entry + self.cfg.take_profit_rr * stop_dist
        else:
            stop = entry + stop_dist
            take_profit = entry - self.cfg.take_profit_rr * stop_dist

        # --- position size from fixed fractional risk ---
        risk_amount = equity * (self.cfg.risk_per_trade_pct / 100.0)
        size = risk_amount / stop_dist            # base units
        notional = size * entry

        # --- leverage cap ---
        max_notional = equity * self.cfg.max_leverage
        leverage = notional / equity if equity > 0 else 0.0
        if notional > max_notional:
            scale = max_notional / notional
            size *= scale
            notional *= scale
            risk_amount *= scale
            leverage = self.cfg.max_leverage
            log.info("%s: size scaled to respect max leverage x%d",
                     signal.symbol, self.cfg.max_leverage)

        if size <= 0:
            base_reject.reason = "computed size is zero"
            return base_reject

        return PositionPlan(
            symbol=signal.symbol, side=signal.side, entry=entry,
            stop_loss=round(stop, 8), take_profit=round(take_profit, 8),
            size=size, notional=notional, risk_amount=risk_amount,
            leverage=round(leverage, 2), reason="ok",
        )

    # ------------------------------------------------------------------ #
    #  Bookkeeping
    # ------------------------------------------------------------------ #
    def register_open(self, order_id: str, plan: PositionPlan) -> None:
        """Record a newly placed entry order. Starts as 'pending' (not yet filled)."""
        self.state.positions[order_id] = OpenPosition(
            symbol=plan.symbol, side=plan.side.value, entry=plan.entry,
            stop_loss=plan.stop_loss, take_profit=plan.take_profit,
            size=plan.size, opened_at=datetime.now(timezone.utc).isoformat(),
            status="pending",
        )
        self.save()

    def mark_filled(self, order_id: str) -> None:
        """Promote a pending entry to an open position (limit order filled)."""
        pos = self.state.positions.get(order_id)
        if pos and pos.status != "open":
            pos.status = "open"
            self.save()
            log.info("entry filled: %s %s", pos.symbol, pos.side)

    def drop_pending(self, order_id: str) -> None:
        """Remove a pending entry that was cancelled/expired without filling."""
        pos = self.state.positions.pop(order_id, None)
        if pos:
            self.save()
            log.info("pending entry cleared (unfilled): %s %s",
                     pos.symbol, pos.side)

    def register_close(self, order_id: str, realized_pnl: float) -> None:
        self.state.positions.pop(order_id, None)
        self.state.daily.realized_pnl += realized_pnl
        self.save()
        if realized_pnl < 0:
            log.info("closed %s pnl=%.2f | daily loss now %.2f%%",
                     order_id, realized_pnl, self.daily_loss_pct)
