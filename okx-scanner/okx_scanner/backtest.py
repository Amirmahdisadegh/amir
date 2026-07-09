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
        self.fee_pct = cfg.backtest.fee_pct
        self.slippage_pct = cfg.backtest.slippage_pct

    def _size(self, equity: float, entry: float, stop: float) -> float:
        dist = abs(entry - stop)
        if dist <= 0:
            return 0.0
        return (equity * self.risk_pct / 100.0) / dist

    def _exit_price(self, trade: Trade, high: float, low: float):
        """Return (exit_price, outcome) if this bar closes the trade, else (None, '')."""
        long = trade.side is Side.LONG
        hit_sl = low <= trade.stop if long else high >= trade.stop
        hit_tp = high >= trade.take_profit if long else low <= trade.take_profit
        if hit_sl:                              # conservative: SL wins ties
            slip = self.slippage_pct / 100.0    # stop = market fill -> slippage
            price = trade.stop * (1 - slip) if long else trade.stop * (1 + slip)
            return price, "sl"
        if hit_tp:                              # take-profit = limit -> no slippage
            return trade.take_profit, "tp"
        return None, ""

    def _book_close(self, trade: Trade, exit_price: float, outcome: str,
                    exit_time: int, equity: float) -> float:
        """Finalize a trade; return realized PnL (net of fees)."""
        d = 1 if trade.side is Side.LONG else -1
        gross = d * (exit_price - trade.entry) * trade.size
        fee_rate = self.fee_pct / 100.0
        fees = (trade.size * trade.entry + trade.size * exit_price) * fee_rate
        trade.exit_price = exit_price
        trade.exit_time = exit_time
        trade.outcome = outcome
        trade.pnl = gross - fees
        risk_amt = equity * self.risk_pct / 100.0
        trade.r_multiple = trade.pnl / risk_amt if risk_amt else 0.0
        return trade.pnl

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
                exit_price, outcome = self._exit_price(open_trade, highs[i], lows[i])
                if exit_price is not None:
                    equity += self._book_close(open_trade, exit_price, outcome,
                                               int(times[i]), equity)
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
                # test only what the live bot would actually trade (score gate)
                sigs = [s for s in sigs if s.score >= self.cfg.scan.min_score]
                if sigs:
                    pending = max(sigs, key=lambda s: s.score)
                    pending_bar = i

            result.equity_curve.append(equity)

        return result

    def run_portfolio(self, symbol_ohlcv: dict[str, list]) -> BacktestResult:
        """Multi-symbol sim on a shared equity with a portfolio-wide open cap.

        All symbols are stepped on a unified timeline; at most
        `backtest.max_open_positions` trades are open at once across the book.
        """
        cap = self.cfg.backtest.max_open_positions
        result = BacktestResult(symbol="PORTFOLIO",
                                starting_equity=self.cfg.backtest.starting_equity)
        equity = self.cfg.backtest.starting_equity

        # per-symbol precomputed context
        ctx: dict[str, dict] = {}
        all_ts: set[int] = set()
        for symbol, ohlcv in symbol_ohlcv.items():
            df = to_dataframe(ohlcv)
            if len(df) < WARMUP + 5:
                continue
            times = df["timestamp"].to_numpy()
            ctx[symbol] = {
                "df": df,
                "atr": atr(df, self.cfg.risk.atr_period),
                "high": df["high"].to_numpy(),
                "low": df["low"].to_numpy(),
                "times": times,
                "ts_to_i": {int(t): i for i, t in enumerate(times)},
                "pending": None,
                "pending_bar": -1,
            }
            all_ts.update(int(t) for t in times)

        open_trades: dict[str, Trade] = {}
        timeline = sorted(all_ts)

        for t in timeline:
            for symbol in sorted(ctx.keys()):
                c = ctx[symbol]
                i = c["ts_to_i"].get(t)
                if i is None or i < WARMUP:
                    continue
                high, low = c["high"][i], c["low"][i]

                # 1) manage open trade
                trade = open_trades.get(symbol)
                if trade is not None:
                    exit_price, outcome = self._exit_price(trade, high, low)
                    if exit_price is not None:
                        equity += self._book_close(trade, exit_price, outcome, t, equity)
                        result.trades.append(trade)
                        del open_trades[symbol]
                        trade = None

                # 2) fill pending if a portfolio slot is free
                if trade is None and c["pending"] is not None:
                    if i - c["pending_bar"] > ENTRY_EXPIRY_BARS:
                        c["pending"] = None
                    elif len(open_trades) < cap and low <= c["pending"].entry <= high:
                        p = c["pending"]
                        size = self._size(equity, p.entry, p.stop_loss)
                        if size > 0:
                            open_trades[symbol] = Trade(
                                symbol=symbol, side=p.side, setup=p.setup.value,
                                entry=p.entry, stop=p.stop_loss,
                                take_profit=p.take_profit, size=size, entry_time=t,
                            )
                        c["pending"] = None

                # 3) detect (only worth it if a slot could open)
                if (symbol not in open_trades and c["pending"] is None
                        and len(open_trades) < cap):
                    sigs = detect_signals(c["df"].iloc[: i + 1], c["atr"].iloc[: i + 1],
                                          self.cfg.rtm, symbol,
                                          self.cfg.backtest.timeframe)
                    sigs = [s for s in sigs if s.score >= self.cfg.scan.min_score]
                    if sigs:
                        c["pending"] = max(sigs, key=lambda s: s.score)
                        c["pending_bar"] = i

            result.equity_curve.append(equity)

        return result

    def _cache_path(self, symbol: str, tf: str) -> "Path":
        from pathlib import Path
        safe = symbol.replace("/", "_").replace(":", "-")
        d = Path("data_cache")
        d.mkdir(exist_ok=True)
        return d / f"{safe}_{tf}_{self.cfg.backtest.since_days}d.json"

    async def _load_history(self, data: OkxData, symbol: str, since: int) -> list:
        """Fetch history, caching to disk so repeated backtests are instant.

        The cache is reused when written the same UTC day (calibration loops),
        avoiding a slow multi-minute re-download on every run.
        """
        import json
        import time as _t
        tf = self.cfg.backtest.timeframe
        path = self._cache_path(symbol, tf)
        if path.exists() and (_t.time() - path.stat().st_mtime) < 24 * 3600:
            try:
                return json.loads(path.read_text())
            except Exception:
                pass
        log.info("backtest fetching %s %s (%d days)...",
                 symbol, tf, self.cfg.backtest.since_days)
        ohlcv = await data.fetch_ohlcv_history(symbol, tf, since)
        try:
            path.write_text(json.dumps(ohlcv))
        except Exception as e:
            log.warning("could not cache %s: %s", symbol, e)
        return ohlcv

    async def run(self, data: OkxData) -> list[BacktestResult]:
        bt = self.cfg.backtest
        since = data.client.milliseconds() - bt.since_days * 24 * 60 * 60 * 1000
        results: list[BacktestResult] = []
        fetched: dict[str, list] = {}
        for symbol in bt.symbols:
            ohlcv = await self._load_history(data, symbol, since)
            if len(ohlcv) < WARMUP + 20:
                log.warning("not enough data for %s (%d bars)", symbol, len(ohlcv))
                continue
            fetched[symbol] = ohlcv
            results.append(self.run_symbol(symbol, ohlcv))

        # portfolio sim (shared equity + global open-position cap)
        if len(fetched) > 1:
            results.append(self.run_portfolio(fetched))
        return results


