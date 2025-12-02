//+------------------------------------------------------------------+
//|                                            Daily Range Breakout EA |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link ""
#property version "1.00"

// Include required libraries
#include <Trade\Trade.mqh>
CTrade trade;

// Input Parameters
input int magic_number = 12345;                        // Magic Number
input double risk_percentage = 1.0;                    // Risk percentage of balance per trade (1.0 = 1%)
input int stop_loss = 90;                              // Stop Loss in % of the range (0=off)
input int take_profit = 0;                             // Take Profit in % of the range (0=off)
input int range_start_time = 90;                       // Range start time in minutes
input int range_duration = 270;                        // Range duration in minutes
input int range_close_time = 1200;                     // Range close time in minutes (-1=off)
input string breakout_mode = "one breakout per range"; // Breakout Mode
input bool range_on_monday = true;                     // Range on Monday
input bool range_on_tuesday = false;                   // Range on Tuesday
input bool range_on_wednesday = true;                  // Range on Wednesday
input bool range_on_thursday = true;                   // Range on Thursday
input bool range_on_friday = true;                     // Range on Friday
input int trailing_stop = 300;                         // Trailing Stop in points (0=off)
input int trailing_start = 500;                        // Activate trailing after profit in points
input double max_range_size = 1500;                    // Maximum range size in points (0=off)
input double min_range_size = 500;                     // Minimum range size in points (0=off)
input int max_spread_points = 50;                      // Maximum spread in points (0=off)

// Trend Confirmation Parameters
input bool enable_trend_confirmation = true; // Enable multi-timeframe trend confirmation
input int trend_swing_period = 10;           // Period for swing highs/lows detection
input int trend_momentum_period = 5;         // Period for recent momentum check
input bool require_all_timeframes = true;    // Require all timeframes to agree

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
string g_start_line_name = "Range_Start_Line";
string g_end_line_name = "Range_End_Line";
string g_close_line_name = "Range_Close_Line";
bool g_lines_drawn = false;
int g_trailing_points = 300;       // Trailing stop in points (default 30 pips)
bool g_trailing_activated = false; // Default trailing status

// Add these global variables to track ranges
double g_max_range_ever = 0;      // Track maximum range seen
double g_min_range_ever = 999999; // Track minimum range seen
datetime g_max_range_date = 0;    // Date of maximum range
datetime g_min_range_date = 0;    // Date of minimum range

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize
   g_range_calculated = false;
   g_orders_placed = false;
   g_lines_drawn = false;
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

   // Recover existing positions if EA restarts mid-day
   RecoverExistingPositions();

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
   DeleteAllLines();

   // Final statistics report
   Print("===============================================");
   Print("           DAILY BREAKOUT EA REPORT           ");
   Print("===============================================");

   if (g_max_range_ever > 0)
   {
      Print("=== Range Statistics ===");
      Print("Maximum range during backtest: ", g_max_range_ever, " points on ", TimeToString(g_max_range_date));
      Print("Minimum range during backtest: ", g_min_range_ever, " points on ", TimeToString(g_min_range_date));
      Print("======================");
   }

   if (enable_trend_confirmation)
   {
      Print("=== Trend Confirmation Settings ===");
      Print("Trend confirmation: ENABLED");
      Print("Swing period: ", trend_swing_period, " bars");
      Print("Momentum period: ", trend_momentum_period, " bars");
      Print("Require all timeframes: ", (require_all_timeframes ? "YES" : "NO"));
      Print("Timeframes analyzed: M5, M15, H1, H4");
      Print("================================");
   }
   else
   {
      Print("=== Trend Confirmation Settings ===");
      Print("Trend confirmation: DISABLED");
      Print("================================");
   }

   Print("=== Risk Management Settings ===");
   Print("Risk per trade: ", risk_percentage, "% of account balance");
   if (stop_loss > 0)
      Print("Stop Loss: ", stop_loss, "% of range");
   else
      Print("Stop Loss: Using full range as risk");
   Print("Lot calculation: Risk-based with symbol constraints");
   Print("===============================");

   Print("===============================================");
   Print("                  END REPORT                   ");
   Print("===============================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check if day has changed
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today = StructToTime(dt);

   if (today != g_current_day)
   {
      // New day, reset EA
      g_range_calculated = false;
      g_orders_placed = false;
      g_lines_drawn = false;
      g_current_day = today;
      DeleteAllLines();
   }

   // Check if it's a valid trading day
   if (!IsTradingDay())
      return;

   // Calculate daily range if not already done
   if (!g_range_calculated)
   {
      CalculateDailyRange();
      return;
   }

   // Draw vertical lines for range times if not already drawn
   if (!g_lines_drawn)
   {
      DrawRangeLines();
      g_lines_drawn = true;
   }

   // Check if we should place orders
   if (!g_orders_placed && TimeCurrent() >= g_range_end_time)
   {
      PlacePendingOrders();
      return;
   }

   // Apply trailing stop to open positions if enabled
   if (trailing_stop > 0)
   {
      ManageTrailingStop();
   }

   // Check if we should close all orders
   if (g_orders_placed && range_close_time > 0 && TimeCurrent() >= g_close_time)
   {
      CloseAllOrders();
      return;
   }

   // Manage existing orders
   ManageOrders();
}

