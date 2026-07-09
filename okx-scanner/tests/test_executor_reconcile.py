"""Pure reconciliation helpers used by the live executor (no network)."""
from okx_scanner.executor import open_position_keys, realized_pnl_from_trades


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
