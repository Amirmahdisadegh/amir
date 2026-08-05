"""Configuration loading: merges config.yaml with secrets from .env.

All settings are exposed as frozen dataclasses so the rest of the code
gets attribute access and type hints instead of raw dicts.
"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

try:  # optional: load .env if python-dotenv is installed
    from dotenv import load_dotenv
except ImportError:  # pragma: no cover
    def load_dotenv(*_a, **_k):  # type: ignore
        return False


# --------------------------------------------------------------------------- #
#  Dataclasses mirroring config.example.yaml
# --------------------------------------------------------------------------- #
@dataclass(frozen=True)
class ExchangeCfg:
    id: str = "okx"
    sandbox: bool = True
    market_type: str = "swap"
    quote: str = "USDT"
    rate_limit_ms: int = 200
    max_concurrency: int = 8


@dataclass(frozen=True)
class UniverseCfg:
    top_by_volume: int = 80
    min_quote_volume: float = 5_000_000
    include: list[str] = field(default_factory=list)
    exclude: list[str] = field(default_factory=list)
    exclude_non_crypto: bool = True   # drop tokenized stocks / commodities / indices


@dataclass(frozen=True)
class ScanCfg:
    timeframes: list[str] = field(default_factory=lambda: ["15m", "1h", "4h"])
    ohlcv_limit: int = 300
    poll_interval_sec: int = 300
    min_timeframe_confluence: int = 1
    min_score: float = 0.0        # only alert signals scoring >= this (0 = all)


@dataclass(frozen=True)
class RtmCfg:
    swing_lookback: int = 2
    base_max_body_ratio: float = 0.45
    base_max_candles: int = 3
    leg_min_body_ratio: float = 0.55
    min_leg_atr_mult: float = 1.2
    confirm_vol_mult: float = 1.3
    max_dist_to_zone_atr: float = 1.5
    min_risk_reward: float = 1.8
    zone_freshness_bars: int = 60
    # --- confirmation layer (makes signals "smarter") ---
    trend_ema_period: int = 50       # EMA used for same-timeframe trend bias
    rsi_period: int = 14
    require_trend_alignment: bool = False  # hard-reject counter-trend setups
    require_htf_alignment: bool = False    # hard-reject vs higher-timeframe trend


@dataclass(frozen=True)
class RiskCfg:
    account_equity_usdt: float = 1000
    risk_per_trade_pct: float = 1.0
    atr_period: int = 14
    atr_sl_mult: float = 1.5
    take_profit_rr: float = 2.0
    max_open_positions: int = 3
    max_positions_per_symbol: int = 1
    daily_loss_limit_pct: float = 3.0
    max_leverage: int = 3


@dataclass(frozen=True)
class TelegramCfg:
    enabled: bool = True
    alert_cooldown_sec: int = 1800
    heartbeat_hours: float = 6.0      # periodic "alive" message (0 = off)
    bot_token: str = ""
    chat_id: str = ""


@dataclass(frozen=True)
class BacktestCfg:
    symbols: list[str] = field(default_factory=lambda: ["BTC/USDT:USDT"])
    timeframe: str = "1h"
    since_days: int = 120
    starting_equity: float = 1000
    fee_pct: float = 0.05        # taker fee per side, % of notional (OKX ~0.05%)
    slippage_pct: float = 0.02   # slippage on market (stop) fills, % of price
    max_open_positions: int = 3  # portfolio-wide cap in the multi-symbol sim


@dataclass(frozen=True)
class SecurityCfg:
    allowed_server_ip: str = ""


@dataclass(frozen=True)
class OkxCredentials:
    api_key: str = ""
    api_secret: str = ""
    passphrase: str = ""

    @property
    def is_complete(self) -> bool:
        return bool(self.api_key and self.api_secret and self.passphrase)


@dataclass(frozen=True)
class Config:
    mode: str
    exchange: ExchangeCfg
    universe: UniverseCfg
    scan: ScanCfg
    rtm: RtmCfg
    risk: RiskCfg
    telegram: TelegramCfg
    backtest: BacktestCfg
    security: SecurityCfg
    credentials: OkxCredentials


# --------------------------------------------------------------------------- #
#  Loading helpers
# --------------------------------------------------------------------------- #
def _section(raw: dict[str, Any], key: str) -> dict[str, Any]:
    val = raw.get(key) or {}
    if not isinstance(val, dict):
        raise ValueError(f"config section '{key}' must be a mapping")
    return val


def _filter_kwargs(cls, data: dict[str, Any]) -> dict[str, Any]:
    """Keep only keys that the dataclass accepts (ignore unknown keys)."""
    valid = {f.name for f in cls.__dataclass_fields__.values()}  # type: ignore[attr-defined]
    return {k: v for k, v in data.items() if k in valid}


def load_config(path: str | Path = "config.yaml") -> Config:
    """Load config.yaml (falling back to config.example.yaml) plus .env secrets."""
    load_dotenv()

    p = Path(path)
    if not p.exists():
        example = p.with_name("config.example.yaml")
        if example.exists():
            p = example
        else:
            raise FileNotFoundError(
                f"Neither {path} nor config.example.yaml found. "
                "Copy config.example.yaml to config.yaml first."
            )

    with p.open("r", encoding="utf-8") as fh:
        raw = yaml.safe_load(fh) or {}

    telegram_raw = _section(raw, "telegram")
    telegram = TelegramCfg(
        **_filter_kwargs(TelegramCfg, telegram_raw),
        bot_token=os.getenv("TELEGRAM_BOT_TOKEN", ""),
        chat_id=os.getenv("TELEGRAM_CHAT_ID", ""),
    )

    credentials = OkxCredentials(
        api_key=os.getenv("OKX_API_KEY", ""),
        api_secret=os.getenv("OKX_API_SECRET", ""),
        passphrase=os.getenv("OKX_API_PASSPHRASE", ""),
    )

    return Config(
        mode=str(raw.get("mode", "scan")).lower(),
        exchange=ExchangeCfg(**_filter_kwargs(ExchangeCfg, _section(raw, "exchange"))),
        universe=UniverseCfg(**_filter_kwargs(UniverseCfg, _section(raw, "universe"))),
        scan=ScanCfg(**_filter_kwargs(ScanCfg, _section(raw, "scan"))),
        rtm=RtmCfg(**_filter_kwargs(RtmCfg, _section(raw, "rtm"))),
        risk=RiskCfg(**_filter_kwargs(RiskCfg, _section(raw, "risk"))),
        telegram=telegram,
        backtest=BacktestCfg(**_filter_kwargs(BacktestCfg, _section(raw, "backtest"))),
        security=SecurityCfg(**_filter_kwargs(SecurityCfg, _section(raw, "security"))),
        credentials=credentials,
    )
