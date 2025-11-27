# Copilot Instructions for MQL5 Trading EA Codebase

## Project Overview

This repository contains a suite of **MetaTrader 5 Expert Advisors (EAs)** and indicators written in MQL5. The project focuses on algorithmic trading tools with emphasis on:

- Daily range breakout strategies (`DailyBreakout.mq5`)
- Multi-trade management with advanced GUI (`MultiTradeManager*.mq5`, `TradeUtility.mq5`)
- Trading session visualization (`Sessions.mq5`)
- Backtesting and optimization against XAUUSD (gold) symbol

## Architecture & Major Components

### Core EAs

**DailyBreakout.mq5** - Daily range breakout strategy

- Identifies high/low range during specified time windows (configurable start time + duration)
- Places pending buy/sell orders at breakout levels after range close
- Features: trailing stops, dynamic range validation (min/max size checks), day-of-week filtering
- Key globals: `g_high_price`, `g_low_price`, `g_range_calculated`, `g_range_end_time`
- Pattern: Day-resets in `OnTick()` via `g_current_day` comparison to handle midnight rollovers

**MultiTradeManager variants** (v1.40, v2, v3) - Flexible multi-order trading with GUI

- v1 uses simple globals, v2 adds class-based dialog, v3 uses `CMultiTradeDialog : public CAppDialog`
- Features: auto-lot calculation, multiple TPs, breakeven management (buffer-based)
- `TradeGroup` struct tracks related trades for coordinated breakeven moves
- GUI built with MetaTrader standard library controls (`CButton`, `CEdit`, `CComboBox`)

**TradeUtility.mq5** - Advanced trade setup calculator with persistent state

- Full GUI for order entry with symbol-aware validation
- Breakeven tracking via `TradeSetup` struct array - reconstructs from existing positions on init
- Pattern: Save/restore UI inputs when symbol changes; disabled fields for derived values (lot size)
- Uses `CTradeUtilityDialog` class extending `CAppDialog` with custom event handlers

### Supporting Files

**Sessions.mq5** - Indicator drawing major Forex sessions (Tokyo/London/New York)

- Rectangle-based visualization using `SessionTime` struct array
- 30-day history display by default; configurable colors per session

## Key Technical Patterns & Conventions

### MQL5 Standard Library Usage

