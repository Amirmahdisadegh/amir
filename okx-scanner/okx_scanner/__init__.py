"""OKX RTM Scanner — semi-automated trading toolkit for the OKX exchange.

Modules:
    config      : typed config loading (YAML + .env)
    indicators  : ATR, swings, candle metrics
    rtm         : RTM setup detection (structure, FTR, Flag Limit)
    signals     : Signal dataclass + quality filtering
    scanner     : async multi-symbol / multi-timeframe scan loop
    risk        : position sizing + non-negotiable risk manager
    notifier    : Telegram alerts (aiogram)
    executor    : order execution for live mode (Mode 2)
    backtest    : historical backtest engine + stats
"""

__version__ = "0.1.0"
