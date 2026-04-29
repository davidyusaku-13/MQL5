//+------------------------------------------------------------------+
//|                                            Daily Range Breakout EA |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"

// Include required libraries
#include <Trade\Trade.mqh>
CTrade trade;

enum ENUM_BREAKOUT_MODE
{
   BREAKOUT_ONE_PER_RANGE,  // One breakout per range
   BREAKOUT_BOTH_DIRECTIONS // Both directions
};

// Input Parameters
input int      magic_number = 12345;       // Magic Number
input bool     autolot = true;            // Use autolot based on balance
input double   base_balance = 100.0;      // Base balance for lot calculation
input double   lot = 0.01;                  // Lot size for each base_balance unit
input double   min_lot = 0.01;             // Minimum lot size
input double   max_lot = 10000.0;             // Maximum lot size
input int      stop_loss = 90;             // Stop Loss in % of the range (0=off)
input int      take_profit = 0;            // Take Profit in % of the range (0=off)
input int      range_start_time = 90;      // Range start time in minutes
input int      range_duration = 270;       // Range duration in minutes
input int      range_close_time = 1200;    // Range close time in minutes (-1=off)
input ENUM_BREAKOUT_MODE breakout_mode = BREAKOUT_ONE_PER_RANGE; // Breakout Mode
input bool     range_on_monday = true;     // Range on Monday
input bool     range_on_tuesday = true;    // Range on Tuesday
input bool     range_on_wednesday = true;  // Range on Wednesday
input bool     range_on_thursday = true;   // Range on Thursday
input bool     range_on_friday = true;     // Range on Friday
input int      trailing_stop = 300;        // Trailing Stop in points (0=off)
input int      trailing_start = 500;       // Activate trailing after profit in points
input double   max_range_size = 1500;         // Maximum range size in points (0=off)
input double   min_range_size = 500;         // Minimum range size in points (0=off)


// Global Variables
double g_high_price = 0;
double g_low_price = 0;
datetime g_range_end_time = 0;
datetime g_close_time = 0;
bool g_range_calculated = false;
bool g_orders_placed = false;
ulong g_buy_ticket = 0;
ulong g_sell_ticket = 0;
double g_lot_size = 0;
datetime g_range_start_time = 0;
datetime g_current_day = 0;
datetime g_test_start_time = 0;
datetime g_test_end_time = 0;
string g_start_line_name = "Range_Start_Line";
string g_end_line_name = "Range_End_Line";
string g_close_line_name = "Range_Close_Line";
bool g_lines_drawn = false;
int g_trailing_points = 300;      // Trailing stop in points (default 30 pips)
bool g_trailing_activated = false; // Default trailing status

// Add these global variables to track ranges
double g_max_range_ever = 0;    // Track maximum range seen
double g_min_range_ever = 999999; // Track minimum range seen
datetime g_max_range_date = 0;  // Date of maximum range
datetime g_min_range_date = 0;  // Date of minimum range

//+------------------------------------------------------------------+
//| Check if close time has passed for current day                    |
//+------------------------------------------------------------------+
bool IsAfterCloseTime()
{
   return (g_close_time > 0 && TimeCurrent() >= g_close_time);
}

//+------------------------------------------------------------------+
//| Check if one-breakout mode is enabled                             |
//+------------------------------------------------------------------+
bool IsOneBreakoutMode()
{
   return (breakout_mode == BREAKOUT_ONE_PER_RANGE);
}

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   if(price <= 0)
      return 0;

   return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Get decimal precision needed for lot step                         |
//+------------------------------------------------------------------+
int GetLotDigits(double lot_step)
{
   if(lot_step <= 0)
      return 2;

   int digits = 0;
   double step = lot_step;

   while(digits < 8 && MathAbs(step - MathRound(step)) > 0.00000001)
   {
      step *= 10.0;
      digits++;
   }

   return digits;
}

//+------------------------------------------------------------------+
//| Clamp and normalize lot size to input and symbol limits            |
//+------------------------------------------------------------------+
double NormalizeLotSize(double requested_lot)
{
   double symbol_min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double symbol_max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(symbol_min_lot <= 0 || symbol_max_lot <= 0 || lot_step <= 0)
   {
      Print("Invalid symbol volume settings. Min: ", symbol_min_lot,
            ", Max: ", symbol_max_lot, ", Step: ", lot_step);
      return 0;
   }

   double effective_min_lot = MathMax(min_lot, symbol_min_lot);
   double effective_max_lot = MathMin(max_lot, symbol_max_lot);

   if(effective_min_lot > effective_max_lot)
   {
      Print("Lot limits invalid for symbol. Input min/max: ", min_lot, "/", max_lot,
            ", Symbol min/max: ", symbol_min_lot, "/", symbol_max_lot);
      return 0;
   }

   double lot_size = requested_lot;
   if(lot_size < effective_min_lot)
      lot_size = effective_min_lot;
   else if(lot_size > effective_max_lot)
      lot_size = effective_max_lot;

   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   if(lot_size < effective_min_lot)
      lot_size = effective_min_lot;

   return NormalizeDouble(lot_size, GetLotDigits(lot_step));
}

