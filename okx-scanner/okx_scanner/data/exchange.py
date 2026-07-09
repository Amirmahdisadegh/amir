"""Async OKX data access built on ccxt.async_support.

Responsibilities:
  * build the tradable universe (top-N by 24h quote volume, filtered)
  * fetch multi-timeframe OHLCV concurrently while respecting rate limits
  * (live mode only) expose the authenticated client for the executor

No API keys are needed for any public data method; keys are only attached
when credentials are supplied AND the caller asks for a private client.
"""
from __future__ import annotations

import asyncio
import logging
import os
import ssl

import ccxt.async_support as ccxt

from ..config import Config

log = logging.getLogger("okx_scanner.data")


class OkxData:
    def __init__(self, cfg: Config, *, authenticated: bool = False):
        self.cfg = cfg
        self._authenticated = authenticated
        self._markets: dict | None = None

        params: dict = {
            "enableRateLimit": True,
            "timeout": 20_000,
            "options": {"defaultType": cfg.exchange.market_type},
        }
        if cfg.exchange.rate_limit_ms:
            params["rateLimit"] = cfg.exchange.rate_limit_ms

        if authenticated:
            creds = cfg.credentials
            if not creds.is_complete:
                raise RuntimeError(
                    "Authenticated client requested but OKX API credentials are "
                    "incomplete. Set OKX_API_KEY/SECRET/PASSPHRASE in .env."
                )
            params.update(
                apiKey=creds.api_key,
                secret=creds.api_secret,
                password=creds.passphrase,
            )

        self.client = ccxt.okx(params)
        self._apply_proxy_env()
        if cfg.exchange.sandbox:
            # OKX Demo Trading (paper). Applies to both data and trading.
            self.client.set_sandbox_mode(True)

        self._sem = asyncio.Semaphore(max(1, cfg.exchange.max_concurrency))

    def _apply_proxy_env(self) -> None:
        """Honour outbound HTTPS proxy + custom CA bundle from the environment.

        Lets the bot run behind a corporate/egress proxy without code changes.
        """
        proxy = os.getenv("HTTPS_PROXY") or os.getenv("https_proxy")
        if proxy:
            self.client.https_proxy = proxy
            log.info("using HTTPS proxy from environment")
        ca = (os.getenv("SSL_CERT_FILE") or os.getenv("REQUESTS_CA_BUNDLE")
              or os.getenv("CURL_CA_BUNDLE"))
        if ca and os.path.exists(ca):
            self.client.ssl_context = ssl.create_default_context(cafile=ca)
            log.info("using custom CA bundle for TLS verification")

    # ------------------------------------------------------------------ #
    async def load_markets(self, reload: bool = False) -> dict:
        if self._markets is None or reload:
            self._markets = await self.client.load_markets(reload)
        return self._markets

    async def build_universe(self) -> list[str]:
        """Return the list of symbols to scan, filtered & ranked by volume."""
        u = self.cfg.universe
        ex = self.cfg.exchange
        await self.load_markets()

        tickers = await self.client.fetch_tickers()

        rows: list[tuple[str, float]] = []
        for symbol, t in tickers.items():
            market = self.client.markets.get(symbol)
            if not market or not market.get("active", True):
                continue
            if market.get("quote") != ex.quote:
                continue
            want_swap = ex.market_type == "swap"
            if market.get("swap", False) != want_swap:
                continue
            if want_swap and market.get("spot", False):
                continue
            qv = t.get("quoteVolume") or 0.0
            if qv < u.min_quote_volume:
                continue
            if symbol in u.exclude:
                continue
            rows.append((symbol, float(qv)))

        rows.sort(key=lambda r: r[1], reverse=True)
        if u.top_by_volume and u.top_by_volume > 0:
            rows = rows[: u.top_by_volume]

        symbols = [s for s, _ in rows]
        for s in u.include:  # force-include, de-duplicated
            if s not in symbols and s in self.client.markets:
                symbols.append(s)

        log.info("universe: %d symbols (%s / %s)", len(symbols),
                 ex.market_type, ex.quote)
        return symbols

    # ------------------------------------------------------------------ #
    async def fetch_ohlcv(self, symbol: str, timeframe: str,
                          limit: int | None = None, since: int | None = None):
        limit = limit or self.cfg.scan.ohlcv_limit
        async with self._sem:
            for attempt in range(4):
                try:
                    return await self.client.fetch_ohlcv(
                        symbol, timeframe=timeframe, since=since, limit=limit
                    )
                except ccxt.RateLimitExceeded:
                    wait = 2 ** attempt
                    log.warning("rate limited on %s %s, backing off %ss",
                                symbol, timeframe, wait)
                    await asyncio.sleep(wait)
                except ccxt.NetworkError as e:
                    wait = 2 ** attempt
                    log.warning("network error %s %s: %s (retry in %ss)",
                                symbol, timeframe, e, wait)
                    await asyncio.sleep(wait)
                except ccxt.BadSymbol:
                    log.warning("bad symbol %s, skipping", symbol)
                    return []
            log.error("giving up on %s %s after retries", symbol, timeframe)
            return []

    async def fetch_ohlcv_history(self, symbol: str, timeframe: str,
                                  since_ms: int, page_limit: int = 300) -> list[list]:
        """Paginate OHLCV forward from `since_ms` up to now (for backtests)."""
        await self.load_markets()
        tf_ms = self.client.parse_timeframe(timeframe) * 1000
        all_rows: list[list] = []
        cursor = since_ms
        now = self.client.milliseconds()
        while cursor < now:
            batch = await self.fetch_ohlcv(symbol, timeframe, limit=page_limit,
                                           since=cursor)
            if not batch:
                break
            all_rows.extend(batch)
            cursor = batch[-1][0] + tf_ms
            if len(batch) < page_limit:
                break
        # de-duplicate on timestamp, keep order
        seen: set[int] = set()
        deduped = []
        for row in all_rows:
            if row[0] not in seen:
                seen.add(row[0])
                deduped.append(row)
        return deduped

    async def fetch_multi_tf(self, symbol: str, timeframes: list[str]) -> dict[str, list]:
        """Fetch several timeframes for one symbol concurrently."""
        results = await asyncio.gather(
            *(self.fetch_ohlcv(symbol, tf) for tf in timeframes)
        )
        return dict(zip(timeframes, results))

    # ------------------------------------------------------------------ #
    async def close(self):
        await self.client.close()

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        await self.close()
