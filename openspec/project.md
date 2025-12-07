# Project Context

## Purpose

This project is a suite of **MetaTrader 5 Expert Advisors (EAs)** and indicators for algorithmic trading. The main goals are:

- Develop reliable automated trading strategies focusing on daily range breakouts
- Provide advanced trade management tools with multi-order capabilities
- Enable systematic backtesting and optimization against historical data (primarily XAUUSD/gold)
- Build intuitive GUI-based trade utilities for manual and semi-automated trading

## Tech Stack

- **MQL5** - MetaQuotes Language 5 (primary programming language for MetaTrader 5)
- **MetaTrader 5** - Trading platform and development environment
- **MQL5 Standard Library** - For trade execution (`CTrade`), GUI controls (`CAppDialog`, `CButton`, `CEdit`, `CComboBox`)
- **Strategy Tester** - MetaTrader 5's built-in backtesting and optimization engine
- **Excel** - For analysis of backtesting results and optimization data

## Project Conventions

### Code Style

- **Naming Conventions**:

  - Global variables: `g_` prefix (e.g., `g_high_price`, `g_current_day`)
  - Input parameters: lowercase with underscores (e.g., `magic_number`, `min_range_size`)
  - Struct names: PascalCase (e.g., `TradeGroup`, `SessionTime`, `TradeSetup`)
  - Class names: PascalCase with `C` prefix following MQL5 convention (e.g., `CMultiTradeDialog`, `CTradeUtilityDialog`)
  - Constants: UPPERCASE with underscores (e.g., `COUNT_UPDATE_THRESHOLD`, `GUI_UPDATE_THRESHOLD`)

- **Formatting**:

  - Use MQL5 standard indentation (spaces preferred)
  - Clear comment blocks for major sections
  - Input parameters grouped logically with descriptive comments

- **Magic Numbers**:
  - Each EA uses unique magic numbers for order identification
  - Input parameter typically named `Magic_Number` or `magic_number`
  - Must match across all related orders in multi-trade strategies

### Architecture Patterns

- **Struct-Based Data Organization**:

  - `TradeGroup` - Groups related trades for coordinated SL/TP management (MultiTradeManager)
  - `TradeSetup` - Tracks per-symbol trade configuration with breakeven mode (TradeUtility)
  - `SessionTime` - Encodes trading session metadata (Sessions indicator)

- **GUI Pattern**:

  - All GUI dialogs inherit from `CAppDialog`
  - Controls created in `Create()` override method
  - Event handling in `OnEventMouseDown()` / `OnEventMouseUp()` overrides
  - Custom control IDs start at 100+ to avoid collision with base class
  - State persistence across symbol changes

- **Day Reset Pattern**:

  ```mql5
  MqlDateTime dt;
  TimeCurrent(dt);
  dt.hour = 0; dt.min = 0; dt.sec = 0;  // Reset to midnight
  datetime today = StructToTime(dt);
  if(today != g_current_day) { /*new day logic*/ }
  ```

- **Performance Optimization**:

  - Cache frequently accessed data (prices, symbol info)
  - Update thresholds to limit redundant operations (e.g., 1000ms for counts, 100ms for GUI)
  - Pre-cache symbol properties: `symbol_point`, `symbol_digits`, `symbol_min_lot`, `symbol_stops_level`

- **Trade Execution**:
  - All EAs use `CTrade` class from `<Trade\Trade.mqh>`
  - Methods: `trade.BuyLimit()`, `trade.Sell()`, `trade.PositionModify()`, etc.
  - Magic number filtering to avoid interference between strategies

### Testing Strategy

- **Backtesting**: Primary validation method using MetaTrader 5 Strategy Tester
- **Test Dataset**: XAUUSD (gold) symbol from 2019-01-01 to present
- **Configuration**: `.set` files in `XAUUSD/` directory contain backtest parameters
- **Metrics**: Focus on equity curves, drawdown metrics (6% vs 30% targets), and risk-adjusted returns
- **Optimization**: Results stored in `.xml` files; compare parameter variations in Excel reports
- **Validation Process**:
  1. Run backtest using provided `.set` file
  2. Export optimization results
  3. Compare equity curves and drawdown against baseline
  4. Verify no regression in key performance indicators

### Git Workflow

**Commit Convention**: Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)

**Format**:

```
<type>[optional scope]: <description>

[optional body]
[optional footer(s)]
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `perf`: Performance improvement
- `test`: Adding or updating tests
- `docs`: Documentation changes
- `style`: Formatting, linting (no code changes)
- `chore`: Dependency updates, configuration

**Examples**:

```
feat(DailyBreakout): add min/max range size validation
fix(TradeUtility): correct symbol change detection on TP updates
refactor(MultiTradeManager): extract breakeven logic to separate function
perf(Sessions): cache session rectangles to reduce redraws
```

**Branching Strategy**: Main branch development with feature branches for major changes

## Domain Context

### Trading Terminology

- **EA (Expert Advisor)**: Automated trading system in MetaTrader
- **Pending Order**: Order that executes when price reaches specified level
- **SL (Stop Loss)**: Price level to exit losing trade
- **TP (Take Profit)**: Price level to exit winning trade
- **Breakeven**: Moving SL to entry price after profit threshold reached
- **Magic Number**: Unique identifier for orders placed by specific EA
- **Lot**: Trading volume unit (1.0 lot = 100,000 units in Forex)

### Strategy Types

1. **Daily Range Breakout** (DailyBreakout.mq5):

   - Identifies high/low during specified time window
   - Places pending orders at breakout levels
   - Features: trailing stops, range validation, day-of-week filtering

2. **Multi-Trade Management** (MultiTradeManager variants):

   - Splits single trade into multiple orders with different TPs
   - Auto-lot calculation based on risk percentage
   - Coordinated breakeven management across related trades

3. **Trade Setup Calculator** (TradeUtility.mq5):
   - GUI-based order entry with symbol-aware validation
   - Persistent state across symbol changes
   - Automatic lot sizing based on risk and stop loss

### Key Algorithms

- **Range Calculation**: Time-windowed high/low identification with min/max size validation
- **Auto-Lot Sizing**: `lot = (balance * risk_percent) / (stop_loss_points * point_value)`
- **Breakeven Logic**: Track profit thresholds per trade group, move SL with buffer
- **Symbol Validation**: Respect symbol's min/max lot, lot step, and stop level constraints

## Important Constraints

### Platform Constraints

- **MQL5 Language**: Strict typing, no dynamic memory management like C++
- **Symbol-Specific**: All calculations must respect symbol properties (digits, lot size, stop level)
- **DateTime Precision**: Always zero-out time components for daily comparisons to prevent off-by-one errors
- **GUI Library**: Limited to MetaTrader standard library controls; no custom rendering

### Trading Constraints

- **Prices vs Points**: TPs/SLs are absolute prices, not point offsets
- **Lot Precision**: Must match symbol's `SYMBOL_VOLUME_STEP`
- **Minimum Stop Level**: Orders must respect broker's `SYMBOL_TRADE_STOPS_LEVEL`
- **Magic Number Isolation**: Each EA must use unique magic numbers

### Performance Constraints

- **OnTick() Frequency**: Runs on every price change; avoid heavy computation
- **GUI Updates**: Batch refreshes with thresholds (100-1000ms) to prevent lag
- **Object Cleanup**: Must explicitly delete chart objects (lines, rectangles) on deinit

## External Dependencies

### MetaTrader 5 Standard Library

- **Trade Module**: `#include <Trade\Trade.mqh>` - `CTrade` class for order execution
- **GUI Controls**:
  - `#include <Controls\Dialog.mqh>` - `CAppDialog` base class
  - `#include <Controls\Button.mqh>` - `CButton` for clickable buttons
  - `#include <Controls\Edit.mqh>` - `CEdit` for text input fields
  - `#include <Controls\ComboBox.mqh>` - `CComboBox` for dropdowns

### Broker/Data Feed

- **Historical Data**: Provided by MetaTrader 5 broker connection
- **Symbol Information**: Retrieved via `SymbolInfo*()` functions
- **Order Execution**: Handled by broker's trading server

### Analysis Tools

- **Excel**: For analyzing `.csv` exports and optimization results
- **Strategy Tester**: MetaTrader 5's built-in backtesting engine (no external dependency)

### Documentation References

- [MQL5 Language Reference](https://www.mql5.com/en/docs)
- [MQL5 Standard Library](https://www.mql5.com/en/docs/standardlibrary)
- [CButton Documentation](https://www.mql5.com/en/docs/standardlibrary/controls/cbutton)
- [CTrade Documentation](https://www.mql5.com/en/docs/standardlibrary/trading/ctrade)