//+------------------------------------------------------------------+
//| Validate EA inputs                                                 |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
   if(autolot && base_balance <= 0)
   {
      Print("Invalid input: base_balance must be > 0 when autolot is enabled.");
      return false;
   }

   if(lot <= 0 || min_lot <= 0 || max_lot <= 0 || min_lot > max_lot)
   {
      Print("Invalid lot inputs. lot/min_lot/max_lot must be positive and min_lot <= max_lot.");
      return false;
   }

   if(range_start_time < 0 || range_start_time >= 1440 || range_duration <= 0)
   {
      Print("Invalid range inputs. range_start_time must be 0..1439 and range_duration must be > 0.");
      return false;
   }

   if(range_close_time < -1 || range_close_time >= 1440)
   {
      Print("Invalid close time. range_close_time must be -1 or 0..1439.");
      return false;
   }

   if(stop_loss < 0 || take_profit < 0 || trailing_stop < 0 || trailing_start < 0)
   {
      Print("Invalid risk inputs. stop_loss, take_profit, trailing_stop, and trailing_start cannot be negative.");
      return false;
   }

   if(max_range_size < 0 || min_range_size < 0 || (max_range_size > 0 && min_range_size > max_range_size))
   {
      Print("Invalid range size filters. min_range_size/max_range_size must be non-negative and min <= max.");
      return false;
   }

   if(NormalizeLotSize(lot) <= 0)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check if EA has open position by type                             |
//+------------------------------------------------------------------+
bool HasPositionType(ENUM_POSITION_TYPE position_type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) == magic_number &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_TYPE) == position_type)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if EA has active exposure                                   |
//+------------------------------------------------------------------+
bool HasActiveExposure()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) == magic_number &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         return true;
      }
   }

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong order_ticket = OrderGetTicket(i);
      if(order_ticket <= 0)
         continue;

      if(OrderGetInteger(ORDER_MAGIC) == magic_number &&
         OrderGetString(ORDER_SYMBOL) == _Symbol)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Delete pending orders by type                                      |
//+------------------------------------------------------------------+
bool DeletePendingOrdersByType(ENUM_ORDER_TYPE order_type)
{
   bool all_deleted = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong order_ticket = OrderGetTicket(i);
      if(order_ticket <= 0)
         continue;

      if(OrderGetInteger(ORDER_MAGIC) != magic_number ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_TYPE) != order_type)
      {
         continue;
      }

      if(!trade.OrderDelete(order_ticket))
      {
         all_deleted = false;
         Print("Failed to delete pending order #", order_ticket, ". Error: ",
               trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }

   return all_deleted;
}

//+------------------------------------------------------------------+
//| Check if SL is valid for trailing modification                     |
//+------------------------------------------------------------------+
bool IsValidTrailingStop(ENUM_POSITION_TYPE position_type, double new_sl)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_distance = MathMax(stop_level, freeze_level) * _Point;

   if(bid <= 0 || ask <= 0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (new_sl < bid - min_distance);

   return (new_sl > ask + min_distance);
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateInputs())
      return(INIT_PARAMETERS_INCORRECT);

   // Initialize
   g_range_calculated = false;
   g_orders_placed = false;
   g_lines_drawn = false;
   g_buy_ticket = 0;
   g_sell_ticket = 0;
   g_lot_size = 0;
   g_test_start_time = 0;
   g_test_end_time = 0;
   g_trailing_points = trailing_stop;

   // Set current day
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   g_current_day = StructToTime(dt);

   // Delete any existing lines
   DeleteAllLines();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
   DeleteAllLines();
   if(g_max_range_ever > 0)
   {
      Print("=== Range Statistics ===");
      Print("Maximum range during backtest: ", g_max_range_ever, " points on ", TimeToString(g_max_range_date));
      Print("Minimum range during backtest: ", g_min_range_ever, " points on ", TimeToString(g_min_range_date));
      Print("======================");
   }
}

