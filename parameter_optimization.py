import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from itertools import product
import warnings
warnings.filterwarnings('ignore')

# Input Parameters (from DailyBreakout-ORIGINAL.mq5)
MAGIC_NUMBER = 12345
BASE_BALANCE = 100.0
LOT = 0.01
MIN_LOT = 0.01
MAX_LOT = 10.0
SYMBOL_POINT = 0.001  # Assumed point size for XAUUSD

class DailyBreakoutSimulator:
    def __init__(self, initial_balance=5000.0,
                 autolot=True, stop_loss=90, take_profit=0,
                 range_start_time=90, range_duration=270,
                 range_close_time=1200, breakout_mode="one breakout per range",
                 range_on_monday=True, range_on_tuesday=False,
                 range_on_wednesday=True, range_on_thursday=True,
                 range_on_friday=True, trailing_stop=300,
                 trailing_start=500, max_range_size=1500,
                 min_range_size=500):

        self.initial_balance = initial_balance
        self.balance = initial_balance
        self.equity = initial_balance
        self.position_opened = False
        self.position_type = None  # 'buy' or 'sell'
        self.position_price = 0
        self.position_lot = 0
        self.position_sl = 0
        self.position_tp = 0
        self.position_trailing = False

        # Parameters specific to this simulation run
        self.autolot = autolot
        self.stop_loss = stop_loss
        self.take_profit = take_profit
        self.range_start_time = range_start_time
        self.range_duration = range_duration
        self.range_close_time = range_close_time
        self.breakout_mode = breakout_mode
        self.range_on_monday = range_on_monday
        self.range_on_tuesday = range_on_tuesday
        self.range_on_wednesday = range_on_wednesday
        self.range_on_thursday = range_on_thursday
        self.range_on_friday = range_on_friday
        self.trailing_stop = trailing_stop
        self.trailing_start = trailing_start
        self.max_range_size = max_range_size
        self.min_range_size = min_range_size

        # Track statistics
        self.total_trades = 0
        self.winning_trades = 0
        self.losing_trades = 0
        self.trade_profits = []
        self.trade_dates = []  # Track when trades occurred
        self.balance_history = [initial_balance]  # Track balance over time
        self.max_equity = initial_balance
        self.min_equity = initial_balance
        self.max_drawdown = 0

        # Track ranges
        self.max_range_ever = 0
        self.min_range_ever = float('inf')
        self.max_range_date = None
        self.min_range_date = None
        self.range_calculated = False
        self.orders_placed = False
        self.current_day = None
        self.range_start_time_calc = None
        self.range_end_time = None
        self.range_close_time_calc = None
        self.high_price = 0
        self.low_price = float('inf')

        # Track orders
        self.buy_order_price = None
        self.sell_order_price = None

    def is_trading_day(self, date):
        """Check if today is a valid trading day"""
        day_of_week = date.weekday()  # Monday is 0, Sunday is 6
        
        if day_of_week == 0:  # Monday
            return self.range_on_monday
        elif day_of_week == 1:  # Tuesday
            return self.range_on_tuesday
        elif day_of_week == 2:  # Wednesday
            return self.range_on_wednesday
        elif day_of_week == 3:  # Thursday
            return self.range_on_thursday
        elif day_of_week == 4:  # Friday
            return self.range_on_friday
        else:  # Weekend
            return False

    def calculate_lot_size(self, range_size):
        """Calculate lot size based on the settings"""
        if self.autolot:  # Autolot mode
            # Calculate lot size proportional to account balance
            balance_ratio = self.balance / BASE_BALANCE
            lot_size = round(balance_ratio * LOT, 2)
            
            # Apply min/max limits
            if lot_size < MIN_LOT:
                lot_size = MIN_LOT
            elif lot_size > MAX_LOT:
                lot_size = MAX_LOT
                
            return lot_size
        else:  # Fixed lot size
            return LOT  # Use LOT as fixed lot value

    def calculate_daily_range(self, day_data):
        """Calculate the daily high/low range for a specific day"""
        # Calculate range start and end times for this day
        day_start = day_data['datetime'].iloc[0].replace(hour=0, minute=0, second=0, microsecond=0)
        self.range_start_time_calc = day_start + timedelta(minutes=self.range_start_time)
        self.range_end_time = self.range_start_time_calc + timedelta(minutes=self.range_duration)
        
        if self.range_close_time > 0:
            self.range_close_time_calc = day_start + timedelta(minutes=self.range_close_time)
        else:
            self.range_close_time_calc = None  # No automatic close time
        
        # Filter data to be within the range time
        range_data = day_data[
            (day_data['datetime'] >= self.range_start_time_calc) & 
            (day_data['datetime'] <= self.range_end_time)
        ]
        
        if len(range_data) == 0:
            return False  # No data in range, can't calculate
        
        self.high_price = range_data['high'].max()
        self.low_price = range_data['low'].min()
        
        # Calculate range size in points
        range_size = self.high_price - self.low_price
        range_points = range_size / SYMBOL_POINT
        
        # Track maximum and minimum ranges observed
        if range_points > self.max_range_ever:
            self.max_range_ever = range_points
            self.max_range_date = day_start
        
        if range_points < self.min_range_ever:
            self.min_range_ever = range_points
            self.min_range_date = day_start
        
        return True

    def place_pending_orders(self):
        """Place pending orders based on the calculated range"""
        if self.high_price <= 0 or self.low_price == float('inf'):
            return False
        
        range_size = self.high_price - self.low_price
        range_points = range_size / SYMBOL_POINT
        
        # Check if range size is within acceptable limits
        if self.max_range_size > 0 and range_points > self.max_range_size:
            self.orders_placed = True
            return False
        
        if self.min_range_size > 0 and range_points < self.min_range_size:
            self.orders_placed = True
            return False
        
        # Calculate lot size
        self.position_lot = self.calculate_lot_size(range_size)
        
        # Calculate SL and TP
        buy_sl = 0
        buy_tp = 0
        sell_sl = 0
        sell_tp = 0
        
        if self.stop_loss > 0:
            # Calculate SL based on range percentage
            buy_sl = self.high_price - (range_size * self.stop_loss / 100)
            sell_sl = self.low_price + (range_size * self.stop_loss / 100)
        
        if self.take_profit > 0:
            buy_tp = self.high_price + (range_size * self.take_profit / 100)
            sell_tp = self.low_price - (range_size * self.take_profit / 100)
        
        # Place orders
        self.buy_order_price = self.high_price
        self.sell_order_price = self.low_price
        self.position_sl = buy_sl if buy_sl > 0 else sell_sl
        self.position_tp = buy_tp if buy_tp > 0 else sell_tp
        
        self.orders_placed = True
        return True

    def check_order_execution(self, current_price, current_datetime):
        """Check if pending orders are executed at the current price and datetime"""
        if not self.orders_placed:
            return False, None
        
        executed = False
        executed_type = None
        
        # Check if buy stop order is triggered (price going up)
        if self.buy_order_price and current_price >= self.buy_order_price:
            # Buy order triggered
            self.position_type = 'buy'
            self.position_price = current_price
            self.position_opened = True
            executed = True
            executed_type = 'buy'
            
            # If "one breakout per range" mode, cancel the sell order
            if self.breakout_mode == "one breakout per range":
                self.sell_order_price = None  # Cancel sell order
            else:
                pass  # Keep both orders open
        
        # Check if sell stop order is triggered (price going down)
        elif self.sell_order_price and current_price <= self.sell_order_price:
            # Sell order triggered
            self.position_type = 'sell'
            self.position_price = current_price
            self.position_opened = True
            executed = True
            executed_type = 'sell'
            
            # If "one breakout per range" mode, cancel the buy order
            if self.breakout_mode == "one breakout per range":
                self.buy_order_price = None  # Cancel buy order
            else:
                pass  # Keep both orders open
        
        return executed, executed_type

    def check_close_conditions(self, current_price, current_datetime):
        """Check if position should be closed based on SL/TP"""
        if not self.position_opened:
            return False, 0  # No position to close
        
        profit = 0
        should_close = False
        reason = ""
        
        if self.position_type == 'buy':
            # Check stop loss
            if self.position_sl > 0 and current_price <= self.position_sl:
                should_close = True
                reason = "Stop Loss"
            # Check take profit
            elif self.position_tp > 0 and current_price >= self.position_tp:
                should_close = True
                reason = "Take Profit"
            
            # Calculate profit for buy position
            profit = (current_price - self.position_price) * self.position_lot * 100  # XAUUSD lot size multiplier
            
        elif self.position_type == 'sell':
            # Check stop loss
            if self.position_sl > 0 and current_price >= self.position_sl:
                should_close = True
                reason = "Stop Loss"
            # Check take profit
            elif self.position_tp > 0 and current_price <= self.position_tp:
                should_close = True
                reason = "Take Profit"
            
            # Calculate profit for sell position
            profit = (self.position_price - current_price) * self.position_lot * 100  # XAUUSD lot size multiplier
        
        if should_close:
            # Close the position
            self.balance += profit
            self.position_opened = False
            self.total_trades += 1
            self.trade_profits.append(profit)
            self.trade_dates.append(current_datetime)  # Record when the trade occurred

            if profit > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1

            # Update equity tracking
            self.equity = self.balance
            self.balance_history.append(self.balance)
            if self.equity > self.max_equity:
                self.max_equity = self.equity
            if self.equity < self.min_equity:
                self.min_equity = self.equity
                self.max_drawdown = self.max_equity - self.min_equity
        
        return should_close, profit

    def manage_trailing_stop(self, current_price, current_datetime):
        """Manage trailing stop for open positions if enabled"""
        if not self.position_opened or self.trailing_stop <= 0 or self.trailing_start <= 0:
            return
        
        # Calculate current profit in points
        profit_points = 0
        if self.position_type == 'buy':
            profit_points = (current_price - self.position_price) / SYMBOL_POINT
        elif self.position_type == 'sell':
            profit_points = (self.position_price - current_price) / SYMBOL_POINT
        
        # If profit has not reached trailing_start, skip
        if profit_points < self.trailing_start:
            return
        
        # Calculate new stop loss level
        new_sl = 0
        if self.position_type == 'buy':
            # For buy positions, trail below current price
            new_sl = current_price - self.trailing_stop * SYMBOL_POINT
            # Only modify if new SL is higher than current SL or no SL is set
            if self.position_sl == 0 or new_sl > self.position_sl:
                self.position_sl = new_sl
        else:
            # For sell positions, trail above current price
            new_sl = current_price + self.trailing_stop * SYMBOL_POINT
            # Only modify if new SL is lower than current SL or no SL is set
            if self.position_sl == 0 or new_sl < self.position_sl:
                self.position_sl = new_sl

    def run_simulation(self, data):
        """Run the daily breakout simulation on the given data"""
        # Group data by trading day
        data['date'] = data['datetime'].dt.date
        grouped = data.groupby(data['datetime'].dt.date)
        
        for date, day_data in grouped:
            # Check if it's a valid trading day
            if not self.is_trading_day(datetime.combine(date, datetime.min.time())):
                continue
            
            # Calculate daily range
            if not self.calculate_daily_range(day_data):
                continue  # No data available in range
            
            # Place pending orders after range calculation
            if not self.place_pending_orders():
                continue  # Range size not within limits
            
            # Process each bar in the data after the range period
            after_range_data = day_data[day_data['datetime'] > self.range_end_time]
            
            for idx, row in after_range_data.iterrows():
                # Check if orders get executed
                executed, executed_type = self.check_order_execution(row['high'], row['datetime'])
                
                # If a position is open, check for close conditions and manage trailing stops
                if self.position_opened:
                    # Check if position should be closed (SL/TP)
                    closed, profit = self.check_close_conditions(row['low'], row['datetime'])
                    
                    # If position is still open, manage trailing stops
                    if not closed and self.trailing_stop > 0:
                        self.manage_trailing_stop(row['close'], row['datetime'])
                
                # Check if we need to close at range close time (if configured)
                if (self.range_close_time_calc and 
                    row['datetime'] >= self.range_close_time_calc and 
                    self.position_opened):
                    
                    # Close position at current close price
                    if self.position_type == 'buy':
                        profit = (row['close'] - self.position_price) * self.position_lot * 100
                    else:
                        profit = (self.position_price - row['close']) * self.position_lot * 100
                    
                    self.balance += profit
                    self.position_opened = False
                    self.total_trades += 1
                    self.trade_profits.append(profit)
                    self.trade_dates.append(row['datetime'])  # Record when the trade occurred

                    if profit > 0:
                        self.winning_trades += 1
                    else:
                        self.losing_trades += 1

                    # Update equity tracking
                    self.equity = self.balance
                    self.balance_history.append(self.balance)
                    if self.equity > self.max_equity:
                        self.max_equity = self.equity
                    if self.equity < self.min_equity:
                        self.min_equity = self.equity
                        self.max_drawdown = self.max_equity - self.min_equity
            
            # Reset for next day
            self.range_calculated = False
            self.orders_placed = False
            self.buy_order_price = None
            self.sell_order_price = None
        
        return {
            'final_balance': self.balance,
            'total_trades': self.total_trades,
            'winning_trades': self.winning_trades,
            'losing_trades': self.losing_trades,
            'max_drawdown': self.max_drawdown,
            'max_equity': self.max_equity
        }

