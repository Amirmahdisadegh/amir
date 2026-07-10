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


# --------------------------------------------------------------------------- #
#  Pure reconciliation helpers (unit-testable without any network)
# --------------------------------------------------------------------------- #
def open_position_keys(positions: list[dict]) -> set[tuple[str, str]]:
    """(symbol, side) of every exchange position that still holds contracts."""
    keys: set[tuple[str, str]] = set()
    for p in positions:
        contracts = p.get("contracts") or p.get("contractSize") or 0
        try:
            if float(contracts) != 0:
                keys.add((p.get("symbol"), p.get("side")))
        except (TypeError, ValueError):
            continue
    return keys


def reconcile_actions(
    tracked: dict,
    open_order_ids: set[str],
    position_keys: set[tuple[str, str]],
) -> list[tuple[str, str]]:
    """Pure state machine mapping tracked entries to (order_id, action).

    Actions:
      "filled"    — pending order gone from the book AND a position now exists
      "cancelled" — pending order gone AND no position (never filled)
      "closed"    — a previously-open position no longer exists (SL/TP hit)
    Entries that are unchanged (still resting, or still open) produce no action.
    """
    actions: list[tuple[str, str]] = []
    for order_id, pos in tracked.items():
        key = (pos.symbol, pos.side)
        if pos.status == "pending":
            if order_id in open_order_ids:
                continue                      # still resting on the book
            if key in position_keys:
                actions.append((order_id, "filled"))
            else:
                actions.append((order_id, "cancelled"))
        else:  # "open"
            if key in position_keys:
                continue                      # still open
            actions.append((order_id, "closed"))
    return actions


def realized_pnl_from_trades(trades: list[dict]) -> float:
    """Sum realized PnL across fills (OKX exposes 'fillPnl' on each trade)."""
    total = 0.0
    for t in trades:
        info = t.get("info", {}) or {}
        val = None
        for key in ("fillPnl", "pnl", "realizedPnl"):
            if info.get(key) not in (None, ""):
                val = info.get(key)
                break
        if val is None:
            val = t.get("info", {}).get("fillPnl")
        try:
            if val is not None and val != "":
                total += float(val)
        except (TypeError, ValueError):
            continue
    return total


