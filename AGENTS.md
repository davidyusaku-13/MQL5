## Verify First

- No repo-local build, lint, test, or CI config found. Verification is manual in MetaEditor / MT5.
- Compile changed `.mq5` file in MetaEditor (`F7`).
- For strategy changes, run MT5 Strategy Tester on `XAUUSD` and load `XAUUSD/XAUUSD_Backtest_20190101_to_Present.set`.
- `XAUUSD/` and `DailyBreakout-RESULT.csv` are tester presets / reports. New `*.csv`, `*.set`, `*.xlsx`, and `*.xml` files are ignored by `.gitignore`.

## Repo Map

- `DailyBreakout.mq5`: base daily range breakout EA. Range inputs are minutes from midnight; day rollover uses midnight-normalized `datetime`.
- `DailyBreakout-ENHANCED.mq5`: breakout EA with weekly loss limit and multi-timeframe trend confirmation.
- `TradeUtility.mq5`: `CAppDialog` trade panel with per-symbol persistence and breakeven tracking.
- `MultiTradeManager_v3.mq5`: `CAppDialog` multi-order manager with terminal Global Variable persistence.
- `MultiTradeManager_v2.mq5` and `MultiTradeManager.mq5`: older variants. `MultiTradeManager.mq5` uses raw chart objects, not `CAppDialog`.

## Editing Gotchas

- Preserve order ownership filters. `TradeUtility` identifies its own orders by `"TradeUtility"` in comment text; `MultiTradeManager*` filters by both `Magic_Number` and `Trade_Comment`.
- Preserve symbol-aware sizing. Current code reads `SYMBOL_VOLUME_MIN/MAX/STEP`, `SYMBOL_DIGITS`, `SYMBOL_TRADE_TICK_VALUE`, and rounds to symbol lot step.
- In `TradeUtility`, lot size is derived from balance, risk %, SL, and `m_orderCount`; `m_edtLotSize` is read-only by design.
- In `TradeUtility`, SL/TP inputs are absolute prices, not points. Dollar labels are derived from those prices.
- `TradeUtility` state is not only UI-local: it reloads from `TradeUtility_Setups.csv`, `TradeUtility_Inputs.csv`, live orders/positions, and symbol-change events. Do not break that reconstruction flow.
- `TradeUtility` uses both `OnTick()` and a 100ms `OnTimer()`; timer drives price refresh, cleanup, debounced input saves, and periodic setup saves.
- `MultiTradeManager_v2.mq5` and `_v3.mq5` start custom control IDs at `100` to avoid `CAppDialog` ID collisions.
- `MultiTradeManager_v3.mq5` persists UI state in terminal Global Variables with `MTMv3_*` keys. Keep keys stable unless migration is intentional.
- `MultiTradeManager.mq5` prefixes chart object names with `MTM_<Magic_Number>_`; keep prefixing if touching v1 so multiple instances do not collide.
- `MultiTradeManager*` cache prices / symbol info and throttle count/UI refresh with `COUNT_UPDATE_THRESHOLD` and `GUI_UPDATE_THRESHOLD`. Avoid adding heavy work to every tick outside those guards.
- `DailyBreakout*` depend on exact midnight normalization (`hour/min/sec = 0`) for day and range resets.
- `DailyBreakout.mq5` calculates ranges from `PERIOD_M1` bars, then places pending breakout orders after range end. Keep time-window math aligned with M1 history.

## Git

- Recent history uses Conventional Commits: `type(scope): subject`.