def calculate_metrics(simulator):
    """Calculate performance metrics based on simulation results"""
    if simulator.total_trades == 0:
        return {
            'net_profit': 0,
            'profit_factor': 0,
            'win_rate': 0,
            'sharpe_ratio': 0,
            'total_trades': 0,
            'max_drawdown': 0,
            'return_on_account': 0
        }

    net_profit = simulator.balance - simulator.initial_balance
    win_rate = simulator.winning_trades / simulator.total_trades if simulator.total_trades > 0 else 0

    # Calculate profit factor (gross profit / gross loss)
    winning_profits = [p for p in simulator.trade_profits if p > 0]
    losing_losses = [abs(p) for p in simulator.trade_profits if p < 0]

    gross_profit = sum(winning_profits) if winning_profits else 0
    gross_loss = sum(losing_losses) if losing_losses else 0

    profit_factor = gross_profit / gross_loss if gross_loss > 0 else float('inf') if gross_profit > 0 else 0

    # Calculate Sharpe ratio
    # For simplicity, we'll use the returns of individual trades
    if len(simulator.trade_profits) > 1:
        # Convert trade profits to returns (as percentages of initial balance)
        returns = [p / simulator.initial_balance for p in simulator.trade_profits]
        avg_return = sum(returns) / len(returns)
        std_return = np.std(returns) if len(returns) > 1 else 0

        # Sharpe ratio (assuming risk-free rate of 0 for simplicity)
        sharpe_ratio = (avg_return / std_return) if std_return > 0 else 0
    else:
        sharpe_ratio = 0

    # Return on account as percentage
    return_on_account = (net_profit / simulator.initial_balance) * 100

    return {
        'net_profit': net_profit,
        'profit_factor': profit_factor,
        'win_rate': win_rate,
        'sharpe_ratio': sharpe_ratio,
        'total_trades': simulator.total_trades,
        'max_drawdown': simulator.max_drawdown,
        'return_on_account': return_on_account
    }