//+------------------------------------------------------------------+
//| Custom optimization criterion                                     |
//+------------------------------------------------------------------+
double OnTester()
{
   double equity_dd_percent = TesterStatistics(STAT_EQUITYDD_PERCENT);
   if(equity_dd_percent >= 30.0)
      return 0.0;

   double trades = TesterStatistics(STAT_TRADES);
   if(trades <= 0 || g_test_start_time <= 0 || g_test_end_time <= g_test_start_time)
      return 0.0;

   double years = (double)(g_test_end_time - g_test_start_time) / 31557600.0;
   if(years <= 0)
      return 0.0;

   double trades_per_year = trades / years;
   if(trades_per_year < 12.0)
      return 0.0;

   double initial_deposit = TesterStatistics(STAT_INITIAL_DEPOSIT);
   double final_balance = initial_deposit + TesterStatistics(STAT_PROFIT);
   if(initial_deposit <= 0 || final_balance <= 0)
      return 0.0;

   double cagr_percent = (MathPow(final_balance / initial_deposit, 1.0 / years) - 1.0) * 100.0;
   if(cagr_percent < 25.0)
      return 0.0;

   return TesterStatistics(STAT_PROFIT);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime current_time = TimeCurrent();
   if(g_test_start_time <= 0)
      g_test_start_time = current_time;
   g_test_end_time = current_time;

   // Check if day has changed
   MqlDateTime dt;
   TimeToStruct(current_time, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today = StructToTime(dt);

   if(today != g_current_day)
   {
      // New day, reset EA
      g_range_calculated = false;
      g_orders_placed = false;
      g_lines_drawn = false;
      g_buy_ticket = 0;
      g_sell_ticket = 0;
      g_lot_size = 0;
      g_current_day = today;
      DeleteAllLines();
   }

   // Check if it's a valid trading day
   if(!IsTradingDay())
      return;

   // Calculate daily range if not already done
   if(!g_range_calculated)
   {
      CalculateDailyRange();
      return;
   }

   // Draw vertical lines for range times if not already drawn
   if(!g_lines_drawn)
   {
      DrawRangeLines();
      g_lines_drawn = true;
   }

   // Do not open new exposure after the daily close time
   if(IsAfterCloseTime())
   {
      if(HasActiveExposure())
         CloseAllOrders();

      g_orders_placed = true;
      return;
   }

   // Check if we should place orders
   if(!g_orders_placed && current_time >= g_range_end_time)
   {
      PlacePendingOrders();
      return;
   }

   // Apply trailing stop to open positions if enabled
   if(trailing_stop > 0)
   {
      ManageTrailingStop();
   }

   // Manage existing orders
   ManageOrders();
}

//+------------------------------------------------------------------+
//| Check if today is a valid trading day                            |
//+------------------------------------------------------------------+
bool IsTradingDay()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int day_of_week = dt.day_of_week;

   switch(day_of_week)
   {
      case 1: return range_on_monday;
      case 2: return range_on_tuesday;
      case 3: return range_on_wednesday;
      case 4: return range_on_thursday;
      case 5: return range_on_friday;
      default: return false; // Weekend
   }
}

//+------------------------------------------------------------------+
//| Calculate the daily high/low range                               |
//+------------------------------------------------------------------+
void CalculateDailyRange()
{
   datetime current_time = TimeCurrent();

   // Calculate range start time (from the start of the day)
   MqlDateTime dt;
   TimeToStruct(current_time, dt);

   // Reset time to beginning of day
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   datetime today = StructToTime(dt);

   // Calculate range start time
   g_range_start_time = today + range_start_time * 60;

   // Calculate range end time
   g_range_end_time = g_range_start_time + range_duration * 60;

   // Calculate order close time
   if(range_close_time > 0)
      g_close_time = today + range_close_time * 60;
   else
      g_close_time = 0; // No automatic close time

   // Check if we're still in range calculation period
   if(current_time < g_range_end_time)
      return;

   // Calculate the high and low of the range
   g_high_price = 0;
   g_low_price = 99999999;

   MqlRates rates[];
   datetime range_last_bar_time = g_range_end_time - 1;
   int bars_copied = CopyRates(_Symbol, PERIOD_M1, g_range_start_time, range_last_bar_time, rates);
   if(bars_copied <= 0)
   {
      Print("No M1 bars found for range window: ", TimeToString(g_range_start_time),
            " - ", TimeToString(range_last_bar_time));
      return;
   }

   for(int i = 0; i < bars_copied; i++)
   {
      if(rates[i].time < g_range_start_time || rates[i].time >= g_range_end_time)
         continue;

      if(rates[i].high > g_high_price)
         g_high_price = rates[i].high;

      if(rates[i].low < g_low_price)
         g_low_price = rates[i].low;
   }

   // Mark range as calculated
   if(g_high_price > 0 && g_low_price < 99999999)
   {
      g_range_calculated = true;
      double range_size = g_high_price - g_low_price;
      double range_points = range_size / _Point;

      // Track maximum and minimum ranges observed
      if(range_points > g_max_range_ever)
      {
         g_max_range_ever = range_points;
         g_max_range_date = TimeCurrent();
         Print("New maximum range detected: ", range_points, " points on ", TimeToString(g_max_range_date));
      }

      if(range_points < g_min_range_ever)
      {
         g_min_range_ever = range_points;
         g_min_range_date = TimeCurrent();
         Print("New minimum range detected: ", range_points, " points on ", TimeToString(g_min_range_date));
      }

      Print("Daily range calculated - High: ", g_high_price, " Low: ", g_low_price,
            " Range: ", range_points, " points");
   }


}

