# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MetaTrader 5 Expert Advisors (EAs) and utilities written in MQL5 for algorithmic FOREX trading. Primary focus on:
- Daily range breakout strategies (DailyBreakout.mq5)
- Multi-trade management with GUI (MultiTradeManager*.mq5, TradeUtility.mq5)
- Backtesting against XAUUSD (gold)

## Build & Development

**No build system** - MQL5 files compile directly in MetaTrader 5 platform (MetaEditor).

**Testing changes:**
1. Open EA in MetaEditor (F4 or right-click → Edit)
2. Compile (F7)
3. Run backtest in MT5 Strategy Tester using XAUUSD symbol
4. Use `XAUUSD/XAUUSD_Backtest_20190101_to_Present.set` for parameter presets

## Architecture

### Core EAs

| File | Purpose |
|------|---------|
| `DailyBreakout.mq5` | Range breakout strategy - calculates daily high/low during time windows, places pending orders at breakout levels |
| `DailyBreakout-ENHANCED.mq5` | Extended version with multi-timeframe trend confirmation, weekly loss limits |
| `TradeUtility.mq5` | Advanced trade calculator GUI - risk-based sizing, multiple TPs, breakeven tracking, persistent state per symbol |
| `MultiTradeManager_v3.mq5` | Latest multi-order manager with `CMultiTradeDialog : public CAppDialog` |

### Key Technical Patterns

**MQL5 Standard Library:**
```mql5
#include <Trade\Trade.mqh>           // CTrade for order execution
#include <Controls\Dialog.mqh>       // CAppDialog for GUI
#include <Controls\Button.mqh>       // CButton, CEdit, CComboBox, CLabel
```

**GUI Pattern:**
- Controls inherit from `CAppDialog`
- Custom control IDs start at 100+ (avoid CAppDialog internal collision)
- Event handling via `OnEventMouseDown()` / `OnEventMouseUp()`

**Day Reset Pattern:**
```mql5
MqlDateTime dt;
TimeCurrent(dt);
dt.hour = 0; dt.min = 0; dt.sec = 0;
datetime today = StructToTime(dt);
if(today != g_current_day) { /*new day logic*/ }
```

**Symbol Awareness:**
- Auto-calculate lots via `SymbolInfoDouble(SYMBOL_VOLUME_MIN)`
- Validate with `symbol_min_lot`, `symbol_max_lot`, `symbol_lot_step`
- Price precision via `SymbolInfoInteger(SYMBOL_DIGITS)`

**Performance Optimization:**
- Cache prices: `last_bid`, `last_ask`, `last_price_update`
- Update thresholds: `COUNT_UPDATE_THRESHOLD` (1000ms), `GUI_UPDATE_THRESHOLD` (100ms)
- Pre-cache symbol info: `symbol_point`, `symbol_digits`, `symbol_stops_level`

### Struct-Based Data Organization

- **TradeGroup** (MultiTradeManager): Groups related trades for coordinated SL/TP
- **TradeSetup** (TradeUtility): Per-symbol config with breakeven mode
- **SessionTime** (Sessions): Session metadata (start/end times, colors)

## Critical Patterns to Preserve

1. **DateTime precision**: Zero out hour/min/sec when comparing daily milestones
2. **TP/SL as absolute prices**: Not points - verify fields use `$` currency prefix
3. **Lot size as derived**: Calculate from risk %, SL, balance - never accept direct user input
4. **Magic number filtering**: Use `Magic_Number` input to avoid strategy interference
5. **Order execution**: Wrap in `CTrade` methods (`trade.BuyLimit()`, `trade.Sell()`)

## Commit Guidelines

Follow Conventional Commits format:

```
<type>(scope): <description>
```

Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `style`, `chore`

Scopes: `DailyBreakout`, `TradeUtility`, `MultiTradeManager`, `ea`, `docs`

Examples:
```
feat(DailyBreakout): add min/max range size validation
fix(TradeUtility): correct symbol change detection on TP updates
refactor(MultiTradeManager): extract breakeven logic to separate function
```