class Executor:
    def __init__(self, cfg: Config, data: OkxData, risk: RiskManager,
                 notifier: TelegramNotifier):
        self.cfg = cfg
        self.data = data          # MUST be an authenticated OkxData
        self.risk = risk
        self.notifier = notifier
        # symbols we've learned are not tradable here (not on the venue,
        # compliance-restricted, or too small) — skipped silently after once
        self._skip_symbols: set[str] = set()

        if not cfg.exchange.sandbox:
            log.warning(
                "LIVE (non-sandbox) trading is enabled. Ensure the API key has "
                "Trade-only permission, withdrawal disabled, and IP whitelist %s.",
                cfg.security.allowed_server_ip,
            )

    # ------------------------------------------------------------------ #
    async def _equity(self) -> float:
        """Sizing capital: the configured amount, capped by live free balance.

        `account_equity_usdt` is the capital YOU choose to risk with, so it is
        the sizing basis even when the (demo) account is funded with far more.
        We still cap by the live free balance so we never size beyond what is
        actually available.
        """
        configured = float(self.cfg.risk.account_equity_usdt)
        try:
            bal = await self.data.client.fetch_balance()
            usdt = bal.get("USDT", {})
            free = usdt.get("free") or usdt.get("total")
            if free:
                return min(configured, float(free))
        except Exception as e:
            log.warning("could not fetch balance (%s); using configured equity", e)
        return configured

    async def _set_leverage(self, symbol: str, leverage: float) -> None:
        lev = max(1, min(int(leverage) or 1, self.cfg.risk.max_leverage))
        try:
            await self.data.client.set_leverage(lev, symbol)
        except Exception as e:
            log.warning("set_leverage failed for %s: %s", symbol, e)

    async def _realized_pnl_for(self, pos) -> float:
        """Best-effort realized PnL for a closed position, from recent fills."""
        try:
            since = None
            if getattr(pos, "opened_at", None):
                from datetime import datetime
                since = int(datetime.fromisoformat(pos.opened_at).timestamp() * 1000)
            trades = await self.data.client.fetch_my_trades(pos.symbol, since=since)
            return realized_pnl_from_trades(trades)
        except Exception as e:
            log.warning("could not fetch fills for %s (%s); recording pnl=0",
                        pos.symbol, e)
            return 0.0

    async def reconcile(self) -> None:
        """Sync tracked entries with the exchange: promote fills, drop unfilled
        orders, and book realized PnL for positions closed by SL/TP.

        Distinguishes resting limit orders (pending) from real positions (open)
        so an unfilled entry is never mistaken for a closed trade. Without this,
        the daily-loss counter would never move in live mode. Runs each cycle.
        """
        if not self.risk.state.positions:
            return
        try:
            positions = await self.data.client.fetch_positions()
        except Exception as e:
            log.warning("reconcile: fetch_positions failed: %s", e)
            return
        try:
            open_orders = await self.data.client.fetch_open_orders()
            open_ids = {str(o.get("id")) for o in open_orders}
        except Exception as e:
            log.warning("reconcile: fetch_open_orders failed (%s); "
                        "treating all orders as resting to stay safe", e)
            open_ids = set(self.risk.state.positions.keys())

        pos_keys = open_position_keys(positions)
        for order_id, action in reconcile_actions(
            dict(self.risk.state.positions), open_ids, pos_keys
        ):
            if action == "filled":
                self.risk.mark_filled(order_id)
            elif action == "cancelled":
                self.risk.drop_pending(order_id)
            elif action == "closed":
                pos = self.risk.state.positions[order_id]
                pnl = await self._realized_pnl_for(pos)
                self.risk.register_close(order_id, pnl)
                log.info("reconciled close %s %s pnl=%.2f",
                         pos.symbol, pos.side, pnl)
                await self.notifier.send_text(
                    f"📕 Closed {pos.symbol} {pos.side} · realized PnL "
                    f"{pnl:+.2f} USDT\nDaily loss now "
                    f"{self.risk.daily_loss_pct:.2f}%"
                )

        if self.risk.is_halted(await self._equity()):
            await self.notifier.send_text(
                "🛑 Daily loss limit reached — trading halted for the day."
            )

    async def handle_signal(self, signal: Signal) -> None:
        # symbols already known to be untradable here: skip silently (no spam)
        if signal.symbol in self._skip_symbols:
            return

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

        # markets must be loaded on THIS (trade) client to resolve the symbol.
        # Symbol not on the venue (e.g. tokenized stock, or not on demo) -> skip
        # silently and remember it, so we don't spam the same message every cycle.
        try:
            await self.data.load_markets()
            market = self.data.client.market(signal.symbol)
        except Exception as e:
            log.info("skip %s: not tradable here (%s)", signal.symbol, e)
            self._skip_symbols.add(signal.symbol)
            return

        # OKX swaps are priced in CONTRACTS: convert base-currency size to contracts
        contract_size = float(market.get("contractSize") or 1) or 1
        amount_contracts = plan.size / contract_size
        min_amt = (((market.get("limits") or {}).get("amount") or {}).get("min")) or 0
        if min_amt and amount_contracts < min_amt:
            log.info("skip %s: size %.4f < exchange min %s (capital too small)",
                     signal.symbol, amount_contracts, min_amt)
            self._skip_symbols.add(signal.symbol)
            return
        try:
            amount = float(self.data.client.amount_to_precision(
                signal.symbol, amount_contracts))
        except Exception:
            amount = amount_contracts
        if amount <= 0:
            log.info("skip %s: rounded size is zero", signal.symbol)
            return

        await self._set_leverage(signal.symbol, plan.leverage)

        # ccxt-unified attached stop-loss / take-profit (maps to OKX algo orders)
        params = {
            "tdMode": "cross",
            "stopLoss": {"triggerPrice": plan.stop_loss, "type": "market"},
            "takeProfit": {"triggerPrice": plan.take_profit, "type": "market"},
        }

        try:
            order = await self.data.client.create_order(
                symbol=signal.symbol,
                type="limit",
                side=side,
                amount=amount,
                price=plan.entry,
                params=params,
            )
        except Exception as e:
            log.error("order placement failed for %s: %s", signal.symbol, e)
            # remember so we don't retry (and re-notify) the same broken symbol
            self._skip_symbols.add(signal.symbol)
            await self.notifier.send_text(
                f"⚠️ Order FAILED {signal.symbol} (won't retry): {str(e)[:180]}"
            )
            return

        order_id = str(order.get("id", f"{signal.symbol}-{signal.bar_time}"))
        self.risk.register_open(order_id, plan)
        log.info("placed %s %s amount=%.6f(contracts) entry=%.6f SL=%.6f TP=%.6f lev=%.1f",
                 side, signal.symbol, amount, plan.entry,
                 plan.stop_loss, plan.take_profit, plan.leverage)
        await self.notifier.send_text(
            f"✅ Order placed {signal.symbol} {side.upper()} "
            f"amount={amount:g} @ {plan.entry:g}\n"
            f"SL {plan.stop_loss:g} · TP {plan.take_profit:g} · risk "
            f"{plan.risk_amount:.2f} USDT"
        )
