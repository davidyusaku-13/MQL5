# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an MQL5 algorithmic trading codebase focused on forex strategy development, testing, and optimization. The primary trading strategies include daily breakout systems with multi-timeframe trend confirmation and multi-trade execution managers.

## Core Architecture

### Trading Expert Advisors (EAs)

1. **DailyBreakout-DEBUGGED.mq5** - Main production EA
   - Daily range breakout strategy with trend confirmation
   - Multi-timeframe analysis (M5, M15, H1, H4)
   - Risk-based position sizing using account balance percentage
   - Configurable trading sessions and range filters

2. **MultiTradeManager_v3.mq5** - Multi-trade execution system
   - Execute 1-4 identical orders with GUI control
   - Advanced breakeven and position management
   - Real-time risk calculation and lot sizing

### Supporting Tools

1. **TradeUtility.mq5** - Comprehensive trading toolbox (2347 lines)
   - Manual trade execution interface
   - Risk management calculator
   - Multiple take profit levels

2. **Sessions.mq5** - Trading sessions indicator
   - Visualizes Tokyo, London, New York sessions

## Development Workflow

### Strategy Testing and Optimization

1. **MT5 Strategy Tester Optimization Process:**
   ```
   1. Run optimization using "Complex Criterion"
   2. After completion, right-click results header and add columns:
      - Profit Factor
      - Maximum Drawdown (%)
      - Recovery Factor
      - Sharpe Ratio
   3. Filter results:
      - Profit Factor ≥ 1.5
      - Max Drawdown ≤ 20%
      - Recovery Factor ≥ 2.0
      - Total Trades ≥ 100
   ```

2. **Configuration Files:**
   - `.set` files in XAUUSD/ directory contain optimized parameters
   - Test results stored as HTML, PNG reports in same directory

### Analysis Pipeline

Python scripts for trade analysis and optimization:

1. **analyze.py** - Parse EA log files and extract trade metrics
   - Input: `log.txt` from EA execution
   - Output: Structured CSV with range, profit, balance data

2. **mt5_heatmap.py** - Generate correlation heatmaps from optimization results
   - Analyzes parameter relationships
   - Identifies optimal parameter combinations

3. **result_regression.py** - Machine learning analysis of optimization results
   - Uses Linear, Ridge, Lasso regression
   - Provides parameter importance ranking

## Code Structure Patterns

### MQL5 EA Architecture
All EAs follow standard MQL5 lifecycle:
- `OnInit()` - Parameter validation and initialization
- `OnTick()` - Main trading logic with state management
- `OnDeinit()` - Resource cleanup and final reporting

### Risk Management Implementation
- **Position Sizing**: Risk percentage of account balance with range-based SL calculation
- **Lot Calculation**: `Lot Size = Risk Amount / (SL Distance * Tick Value / Tick Size)`
- **Multi-timeframe Confirmation**: Trend validation across M5, M15, H1, H4

### State Management
- Global variables for EA state (range highs/lows, order tickets, tracking flags)
- Daily reset mechanisms using time-based triggers
- Persistent trade tracking across terminal restarts

## Environment Setup

### Python Dependencies
```bash
pip install -r requirements.txt
```

Required packages: pandas>=1.5.0, numpy>=1.21.0, plotly>=5.10.0, python-dotenv>=0.19.0

### MT5 Configuration
- MT5 connection credentials stored in `.env` file
- Git integration enabled for code versioning
- Claude AI permissions configured for web search and analysis

## Key Parameters

### DailyBreakout EA
- `risk_percentage = 1.0` - Risk per trade (1% of account balance)
- `stop_loss = 90` - Stop loss as percentage of range
- `trend_swing_period = 10` - Period for swing high/low detection
- `trend_momentum_period = 5` - Period for recent momentum check

### MultiTradeManager
- `RiskPercent = 1.0` - Risk percentage per order
- `OrderCount` - Number of orders to execute (1-4)
- `BreakevenBuffer = 300` - Points to lock in profit

## File Relationships

```
DailyBreakout-DEBUGGED.mq5  ← Core strategy
    ↓ generates
log.txt                     ← Trade execution log
    ↓ analyzed by
analyze.py                  ← Extracts metrics
    ↓ produces
trade_results.csv           ← Structured data
    ↓ consumed by
mt5_heatmap.py             ← Correlation analysis
result_regression.py       ← ML optimization
```

## Testing Strategy

1. **Backtesting**: Use MT5 Strategy Tester with historical data
2. **Parameter Optimization**: Complex criterion optimization with manual filtering
3. **Forward Testing**: Validate optimized parameters on out-of-sample data
4. **Performance Analysis**: Use Python scripts for detailed metric analysis

## Git Workflow

### Commit Message Convention

Follow **Conventional Commits** specification (v1.0.0) for consistent commit history:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Commit Types
- **feat**: New feature for the user (correlates with MINOR SemVer)
- **fix**: Bug fix for the user (correlates with PATCH SemVer)
- **docs**: Documentation only changes
- **style**: Code style changes (formatting, missing semicolons, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvements
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes that affect the build system or external dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Maintenance tasks, dependency updates, etc.

### Examples for This Codebase
```
feat(ea): add multi-timeframe trend confirmation
fix(trading): resolve position sizing calculation error
docs(readme): update optimization workflow instructions
refactor(utility): simplify lot calculation algorithm
perf(analysis): optimize data processing in result regression
test(ea): add unit tests for range detection logic
```

### Breaking Changes
Indicate breaking changes with exclamation mark or footer:
```
feat(ea)!: change risk calculation methodology
BREAKING CHANGE: Position sizing now uses account equity instead of balance
```

### Recent Commit Focus
- Trade closure and reporting enhancements
- Analysis tool integration
- Feature refactoring and code streamlining
- Risk management improvements