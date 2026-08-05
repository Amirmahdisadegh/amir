"""The scan loop: universe -> multi-TF OHLCV -> RTM detection -> alerts.

Mode 1 (scan): detect + Telegram alert only.
Mode 2 (live): additionally hand qualifying signals to the executor under
full risk control. The executor is optional and injected by main.py.
"""
from __future__ import annotations

import asyncio
import logging
from collections import defaultdict

from .config import Config
from .data import OkxData
from .indicators import atr, to_dataframe, trend_bias
from .notifier import TelegramNotifier
from .rtm import detect_signals
from .signals import Signal

log = logging.getLogger("okx_scanner.scanner")


class Scanner:
    def __init__(self, cfg: Config, data: OkxData, notifier: TelegramNotifier,
                 executor=None):
        self.cfg = cfg
        self.data = data
        self.notifier = notifier
        self.executor = executor
        self._universe: list[str] = []
        self._last_sent_count = 0        # signals sent in the last cycle
        self._cycles = 0

    async def refresh_universe(self) -> None:
        self._universe = await self.data.build_universe()

    # ------------------------------------------------------------------ #
    def _scan_symbol_frames(self, symbol: str,
                            frames: dict[str, list]) -> list[Signal]:
        """Run RTM detection across all timeframes for one symbol.

        The highest configured timeframe defines the dominant trend (HTF bias),
        which is fed into every lower-timeframe detection so setups aligned with
        the big-picture trend score higher (and can be hard-required in config).
        """
        # highest timeframe = last in the configured list
        htf = self.cfg.scan.timeframes[-1] if self.cfg.scan.timeframes else None
        htf_bias = 0
        if htf and frames.get(htf) and len(frames[htf]) >= 30:
            htf_df = to_dataframe(frames[htf])
            htf_bias = trend_bias(htf_df["close"], self.cfg.rtm.trend_ema_period)

        found: list[Signal] = []
        for tf, ohlcv in frames.items():
            if not ohlcv or len(ohlcv) < 30:
                continue
            df = to_dataframe(ohlcv)
            atr_series = atr(df, self.cfg.risk.atr_period)
            # a signal ON the htf itself uses its own trend as the bias
            bias = htf_bias
            try:
                found.extend(
                    detect_signals(df, atr_series, self.cfg.rtm, symbol, tf, bias)
                )
            except Exception as e:  # one bad symbol must not kill the scan
                log.exception("detection failed for %s %s: %s", symbol, tf, e)
        return found

    def _apply_confluence(self, signals: list[Signal]) -> list[Signal]:
        """Require a setup to appear on >= min_timeframe_confluence timeframes."""
        need = self.cfg.scan.min_timeframe_confluence
        if need <= 1:
            return signals
        buckets: dict[tuple, list[Signal]] = defaultdict(list)
        for s in signals:
            buckets[(s.symbol, s.setup, s.side)].append(s)
        out: list[Signal] = []
        for group in buckets.values():
            tfs = {s.timeframe for s in group}
            if len(tfs) >= need:
                out.append(max(group, key=lambda s: s.score))  # best of the group
        return out

    async def scan_once(self) -> list[Signal]:
        if not self._universe:
            await self.refresh_universe()

        # In live mode, first book any positions closed since last cycle so the
        # daily-loss guard and open-position count are up to date.
        if self.executor is not None:
            await self.executor.reconcile()

        all_signals: list[Signal] = []
        tfs = self.cfg.scan.timeframes

        async def handle(symbol: str):
            frames = await self.data.fetch_multi_tf(symbol, tfs)
            return self._scan_symbol_frames(symbol, frames)

        results = await asyncio.gather(
            *(handle(s) for s in self._universe), return_exceptions=True
        )
        for r in results:
            if isinstance(r, Exception):
                log.error("symbol task failed: %s", r)
                continue
            all_signals.extend(r)

        signals = self._apply_confluence(all_signals)

        # drop weak setups below the score threshold (noise control)
        min_score = self.cfg.scan.min_score
        strong = [s for s in signals if s.score >= min_score]
        strong.sort(key=lambda s: s.score, reverse=True)

        for sig in strong:
            await self.notifier.send_signal(sig)
            if self.executor is not None:
                await self.executor.handle_signal(sig)

        self._last_sent_count = len(strong)
        self._cycles += 1
        log.info("scan complete: %d raw / %d confluence / %d sent (score>=%g)",
                 len(all_signals), len(signals), len(strong), min_score)
        return strong

    async def _heartbeat(self) -> None:
        """Compose and send a periodic 'alive' status message."""
        lines = [
            "💓 <b>ربات زنده است</b>",
            f"حالت: {self.cfg.mode}  ·  کوین‌ها: {len(self._universe)}",
            f"اسکن‌های انجام‌شده: {self._cycles}",
            f"سیگنال‌های آخرین اسکن: {self._last_sent_count}",
        ]
        if self.executor is not None:
            risk = self.executor.risk
            lines.append(
                f"پوزیشن‌های باز: {len(risk.state.positions)}  ·  "
                f"ضرر روز: {risk.daily_loss_pct:.2f}%"
            )
        await self.notifier.send_text("\n".join(lines))

    async def run_forever(self) -> None:
        import time
        interval = self.cfg.scan.poll_interval_sec
        hb_secs = self.cfg.telegram.heartbeat_hours * 3600
        last_hb = time.time()
        log.info("scanner started in '%s' mode, interval=%ss",
                 self.cfg.mode, interval)
        await self.notifier.send_text(
            f"🤖 OKX RTM scanner online — mode: {self.cfg.mode}"
        )
        while True:
            try:
                await self.scan_once()
            except Exception as e:
                log.exception("scan cycle error: %s", e)
            # heartbeat: let the operator know the bot is still alive
            if hb_secs > 0 and time.time() - last_hb >= hb_secs:
                try:
                    await self._heartbeat()
                except Exception as e:
                    log.warning("heartbeat failed: %s", e)
                last_hb = time.time()
            # periodically refresh the universe (volumes drift)
            await asyncio.sleep(interval)
            try:
                await self.refresh_universe()
            except Exception as e:
                log.warning("universe refresh failed: %s", e)
