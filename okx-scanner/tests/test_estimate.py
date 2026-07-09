"""Plain-money trade preview used in Mode-1 alerts."""
from okx_scanner.notifier import quality_label
from okx_scanner.risk import estimate_trade
from okx_scanner.signals import Side, SetupType, Signal, Zone


def _sig(entry, stop, tp):
    z = Zone(proximal=entry, distal=stop, start_index=0, end_index=1, side=Side.LONG)
    return Signal("TIA/USDT:USDT", "1h", SetupType.FTR, Side.LONG,
                  entry, stop, tp, z, entry, 0.01, 2.0, 78, bar_time=1)


def test_estimate_sizes_to_risk_pct():
    # risk 1% of 1000 = 10 USDT; stop distance 0.01 -> size 1000 coins
    est = estimate_trade(_sig(0.42, 0.41, 0.44), equity=1000, risk_pct=1.0)
    assert abs(est["risk_amount"] - 10.0) < 1e-9
    assert abs(est["size"] - 10.0 / 0.01) < 1e-6
    # reward per unit 0.02 -> profit ~ size*0.02 = 20
    assert abs(est["profit_amount"] - 20.0) < 1e-6


def test_estimate_rejects_zero_stop_distance():
    assert estimate_trade(_sig(0.42, 0.42, 0.44), 1000, 1.0) is None
    assert estimate_trade(_sig(0.42, 0.41, 0.44), 0, 1.0) is None


def test_quality_labels():
    assert "عالی" in quality_label(80)
    assert "خوب" in quality_label(66)
    assert "متوسط" in quality_label(55)
    assert "ضعیف" in quality_label(40)