def print_report(results: list[BacktestResult]) -> None:
    try:
        from tabulate import tabulate
    except ImportError:
        tabulate = None

    all_stats = [r.stats() for r in results]
    if not all_stats:
        print("No backtest results (insufficient data or no trades).")
        return

    # Separate the portfolio row: it must NOT be folded into the per-symbol
    # aggregate (it already spans all symbols on shared equity).
    per_symbol = [s for s in all_stats if s["symbol"] != "PORTFOLIO"]
    portfolio = [s for s in all_stats if s["symbol"] == "PORTFOLIO"]

    rows = list(per_symbol)
    if per_symbol:
        total_trades = sum(r["trades"] for r in per_symbol)
        total_wins = sum(r["wins"] for r in per_symbol)
        rows.append({
            "symbol": "ALL (indep.)",
            "trades": total_trades,
            "wins": total_wins,
            "losses": total_trades - total_wins,
            "win_rate_pct": round(total_wins / total_trades * 100, 2) if total_trades else 0.0,
            "profit_factor": "-",
            "avg_rr": round(np.mean([r["avg_rr"] for r in per_symbol]), 2),
            "expectancy_r": round(np.mean([r["expectancy_r"] for r in per_symbol]), 3),
            "max_drawdown_pct": max(r["max_drawdown_pct"] for r in per_symbol),
            "return_pct": round(np.mean([r["return_pct"] for r in per_symbol]), 2),
            "final_equity": "-",
        })
    rows.extend(portfolio)  # realistic shared-equity result, shown last

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
