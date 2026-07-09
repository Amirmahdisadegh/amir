"""Telegram alerts via aiogram, with per-signal cooldown.

Falls back to logging if Telegram is disabled or aiogram is missing, so the
scanner keeps working without a bot configured.
"""
from __future__ import annotations

import html
import logging
import time

from .config import RiskCfg, TelegramCfg
from .risk import estimate_trade
from .signals import SetupType, Side, Signal

log = logging.getLogger("okx_scanner.notifier")

try:
    from aiogram import Bot
    from aiogram.enums import ParseMode
    _HAS_AIOGRAM = True
except ImportError:  # pragma: no cover
    _HAS_AIOGRAM = False


def quality_label(score: float) -> str:
    """Plain-language quality tag for a signal score."""
    if score >= 75:
        return "عالی ✅"
    if score >= 65:
        return "خوب ✅"
    if score >= 50:
        return "متوسط ⚠️"
    return "ضعیف ❌"


def _fmt_money(x: float) -> str:
    return f"{x:,.2f}"


def format_signal(sig: Signal, risk: RiskCfg | None = None) -> str:
    direction = "🟢 خرید (LONG)" if sig.side is Side.LONG else "🔴 فروش (SHORT)"
    setup_name = "FTR" if sig.setup is SetupType.FTR else "Flag Limit"
    vol_note = "  ·  📊 تأیید حجم" if "volume-confirmed" in sig.notes else ""

    msg = (
        f"⚡️ <b>سیگنال جدید</b> — {direction}\n"
        f"<b>{html.escape(sig.symbol)}</b>  ·  تایم {sig.timeframe}  ·  {setup_name}\n"
        f"کیفیت: <b>{quality_label(sig.score)}</b> ({sig.score:.0f}/100){vol_note}\n"
        f"───────────────\n"
        f"قیمت الان: <code>{sig.price:g}</code>\n"
        f"💰 بخر نزدیک: <code>{sig.entry:g}</code>\n"
        f"🛑 حد ضرر: <code>{sig.stop_loss:g}</code>\n"
        f"🎯 هدف سود: <code>{sig.take_profit:g}</code>\n"
        f"نسبت سود به ضرر: <b>{sig.risk_reward:.1f} برابر</b>"
    )

    if risk is not None:
        est = estimate_trade(sig, risk.account_equity_usdt, risk.risk_per_trade_pct)
        if est:
            coin = html.escape(sig.symbol.split("/")[0])
            msg += (
                f"\n───────────────\n"
                f"📊 <b>پیشنهاد</b> (سرمایه {_fmt_money(risk.account_equity_usdt)}$ "
                f"· ریسک {risk.risk_per_trade_pct:g}٪):\n"
                f"• حجم خرید: ~{est['size']:,.4g} {coin}  (~{_fmt_money(est['notional'])}$)\n"
                f"• اگر ضرر خورد: حدود <b>-{_fmt_money(est['risk_amount'])}$</b>\n"
                f"• اگر به هدف رسید: حدود <b>+{_fmt_money(est['profit_amount'])}$</b>"
            )

    msg += "\n<i>Mode 1 — دستی معامله کن و خودت هم بررسی کن.</i>"
    return msg


class TelegramNotifier:
    def __init__(self, cfg: TelegramCfg, risk: RiskCfg | None = None):
        self.cfg = cfg
        self.risk = risk           # used to add the plain-money trade preview
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
        text = format_signal(sig, self.risk)
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