//+------------------------------------------------------------------+
//| Check if today is a valid trading day                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect trend based on higher highs/lower lows pattern           |
//+------------------------------------------------------------------+
int DetectTrendBySwings(ENUM_TIMEFRAMES timeframe)
{
   // Return: 1 = Uptrend (higher highs and higher lows)
   // Return: -1 = Downtrend (lower highs and lower lows)
   // Return: 0 = Sideways/No clear trend

   int bars_needed = trend_swing_period * 3; // Need enough bars for analysis
   if (Bars(_Symbol, timeframe) < bars_needed)
      return 0; // Not enough data

   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   // Copy high and low data
   int copied = CopyHigh(_Symbol, timeframe, 0, bars_needed, highs);
   if (copied < bars_needed)
      return 0;

   copied = CopyLow(_Symbol, timeframe, 0, bars_needed, lows);
   if (copied < bars_needed)
      return 0;

   // Find recent swing highs and lows
   int higher_highs = 0;
   int lower_highs = 0;
   int higher_lows = 0;
   int lower_lows = 0;

   // Analyze swing points over the specified period
   for (int i = trend_momentum_period; i < trend_swing_period; i++)
   {
      // Check for swing high
      if (highs[i] > highs[i - 1] && highs[i] > highs[i + 1])
      {
         if (i > 0)
         {
            if (highs[i] > highs[i - trend_momentum_period])
               higher_highs++;
            else if (highs[i] < highs[i - trend_momentum_period])
               lower_highs++;
         }
      }

      // Check for swing low
      if (lows[i] < lows[i - 1] && lows[i] < lows[i + 1])
      {
         if (i > 0)
         {
            if (lows[i] > lows[i - trend_momentum_period])
               higher_lows++;
            else if (lows[i] < lows[i - trend_momentum_period])
               lower_lows++;
         }
      }
   }

   // Check recent momentum (last few bars)
   double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2;
   double old_price = 0;

   double closes[];  // Use separate array for close prices
   ArraySetAsSeries(closes, true);
   if (CopyClose(_Symbol, timeframe, trend_momentum_period, 1, closes) > 0)
      old_price = closes[0];

   bool recent_upward_momentum = (current_price > old_price);

   // Determine trend based on swing analysis and momentum
   if (higher_highs > lower_highs && higher_lows > lower_lows && recent_upward_momentum)
      return 1; // Clear uptrend
   else if (lower_highs > higher_highs && lower_lows > higher_lows && !recent_upward_momentum)
      return -1; // Clear downtrend
   else if (higher_highs > lower_highs || (recent_upward_momentum && higher_highs >= lower_highs))
      return 1; // Leaning upward with momentum
   else if (lower_highs > higher_highs || (!recent_upward_momentum && lower_highs >= higher_highs))
      return -1; // Leaning downward

   return 0; // Sideways or unclear
}

