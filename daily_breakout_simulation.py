import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Input Parameters (from DailyBreakout-ORIGINAL.mq5)
MAGIC_NUMBER = 12345
AUTOLOT = True
BASE_BALANCE = 100.0
LOT = 0.01
MIN_LOT = 0.01
MAX_LOT = 10.0
STOP_LOSS = 90  # in % of the range
TAKE_PROFIT = 0  # in % of the range
RANGE_START_TIME = 90  # Range start time in minutes from start of day
RANGE_DURATION = 270  # Range duration in minutes
RANGE_CLOSE_TIME = 1200  # Range close time in minutes (-1=off)
BREAKOUT_MODE = "one breakout per range"
RANGE_ON_MONDAY = True
RANGE_ON_TUESDAY = False
RANGE_ON_WEDNESDAY = True
RANGE_ON_THURSDAY = True
RANGE_ON_FRIDAY = True
TRAILING_STOP = 300  # in points (0=off)
TRAILING_START = 500  # Activate trailing after profit in points
MAX_RANGE_SIZE = 1500  # Maximum range size in points (0=off)
MIN_RANGE_SIZE = 500  # Minimum range size in points (0=off)

# Trading constants
SYMBOL_POINT = 0.001  # Assumed point size for XAUUSD

class DailyBreakoutSimulator:
    def __init__(self, initial_balance=5000.0):
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
        
        # Track statistics
        self.total_trades = 0
        self.winning_trades = 0
        self.losing_trades = 0
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
        self.range_start_time = None
        self.range_end_time = None
        self.range_close_time = None
        self.high_price = 0
        self.low_price = float('inf')
        
        # Track orders
        self.buy_order_price = None
        self.sell_order_price = None
        
    def is_trading_day(self, date):
        """Check if today is a valid trading day"""
        day_of_week = date.weekday()  # Monday is 0, Sunday is 6
        
        if day_of_week == 0:  # Monday
            return RANGE_ON_MONDAY
        elif day_of_week == 1:  # Tuesday
            return RANGE_ON_TUESDAY
        elif day_of_week == 2:  # Wednesday
            return RANGE_ON_WEDNESDAY
        elif day_of_week == 3:  # Thursday
            return RANGE_ON_THURSDAY
        elif day_of_week == 4:  # Friday
            return RANGE_ON_FRIDAY
        else:  # Weekend
            return False
    
    def calculate_lot_size(self, range_size):
        """Calculate lot size based on the settings"""
        if AUTOLOT:  # Autolot mode
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
        self.range_start_time = day_start + timedelta(minutes=RANGE_START_TIME)
        self.range_end_time = self.range_start_time + timedelta(minutes=RANGE_DURATION)
        
        if RANGE_CLOSE_TIME > 0:
            self.range_close_time = day_start + timedelta(minutes=RANGE_CLOSE_TIME)
        else:
            self.range_close_time = None  # No automatic close time
        
        # Filter data to be within the range time
        range_data = day_data[
            (day_data['datetime'] >= self.range_start_time) & 
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
            print(f"New maximum range detected: {range_points:.2f} points on {self.max_range_date.strftime('%Y-%m-%d')}")
        
        if range_points < self.min_range_ever:
            self.min_range_ever = range_points
            self.min_range_date = day_start
            print(f"New minimum range detected: {range_points:.2f} points on {self.min_range_date.strftime('%Y-%m-%d')}")
        
        print(f"Daily range calculated - High: {self.high_price:.3f} Low: {self.low_price:.3f} Range: {range_points:.2f} points")
        return True
    
    def place_pending_orders(self):
        """Place pending orders based on the calculated range"""
        if self.high_price <= 0 or self.low_price == float('inf'):
            return False
        
        range_size = self.high_price - self.low_price
        range_points = range_size / SYMBOL_POINT
        
        print("=== Daily Range Details ===")
        print(f"Date: {self.range_start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Range High: {self.high_price:.3f}")
        print(f"Range Low: {self.low_price:.3f}")
        print(f"Range Size: {range_points:.2f} points")
        print("=========================")
        
        # Check if range size is within acceptable limits
        if MAX_RANGE_SIZE > 0 and range_points > MAX_RANGE_SIZE:
            print(f"Range size ({range_points:.2f} points) exceeds maximum ({MAX_RANGE_SIZE} points). No orders placed.")
            self.orders_placed = True
            return False
        
        if MIN_RANGE_SIZE > 0 and range_points < MIN_RANGE_SIZE:
            print(f"Range size ({range_points:.2f} points) is below minimum ({MIN_RANGE_SIZE} points). No orders placed.")
            self.orders_placed = True
            return False
        
        # Calculate lot size
        self.position_lot = self.calculate_lot_size(range_size)
        
        # Calculate SL and TP
        buy_sl = 0
        buy_tp = 0
        sell_sl = 0
        sell_tp = 0
        
        if STOP_LOSS > 0:
            # Calculate SL based on range percentage
            buy_sl = self.high_price - (range_size * STOP_LOSS / 100)
            sell_sl = self.low_price + (range_size * STOP_LOSS / 100)
        
        if TAKE_PROFIT > 0:
            buy_tp = self.high_price + (range_size * TAKE_PROFIT / 100)
            sell_tp = self.low_price - (range_size * TAKE_PROFIT / 100)
        
        # Place orders
        self.buy_order_price = self.high_price
        self.sell_order_price = self.low_price
        self.position_sl = buy_sl if buy_sl > 0 else sell_sl
        self.position_tp = buy_tp if buy_tp > 0 else sell_tp
        
        print(f"Buy Stop order placed at {self.buy_order_price:.3f} with lot size {self.position_lot}")
        print(f"Sell Stop order placed at {self.sell_order_price:.3f} with lot size {self.position_lot}")
        
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
            if BREAKOUT_MODE == "one breakout per range":
                self.sell_order_price = None  # Cancel sell order
                print(f"{current_datetime} - Buy order triggered at {current_price:.3f}. Sell order cancelled due to 'one breakout per range' mode.")
            else:
                print(f"{current_datetime} - Buy order triggered at {current_price:.3f}")
        
        # Check if sell stop order is triggered (price going down)
        elif self.sell_order_price and current_price <= self.sell_order_price:
            # Sell order triggered
            self.position_type = 'sell'
            self.position_price = current_price
            self.position_opened = True
            executed = True
            executed_type = 'sell'
            
            # If "one breakout per range" mode, cancel the buy order
            if BREAKOUT_MODE == "one breakout per range":
                self.buy_order_price = None  # Cancel buy order
                print(f"{current_datetime} - Sell order triggered at {current_price:.3f}. Buy order cancelled due to 'one breakout per range' mode.")
            else:
                print(f"{current_datetime} - Sell order triggered at {current_price:.3f}")
        
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
            
            if profit > 0:
                self.winning_trades += 1
            else:
                self.losing_trades += 1
            
            print(f"{current_datetime} - Position closed due to {reason}. Profit: {profit:.2f}. Balance: {self.balance:.2f}")
            
            # Update equity tracking
            self.equity = self.balance
            if self.equity > self.max_equity:
                self.max_equity = self.equity
            if self.equity < self.min_equity:
                self.min_equity = self.equity
                self.max_drawdown = self.max_equity - self.min_equity
        
        return should_close, profit
    
    def manage_trailing_stop(self, current_price, current_datetime):
        """Manage trailing stop for open positions if enabled"""
        if not self.position_opened or TRAILING_STOP <= 0 or TRAILING_START <= 0:
            return
        
        # Calculate current profit in points
        profit_points = 0
        if self.position_type == 'buy':
            profit_points = (current_price - self.position_price) / SYMBOL_POINT
        elif self.position_type == 'sell':
            profit_points = (self.position_price - current_price) / SYMBOL_POINT
        
        # If profit has not reached trailing_start, skip
        if profit_points < TRAILING_START:
            return
        
        # Calculate new stop loss level
        new_sl = 0
        if self.position_type == 'buy':
            # For buy positions, trail below current price
            new_sl = current_price - TRAILING_STOP * SYMBOL_POINT
            # Only modify if new SL is higher than current SL or no SL is set
            if self.position_sl == 0 or new_sl > self.position_sl:
                self.position_sl = new_sl
                print(f"{current_datetime} - Trailing stop for buy position - New SL: {new_sl:.3f}")
        else:
            # For sell positions, trail above current price
            new_sl = current_price + TRAILING_STOP * SYMBOL_POINT
            # Only modify if new SL is lower than current SL or no SL is set
            if self.position_sl == 0 or new_sl < self.position_sl:
                self.position_sl = new_sl
                print(f"{current_datetime} - Trailing stop for sell position - New SL: {new_sl:.3f}")
    
    def run_simulation(self, data):
        """Run the daily breakout simulation on the given data"""
        print(f"Starting Daily Breakout simulation with initial balance: ${self.initial_balance:.2f}")
        print(f"Using parameters from DailyBreakout-ORIGINAL.mq5")
        print("================================")
        
        # Group data by trading day
        data['date'] = data['datetime'].dt.date
        grouped = data.groupby(data['datetime'].dt.date)
        
        for date, day_data in grouped:
            print(f"\nProcessing day: {date}")
            
            # Check if it's a valid trading day
            if not self.is_trading_day(datetime.combine(date, datetime.min.time())):
                print(f"{date} is not a valid trading day, skipping...")
                continue
            
            print(f"Calculating range for {date}...")
            
            # Calculate daily range
            if not self.calculate_daily_range(day_data):
                print(f"No data available in range for {date}, skipping...")
                continue
            
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
                    if not closed and TRAILING_STOP > 0:
                        self.manage_trailing_stop(row['close'], row['datetime'])
                
                # Check if we need to close at range close time (if configured)
                if self.range_close_time and row['datetime'] >= self.range_close_time and self.position_opened:
                    # Close position at current close price
                    if self.position_type == 'buy':
                        profit = (row['close'] - self.position_price) * self.position_lot * 100
                    else:
                        profit = (self.position_price - row['close']) * self.position_lot * 100
                    
                    self.balance += profit
                    self.position_opened = False
                    self.total_trades += 1
                    
                    if profit > 0:
                        self.winning_trades += 1
                    else:
                        self.losing_trades += 1
                    
                    print(f"{row['datetime']} - Position closed at range close time. Profit: {profit:.2f}. Balance: {self.balance:.2f}")
                    
                    # Update equity tracking
                    self.equity = self.balance
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
        
        # Print final statistics
        print("\n" + "="*40)
        print("SIMULATION COMPLETE")
        print("="*40)
        print(f"Initial Balance: ${self.initial_balance:.2f}")
        print(f"Final Balance: ${self.balance:.2f}")
        print(f"Net Profit: ${self.balance - self.initial_balance:.2f}")
        print(f"Total Trades: {self.total_trades}")
        if self.total_trades > 0:
            print(f"Winning Trades: {self.winning_trades}")
            print(f"Losing Trades: {self.losing_trades}")
            print(f"Win Rate: {(self.winning_trades/self.total_trades)*100:.2f}%")
        print(f"Max Equity: ${self.max_equity:.2f}")
        print(f"Min Equity: ${self.min_equity:.2f}")
        print(f"Max Drawdown: ${self.max_drawdown:.2f}")
        print(f"Max Range Ever: {self.max_range_ever:.2f} points on {self.max_range_date}")
        print(f"Min Range Ever: {self.min_range_ever:.2f} points on {self.min_range_date}")
        print("="*40)

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
    # Execute the function and create the simulator
    try:
        filtered_data = read_and_filter_xauusd()
        
        print(f"Running simulation on data from {filtered_data['datetime'].min()} to {filtered_data['datetime'].max()}")
        print(f"Total rows in filtered dataset: {len(filtered_data)}")
        
        # Create and run the simulator
        simulator = DailyBreakoutSimulator(initial_balance=5000.0)
        simulator.run_simulation(filtered_data)
        
    except FileNotFoundError:
        print("Error: XAUUSD_M30.csv file not found in the current directory.")
    except Exception as e:
        print(f"An error occurred: {e}")