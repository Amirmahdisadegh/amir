"""Historical backtest of the RTM strategy on OKX data.

Event-driven, single-position-per-symbol simulation:
  * At each closed bar, run the same RTM detectors used live on the visible
    window (no look-ahead: only candles up to and including bar i are used).
  * A signal places a pending LIMIT at its entry; it fills if a later bar
    trades through the entry price within an expiry window.
  * Once filled, SL/TP are monitored bar-by-bar. If a single bar spans both,
    the stop is assumed hit first (conservative).
  * Sizing uses the same fixed-fractional risk rule as live trading.

Outputs real stats: win rate, profit factor, max drawdown, avg R:R, expectancy.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

import numpy as np
import pandas as pd

from .config import Config
from .data import OkxData
from .indicators import atr, to_dataframe
from .rtm import detect_signals
from .signals import Side, Signal

log = logging.getLogger("okx_scanner.backtest")

WARMUP = 60           # bars before we start detecting
ENTRY_EXPIRY_BARS = 20  # cancel a pending entry if unfilled within this many bars


@dataclass
class Trade:
    symbol: str
    side: Side
    setup: str
    entry: float
    stop: float
    take_profit: float
    size: float
    entry_time: int
    exit_time: int = 0
    exit_price: float = 0.0
    pnl: float = 0.0
    r_multiple: float = 0.0
    outcome: str = ""     # "tp" | "sl" | "expired-open"


@dataclass
class BacktestResult:
    symbol: str
    trades: list[Trade] = field(default_factory=list)
    equity_curve: list[float] = field(default_factory=list)
    starting_equity: float = 0.0

    # -- derived stats --
    def stats(self) -> dict:
        closed = [t for t in self.trades if t.outcome in ("tp", "sl")]
        n = len(closed)
        wins = [t for t in closed if t.pnl > 0]
        losses = [t for t in closed if t.pnl <= 0]
        gross_win = sum(t.pnl for t in wins)
        gross_loss = -sum(t.pnl for t in losses)
        eq = np.array(self.equity_curve) if self.equity_curve else np.array(
            [self.starting_equity])
        peak = np.maximum.accumulate(eq)
        dd = (peak - eq) / np.where(peak == 0, 1, peak)
        final = float(eq[-1])
        return {
            "symbol": self.symbol,
            "trades": n,
            "wins": len(wins),
            "losses": len(losses),
            "win_rate_pct": round(len(wins) / n * 100, 2) if n else 0.0,
            "profit_factor": round(gross_win / gross_loss, 2) if gross_loss else float("inf"),
            "avg_rr": round(np.mean([t.r_multiple for t in closed]), 2) if n else 0.0,
            "expectancy_r": round(np.mean([t.r_multiple for t in closed]), 3) if n else 0.0,
            "max_drawdown_pct": round(float(dd.max()) * 100, 2) if len(eq) else 0.0,
            "return_pct": round((final / self.starting_equity - 1) * 100, 2)
            if self.starting_equity else 0.0,
            "final_equity": round(final, 2),
        }


class Backtester:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.risk_pct = cfg.risk.risk_per_trade_pct

    def _size(self, equity: float, entry: float, stop: float) -> float:
        dist = abs(entry - stop)
        if dist <= 0:
            return 0.0
        return (equity * self.risk_pct / 100.0) / dist

    def run_symbol(self, symbol: str, ohlcv: list[list]) -> BacktestResult:
        df = to_dataframe(ohlcv)
        atr_series = atr(df, self.cfg.risk.atr_period)
        n = len(df)
        result = BacktestResult(symbol=symbol,
                                starting_equity=self.cfg.backtest.starting_equity)
        equity = self.cfg.backtest.starting_equity

        highs = df["high"].to_numpy()
        lows = df["low"].to_numpy()
        times = df["timestamp"].to_numpy()

        pending: Signal | None = None
        pending_bar = -1
        open_trade: Trade | None = None

        for i in range(WARMUP, n):
            # ---- manage an open trade against this bar ----
            if open_trade is not None:
                hit_sl = lows[i] <= open_trade.stop if open_trade.side is Side.LONG \
                    else highs[i] >= open_trade.stop
                hit_tp = highs[i] >= open_trade.take_profit if open_trade.side is Side.LONG \
                    else lows[i] <= open_trade.take_profit
                exit_price = None
                if hit_sl:                      # conservative: SL wins ties
                    exit_price, open_trade.outcome = open_trade.stop, "sl"
                elif hit_tp:
                    exit_price, open_trade.outcome = open_trade.take_profit, "tp"
                if exit_price is not None:
                    d = 1 if open_trade.side is Side.LONG else -1
                    open_trade.exit_price = exit_price
                    open_trade.exit_time = int(times[i])
                    open_trade.pnl = d * (exit_price - open_trade.entry) * open_trade.size
                    risk_amt = equity * self.risk_pct / 100.0
                    open_trade.r_multiple = open_trade.pnl / risk_amt if risk_amt else 0.0
                    equity += open_trade.pnl
                    result.trades.append(open_trade)
                    open_trade = None

            # ---- try to fill a pending entry ----
            if open_trade is None and pending is not None:
                if i - pending_bar > ENTRY_EXPIRY_BARS:
                    pending = None
                elif lows[i] <= pending.entry <= highs[i]:
                    size = self._size(equity, pending.entry, pending.stop_loss)
                    if size > 0:
                        open_trade = Trade(
                            symbol=symbol, side=pending.side, setup=pending.setup.value,
                            entry=pending.entry, stop=pending.stop_loss,
                            take_profit=pending.take_profit, size=size,
                            entry_time=int(times[i]),
                        )
                    pending = None

            # ---- detect on the visible window (no look-ahead) ----
            if open_trade is None and pending is None:
                window = df.iloc[: i + 1]
                atr_win = atr_series.iloc[: i + 1]
                sigs = detect_signals(window, atr_win, self.cfg.rtm,
                                      symbol, self.cfg.backtest.timeframe)
                if sigs:
                    pending = max(sigs, key=lambda s: s.score)
                    pending_bar = i

            result.equity_curve.append(equity)

        return result

    async def run(self, data: OkxData) -> list[BacktestResult]:
        bt = self.cfg.backtest
        since = data.client.milliseconds() - bt.since_days * 24 * 60 * 60 * 1000
        results: list[BacktestResult] = []
        for symbol in bt.symbols:
            log.info("backtest fetching %s %s (%d days)...",
                     symbol, bt.timeframe, bt.since_days)
            ohlcv = await data.fetch_ohlcv_history(symbol, bt.timeframe, since)
            if len(ohlcv) < WARMUP + 20:
                log.warning("not enough data for %s (%d bars)", symbol, len(ohlcv))
                continue
            results.append(self.run_symbol(symbol, ohlcv))
        return results


def print_report(results: list[BacktestResult]) -> None:
    try:
        from tabulate import tabulate
    except ImportError:
        tabulate = None

    rows = [r.stats() for r in results]
    if not rows:
        print("No backtest results (insufficient data or no trades).")
        return

    # aggregate
    total_trades = sum(r["trades"] for r in rows)
    total_wins = sum(r["wins"] for r in rows)
    agg = {
        "symbol": "ALL",
        "trades": total_trades,
        "wins": total_wins,
        "losses": total_trades - total_wins,
        "win_rate_pct": round(total_wins / total_trades * 100, 2) if total_trades else 0.0,
        "profit_factor": "-",
        "avg_rr": round(np.mean([r["avg_rr"] for r in rows]), 2),
        "expectancy_r": round(np.mean([r["expectancy_r"] for r in rows]), 3),
        "max_drawdown_pct": max(r["max_drawdown_pct"] for r in rows),
        "return_pct": round(np.mean([r["return_pct"] for r in rows]), 2),
        "final_equity": "-",
    }
    rows.append(agg)

    headers = ["symbol", "trades", "wins", "losses", "win_rate_pct",
               "profit_factor", "avg_rr", "expectancy_r", "max_drawdown_pct",
               "return_pct", "final_equity"]
    table = [[r[h] for h in headers] for r in rows]
    print("\n=== RTM Backtest Report ===")
    if tabulate:
        print(tabulate(table, headers=headers, tablefmt="github"))
    else:
        print("\t".join(headers))
        for row in table:
            print("\t".join(str(x) for x in row))
    print()
