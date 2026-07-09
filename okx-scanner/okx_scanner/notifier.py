"""Telegram alerts via aiogram, with per-signal cooldown.

Falls back to logging if Telegram is disabled or aiogram is missing, so the
scanner keeps working without a bot configured.
"""
from __future__ import annotations

import html
import logging
import time

from .config import TelegramCfg
from .signals import SetupType, Side, Signal

log = logging.getLogger("okx_scanner.notifier")

try:
    from aiogram import Bot
    from aiogram.enums import ParseMode
    _HAS_AIOGRAM = True
except ImportError:  # pragma: no cover
    _HAS_AIOGRAM = False


def format_signal(sig: Signal) -> str:
    arrow = "🟢 LONG" if sig.side is Side.LONG else "🔴 SHORT"
    setup_name = "FTR (Failure To Return)" if sig.setup is SetupType.FTR else "Flag Limit"
    notes = f"\n📝 {', '.join(sig.notes)}" if sig.notes else ""
    return (
        f"⚡️ <b>RTM Setup</b> — {arrow}\n"
        f"<b>{html.escape(sig.symbol)}</b>  ·  {sig.timeframe}\n"
        f"Setup: <b>{setup_name}</b>\n"
        f"───────────────\n"
        f"Entry: <code>{sig.entry:g}</code>\n"
        f"Stop:  <code>{sig.stop_loss:g}</code>\n"
        f"TP:    <code>{sig.take_profit:g}</code>\n"
        f"R:R:   <b>{sig.risk_reward:.2f}</b>   ·   Score: {sig.score:.0f}/100\n"
        f"ATR:   {sig.atr:g}   ·   Price: {sig.price:g}"
        f"{notes}\n"
        f"<i>Mode 1 — manual execution. Verify before trading.</i>"
    )


class TelegramNotifier:
    def __init__(self, cfg: TelegramCfg):
        self.cfg = cfg
        self._last_sent: dict[str, float] = {}
        self._bot = None
        self.active = False

        if not cfg.enabled:
            log.info("Telegram disabled in config.")
            return
        if not _HAS_AIOGRAM:
            log.warning("aiogram not installed — alerts will be logged only.")
            return
        if not (cfg.bot_token and cfg.chat_id):
            log.warning("TELEGRAM_BOT_TOKEN / CHAT_ID missing — alerts logged only.")
            return

        self._bot = Bot(token=cfg.bot_token)
        self.active = True

    def _on_cooldown(self, sig: Signal) -> bool:
        key = f"{sig.symbol}|{sig.timeframe}|{sig.setup.value}"
        now = time.time()
        last = self._last_sent.get(key, 0.0)
        if now - last < self.cfg.alert_cooldown_sec:
            return True
        self._last_sent[key] = now
        return False

    async def send_signal(self, sig: Signal) -> None:
        if self._on_cooldown(sig):
            return
        text = format_signal(sig)
        if not self.active or self._bot is None:
            log.info("[ALERT]\n%s", text)
            return
        try:
            await self._bot.send_message(
                self.cfg.chat_id, text, parse_mode=ParseMode.HTML
            )
        except Exception as e:  # never let a notify failure crash the scan
            log.error("Telegram send failed: %s", e)

    async def send_text(self, text: str) -> None:
        if not self.active or self._bot is None:
            log.info("[MSG] %s", text)
            return
        try:
            await self._bot.send_message(self.cfg.chat_id, text)
        except Exception as e:
            log.error("Telegram send failed: %s", e)

    async def close(self) -> None:
        if self._bot is not None:
            await self._bot.session.close()
