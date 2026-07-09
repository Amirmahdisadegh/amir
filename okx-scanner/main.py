#!/usr/bin/env python3
"""OKX RTM Scanner — entry point.

Usage:
    python main.py scan                # Mode 1/2 per config: scan + alert (+ live)
    python main.py backtest            # run the historical backtest + report
    python main.py universe            # print the symbols that would be scanned
    python main.py --config my.yaml scan

Mode (scan/live) is driven by `mode:` in config.yaml. Live mode additionally
requires complete OKX credentials in .env and enforces all risk limits.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import sys

from okx_scanner.backtest import Backtester, print_report
from okx_scanner.config import Config, load_config
from okx_scanner.data import OkxData
from okx_scanner.executor import Executor
from okx_scanner.notifier import TelegramNotifier
from okx_scanner.risk import RiskManager
from okx_scanner.scanner import Scanner


def setup_logging(level: str = "INFO", log_file: str = "logs/okx-scanner.log") -> None:
    fmt = logging.Formatter(
        "%(asctime)s %(levelname)-7s %(name)s | %(message)s", datefmt="%H:%M:%S")
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    console = logging.StreamHandler()
    console.setFormatter(fmt)
    root.addHandler(console)

    # rotating file log so a long-running server keeps history without growth
    try:
        from logging.handlers import RotatingFileHandler
        from pathlib import Path
        Path(log_file).parent.mkdir(parents=True, exist_ok=True)
        fh = RotatingFileHandler(log_file, maxBytes=5_000_000, backupCount=5)
        fh.setFormatter(fmt)
        root.addHandler(fh)
    except Exception as e:  # file logging is best-effort
        root.warning("file logging disabled: %s", e)


async def cmd_universe(cfg: Config) -> None:
    async with OkxData(cfg) as data:
        symbols = await data.build_universe()
    print(f"\nUniverse ({len(symbols)} symbols):")
    for s in symbols:
        print(" ", s)


async def cmd_backtest(cfg: Config) -> None:
    bt = Backtester(cfg)
    async with OkxData(cfg) as data:
        results = await bt.run(data)
    print_report(results)


async def cmd_scan(cfg: Config) -> None:
    notifier = TelegramNotifier(cfg.telegram, risk=cfg.risk)
    live = cfg.mode == "live"

    if live:
        if not cfg.credentials.is_complete:
            print("ERROR: live mode requires OKX_API_KEY/SECRET/PASSPHRASE in .env",
                  file=sys.stderr)
            sys.exit(2)
        logging.getLogger("main").warning(
            "LIVE MODE. sandbox=%s. Risk limits are enforced.", cfg.exchange.sandbox)

    # Market data ALWAYS comes from production (public, real liquidity).
    data = OkxData(cfg)
    # In live mode, a separate authenticated client handles execution and may
    # point at OKX Demo (sandbox) per config.
    trade_data = None
    executor = None
    if live:
        trade_data = OkxData(cfg, authenticated=True)
        risk = RiskManager(cfg.risk)
        executor = Executor(cfg, trade_data, risk, notifier)

    scanner = Scanner(cfg, data, notifier, executor=executor)
    try:
        await scanner.run_forever()
    except (KeyboardInterrupt, asyncio.CancelledError):
        logging.getLogger("main").info("shutting down...")
    finally:
        await data.close()
        if trade_data is not None:
            await trade_data.close()
        await notifier.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="OKX RTM Scanner")
    parser.add_argument("command", choices=["scan", "backtest", "universe"],
                        help="what to run")
    parser.add_argument("--config", default="config.yaml", help="config file path")
    parser.add_argument("--log", default="INFO", help="log level")
    args = parser.parse_args()

    setup_logging(args.log)
    cfg = load_config(args.config)

    runner = {
        "scan": cmd_scan,
        "backtest": cmd_backtest,
        "universe": cmd_universe,
    }[args.command]

    try:
        asyncio.run(runner(cfg))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
