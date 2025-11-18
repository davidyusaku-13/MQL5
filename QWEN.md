# MQL5 Trading System Portfolio

This repository contains a comprehensive collection of MQL5 Expert Advisors (EAs) and trading utilities for MetaTrader 5, developed for algorithmic trading strategies. The project includes several distinct trading systems, utilities, and indicators, each implementing different trading concepts and risk management strategies.

## Project Overview

### Trading Systems

1. **DBxEMA (Daily Breakout x EMA Strategy)**
   - Combines daily range breakout concepts with EMA trend following
   - Uses previous day's high/low range as breakout levels
   - Implements two EMA indicators (10 and 20 period) for trend confirmation
   - Features four trade types: LONG_BREAK, SHORT_BREAK, LONG_REJECT, SHORT_REJECT
   - Includes sophisticated confirmation logic with candlestick patterns
   - Risk management with configurable risk percentage and risk-reward ratio
   - Dynamic stop-loss placement based on breakout/rejection patterns

2. **Daily Breakout EA**
   - Classic daily range breakout strategy
   - Defines a daily range within configurable time windows
   - Places pending orders at range extremes (buy stop at high, sell stop at low)
   - Implements "one breakout per range" mode to avoid double trades
   - Includes range size validation (min/max limits)
   - Trailing stop functionality
   - Visual indicators showing range times on chart

3. **Multi-Trade Manager**
   - Allows placing multiple identical trades simultaneously
   - Includes breakeven buffer functionality for risk management
   - Supports flexible trade counts and configurable lot sizes
   - Implements safety limits for maximum positions
   - Features GUI panel for trade management

4. **Trade Utility**
   - Advanced trading interface with GUI controls
   - Supports both market and pending orders
   - Risk-based lot sizing based on stop-loss distance
   - Multi-target system with configurable take-profit levels (TP1-TP4)
   - Breakeven automation ("After TP1", "After TP2" modes)
   - Persistent data storage for setups and input values
   - Position and order management tools

5. **Session Indicator**
   - Visualizes major trading sessions (Tokyo, London, New York)
   - Colors price action based on session times
   - Includes session legends and customizable time ranges

### Key Features

- **Risk Management**: All systems incorporate configurable risk percentage and risk-reward ratios
- **Visual Indicators**: Systems draw support/resistance lines and session ranges
- **Persistent Storage**: Trade setups and user inputs are saved to disk
- **Market Conditions Adaptation**: Different strategies for breakouts, rejections, and consolidations
- **GUI Interfaces**: Several systems include user-friendly panels for manual adjustments

## Building and Running

This is a MetaTrader 5 (MT5) project that runs within the MQL5 environment:

1. **Prerequisites**:
   - MetaTrader 5 trading platform installed
   - MQL5 language environment

2. **Installation**:
   - Copy the .mq5 files to your MT5 Experts folder
   - Recompile the code in MetaEditor (F7) or MT5 terminal (Ctrl+R)

3. **Deployment**:
   - Attach the Expert Advisors to relevant charts
   - Configure input parameters according to your trading preferences
   - Enable automated trading in MT5 settings (F7 > Auto Trading)

4. **Operation**:
   - Each EA runs independently on its assigned timeframe and symbol
   - The DBxEMA EA typically uses M5 timeframe with D1 range data
   - Trade Utility provides real-time GUI controls for manual trade execution

## Development Conventions

- **Code Structure**: Follows MQL5 standards with OnInit(), OnTick(), OnDeinit(), and OnChartEvent() functions
- **Risk Management**: All systems implement risk percentage calculations based on account balance
- **Input Parameters**: Use descriptive input parameters for configuration flexibility
- **Error Handling**: Includes checks for valid market conditions and order execution
- **Logging**: Comprehensive print statements for debugging and monitoring
- **Persistence**: CSV file storage for maintaining state across platform restarts

## File Structure

- `DBxEMA.mq5`: Daily Breakout x EMA Strategy EA
- `DailyBreakout-ORIGINAL.mq5` and `DailyBreakout-MODIFIED.mq5`: Daily range breakout strategies
- `TradeUtility.mq5`: Advanced trading interface with GUI
- `MultiTradeManager*.mq5`: Multi-order trading systems
- `Sessions.mq5`: Trading session visualization indicator
- `*-first_prompt.txt`: Original requirements and specifications for the EAs
- `.gitignore`: Git ignore file for MQL5-specific files

## Trading Concepts

The systems implement various trading concepts including:
- Range breakouts and rejections
- EMA trend following
- Risk management with stop-losses and take-profits
- Breakeven strategies for profit protection
- Session-based trading
- Multi-target position management

## Commit Guidelines

This project follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification for commit messages. This ensures a consistent and structured format for commit messages that allows for automated generation of changelogs and versioning.

### Format

Commits should follow the pattern:
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files

### Examples

```
feat(DBxEMA): add trailing stop functionality

Add trailing stop feature to the DBxEMA EA that activates after reaching a specified profit level.

Closes #123
```

```
fix(DailyBreakout): correct range calculation logic

Fix edge case where range calculation would fail on weekends
or holidays when market is closed.
```

```
refactor(TradeUtility): improve input validation

Simplify validation logic and add more comprehensive error
messages for user input fields.
```