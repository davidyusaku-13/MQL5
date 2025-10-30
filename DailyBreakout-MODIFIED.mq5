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
input bool autolot = true;                             // Use autolot based on balance
input double base_balance = 100.0;                     // Base balance for lot calculation
input double lot = 0.01;                               // Lot size for each base_balance unit
input double min_lot = 0.01;                           // Minimum lot size
input double max_lot = 10.0;                           // Maximum lot size
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
input bool show_sessions = true;                       // Show trading sessions in backtest
input color AsianSessionColor = 0xFFE6CC;              // Asian session color (Pastel peach)
input color LondonSessionColor = 0xCCE5FF;             // London session color (Pastel blue)
input color NewYorkSessionColor = 0xD4EDDA;            // New York session color (Pastel mint green)
input int SessionTransparency = 85;                    // Session transparency (0-100)

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

   // Draw sessions if enabled
   if (show_sessions)
   {
      DrawSessions();
   }

   return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
   DeleteAllLines();
   
   // Clean up session objects if sessions were enabled
   if (show_sessions)
   {
      CleanupSessionObjects();
   }
   
   if (g_max_range_ever > 0)
   {
      Print("=== Range Statistics ===");
      Print("Maximum range during backtest: ", g_max_range_ever, " points on ", TimeToString(g_max_range_date));
      Print("Minimum range during backtest: ", g_min_range_ever, " points on ", TimeToString(g_min_range_date));
      Print("======================");
   }
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
      
      // Redraw sessions if enabled
      if (show_sessions)
      {
         CleanupSessionObjects();
         DrawSessions();
      }
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

   // Always use M1 for accurate range calculation regardless of chart timeframe
   int bars_to_check = (int)((range_duration * 60) / PeriodSeconds(PERIOD_M1)) + 1;
   if (bars_to_check > Bars(_Symbol, PERIOD_M1))
      bars_to_check = Bars(_Symbol, PERIOD_M1);

   // Use M1 bars for precise range calculation
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
//| Calculate lot size based on the settings                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size)
{
   if (autolot) // Autolot mode
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Calculate lot size proportional to account balance
      double balance_ratio = account_balance / base_balance;
      double lot_size = NormalizeDouble(balance_ratio * lot, 2);

      // Apply min/max limits
      if (lot_size < min_lot)
         lot_size = min_lot;
      else if (lot_size > max_lot)
         lot_size = max_lot;

      Print("Autolot calculation - Balance: ", account_balance, ", Base balance: ", base_balance,
            ", Balance ratio: ", balance_ratio, ", Base lot: ", lot, ", Calculated lot: ", lot_size);

      return lot_size;
   }
   else // Fixed lot size
   {
      return lot; // Use lot as fixed lot value
   }
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

   // Place buy stop order at the high of the range
   trade.SetExpertMagicNumber(magic_number);

   bool buy_success = trade.BuyStop(
       g_lot_size,
       g_high_price,
       _Symbol,
       buy_sl,
       buy_tp,
       ORDER_TIME_DAY,
       0,
       "Range Breakout Buy");

   if (buy_success)
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
       g_low_price,
       _Symbol,
       sell_sl,
       sell_tp,
       ORDER_TIME_DAY,
       0,
       "Range Breakout Sell");

   if (sell_success)
   {
      g_sell_ticket = trade.ResultOrder();
      Print("Sell Stop order placed at ", g_low_price, " with lot size ", g_lot_size);
   }
   else
   {
      Print("Failed to place Sell Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
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

//+------------------------------------------------------------------+
//| Cleanup session objects                                          |
//+------------------------------------------------------------------+
void CleanupSessionObjects()
{
   ObjectsDeleteAll(0, "Asian_");
   ObjectsDeleteAll(0, "London_");
   ObjectsDeleteAll(0, "NewYork_");
   ObjectsDeleteAll(0, "AsianLondon_");
   ObjectsDeleteAll(0, "LondonNY_");
}

//+------------------------------------------------------------------+
//| Blend two colors together                                         |
//+------------------------------------------------------------------+
color BlendColors(color color1, color color2)
{
   int r1 = (color1 & 0xFF);
   int g1 = ((color1 >> 8) & 0xFF);
   int b1 = ((color1 >> 16) & 0xFF);
   
   int r2 = (color2 & 0xFF);
   int g2 = ((color2 >> 8) & 0xFF);
   int b2 = ((color2 >> 16) & 0xFF);
   
   int r = (r1 + r2) / 2;
   int g = (g1 + g2) / 2;
   int b = (b1 + b2) / 2;
   
   return (color)(r | (g << 8) | (b << 16));
}

//+------------------------------------------------------------------+
//| Convert color to ARGB with transparency                          |
//+------------------------------------------------------------------+
color ColorToARGB(color col, int transparency)
{
   int alpha = (int)((transparency / 100.0) * 255);
   int red = (col & 0xFF);
   int green = ((col >> 8) & 0xFF);
   int blue = ((col >> 16) & 0xFF);

   return (color)((alpha << 24) | (blue << 16) | (green << 8) | red);
}

//+------------------------------------------------------------------+
//| Draw session rectangle                                            |
//+------------------------------------------------------------------+
void DrawSessionRectangle(string name, datetime startTime, datetime endTime, color sessionColor, color textColor, string labelText)
{
   // Find highest and lowest price during session
   double sessionHigh = 0;
   double sessionLow = DBL_MAX;

   int startBar = iBarShift(_Symbol, PERIOD_CURRENT, startTime);
   int endBar = iBarShift(_Symbol, PERIOD_CURRENT, endTime);

   // Loop through bars in session to find high/low
   for(int i = endBar; i <= startBar; i++)
   {
      if(i < 0) continue;

      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);

      if(high > sessionHigh) sessionHigh = high;
      if(low < sessionLow) sessionLow = low;
   }

   // Skip if no valid data
   if(sessionHigh == 0 || sessionLow == DBL_MAX) return;

   // Delete old object if exists
   ObjectDelete(0, name);

   // Create rectangle with session high/low
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, startTime, sessionHigh, endTime, sessionLow);
   ObjectSetInteger(0, name, OBJPROP_COLOR, sessionColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);

   // Set transparency
   color transparentColor = ColorToARGB(sessionColor, SessionTransparency);
   ObjectSetInteger(0, name, OBJPROP_COLOR, transparentColor);

   // Add session label text only if labelText is provided
   if(labelText != "")
   {
      string labelName = name + "_Label";
      ObjectDelete(0, labelName);

      // Calculate middle position
      datetime middleTime = startTime + (endTime - startTime) / 2;
      double middlePrice = sessionHigh - (sessionHigh - sessionLow) * 0.1; // 10% from top

      // Create text label
      ObjectCreate(0, labelName, OBJ_TEXT, 0, middleTime, middlePrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Draw trading sessions                                             |
//+------------------------------------------------------------------+
void DrawSessions()
{
   // Only draw for last month (30 days)
   datetime currentTime = TimeCurrent();
   datetime oneMonthAgo = currentTime - (30 * 86400); // 30 days ago

   // Always start from 30 days ago, regardless of visible bars
   datetime startTime = oneMonthAgo;

   // Loop through each day in the limited range
   datetime currentDay = startTime - (startTime % 86400); // Start of day

   while(currentDay <= currentTime + 86400)
   {
      // Blend colors for overlap zones
      color asianLondonBlend = BlendColors(AsianSessionColor, LondonSessionColor);
      color londonNYBlend = BlendColors(LondonSessionColor, NewYorkSessionColor);

      // Define text colors for session labels
      color asianTextColor = 0xFF6600;   // Deep orange
      color londonTextColor = 0x0066CC;  // Deep blue
      color newYorkTextColor = 0x28A745; // Deep green

      // 1. Asian-only zone: 00:00 - 08:00 GMT
      DrawSessionRectangle("Asian_Only_" + TimeToString(currentDay),
                           currentDay,
                           currentDay + 8 * 3600,
                           AsianSessionColor,
                           asianTextColor,
                           "ASIAN");

      // 2. Asian-London overlap: 08:00 - 09:00 GMT
      DrawSessionRectangle("AsianLondon_" + TimeToString(currentDay),
                           currentDay + 8 * 3600,
                           currentDay + 9 * 3600,
                           asianLondonBlend,
                           0,
                           "");

      // 3. London-only zone: 09:00 - 13:00 GMT
      DrawSessionRectangle("London_Only_" + TimeToString(currentDay),
                           currentDay + 9 * 3600,
                           currentDay + 13 * 3600,
                           LondonSessionColor,
                           londonTextColor,
                           "LONDON");

      // 4. London-NY overlap: 13:00 - 16:00 GMT
      DrawSessionRectangle("LondonNY_" + TimeToString(currentDay),
                           currentDay + 13 * 3600,
                           currentDay + 16 * 3600,
                           londonNYBlend,
                           0,
                           "");

      // 5. NY-only zone: 16:00 - 21:00 GMT
      DrawSessionRectangle("NewYork_Only_" + TimeToString(currentDay),
                           currentDay + 16 * 3600,
                           currentDay + 21 * 3600,
                           NewYorkSessionColor,
                           newYorkTextColor,
                           "NEW YORK");

      // Move to next day
      currentDay += 86400;
   }

   ChartRedraw();
}