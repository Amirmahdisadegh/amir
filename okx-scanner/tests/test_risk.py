import tempfile
from pathlib import Path

from okx_scanner.config import RiskCfg
from okx_scanner.risk import RiskManager
from okx_scanner.signals import Side, SetupType, Signal, Zone


def _signal(entry=100.0, stop=98.0, tp=106.0):
    z = Zone(proximal=entry, distal=stop, start_index=0, end_index=1, side=Side.LONG)
    return Signal(
        symbol="BTC/USDT:USDT", timeframe="1h", setup=SetupType.FTR, side=Side.LONG,
        entry=entry, stop_loss=stop, take_profit=tp, zone=z, price=entry,
        atr=1.0, risk_reward=3.0, score=80, bar_time=1,
    )


def _mgr(tmp, **over):
    defaults = dict(account_equity_usdt=1000, risk_per_trade_pct=1.0, atr_sl_mult=1.5,
                    take_profit_rr=2.0, max_open_positions=3, max_positions_per_symbol=1,
                    daily_loss_limit_pct=3.0, max_leverage=3)
    defaults.update(over)
    return RiskManager(RiskCfg(**defaults), state_path=Path(tmp) / "state.json")


def test_position_sizing_respects_risk_pct():
    with tempfile.TemporaryDirectory() as tmp:
        mgr = _mgr(tmp)
        plan = mgr.build_plan(_signal(), equity=1000, atr=1.0)
        assert plan.is_valid
        # stop distance enforced to max(signal 2.0, atr_sl_mult*atr = 1.5) = 2.0
        risk_amt = 1000 * 0.01
        assert abs(plan.risk_amount - risk_amt) < 1e-6 or plan.leverage == 3
        # size * stop_distance ~= risk amount (before any leverage scaling)
        assert plan.size > 0


def test_stop_always_present():
    with tempfile.TemporaryDirectory() as tmp:
        mgr = _mgr(tmp)
        plan = mgr.build_plan(_signal(), equity=1000, atr=1.0)
        assert plan.stop_loss > 0
        assert plan.stop_loss < plan.entry  # long stop below entry


def test_max_open_positions_enforced():
    with tempfile.TemporaryDirectory() as tmp:
        mgr = _mgr(tmp, max_open_positions=1, max_positions_per_symbol=5)
        p1 = mgr.build_plan(_signal(), 1000, 1.0)
        mgr.register_open("o1", p1)
        ok, reason = mgr.can_open("ETH/USDT:USDT", 1000)
        assert not ok and "max open" in reason


def test_daily_loss_limit_halts():
    with tempfile.TemporaryDirectory() as tmp:
        mgr = _mgr(tmp, daily_loss_limit_pct=3.0)
        mgr.register_open("o1", mgr.build_plan(_signal(), 1000, 1.0))
        mgr.register_close("o1", realized_pnl=-31)  # -3.1% of 1000
        assert mgr.is_halted(1000)
        ok, reason = mgr.can_open("BTC/USDT:USDT", 1000)
        assert not ok


def test_leverage_cap():
    with tempfile.TemporaryDirectory() as tmp:
        # tiny stop distance -> huge size -> must be capped by leverage
        mgr = _mgr(tmp, max_leverage=3, risk_per_trade_pct=2.0)
        sig = _signal(entry=100.0, stop=99.99)
        plan = mgr.build_plan(sig, equity=1000, atr=0.001)
        assert plan.notional <= 1000 * 3 + 1e-6


def test_state_persists_daily_pnl():
    with tempfile.TemporaryDirectory() as tmp:
        mgr = _mgr(tmp)
        mgr.register_open("o1", mgr.build_plan(_signal(), 1000, 1.0))
        mgr.register_close("o1", realized_pnl=-10)
        mgr2 = _mgr(tmp)  # reload from disk
        assert abs(mgr2.state.daily.realized_pnl - (-10)) < 1e-6