//+------------------------------------------------------------------+
//| Check trend confirmation across multiple timeframes             |
//+------------------------------------------------------------------+
bool ConfirmTrendDirection(bool is_bullish_breakout)
{
   if (!enable_trend_confirmation)
      return true; // Trend confirmation disabled

   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
   string timeframe_names[] = {"M5", "M15", "H1", "H4"};

   int agreeing_timeframes = 0;
   int total_timeframes = ArraySize(timeframes);

   Print("=== Trend Confirmation Analysis ===");

   for (int i = 0; i < total_timeframes; i++)
   {
      int trend = DetectTrendBySwings(timeframes[i]);

      string trend_str = "Neutral";
      if (trend == 1)
         trend_str = "Uptrend";
      else if (trend == -1)
         trend_str = "Downtrend";

      Print(timeframe_names[i], " trend: ", trend_str);

      // Check if this timeframe agrees with our breakout direction
      if (is_bullish_breakout && trend == 1)
      {
         agreeing_timeframes++;
         Print(timeframe_names[i], " confirms bullish breakout");
      }
      else if (!is_bullish_breakout && trend == -1)
      {
         agreeing_timeframes++;
         Print(timeframe_names[i], " confirms bearish breakout");
      }
      else if (trend == 0)
      {
         Print(timeframe_names[i], " is neutral - not counting against confirmation");
         if (!require_all_timeframes)
            agreeing_timeframes++; // Allow neutral if not requiring all
      }
      else
      {
         Print(timeframe_names[i], " conflicts with breakout direction");
      }
   }

   int required_timeframes = require_all_timeframes ? total_timeframes : (total_timeframes + 1) / 2;

   Print("Trend confirmation: ", agreeing_timeframes, "/", total_timeframes,
         " timeframes agree (Required: ", required_timeframes, ")");

   bool confirmed = (agreeing_timeframes >= required_timeframes);

   if (confirmed)
      Print("✓ Trend confirmation PASSED");
   else
      Print("✗ Trend confirmation FAILED - orders will be skipped");

   Print("================================");

   return confirmed;
}

//+------------------------------------------------------------------+
//| Optimized trend confirmation - checks both directions in one pass|
//+------------------------------------------------------------------+
void GetTrendConfirmation(bool &bullish_confirmed, bool &bearish_confirmed)
{
   bullish_confirmed = false;
   bearish_confirmed = false;

   if (!enable_trend_confirmation)
   {
      bullish_confirmed = true;
      bearish_confirmed = true;
      return;
   }

   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4};
   string timeframe_names[] = {"M5", "M15", "H1", "H4"};

   int bullish_agreeing = 0;
   int bearish_agreeing = 0;
   int total_timeframes = ArraySize(timeframes);

   Print("=== Trend Confirmation Analysis (Optimized) ===");

   for (int i = 0; i < total_timeframes; i++)
   {
      int trend = DetectTrendBySwings(timeframes[i]);

      string trend_str = "Neutral";
      if (trend == 1)
         trend_str = "Uptrend";
      else if (trend == -1)
         trend_str = "Downtrend";

      Print(timeframe_names[i], " trend: ", trend_str);

      // Count agreements for both directions
      if (trend == 1)
      {
         bullish_agreeing++;
         Print(timeframe_names[i], " supports bullish breakout");
      }
      else if (trend == -1)
      {
         bearish_agreeing++;
         Print(timeframe_names[i], " supports bearish breakout");
      }
      else // Neutral
      {
         if (!require_all_timeframes)
         {
            bullish_agreeing++;
            bearish_agreeing++;
         }
         Print(timeframe_names[i], " is neutral");
      }
   }

   int required_timeframes = require_all_timeframes ? total_timeframes : (total_timeframes + 1) / 2;

   bullish_confirmed = (bullish_agreeing >= required_timeframes);
   bearish_confirmed = (bearish_agreeing >= required_timeframes);

   Print("Bullish confirmation: ", bullish_agreeing, "/", total_timeframes,
         " (Required: ", required_timeframes, ") - ", (bullish_confirmed ? "PASSED" : "FAILED"));
   Print("Bearish confirmation: ", bearish_agreeing, "/", total_timeframes,
         " (Required: ", required_timeframes, ") - ", (bearish_confirmed ? "PASSED" : "FAILED"));
   Print("================================");
}

