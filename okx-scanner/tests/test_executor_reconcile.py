"""Pure reconciliation helpers used by the live executor (no network)."""
from okx_scanner.executor import (
    open_position_keys, realized_pnl_from_trades, reconcile_actions,
)
from okx_scanner.risk import OpenPosition


def _pos(symbol, side, status):
    return OpenPosition(symbol=symbol, side=side, entry=1, stop_loss=1,
                        take_profit=1, size=1, opened_at="", status=status)


def test_open_position_keys_filters_zero_contracts():
    positions = [
        {"symbol": "BTC/USDT:USDT", "side": "long", "contracts": 1.0},
        {"symbol": "ETH/USDT:USDT", "side": "short", "contracts": 0},
        {"symbol": "SOL/USDT:USDT", "side": "long", "contracts": None},
    ]
    keys = open_position_keys(positions)
    assert ("BTC/USDT:USDT", "long") in keys
    assert ("ETH/USDT:USDT", "short") not in keys
    assert ("SOL/USDT:USDT", "long") not in keys


def test_realized_pnl_sums_fillpnl():
    trades = [
        {"info": {"fillPnl": "1.5"}},
        {"info": {"fillPnl": "-0.5"}},
        {"info": {"fillPnl": ""}},          # ignored
        {"info": {"realizedPnl": "2.0"}},   # fallback key
    ]
    assert abs(realized_pnl_from_trades(trades) - 3.0) < 1e-9


def test_realized_pnl_handles_garbage():
    trades = [{"info": {}}, {}, {"info": {"fillPnl": "not-a-number"}}]
    assert realized_pnl_from_trades(trades) == 0.0


# ---- reconcile state machine ----
def test_pending_order_still_resting_is_untouched():
    tracked = {"o1": _pos("BTC/USDT:USDT", "long", "pending")}
    actions = reconcile_actions(tracked, open_order_ids={"o1"}, position_keys=set())
    assert actions == []


def test_pending_order_filled_becomes_open():
    tracked = {"o1": _pos("BTC/USDT:USDT", "long", "pending")}
    actions = reconcile_actions(
        tracked, open_order_ids=set(),
        position_keys={("BTC/USDT:USDT", "long")},
    )
    assert actions == [("o1", "filled")]


def test_pending_order_gone_without_position_is_cancelled():
    tracked = {"o1": _pos("BTC/USDT:USDT", "long", "pending")}
    actions = reconcile_actions(tracked, open_order_ids=set(), position_keys=set())
    assert actions == [("o1", "cancelled")]


def test_open_position_gone_is_closed():
    tracked = {"o1": _pos("BTC/USDT:USDT", "long", "open")}
    actions = reconcile_actions(tracked, open_order_ids=set(), position_keys=set())
    assert actions == [("o1", "closed")]


def test_open_position_still_present_is_untouched():
    tracked = {"o1": _pos("BTC/USDT:USDT", "long", "open")}
    actions = reconcile_actions(
        tracked, open_order_ids=set(),
        position_keys={("BTC/USDT:USDT", "long")},
    )
    assert actions == []
