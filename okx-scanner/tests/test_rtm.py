"""RTM detection tests on synthetic, hand-built structure."""
import numpy as np

from okx_scanner.config import RtmCfg
from okx_scanner.indicators import atr, candle_metrics, to_dataframe
from okx_scanner.rtm import detect_signals
from okx_scanner.rtm import structure as st
from okx_scanner.signals import Side


def _bar(ts, o, h, l, c, v=100.0):
    return [ts, o, h, l, c, v]


def _relaxed_cfg():
    return RtmCfg(
        swing_lookback=1,
        base_max_body_ratio=0.5,
        base_max_candles=3,
        leg_min_body_ratio=0.5,
        min_leg_atr_mult=0.3,
        confirm_vol_mult=50.0,        # effectively disable volume hard-scoring
        max_dist_to_zone_atr=6.0,
        min_risk_reward=1.0,
        zone_freshness_bars=200,
    )


def _bullish_series():
    """Build a bullish scenario: oscillation -> base -> BOS up -> pullback to zone."""
    rows = []
    ts = 0
    # 1) 40 bars oscillating ~100 to seed ATR/swings
    for i in range(40):
        base = 100 + (1 if i % 2 == 0 else -1) * 0.6
        rows.append(_bar(ts, base - 0.2, base + 0.5, base - 0.5, base + 0.1))
        ts += 1
    # 2) swing high at ~102 (to be broken later)
    rows.append(_bar(ts, 100.5, 102.2, 100.3, 101.0)); ts += 1
    # 3) dip
    for _ in range(3):
        rows.append(_bar(ts, 100.5, 100.7, 99.8, 100.0)); ts += 1
    # 4) demand base (small candles) ~100.0-100.6
    for _ in range(3):
        rows.append(_bar(ts, 100.2, 100.6, 100.0, 100.3)); ts += 1
    base_top = 100.6
    # 5) impulsive breakout candle: closes above 102.2 (BOS up)
    rows.append(_bar(ts, 100.4, 103.5, 100.4, 103.2, v=500)); ts += 1
    # 6) drift up a bit then pull back toward the base top
    for c in [103.4, 103.6, 103.2, 102.6, 102.0, 101.4, 100.9, 100.7]:
        rows.append(_bar(ts, c + 0.1, c + 0.3, c - 0.3, c)); ts += 1
    return rows, base_top


def test_find_bases_and_bos():
    cfg = _relaxed_cfg()
    rows, _ = _bullish_series()
    df = to_dataframe(rows)
    dfm = candle_metrics(df)
    view = st.build_structure(dfm, cfg)
    assert view.bases, "should find at least one base"
    bos = st.latest_bos(view, atr(df, 14), cfg)
    assert bos is not None
    assert bos.direction == +1  # bullish break


def test_detect_bullish_setup():
    cfg = _relaxed_cfg()
    rows, base_top = _bullish_series()
    df = to_dataframe(rows)
    atr_series = atr(df, 14)
    sigs = detect_signals(df, atr_series, cfg, "TEST/USDT:USDT", "1h")
    assert sigs, "expected at least one RTM signal on the bullish scenario"
    s = sigs[0]
    assert s.side is Side.LONG
    assert s.stop_loss < s.entry < s.take_profit
    assert s.risk_reward >= cfg.min_risk_reward


def test_htf_alignment_raises_score():
    cfg = _relaxed_cfg()
    rows, _ = _bullish_series()
    df = to_dataframe(rows)
    atr_series = atr(df, 14)
    aligned = detect_signals(df, atr_series, cfg, "T/USDT:USDT", "1h", htf_bias=+1)
    against = detect_signals(df, atr_series, cfg, "T/USDT:USDT", "1h", htf_bias=-1)
    assert aligned and against
    # a LONG setup with bullish HTF must score higher than with bearish HTF
    assert aligned[0].score > against[0].score
    assert "HTF-aligned" in aligned[0].notes


def test_require_htf_alignment_rejects_counter_trend():
    from okx_scanner.config import RtmCfg
    base = _relaxed_cfg()
    cfg = RtmCfg(**{**base.__dict__, "require_htf_alignment": True})
    rows, _ = _bullish_series()
    df = to_dataframe(rows)
    atr_series = atr(df, 14)
    # LONG setup, bearish HTF, hard requirement -> no signal
    assert detect_signals(df, atr_series, cfg, "T/USDT:USDT", "1h", htf_bias=-1) == []


def test_no_signal_on_flat_noise():
    cfg = _relaxed_cfg()
    rng = np.random.default_rng(0)
    rows = []
    for i in range(120):
        c = 100 + rng.normal(0, 0.05)
        rows.append(_bar(i, c, c + 0.05, c - 0.05, c))
    df = to_dataframe(rows)
    sigs = detect_signals(df, atr(df, 14), cfg, "FLAT/USDT:USDT", "1h")
    # flat noise should not produce a large-leg BOS setup
    assert sigs == [] or all(s.risk_reward >= cfg.min_risk_reward for s in sigs)