//+------------------------------------------------------------------+
//| Recover existing positions if EA restarts mid-day               |
//+------------------------------------------------------------------+
void RecoverExistingPositions()
{
   Print("=== Checking for existing positions to recover ===");

   int recovered_positions = 0;
   int recovered_orders = 0;

   // Check for open positions with our magic number
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      if (position_ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == magic_number && 
             PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if (pos_type == POSITION_TYPE_BUY)
            {
               g_buy_ticket = position_ticket;
               Print("Recovered BUY position #", position_ticket);
            }
            else if (pos_type == POSITION_TYPE_SELL)
            {
               g_sell_ticket = position_ticket;
               Print("Recovered SELL position #", position_ticket);
            }
            
            recovered_positions++;
            g_orders_placed = true;  // Mark as already placed for today
            g_range_calculated = true;  // Assume range was calculated
         }
      }
   }

   // Check for pending orders with our magic number
   for (int i = 0; i < OrdersTotal(); i++)
   {
      ulong order_ticket = OrderGetTicket(i);
      if (order_ticket > 0)
      {
         if (OrderGetInteger(ORDER_MAGIC) == magic_number && 
             OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if (order_type == ORDER_TYPE_BUY_STOP)
            {
               g_buy_ticket = order_ticket;
               g_high_price = OrderGetDouble(ORDER_PRICE_OPEN);
               Print("Recovered BUY STOP order #", order_ticket, " at ", g_high_price);
            }
            else if (order_type == ORDER_TYPE_SELL_STOP)
            {
               g_sell_ticket = order_ticket;
               g_low_price = OrderGetDouble(ORDER_PRICE_OPEN);
               Print("Recovered SELL STOP order #", order_ticket, " at ", g_low_price);
            }
            
            recovered_orders++;
            g_orders_placed = true;  // Mark as already placed for today
            g_range_calculated = true;  // Assume range was calculated
         }
      }
   }

   if (recovered_positions > 0 || recovered_orders > 0)
   {
      Print("Recovery complete: ", recovered_positions, " positions, ", recovered_orders, " pending orders");
      
      // Recalculate close time for today
      if (range_close_time > 0)
      {
         MqlDateTime dt;
         TimeCurrent(dt);
         dt.hour = 0;
         dt.min = 0;
         dt.sec = 0;
         datetime today = StructToTime(dt);
         g_close_time = today + range_close_time * 60;
         Print("Close time set to: ", TimeToString(g_close_time));
      }
   }
   else
   {
      Print("No existing positions or orders found for this EA");
   }

   Print("================================================");
}