def grid_search_optimization(data, param_grid, top_n=10):
    """
    Perform grid search optimization to find the best parameters
    """
    print("Starting parameter optimization...")
    results = []
    
    param_combinations = list(product(*param_grid.values()))
    total_combinations = len(param_combinations)
    print(f"Testing {total_combinations} parameter combinations...")
    
    for i, param_values in enumerate(param_combinations):
        # Create parameter dict from current values
        params = dict(zip(param_grid.keys(), param_values))
        
        # Create simulator with these parameters
        simulator = DailyBreakoutSimulator(
            autolot=params['autolot'],
            stop_loss=params['stop_loss'],
            take_profit=params['take_profit'],
            range_start_time=params['range_start_time'],
            range_duration=params['range_duration'],
            range_close_time=params['range_close_time'],
            breakout_mode=params['breakout_mode'],
            range_on_monday=params['range_on_monday'],
            range_on_tuesday=params['range_on_tuesday'],
            range_on_wednesday=params['range_on_wednesday'],
            range_on_thursday=params['range_on_thursday'],
            range_on_friday=params['range_on_friday'],
            trailing_stop=params['trailing_stop'],
            trailing_start=params['trailing_start'],
            max_range_size=params['max_range_size'],
            min_range_size=params['min_range_size']
        )
        
        # Run simulation with these parameters
        run_results = simulator.run_simulation(data)
        metrics = calculate_metrics(simulator)  # Pass the simulator instance instead of results dict

        # Calculate composite score (you can modify this scoring function)
        # For now, using a simple weighted score
        score = (
            metrics['net_profit'] * 0.3 +
            metrics['profit_factor'] * 0.3 +
            metrics['win_rate'] * 0.2 +
            metrics['sharpe_ratio'] * 0.2
        )

        results.append({
            'params': params,
            'metrics': metrics,
            'score': score
        })
        
        if (i + 1) % 50 == 0:
            print(f"Completed {i + 1}/{total_combinations} combinations")
    
    # Sort by score (highest first)
    results.sort(key=lambda x: x['score'], reverse=True)
    
    print(f"\nTop {top_n} parameter combinations:")
    for i, result in enumerate(results[:top_n]):
        print(f"\n{i+1}. Score: {result['score']:.4f}")
        print(f"   Parameters: {result['params']}")
        print(f"   Metrics: Net Profit: {result['metrics']['net_profit']:.2f}, "
              f"Profit Factor: {result['metrics']['profit_factor']:.2f}, "
              f"Win Rate: {result['metrics']['win_rate']:.2%}, "
              f"Sharpe: {result['metrics']['sharpe_ratio']:.2f}, "
              f"Trades: {result['metrics']['total_trades']}")
    
    return results[:top_n]