//+------------------------------------------------------------------+
//| Calculate lot size based on the settings                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size)
{
   double requested_lot = lot;

   if(autolot) // Autolot mode
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Calculate lot size proportional to account balance
      double balance_ratio = account_balance / base_balance;
      requested_lot = balance_ratio * lot;
      double lot_size = NormalizeLotSize(requested_lot);

      Print("Autolot calculation - Balance: ", account_balance, ", Base balance: ", base_balance,
            ", Balance ratio: ", balance_ratio, ", Base lot: ", lot, ", Calculated lot: ", lot_size);

      return lot_size;
   }

   return NormalizeLotSize(requested_lot);
}

//+------------------------------------------------------------------+
//| Place pending orders based on the calculated range               |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if(g_high_price <= 0 || g_low_price >= 99999999)
      return;

   if(IsAfterCloseTime())
   {
      g_orders_placed = true;
      return;
   }

   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;

   Print("=== Daily Range Details ===");
   Print("Date: ", TimeToString(TimeCurrent()));
   Print("Range High: ", g_high_price);
   Print("Range Low: ", g_low_price);
   Print("Range Size: ", range_points, " points");
   Print("=========================");


   // Check if range size is within acceptable limits
   if(max_range_size > 0 && range_points > max_range_size)
   {
      Print("Range size (", range_points, " points) exceeds maximum (", max_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   if(min_range_size > 0 && range_points < min_range_size)
   {
      Print("Range size (", range_points, " points) is below minimum (", min_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }


   g_lot_size = CalculateLotSize(range_size);
   if(g_lot_size <= 0)
   {
      Print("Invalid calculated lot size. No orders placed.");
      return;
   }

   // Calculate SL and TP
   double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;

   if(stop_loss > 0)
   {
      // Calculate SL based on range percentage
      buy_sl = NormalizePrice(g_high_price - (range_size * stop_loss / 100));
      sell_sl = NormalizePrice(g_low_price + (range_size * stop_loss / 100));
   }

   if(take_profit > 0)
   {
      buy_tp = NormalizePrice(g_high_price + (range_size * take_profit / 100));
      sell_tp = NormalizePrice(g_low_price - (range_size * take_profit / 100));
   }

   // Place buy stop order at the high of the range
   trade.SetExpertMagicNumber(magic_number);

   bool buy_success = trade.BuyStop(
      g_lot_size,
      NormalizePrice(g_high_price),
      _Symbol,
      buy_sl,
      buy_tp,
      ORDER_TIME_DAY,
      0,
      "Range Breakout Buy"
   );

   if(buy_success)
   {
      g_buy_ticket = trade.ResultOrder();
      Print("Buy Stop order placed at ", g_high_price, " with lot size ", g_lot_size);
   }
   else
   {
      Print("Failed to place Buy Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
   }

   // Place sell stop order at the low of the range
   bool sell_success = trade.SellStop(
      g_lot_size,
      NormalizePrice(g_low_price),
      _Symbol,
      sell_sl,
      sell_tp,
      ORDER_TIME_DAY,
      0,
      "Range Breakout Sell"
   );

   if(sell_success)
   {
      g_sell_ticket = trade.ResultOrder();
      Print("Sell Stop order placed at ", g_low_price, " with lot size ", g_lot_size);
   }
   else
   {
      Print("Failed to place Sell Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
   }

   if(buy_success || sell_success)
      g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| Manage open orders                                               |
//+------------------------------------------------------------------+
void ManageOrders()
{
   // If using "one breakout per range" mode, check if one order has been triggered
   if(!IsOneBreakoutMode())
      return;

   bool buy_triggered = HasPositionType(POSITION_TYPE_BUY);
   bool sell_triggered = HasPositionType(POSITION_TYPE_SELL);

   // If one order has been triggered, delete the other pending order
   if(buy_triggered)
   {
      if(DeletePendingOrdersByType(ORDER_TYPE_SELL_STOP))
         g_sell_ticket = 0;
   }
   else if(sell_triggered)
   {
      if(DeletePendingOrdersByType(ORDER_TYPE_BUY_STOP))
         g_buy_ticket = 0;
   }
}

//+------------------------------------------------------------------+
//| Close all orders for this EA                                     |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   // Close all positions with this magic number
   int positions_total = PositionsTotal();
   for(int i = positions_total - 1; i >= 0; i--)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(position_ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to close position #", position_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Delete all pending orders with this magic number
   int orders_total = OrdersTotal();
   for(int i = orders_total - 1; i >= 0; i--)
   {
      ulong order_ticket = OrderGetTicket(i);
      if(order_ticket > 0)
      {
         if(OrderGetInteger(ORDER_MAGIC) == magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(order_ticket);
            if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to delete order #", order_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Keep the day processed so close time cannot reopen exposure
   g_orders_placed = true;
   g_buy_ticket = 0;
   g_sell_ticket = 0;
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(trailing_stop <= 0 || trailing_start <= 0)
      return;

   // Check all open positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);

      if(position_ticket > 0)
      {
         // Check if this position belongs to our EA
         if(PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Get position details
            double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double position_sl = PositionGetDouble(POSITION_SL);
            double position_tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Current price depending on position type
            double current_price = (position_type == POSITION_TYPE_BUY) ?
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // Calculate current profit in points
            double profit_points = 0;

            if(position_type == POSITION_TYPE_BUY)
               profit_points = (current_price - position_open_price) / _Point;
            else
               profit_points = (position_open_price - current_price) / _Point;

            // If profit has not reached trailing_start, skip
            if(profit_points < trailing_start)
               continue;

            // Calculate new stop loss level
            double new_sl = 0;

            if(position_type == POSITION_TYPE_BUY)
            {
               // For buy positions, trail below current price
               new_sl = NormalizePrice(current_price - trailing_stop * _Point);

               // Only modify if new SL is higher than current SL
               if((position_sl == 0 || new_sl > position_sl) && IsValidTrailingStop(position_type, new_sl))
               {
                  if(trade.PositionModify(position_ticket, new_sl, position_tp))
                     Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
                  else
                     Print("Failed to modify trailing stop for position #", position_ticket,
                           ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
               }
            }
            else
            {
               // For sell positions, trail above current price
               new_sl = NormalizePrice(current_price + trailing_stop * _Point);

               // Only modify if new SL is lower than current SL or no SL is set
               if((position_sl == 0 || new_sl < position_sl) && IsValidTrailingStop(position_type, new_sl))
               {
                  if(trade.PositionModify(position_ticket, new_sl, position_tp))
                     Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
                  else
                     Print("Failed to modify trailing stop for position #", position_ticket,
                           ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw vertical lines for range times                             |
//+------------------------------------------------------------------+
void DrawRangeLines()
{
   // Delete any existing lines
   DeleteAllLines();

   // Draw range start line (blue)
   ObjectCreate(0, g_start_line_name, OBJ_VLINE, 0, g_range_start_time, 0);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_start_line_name, OBJPROP_WIDTH, 2);  // Thicker line
   ObjectSetString(0, g_start_line_name, OBJPROP_TOOLTIP, "Range Start Time");

   // Draw range end line (blue)
   ObjectCreate(0, g_end_line_name, OBJ_VLINE, 0, g_range_end_time, 0);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_WIDTH, 2);  // Thicker line
   ObjectSetString(0, g_end_line_name, OBJPROP_TOOLTIP, "Range End Time");

   // Draw range close line (red) if applicable
   if(g_close_time > 0)
   {
      ObjectCreate(0, g_close_line_name, OBJ_VLINE, 0, g_close_time, 0);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_WIDTH, 2);  // Thicker line
      ObjectSetString(0, g_close_line_name, OBJPROP_TOOLTIP, "Range Close Time");
   }

   // Force chart redraw
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete all vertical lines                                        |
//+------------------------------------------------------------------+
void DeleteAllLines()
{
   ObjectDelete(0, g_start_line_name);
   ObjectDelete(0, g_end_line_name);
   ObjectDelete(0, g_close_line_name);
   ChartRedraw();
}