- **Trade**: `#include <Trade\Trade.mqh>` - All EAs use `CTrade` class for order execution
- **GUI Controls**: TradeUtility and MultiTradeManager use `<Controls\Dialog.mqh>`, `<Button.mqh>`, `<Edit.mqh>`, `<ComboBox.mqh>`
  - Controls inherit from `CAppDialog` and require `Create()` / `OnEventMouseDown()` / `OnEventMouseUp()` pattern
  - Custom control IDs start at 100 to avoid collision with CAppDialog internal IDs
  - Reference: [MQL5 CButton docs](https://www.mql5.com/en/docs/standardlibrary/controls/cbutton)

### Struct-Based Data Organization

- **TradeGroup** (MultiTradeManager): Groups related trades for coordinated SL/TP management
  - Fields: `entry_price`, `tp1`, `tp2`, `initial_sl`, `be_activated`
- **TradeSetup** (TradeUtility): Tracks per-symbol trade configuration with breakeven mode
  - Fields: `symbol`, `magicNumber`, `tp1`, `tp2`, `beMode`, `beActivated`
- **SessionTime** (Sessions): Encodes session metadata
  - Fields: `startHour/Minute`, `endHour/Minute`, `name`, `clr`

### Day Reset & Time Management Pattern

```mql5
// Common pattern for handling daily rollovers (DailyBreakout, TradeUtility)
MqlDateTime dt;
TimeCurrent(dt);
dt.hour = 0; dt.min = 0; dt.sec = 0;  // Reset to midnight
datetime today = StructToTime(dt);

if(today != g_current_day) { /*new day logic*/ }
```

### Input Validation & Symbol Awareness

- TradeUtility auto-calculates minimum lot based on symbol's `SymbolInfoDouble(SYMBOL_VOLUME_MIN)`
- Lot validation uses: `symbol_min_lot`, `symbol_max_lot`, `symbol_lot_step`
- Entry price precision follows symbol's decimal digits via `SymbolInfoInteger(SYMBOL_DIGITS)`

### Performance Optimization (MultiTradeManager, TradeUtility)

- Caching patterns: `last_bid`, `last_ask`, `last_price_update` avoid redundant price lookups
- Update thresholds: `COUNT_UPDATE_THRESHOLD` (1000ms) for order/position counts, `GUI_UPDATE_THRESHOLD` (100ms) for display
- Symbol info pre-cached: `symbol_point`, `symbol_digits`, `symbol_min_lot`, `symbol_stops_level`

## Backtesting & Optimization

Located in `XAUUSD/` directory:

- `.set` file: `XAUUSD_Backtest_20190101_to_Present.set` - primary backtest dataset (gold, 10+ years)
- `.xlsx` files: Results with varying risk profiles (1% vs 5%, 6% vs 30% drawdown targets)
- `.xml` file: Optimizer results snapshot

**To test changes:**

1. Run backtest in MetaTrader 5 Strategy Tester against XAUUSD symbol using provided `.set` file
2. Review results in `ReportOptimizer-11101038.xml` or export new optimization results
3. Compare equity curves and drawdown metrics

## Development Workflows

### Adding Features to EAs

1. **GUI Components**: Use MetaTrader standard library controls; create as members of dialog class
2. **Order Logic**: Wrap in `CTrade` methods (e.g., `trade.BuyLimit()`, `trade.Sell()`)
3. **State Management**: Use global/member structs for tracking order groups; reset on day/symbol changes
4. **Magic Numbers**: Must match across all related orders; input parameter `Magic_Number` or `magic_number`

### Testing UI Changes

- MultiTradeManager v3 and TradeUtility have full GUI implementations
- Control creation is typically in `Create()` override; event handling in `OnEventMouseDown()` / `OnEventMouseUp()`
- Disabled fields use `ReadOnly()` method; color styling via control's color properties

### Modifying Trade Logic

- DailyBreakout: Update range calculation in `CalculateDailyRange()` and `IsTradingDay()` for day filters
- MultiTradeManager: Adjust `TradeGroup` fields or add tracking in `AutoBreakevenLogic()` function
- Ensure order closure respects magic number filtering to avoid interfering with other strategies

## Common Gotchas & Patterns to Preserve

1. **DateTime precision**: Always zero-out hour/min/sec when comparing daily milestones to prevent off-by-one errors
2. **Line cleanup**: DailyBreakout explicitly deletes VLines in `DeleteAllLines()` on deinit and day reset
3. **GUI update batching**: TradeUtility batches UI refreshes; avoid excessive `Refresh()` calls in tight loops
4. **Symbol context**: TradeUtility detects symbol changes and preserves/resets inputs accordingly
5. **TP/SL as prices, not points**: TradeUtility and MultiTradeManager v3 use absolute prices, not points—verify input fields use `$` currency prefix
6. **Lot size as derived**: Always calculate from risk %, SL, and balance; never accept user input directly

## Key Files by Purpose

| File                           | Purpose                                           |
| ------------------------------ | ------------------------------------------------- |
| `DailyBreakout.mq5`            | Range breakout entry logic                        |
| `MultiTradeManager_v3.mq5`     | Latest multi-order manager with full GUI          |
| `TradeUtility.mq5`             | Advanced trade entry calculator + symbol tracking |
| `Sessions.mq5`                 | Session visualization for reference               |
| `XAUUSD/XAUUSD_Backtest_*.set` | Backtest datasets for validation                  |

## Questions to Ask Before Major Changes

- Does this affect order execution or SL/TP logic? → Validate against backtest results
- Is a new input parameter needed? → Add to appropriate input group with clear description
- Does this interact with GUI? → Ensure compatible with standard library controls API
- Will this affect multiple EAs? → Consider whether shared code should be extracted

## Commit Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) for all commit messages.

### Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Code change that improves performance
- **test**: Adding or updating tests
- **docs**: Documentation changes
- **style**: Formatting, linting (no code changes)
- **chore**: Dependency updates, configuration changes

### Examples

```
feat(DailyBreakout): add min/max range size validation
fix(TradeUtility): correct symbol change detection on TP updates
refactor(MultiTradeManager): extract breakeven logic to separate function
perf(Sessions): cache session rectangles to reduce redraws
```