def read_and_filter_xauusd():
    """
    Reads the XAUUSD_M30.csv file and filters it for the date range 2019-11-01 to 2020-08-31.
    Also filters out weekend data to match trading hours.
    """
    # Read the CSV file
    df = pd.read_csv('XAUUSD_M30.csv', header=None)
    
    # Assuming the first column contains datetime information
    # Column names based on typical forex data: datetime, open, high, low, close, volume
    df.columns = ['datetime', 'open', 'high', 'low', 'close', 'volume']
    
    # Convert the datetime column to pandas datetime
    df['datetime'] = pd.to_datetime(df['datetime'])
    
    # Define the start and end dates for filtering
    start_date = datetime(2019, 11, 1)
    end_date = datetime(2020, 8, 31)
    
    # Filter the dataframe to the specified date range
    filtered_df = df[(df['datetime'] >= start_date) & (df['datetime'] <= end_date)]
    
    # Filter out weekend data (Saturday=5, Sunday=6 in pandas weekday)
    filtered_df = filtered_df[filtered_df['datetime'].dt.weekday < 5]
    
    # Sort by datetime to ensure chronological order
    filtered_df = filtered_df.sort_values(by='datetime')
    
    return filtered_df

if __name__ == "__main__":
    # Read the data
    print("Loading data...")
    data = read_and_filter_xauusd()
    
    print(f"Data loaded: {len(data)} rows from {data['datetime'].min()} to {data['datetime'].max()}")
    
    # Define parameter grid for optimization
    # Note: Using a smaller grid for demonstration, you can expand this
    param_grid = {
        'autolot': [True],
        'stop_loss': [50, 90, 120],  # 50%, 90%, 120% of range
        'take_profit': [0, 100, 200],  # 0%, 100%, 200% of range
        'range_start_time': [60, 90, 120],  # 1, 1.5, 2 hours after market open
        'range_duration': [180, 270, 360],  # 3, 4.5, 6 hours
        'range_close_time': [1020, 1200, 1380],  # Various closing times
        'breakout_mode': ["one breakout per range"],
        'range_on_monday': [True, False],
        'range_on_tuesday': [False],  # As per original
        'range_on_wednesday': [True, False],
        'range_on_thursday': [True, False],
        'range_on_friday': [True, False],
        'trailing_stop': [200, 300, 500],  # points
        'trailing_start': [300, 500, 800],  # points
        'max_range_size': [1500, 2000, 2500],  # points
        'min_range_size': [300, 500, 800]  # points
    }
    
    # Run the optimization
    best_params = grid_search_optimization(data, param_grid, top_n=5)
    
    # Save results to CSV
    import csv
    import json

    # Create a CSV file with the results
    with open('optimization.csv', 'w', newline='') as csvfile:
        fieldnames = ['rank', 'score', 'net_profit', 'profit_factor', 'win_rate',
                     'sharpe_ratio', 'total_trades', 'max_drawdown', 'return_on_account'] + \
                    list(param_grid.keys())
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

        writer.writeheader()
        for i, result in enumerate(best_params):
            row = {
                'rank': i + 1,
                'score': result['score'],
                'net_profit': result['metrics']['net_profit'],
                'profit_factor': result['metrics']['profit_factor'],
                'win_rate': result['metrics']['win_rate'],
                'sharpe_ratio': result['metrics']['sharpe_ratio'],
                'total_trades': result['metrics']['total_trades'],
                'max_drawdown': result['metrics']['max_drawdown'],
                'return_on_account': result['metrics']['return_on_account']
            }
            # Add parameter values to the row
            for param, value in result['params'].items():
                row[param] = value
            writer.writerow(row)

    print(f"\nOptimization complete! Best parameter combination:")
    best = best_params[0]
    print(f"Score: {best['score']:.4f}")
    print(f"Parameters: {best['params']}")
    print(f"Metrics: {best['metrics']}")
    print(f"\nFull results saved to optimization.csv")