bool IsTradingDay()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int day_of_week = dt.day_of_week;

   switch (day_of_week)
   {
   case 1:
      return range_on_monday;
   case 2:
      return range_on_tuesday;
   case 3:
      return range_on_wednesday;
   case 4:
      return range_on_thursday;
   case 5:
      return range_on_friday;
   default:
      return false; // Weekend
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
   if (range_close_time > 0)
      g_close_time = today + range_close_time * 60;
   else
      g_close_time = 0; // No automatic close time

   // Check if we're still in range calculation period
   if (current_time < g_range_end_time)
      return;

   // Calculate the high and low of the range
   g_high_price = 0;
   g_low_price = 99999999;

   int bars_to_check = range_duration / PeriodSeconds(PERIOD_M1) * 60;
   if (bars_to_check > Bars(_Symbol, PERIOD_M1))
      bars_to_check = Bars(_Symbol, PERIOD_M1);

   for (int i = 0; i < bars_to_check; i++)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_M1, i);

      // Check if the bar is within our range time
      if (bar_time >= g_range_start_time && bar_time <= g_range_end_time)
      {
         double bar_high = iHigh(_Symbol, PERIOD_M1, i);
         if (bar_high > g_high_price)
            g_high_price = bar_high;

         double bar_low = iLow(_Symbol, PERIOD_M1, i);
         if (bar_low < g_low_price)
            g_low_price = bar_low;
      }
   }

   // Mark range as calculated
   if (g_high_price > 0 && g_low_price < 99999999)
   {
      g_range_calculated = true;
      double range_size = g_high_price - g_low_price;
      double range_points = range_size / _Point;

      // Track maximum and minimum ranges observed
      if (range_points > g_max_range_ever)
      {
         g_max_range_ever = range_points;
         g_max_range_date = TimeCurrent();
         Print("New maximum range detected: ", range_points, " points on ", TimeToString(g_max_range_date));
      }

      if (range_points < g_min_range_ever)
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
//| Calculate lot size based on risk percentage of balance           |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size)
{
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Calculate risk amount in account currency
   double risk_amount = account_balance * (risk_percentage / 100.0);

   // Calculate stop loss distance in price units
   double sl_distance = 0;

   if (stop_loss > 0)
   {
      // Use configured stop loss percentage of range
      sl_distance = range_size * (stop_loss / 100.0);
   }
   else
   {
      // If no stop loss configured, use the full range as risk distance
      sl_distance = range_size;
   }

   // Get symbol information for lot calculation
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Calculate lot size based on risk
   // Formula: Lot Size = Risk Amount / (SL Distance * Tick Value / Tick Size)
   double lot_size = 0;

   if (sl_distance > 0 && tick_value > 0 && tick_size > 0)
   {
      // Convert SL distance to ticks
      double sl_ticks = sl_distance / tick_size;

      // Calculate required lot size
      lot_size = risk_amount / (sl_ticks * tick_value);

      // Normalize to allowed lot step
      if (lot_step > 0)
      {
         lot_size = MathFloor(lot_size / lot_step) * lot_step;
      }

      // Apply minimum/maximum lot constraints
      if (lot_size < min_lot)
         lot_size = min_lot;
      else if (lot_size > max_lot)
         lot_size = max_lot;
   }
   else
   {
      // Fallback to minimum lot if calculation fails
      lot_size = min_lot;
      Print("Warning: Could not calculate risk-based lot size, using minimum lot");
   }

   // Normalize to 2 decimal places
   lot_size = NormalizeDouble(lot_size, 2);

   Print("Risk-based lot calculation:");
   Print("  Account Balance: $", account_balance);
   Print("  Risk Percentage: ", risk_percentage, "%");
   Print("  Risk Amount: $", NormalizeDouble(risk_amount, 2));
   Print("  Range Size: ", NormalizeDouble(range_size / _Point, 2), " points");
   Print("  SL Distance: ", NormalizeDouble(sl_distance / _Point, 2), " points");
   Print("  Tick Value: $", tick_value);
   Print("  Calculated Lot Size: ", lot_size);
   Print("  ==================================");

   return lot_size;
}

//+------------------------------------------------------------------+
//| Place pending orders based on the calculated range               |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if (g_high_price <= 0 || g_low_price >= 99999999)
      return;

   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;

   Print("=== Daily Range Details ===");
   Print("Date: ", TimeToString(TimeCurrent()));
   Print("Range High: ", g_high_price);
   Print("Range Low: ", g_low_price);
   Print("Range Size: ", range_points, " points");
   Print("=========================");

   // Check if range size is within acceptable limits
   if (max_range_size > 0 && range_points > max_range_size)
   {
      Print("Range size (", range_points, " points) exceeds maximum (", max_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   if (min_range_size > 0 && range_points < min_range_size)
   {
      Print("Range size (", range_points, " points) is below minimum (", min_range_size, " points). No orders placed.");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   // Spread Filter Check
   if (max_spread_points > 0)
   {
      long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (current_spread > max_spread_points)
      {
         Print("Current spread (", current_spread, " points) exceeds maximum (", max_spread_points, " points). Waiting for better conditions.");
         return; // Don't mark as processed - will retry on next tick
      }
   }

   // Trend Confirmation Check - Optimized single-pass for both directions
   bool bullish_trend_confirmed = false;
   bool bearish_trend_confirmed = false;
   GetTrendConfirmation(bullish_trend_confirmed, bearish_trend_confirmed);

   // If neither direction has trend confirmation, skip orders for the day
   if (enable_trend_confirmation && !bullish_trend_confirmed && !bearish_trend_confirmed)
   {
      Print("No trend confirmation for either direction - skipping order placement for today");
      g_orders_placed = true; // Mark as processed so we don't try again today
      return;
   }

   g_lot_size = CalculateLotSize(range_size);

   // Calculate SL and TP
   double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;

   if (stop_loss > 0)
   {
      // Calculate SL based on range percentage
      buy_sl = g_high_price - (range_size * stop_loss / 100);
      sell_sl = g_low_price + (range_size * stop_loss / 100);
   }

   if (take_profit > 0)
   {
      buy_tp = g_high_price + (range_size * take_profit / 100);
      sell_tp = g_low_price - (range_size * take_profit / 100);
   }

   // Place orders based on trend confirmation
   trade.SetExpertMagicNumber(magic_number);

   // Place buy stop order at the high of the range only if bullish trend is confirmed
   if (!enable_trend_confirmation || bullish_trend_confirmed)
   {
      bool buy_success = trade.BuyStop(
          g_lot_size,
          g_high_price,
          _Symbol,
          buy_sl,
          buy_tp,
          ORDER_TIME_DAY,
          0,
          "Range Breakout Buy (Trend Confirmed)");

      if (buy_success)
      {
         g_buy_ticket = trade.ResultOrder();
         Print("✓ Buy Stop order placed at ", g_high_price, " with lot size ", g_lot_size, " (Bullish trend confirmed)");
      }
      else
      {
         Print("Failed to place Buy Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print("✗ Buy Stop order SKIPPED - bullish trend not confirmed");
   }

   // Place sell stop order at the low of the range only if bearish trend is confirmed
   if (!enable_trend_confirmation || bearish_trend_confirmed)
   {
      bool sell_success = trade.SellStop(
          g_lot_size,
          g_low_price,
          _Symbol,
          sell_sl,
          sell_tp,
          ORDER_TIME_DAY,
          0,
          "Range Breakout Sell (Trend Confirmed)");

      if (sell_success)
      {
         g_sell_ticket = trade.ResultOrder();
         Print("✓ Sell Stop order placed at ", g_low_price, " with lot size ", g_lot_size, " (Bearish trend confirmed)");
      }
      else
      {
         Print("Failed to place Sell Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print("✗ Sell Stop order SKIPPED - bearish trend not confirmed");
   }

   g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| Manage open orders                                               |
//+------------------------------------------------------------------+
void ManageOrders()
{
   // If using "one breakout per range" mode, check if one order has been triggered
   if (StringCompare(breakout_mode, "one breakout per range") == 0)
   {
      bool buy_triggered = false;
      bool sell_triggered = false;

      // Get order information
      if (g_buy_ticket > 0)
      {
         // Check if the order still exists and if it's a market order (was triggered)
         if (OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (order_type == ORDER_TYPE_BUY) // Changed from pending to market = triggered
               buy_triggered = true;
         }
         else
         {
            // Check if it became a position (was triggered and is still open)
            if (PositionSelectByTicket(g_buy_ticket))
            {
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  buy_triggered = true;
            }
            else
            {
               g_buy_ticket = 0; // Order no longer exists
            }
         }
      }

      // Check if sell stop order has been triggered
      if (g_sell_ticket > 0)
      {
         // Check if the order still exists and if it's a market order (was triggered)
         if (OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (order_type == ORDER_TYPE_SELL) // Changed from pending to market = triggered
               sell_triggered = true;
         }
         else
         {
            // Check if it became a position (was triggered and is still open)
            if (PositionSelectByTicket(g_sell_ticket))
            {
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  sell_triggered = true;
            }
            else
            {
               g_sell_ticket = 0; // Order no longer exists
            }
         }
      }

      // If one order has been triggered, delete the other pending order
      if (buy_triggered && g_sell_ticket > 0)
      {
         if (OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (order_type == ORDER_TYPE_SELL_STOP)
               trade.OrderDelete(g_sell_ticket);
         }
         g_sell_ticket = 0;
      }
      else if (sell_triggered && g_buy_ticket > 0)
      {
         if (OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if (order_type == ORDER_TYPE_BUY_STOP)
               trade.OrderDelete(g_buy_ticket);
         }
         g_buy_ticket = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Close all orders for this EA                                     |
//+------------------------------------------------------------------+
void CloseAllOrders()
{
   // Close all positions with this magic number
   int positions_total = PositionsTotal();
   for (int i = positions_total - 1; i >= 0; i--)
   {
      ulong position_ticket = PositionGetTicket(i);
      if (position_ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            trade.PositionClose(position_ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to close position #", position_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Delete all pending orders with this magic number
   int orders_total = OrdersTotal();
   for (int i = orders_total - 1; i >= 0; i--)
   {
      ulong order_ticket = OrderGetTicket(i);
      if (order_ticket > 0)
      {
         if (OrderGetInteger(ORDER_MAGIC) == magic_number && OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(order_ticket);
            if (trade.ResultRetcode() != TRADE_RETCODE_DONE)
               Print("Failed to delete order #", order_ticket, ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Reset flags for next day
   g_range_calculated = false;
   g_orders_placed = false;
   g_buy_ticket = 0;
   g_sell_ticket = 0;
}

//+------------------------------------------------------------------+
//| Manage trailing stop for open positions                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if (trailing_stop <= 0 || trailing_start <= 0)
      return;

   // Check all open positions
   for (int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);

      if (position_ticket > 0)
      {
         // Check if this position belongs to our EA
         if (PositionGetInteger(POSITION_MAGIC) == magic_number && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            // Get position details
            double position_open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double position_sl = PositionGetDouble(POSITION_SL);
            double position_tp = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Current price depending on position type
            double current_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // Calculate current profit in points
            double profit_points = 0;

            if (position_type == POSITION_TYPE_BUY)
               profit_points = (current_price - position_open_price) / _Point;
            else
               profit_points = (position_open_price - current_price) / _Point;

            // If profit has not reached trailing_start, skip
            if (profit_points < trailing_start)
               continue;

            // Calculate new stop loss level
            double new_sl = 0;

            if (position_type == POSITION_TYPE_BUY)
            {
               // For buy positions, trail below current price
               new_sl = current_price - trailing_stop * _Point;

               // Only modify if new SL is higher than current SL
               if (position_sl == 0 || new_sl > position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
                  Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
               }
            }
            else
            {
               // For sell positions, trail above current price
               new_sl = current_price + trailing_stop * _Point;

               // Only modify if new SL is lower than current SL or no SL is set
               if (position_sl == 0 || new_sl < position_sl)
               {
                  trade.PositionModify(position_ticket, new_sl, position_tp);
                  Print("Trailing stop for position #", position_ticket, " - New SL: ", new_sl);
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
   ObjectSetInteger(0, g_start_line_name, OBJPROP_WIDTH, 2); // Thicker line
   ObjectSetString(0, g_start_line_name, OBJPROP_TOOLTIP, "Range Start Time");

   // Draw range end line (blue)
   ObjectCreate(0, g_end_line_name, OBJ_VLINE, 0, g_range_end_time, 0);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_end_line_name, OBJPROP_WIDTH, 2); // Thicker line
   ObjectSetString(0, g_end_line_name, OBJPROP_TOOLTIP, "Range End Time");

   // Draw range close line (red) if applicable
   if (g_close_time > 0)
   {
      ObjectCreate(0, g_close_line_name, OBJ_VLINE, 0, g_close_time, 0);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_close_line_name, OBJPROP_WIDTH, 2); // Thicker line
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