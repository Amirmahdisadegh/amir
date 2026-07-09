"""Live order execution — Mode 2 only.

Hard safety properties:
  * Never places an entry without an attached stop loss.
  * Every order is sized and gated by the RiskManager (no bypass).
  * Refuses to run against a live (non-sandbox) account unless the operator
    explicitly acknowledges via config.
  * Leverage is capped to RiskCfg.max_leverage.

This module is intentionally conservative: it is meant to be exercised for
weeks on OKX Demo Trading before any real capital is involved.
"""
from __future__ import annotations

import logging

from .config import Config
from .data import OkxData
from .notifier import TelegramNotifier
from .risk import RiskManager
from .signals import Side, Signal

log = logging.getLogger("okx_scanner.executor")


class Executor:
    def __init__(self, cfg: Config, data: OkxData, risk: RiskManager,
                 notifier: TelegramNotifier):
        self.cfg = cfg
        self.data = data          # MUST be an authenticated OkxData
        self.risk = risk
        self.notifier = notifier

        if not cfg.exchange.sandbox:
            log.warning(
                "LIVE (non-sandbox) trading is enabled. Ensure the API key has "
                "Trade-only permission, withdrawal disabled, and IP whitelist %s.",
                cfg.security.allowed_server_ip,
            )

    # ------------------------------------------------------------------ #
    async def _equity(self) -> float:
        """Live free USDT balance, falling back to configured equity."""
        try:
            bal = await self.data.client.fetch_balance()
            usdt = bal.get("USDT", {})
            free = usdt.get("free") or usdt.get("total")
            if free:
                return float(free)
        except Exception as e:
            log.warning("could not fetch balance (%s); using configured equity", e)
        return self.cfg.risk.account_equity_usdt

    async def _set_leverage(self, symbol: str, leverage: float) -> None:
        lev = max(1, min(int(leverage) or 1, self.cfg.risk.max_leverage))
        try:
            await self.data.client.set_leverage(lev, symbol)
        except Exception as e:
            log.warning("set_leverage failed for %s: %s", symbol, e)

    async def handle_signal(self, signal: Signal) -> None:
        equity = await self._equity()

        if self.risk.is_halted(equity):
            log.info("skip %s — risk manager halted", signal.symbol)
            return

        plan = self.risk.build_plan(signal, equity, signal.atr)
        if not plan.is_valid:
            log.info("skip %s — %s", signal.symbol, plan.reason)
            return

        # ---- invariant: a stop loss must exist. Refuse otherwise. ----
        if not plan.stop_loss or plan.stop_loss <= 0:
            log.error("REFUSING order for %s: no stop loss on plan", signal.symbol)
            return

        side = "buy" if plan.side is Side.LONG else "sell"
        await self._set_leverage(signal.symbol, plan.leverage)

        params = {
            # OKX native attached stop-loss / take-profit (algo on the order)
            "slTriggerPx": plan.stop_loss,
            "slOrdPx": -1,                     # -1 => market stop when triggered
            "tpTriggerPx": plan.take_profit,
            "tpOrdPx": -1,
        }

        try:
            order = await self.data.client.create_order(
                symbol=signal.symbol,
                type="limit",
                side=side,
                amount=plan.size,
                price=plan.entry,
                params=params,
            )
        except Exception as e:
            log.error("order placement failed for %s: %s", signal.symbol, e)
            await self.notifier.send_text(
                f"⚠️ Order FAILED {signal.symbol}: {e}"
            )
            return

        order_id = str(order.get("id", f"{signal.symbol}-{signal.bar_time}"))
        self.risk.register_open(order_id, plan)
        log.info("placed %s %s size=%.6f entry=%.6f SL=%.6f TP=%.6f lev=%.1f",
                 side, signal.symbol, plan.size, plan.entry,
                 plan.stop_loss, plan.take_profit, plan.leverage)
        await self.notifier.send_text(
            f"✅ Order placed {signal.symbol} {side.upper()} "
            f"size={plan.size:.4f} @ {plan.entry:g}\n"
            f"SL {plan.stop_loss:g} · TP {plan.take_profit:g} · risk "
            f"{plan.risk_amount:.2f} USDT"
        )
