#property copyright "Copyright 2025"
#property link      ""
#property version   "2.00"

// Include required libraries
#include <Trade\Trade.mqh>
CTrade trade;

// Input Parameters
input int      magic_number = 12345;       // Magic Number
input bool     autolot = true;            // Use autolot based on balance
input double   risk_percentage = 1.0;      // Risk % of balance per trade
input double   max_lot = 10.0;             // Maximum lot size
input int      stop_loss = 150;            // Stop Loss in % of the range (0=off) - Increased for better breakout survival
input int      take_profit = 0;            // Take Profit in % of the range (0=off)
input int      fixed_sl_pips = 0;          // Fixed stop loss in pips (0=off, overrides % if > 0)
input int      profit_target_pips = 0;     // Fixed profit target in pips (0=off)
input int      min_range_pips = 50;        // Minimum range size in pips to consider trading
input int      max_range_pips = 800;       // Maximum range size in pips to consider trading
input double   atr_sl_multiplier = 2.0;    // ATR multiplier for stop loss (0=off)
input double   atr_tp_multiplier = 3.0;    // ATR multiplier for take profit (0=off)
input bool     use_atr_stops = true;       // Use ATR-based stops instead of range % stops
input int      range_start_time = 90;      // Range start time in minutes
input int      range_duration = 270;       // Range duration in minutes
input int      range_close_time = 1200;    // Range close time in minutes (-1=off)
input bool     single_breakout_only = true;  // Allow only one breakout per range (if true: cancel opposite order when one triggers)
input int      ema_period = 50;              // EMA period for trend confirmation - Reduced for faster response
input bool     range_on_monday = true;     // Range on Monday
input bool     range_on_tuesday = true;    // Range on Tuesday
input bool     range_on_wednesday = true;  // Range on Wednesday
input bool     range_on_thursday = true;   // Range on Thursday
input bool     range_on_friday = true;     // Range on Friday
input int      atr_period = 14;            // ATR period for trailing stops
input double   atr_multiplier = 3.0;       // ATR multiplier for trailing stops
input double   trailing_atr_multiplier = 1.0; // ATR multiplier for trailing activation threshold
input double   max_atr_threshold = 100.0;  // Maximum ATR value allowed for trading (0=off)

// Additional Safety Parameters
input double   max_risk_per_trade = 2.0;    // Maximum risk % per trade (safety override)
input double   min_confidence_threshold = 0.5; // Minimum confidence to trade
input bool     use_risk_management = true;   // Enable additional risk management

// Enhanced Trend Confirmation Parameters
input int      adx_period = 14;            // ADX period for trend strength
input double   adx_threshold = 25.0;       // ADX threshold for trend confirmation
input int      macd_fast_ema = 12;         // MACD fast EMA period
input int      macd_slow_ema = 26;         // MACD slow EMA period
input int      macd_signal = 9;            // MACD signal line period
input double   macd_threshold = 0.0002;    // MACD threshold for confirmation
input int      rsi_period = 14;            // RSI period for overbought/oversold
input double   rsi_overbought = 70.0;      // RSI overbought level
input double   rsi_oversold = 30.0;        // RSI oversold level

// Multi-Timeframe Analysis Parameters
input ENUM_TIMEFRAMES  trend_timeframe = PERIOD_H4;    // Timeframe for trend analysis
input int      trend_ema_period = 200;        // EMA period for trend on higher timeframe
input int      trend_adx_period = 14;        // ADX period for trend on higher timeframe
input int      trend_macd_fast = 12;          // MACD fast for trend on higher timeframe
input int      trend_macd_slow = 26;          // MACD slow for trend on higher timeframe
input int      trend_macd_signal = 9;          // MACD signal for trend on higher timeframe
input int      trend_rsi_period = 14;          // RSI period for trend on higher timeframe
input bool     use_multitimeframe_analysis = true; // Enable multi-timeframe analysis

// Volatility Filtering Parameters
input double   min_range_atr_multiplier = 0.1;  // Minimum range size as ATR multiple
input double   max_range_atr_multiplier = 50.0; // Maximum range size as ATR multiple
input bool     use_volatility_filter = true;    // Enable volatility filtering
input double   volatility_threshold = 10.0;    // Volatility threshold multiplier

// Market Regime Detection Parameters
input bool     use_market_regime_filter = true;  // Enable market regime detection
input double   trending_threshold = 25.0;         // ADX threshold for trending market
input int      bb_period = 20;                    // Bollinger Bands period
input double   bb_deviation = 2.0;                // Bollinger Bands deviation

// Dynamic Position Sizing Parameters
input bool     use_dynamic_position_sizing = true;  // Enable dynamic position sizing
input double   base_confidence = 1.0;               // Base confidence multiplier
input double   max_confidence_multiplier = 2.0;     // Maximum confidence multiplier

// Session-Based Parameters
input bool     use_session_filters = true;    // Enable session-based filters
input bool     trade_asian_session = true;     // Trade during Asian session
input bool     trade_european_session = true;  // Trade during European session
input bool     trade_us_session = true;       // Trade during US session

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
int g_trailing_points = 300;      // Trailing stop in points (default 30 pips)
bool g_trailing_activated = false; // Default trailing status

// Add these global variables to track ranges
double g_max_range_ever = 0;    // Track maximum range seen
double g_min_range_ever = 999999; // Track minimum range seen
datetime g_max_range_date = 0;  // Date of maximum range
datetime g_min_range_date = 0;  // Date of minimum range

// Indicator handles
int atr_handle = INVALID_HANDLE;
int ema_handle = INVALID_HANDLE;
int adx_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int rsi_handle = INVALID_HANDLE;
int bb_handle = INVALID_HANDLE;

// Multi-timeframe indicator handles
int trend_ema_handle = INVALID_HANDLE;
int trend_adx_handle = INVALID_HANDLE;
int trend_macd_handle = INVALID_HANDLE;
int trend_rsi_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize
   g_range_calculated = false;
   g_orders_placed = false;
   g_lines_drawn = false;
   g_trailing_points = atr_period;  // Update to use ATR period instead

   // Initialize ATR indicator
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, atr_period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return(INIT_FAILED);
   }

   // Initialize EMA indicator for trend confirmation
   ema_handle = iMA(_Symbol, PERIOD_M1, ema_period, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA indicator");
      return(INIT_FAILED);
   }

   // Initialize ADX indicator for trend strength
   adx_handle = iADX(_Symbol, PERIOD_CURRENT, adx_period);
   if(adx_handle == INVALID_HANDLE)
   {
      Print("Failed to create ADX indicator");
      return(INIT_FAILED);
   }

   // Initialize MACD indicator for momentum
   macd_handle = iMACD(_Symbol, PERIOD_CURRENT, macd_fast_ema, macd_slow_ema, macd_signal, PRICE_CLOSE);
   if(macd_handle == INVALID_HANDLE)
   {
      Print("Failed to create MACD indicator");
      return(INIT_FAILED);
   }

   // Initialize RSI indicator for overbought/oversold
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create RSI indicator");
      return(INIT_FAILED);
   }

   // Initialize Bollinger Bands for market regime detection
   bb_handle = iBands(_Symbol, PERIOD_CURRENT, bb_period, 0, bb_deviation, PRICE_CLOSE);
   if(bb_handle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands indicator");
      return(INIT_FAILED);
   }

   // Initialize multi-timeframe indicators for trend analysis
   if(use_multitimeframe_analysis)
   {
      trend_ema_handle = iMA(_Symbol, trend_timeframe, trend_ema_period, 0, MODE_EMA, PRICE_CLOSE);
      if(trend_ema_handle == INVALID_HANDLE)
      {
         Print("Failed to create trend EMA indicator");
         return(INIT_FAILED);
      }
      
      trend_adx_handle = iADX(_Symbol, trend_timeframe, trend_adx_period);
      if(trend_adx_handle == INVALID_HANDLE)
      {
         Print("Failed to create trend ADX indicator");
         return(INIT_FAILED);
      }
      
      trend_macd_handle = iMACD(_Symbol, trend_timeframe, trend_macd_fast, trend_macd_slow, trend_macd_signal, PRICE_CLOSE);
      if(trend_macd_handle == INVALID_HANDLE)
      {
         Print("Failed to create trend MACD indicator");
         return(INIT_FAILED);
      }
      
      trend_rsi_handle = iRSI(_Symbol, trend_timeframe, trend_rsi_period, PRICE_CLOSE);
      if(trend_rsi_handle == INVALID_HANDLE)
      {
         Print("Failed to create trend RSI indicator");
         return(INIT_FAILED);
      }
   }

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

   // Release indicators
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
   if(ema_handle != INVALID_HANDLE)
      IndicatorRelease(ema_handle);
   if(adx_handle != INVALID_HANDLE)
      IndicatorRelease(adx_handle);
   if(macd_handle != INVALID_HANDLE)
      IndicatorRelease(macd_handle);
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
   if(bb_handle != INVALID_HANDLE)
      IndicatorRelease(bb_handle);
      
   // Release multi-timeframe indicators
   if(trend_ema_handle != INVALID_HANDLE)
      IndicatorRelease(trend_ema_handle);
   if(trend_adx_handle != INVALID_HANDLE)
      IndicatorRelease(trend_adx_handle);
   if(trend_macd_handle != INVALID_HANDLE)
      IndicatorRelease(trend_macd_handle);
   if(trend_rsi_handle != INVALID_HANDLE)
      IndicatorRelease(trend_rsi_handle);

   if(g_max_range_ever > 0)
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
   
   if(today != g_current_day)
   {
      // New day, reset EA
      g_range_calculated = false;
      g_orders_placed = false;
      g_lines_drawn = false;
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
   
   // Check if we should place orders
   if(!g_orders_placed && TimeCurrent() >= g_range_end_time)
   {
      PlacePendingOrders();
      return;
   }
   
   // Apply ATR trailing stop to open positions if enabled
   if(atr_period > 0 && atr_multiplier > 0)
   {
      ManageTrailingStop();
   }
   
   // Check if we should close all orders
   if(g_orders_placed && range_close_time > 0 && TimeCurrent() >= g_close_time)
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
//| Check if current session is allowed for trading                  |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   if(!use_session_filters)
      return true;
      
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;
   
   // Asian session (approximately 00:00-08:00 UTC)
   if(trade_asian_session && hour >= 0 && hour < 8)
      return true;
   
   // European session (approximately 07:00-16:00 UTC)
   if(trade_european_session && hour >= 7 && hour < 16)
      return true;
   
   // US session (approximately 13:00-22:00 UTC)
   if(trade_us_session && hour >= 13 && hour < 22)
      return true;
   
   return false;
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
   
   int bars_to_check = range_duration / PeriodSeconds(PERIOD_M1) * 60;
   if(bars_to_check > Bars(_Symbol, PERIOD_M1))
      bars_to_check = Bars(_Symbol, PERIOD_M1);
   
   for(int i = 0; i < bars_to_check; i++)
   {
      datetime bar_time = iTime(_Symbol, PERIOD_M1, i);
      
      // Check if the bar is within our range time
      if(bar_time >= g_range_start_time && bar_time <= g_range_end_time)
      {
         double bar_high = iHigh(_Symbol, PERIOD_M1, i);
         if(bar_high > g_high_price)
            g_high_price = bar_high;
            
         double bar_low = iLow(_Symbol, PERIOD_M1, i);
         if(bar_low < g_low_price)
            g_low_price = bar_low;
      }
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
//| Calculate lot size based on the settings and confidence          |
//+------------------------------------------------------------------+
double CalculateLotSize(double range_size, double confidence_multiplier = 1.0)
{
   if(autolot) // Autolot mode
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

      // Calculate stop loss in price terms based on the selected method
      double sl_price = 0;
      double point_value = _Point;

      // Calculate stop loss in price terms based on the selected method
      if(use_atr_stops && atr_handle != INVALID_HANDLE)
      {
         // ATR-based stops
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) >= 1)
            sl_price = atr_buffer[0] * atr_sl_multiplier;
      }
      
      if(sl_price == 0 && fixed_sl_pips > 0)
      {
         // Fixed pips stops
         sl_price = fixed_sl_pips * point_value;
      }
      
      if(sl_price == 0 && stop_loss > 0)
      {
         // Fallback to percentage-based stops
         sl_price = range_size * stop_loss / 100;  // SL as percentage of range
      }
      
      // Final fallback if no SL method is available
      if(sl_price == 0)
      {
         // This approach estimates risk based on range size
         sl_price = range_size * 0.15;  // Default to 15% of range if no stop loss percentage set
      }

      // Calculate lot size based on risk percentage
      double risk_amount = account_balance * (risk_percentage / 100.0);  // Risk amount in account currency

      // Get symbol properties for proper calculation
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      // Calculate lot size based on risk
      double lot_size = 0;
      if(sl_price > 0 && tick_value > 0)
      {
         // Calculate number of ticks in stop loss
         double sl_in_ticks = sl_price / tick_size;
         // Calculate lot size to risk the desired amount
         lot_size = risk_amount / (sl_in_ticks * tick_value);
      }
      else
      {
         // Fallback: use the symbol minimum lot size if calculations fail
         lot_size = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      }

      // Apply confidence multiplier if dynamic position sizing is enabled
      if(use_dynamic_position_sizing && confidence_multiplier > 0)
      {
         // Apply confidence threshold check
         if(use_risk_management && confidence_multiplier < min_confidence_threshold)
         {
            Print("Confidence too low: ", confidence_multiplier, " < ", min_confidence_threshold, ". Reducing confidence to minimum.");
            confidence_multiplier = min_confidence_threshold;
         }
         
         lot_size *= confidence_multiplier;
         // Ensure confidence multiplier doesn't exceed maximum
         if(confidence_multiplier > max_confidence_multiplier)
            lot_size /= (confidence_multiplier / max_confidence_multiplier);
            
         // Apply additional risk management
         if(use_risk_management)
         {
            double current_risk_pct = (risk_amount / account_balance) * 100;
            if(current_risk_pct > max_risk_per_trade)
            {
               double adjustment_factor = max_risk_per_trade / current_risk_pct;
               lot_size *= adjustment_factor;
               Print("Risk management applied: Reducing lot size by factor ", adjustment_factor,
                     " to keep risk under ", max_risk_per_trade, "%. Current risk: ", current_risk_pct, "%, New lot size: ", lot_size);
            }
         }
      }

      // Get symbol specifications
      double symbol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double symbol_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double symbol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

      // Apply limits based on symbol specifications and max_lot parameter
      // Use a reasonable minimum (symbol minimum or 0.01 as a floor)
      double effective_min_lot = MathMax(symbol_min, 0.01);  // Use 0.01 as minimum floor

      if(lot_size < effective_min_lot)
         lot_size = effective_min_lot;
      else if(lot_size > max_lot)
         lot_size = max_lot;
      // Also respect the symbol's maximum lot size
      else if(lot_size > symbol_max)
         lot_size = symbol_max;

      // Normalize lot size to match broker's step size
      // This is crucial to avoid "invalid volume" errors
      if(symbol_step > 0)
      {
         // Round down to the nearest valid step
         lot_size = MathFloor(lot_size / symbol_step) * symbol_step;
         
         // Ensure we're still above minimum after rounding
         if(lot_size < effective_min_lot)
            lot_size = effective_min_lot;
      }

      // Final validation - ensure lot size is within valid range
      if(lot_size < symbol_min)
         lot_size = symbol_min;
      if(lot_size > symbol_max)
         lot_size = symbol_max;

      Print("Risk-based lot calculation - Balance: ", account_balance,
            ", Risk %: ", risk_percentage, ", Risk amount: ", risk_amount,
            ", SL in price: ", sl_price, ", Calculated lot: ", lot_size,
            ", Confidence multiplier: ", confidence_multiplier,
            ", Min lot: ", effective_min_lot, ", Max lot: ", max_lot,
            ", Step size: ", symbol_step);

      return lot_size;
   }
   else // Fixed lot size - keep as is for backward compatibility
   {
      // For fixed lot mode, return the symbol's minimum lot size
      double symbol_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double symbol_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Normalize to step size
      double lot_size = symbol_min;
      if(symbol_step > 0)
      {
         lot_size = MathFloor(lot_size / symbol_step) * symbol_step;
      }
      
      return lot_size;
   }
}

//+------------------------------------------------------------------+
//| Enhanced trend confirmation with multiple indicators            |
//+------------------------------------------------------------------+
bool ConfirmTrendDirection(bool is_buy_signal)
{
   double ema_buffer[];
   double adx_buffer[];
   double macd_main_buffer[];
   double macd_signal_buffer[];
   double rsi_buffer[];
   
   ArraySetAsSeries(ema_buffer, true);
   ArraySetAsSeries(adx_buffer, true);
   ArraySetAsSeries(macd_main_buffer, true);
   ArraySetAsSeries(macd_signal_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);
   
   // Get EMA values
   if(CopyBuffer(ema_handle, 0, 0, 2, ema_buffer) < 2)
   {
      Print("Failed to get EMA values for trend confirmation");
      return false;
   }
   
   // Get ADX values
   if(CopyBuffer(adx_handle, 0, 0, 2, adx_buffer) < 2)
   {
      Print("Failed to get ADX values for trend confirmation");
      return false;
   }
   
   // Get MACD values
   if(CopyBuffer(macd_handle, 0, 0, 2, macd_main_buffer) < 2 ||
      CopyBuffer(macd_handle, 1, 0, 2, macd_signal_buffer) < 2)
   {
      Print("Failed to get MACD values for trend confirmation");
      return false;
   }
   
   // Get RSI values
   if(CopyBuffer(rsi_handle, 0, 0, 2, rsi_buffer) < 2)
   {
      Print("Failed to get RSI values for trend confirmation");
      return false;
   }
   
   double current_ema = ema_buffer[0];
   double previous_ema = ema_buffer[1];
   double current_adx = adx_buffer[0];
   double current_macd_main = macd_main_buffer[0];
   double current_macd_signal = macd_signal_buffer[0];
   double previous_macd_main = macd_main_buffer[1];
   double previous_macd_signal = macd_signal_buffer[1];
   double current_rsi = rsi_buffer[0];
   
   // Multi-timeframe trend analysis (if enabled)
   // Get current prices first for use throughout the function
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double trend_ema_buffer[];
   double trend_adx_buffer[];
   double trend_macd_main_buffer[];
   double trend_macd_signal_buffer[];
   double trend_rsi_buffer[];
   
   bool trend_confirmed = false;
   
   if(use_multitimeframe_analysis)
   {
      ArraySetAsSeries(trend_ema_buffer, true);
      ArraySetAsSeries(trend_adx_buffer, true);
      ArraySetAsSeries(trend_macd_main_buffer, true);
      ArraySetAsSeries(trend_macd_signal_buffer, true);
      ArraySetAsSeries(trend_rsi_buffer, true);
      
      // Get higher timeframe values
      if(CopyBuffer(trend_ema_handle, 0, 0, 2, trend_ema_buffer) >= 2 &&
         CopyBuffer(trend_adx_handle, 0, 0, 2, trend_adx_buffer) >= 2 &&
         CopyBuffer(trend_macd_handle, 0, 0, 2, trend_macd_main_buffer) >= 2 &&
         CopyBuffer(trend_macd_handle, 1, 0, 2, trend_macd_signal_buffer) >= 2 &&
         CopyBuffer(trend_rsi_handle, 0, 0, 2, trend_rsi_buffer) >= 2)
      {
         double trend_ema = trend_ema_buffer[0];
         double trend_adx = trend_adx_buffer[0];
         double trend_macd_main = trend_macd_main_buffer[0];
         double trend_macd_signal_value = trend_macd_signal_buffer[0];
         double trend_rsi = trend_rsi_buffer[0];
         
         // Higher timeframe trend confirmation score
         int trend_score = 0;
         
         // 1. Higher timeframe EMA trend
         if(is_buy_signal && current_bid > trend_ema)
            trend_score++;
         else if(!is_buy_signal && current_ask < trend_ema)
            trend_score++;
         
         // 2. Higher timeframe ADX strength
         if(trend_adx > adx_threshold)
            trend_score++;
         
         // 3. Higher timeframe MACD momentum
         if(is_buy_signal)
         {
            if(trend_macd_main > trend_macd_signal_value &&
               trend_macd_main > macd_threshold &&
               (trend_macd_main - trend_macd_signal_value) > 0)
               trend_score++;
         }
         else
         {
            if(trend_macd_main < trend_macd_signal_value &&
               trend_macd_main < -macd_threshold &&
               (trend_macd_main - trend_macd_signal_value) < 0)
               trend_score++;
         }
         
         // 4. Higher timeframe RSI
         if(is_buy_signal && trend_rsi < rsi_overbought && trend_rsi > rsi_oversold)
            trend_score++;
         else if(!is_buy_signal && trend_rsi > rsi_oversold && trend_rsi < rsi_overbought)
            trend_score++;
         
         // Require at least 1 confirmation from higher timeframe (less restrictive)
         trend_confirmed = (trend_score >= 1);
         
         Print("Multi-timeframe trend analysis for ", is_buy_signal ? "BUY" : "SELL",
               " - Score: ", trend_score, "/1",
               " - EMA: ", trend_ema, ", ADX: ", trend_adx,
               ", MACD: ", trend_macd_main, ", RSI: ", trend_rsi,
               " -> ", trend_confirmed ? "CONFIRMED" : "REJECTED");
      }
      else
      {
         Print("Failed to get multi-timeframe indicator values");
      }
   }
   
   // Trend confirmation score
   int confirmation_score = 0;
   int required_confirmations = 1; // Require at least 1 confirmation - Less restrictive for more opportunities
   
   // 1. EMA trend confirmation
   if(is_buy_signal && current_bid > current_ema)
      confirmation_score++;
   else if(!is_buy_signal && current_ask < current_ema)
      confirmation_score++;
   
   // 2. ADX strength confirmation (must be above threshold)
   if(current_adx > adx_threshold)
      confirmation_score++;
   
   // 3. MACD momentum confirmation
   if(is_buy_signal)
   {
      // For buy: MACD line above signal line and both positive or crossing up
      if(current_macd_main > current_macd_signal && 
         current_macd_main > macd_threshold &&
         (current_macd_main - current_macd_signal) > (previous_macd_main - previous_macd_signal))
         confirmation_score++;
   }
   else
   {
      // For sell: MACD line below signal line and both negative or crossing down
      if(current_macd_main < current_macd_signal && 
         current_macd_main < -macd_threshold &&
         (current_macd_main - current_macd_signal) < (previous_macd_main - previous_macd_signal))
         confirmation_score++;
   }
   
   // 4. RSI overbought/oversold confirmation
   if(is_buy_signal && current_rsi < rsi_overbought && current_rsi > rsi_oversold)
      confirmation_score++;
   else if(!is_buy_signal && current_rsi > rsi_oversold && current_rsi < rsi_overbought)
      confirmation_score++;
   
   // 5. EMA direction confirmation
   if(is_buy_signal && current_ema > previous_ema)
      confirmation_score++;
   else if(!is_buy_signal && current_ema < previous_ema)
      confirmation_score++;
   
   // If multi-timeframe analysis is enabled and confirms trend, give it higher weight
   if(trend_confirmed)
      confirmation_score += 2; // Bonus for higher timeframe confirmation
   
   Print("Trend confirmation for ", is_buy_signal ? "BUY" : "SELL",
         " - Score: ", confirmation_score, "/", required_confirmations,
         " - EMA: ", current_ema, ", ADX: ", current_adx,
         ", MACD: ", current_macd_main, ", RSI: ", current_rsi,
         (trend_confirmed ? " + Multi-timeframe CONFIRMED" : ""));
   
   return confirmation_score >= required_confirmations;
}

//+------------------------------------------------------------------+
//| Check volatility conditions                                      |
//+------------------------------------------------------------------+
bool CheckVolatilityConditions(double range_size)
{
   if(!use_volatility_filter)
      return true;
      
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);
   
   if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1)
   {
      Print("Failed to get ATR value for volatility check");
      return false;
   }
   
   double current_atr = atr_buffer[0];
   double range_points = range_size / _Point;
   double atr_points = current_atr / _Point;
   
   // Check if range is within acceptable ATR multiples
   if(range_points < atr_points * min_range_atr_multiplier)
   {
      Print("Range too small for volatility filter: ", range_points, " points < ", 
            atr_points * min_range_atr_multiplier, " points");
      return false;
   }
   
   if(range_points > atr_points * max_range_atr_multiplier)
   {
      Print("Range too large for volatility filter: ", range_points, " points > ", 
            atr_points * max_range_atr_multiplier, " points");
      return false;
   }
   
   // Check if current volatility is acceptable
   double avg_atr = 0;
   double atr_buffer_avg[];
   ArraySetAsSeries(atr_buffer_avg, true);
   
   if(CopyBuffer(atr_handle, 0, 0, 14, atr_buffer_avg) >= 14)
   {
      for(int i = 0; i < 14; i++)
         avg_atr += atr_buffer_avg[i];
      avg_atr /= 14;
      
      if(current_atr > avg_atr * volatility_threshold)
      {
         Print("Current volatility too high: ", current_atr, " > ", avg_atr * volatility_threshold);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect market regime (trending vs ranging)                       |
//+------------------------------------------------------------------+
bool IsMarketTrending()
{
   if(!use_market_regime_filter)
      return true; // Default to trending if filter is disabled
      
   double adx_buffer[];
   double bb_upper_buffer[];
   double bb_middle_buffer[];
   double bb_lower_buffer[];
   
   ArraySetAsSeries(adx_buffer, true);
   ArraySetAsSeries(bb_upper_buffer, true);
   ArraySetAsSeries(bb_middle_buffer, true);
   ArraySetAsSeries(bb_lower_buffer, true);
   
   // Get ADX values
   if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) < 1)
   {
      Print("Failed to get ADX values for market regime detection");
      return true; // Default to trending
   }
   
   // Get Bollinger Bands values
   if(CopyBuffer(bb_handle, 0, 0, 1, bb_middle_buffer) < 1 ||
      CopyBuffer(bb_handle, 1, 0, 1, bb_upper_buffer) < 1 ||
      CopyBuffer(bb_handle, 2, 0, 1, bb_lower_buffer) < 1)
   {
      Print("Failed to get Bollinger Bands values for market regime detection");
      return true; // Default to trending
   }
   
   double current_adx = adx_buffer[0];
   double bb_upper = bb_upper_buffer[0];
   double bb_middle = bb_middle_buffer[0];
   double bb_lower = bb_lower_buffer[0];
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Market is trending if ADX is above threshold OR price is outside Bollinger Bands
   bool is_trending = (current_adx > trending_threshold) || 
                      (current_price > bb_upper) || 
                      (current_price < bb_lower);
   
   Print("Market regime detection - ADX: ", current_adx, 
         " (threshold: ", trending_threshold, "), ",
         "Price: ", current_price, ", BB Upper: ", bb_upper, 
         ", BB Lower: ", bb_lower, " -> ", is_trending ? "TRENDING" : "RANGING");
   
   return is_trending;
}

//+------------------------------------------------------------------+
//| Calculate confidence multiplier for position sizing             |
//+------------------------------------------------------------------+
double CalculateConfidenceMultiplier(bool is_buy_signal)
{
   if(!use_dynamic_position_sizing)
      return base_confidence;
      
   double confidence = base_confidence;
   double adx_buffer[];
   double rsi_buffer[];
   
   ArraySetAsSeries(adx_buffer, true);
   ArraySetAsSeries(rsi_buffer, true);
   
   // Get ADX and RSI values
   if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) >= 1 &&
      CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) >= 1)
   {
      double current_adx = adx_buffer[0];
      double current_rsi = rsi_buffer[0];
      
      // Increase confidence based on ADX strength
      if(current_adx > 40)
         confidence += 0.5;
      else if(current_adx > 30)
         confidence += 0.3;
      else if(current_adx > 25)
         confidence += 0.1;
      
      // Adjust confidence based on RSI levels
      if(is_buy_signal)
      {
         if(current_rsi > 40 && current_rsi < 60)
            confidence += 0.2; // Neutral RSI is good for breakouts
         else if(current_rsi < 30)
            confidence -= 0.2; // Oversold might mean reversal
      }
      else
      {
         if(current_rsi > 40 && current_rsi < 60)
            confidence += 0.2; // Neutral RSI is good for breakouts
         else if(current_rsi > 70)
            confidence -= 0.2; // Overbought might mean reversal
      }
   }
   
   // Ensure confidence is within bounds
   if(confidence > max_confidence_multiplier)
      confidence = max_confidence_multiplier;
   if(confidence < 0.5)
      confidence = 0.5;
      
   Print("Calculated confidence multiplier: ", confidence);
   return confidence;
}

//+------------------------------------------------------------------+
//| Place pending orders based on the calculated range               |
//+------------------------------------------------------------------+
void PlacePendingOrders()
{
   if(g_high_price <= 0 || g_low_price >= 99999999)
      return;
      
   double range_size = g_high_price - g_low_price;
   double range_points = range_size / _Point;
   
   Print("=== Daily Range Details ===");
   Print("Date: ", TimeToString(TimeCurrent()));
   Print("Range High: ", g_high_price);
   Print("Range Low: ", g_low_price);
   Print("Range Size: ", range_points, " points");
   Print("=========================");
   
   // Apply range size filter
   if(range_points < min_range_pips || range_points > max_range_pips)
   {
      Print("Range size filter: ", range_points, " points outside range [", min_range_pips, "-", max_range_pips, "]. No orders placed.");
      g_orders_placed = true;
      return;
   }
   
   // Check session filter
   if(!IsTradingSession())
   {
      Print("Current session is not allowed for trading. No orders placed.");
      g_orders_placed = true;
      return;
   }
   
   // Check volatility conditions
   if(!CheckVolatilityConditions(range_size))
   {
      Print("Volatility conditions not met. No orders placed.");
      g_orders_placed = true;
      return;
   }
   
   // Check market regime
   if(!IsMarketTrending())
   {
      Print("Market is in ranging mode. No breakout orders placed.");
      g_orders_placed = true;
      return;
   }
   
   // Get current ATR value for range validation
   if(atr_handle == INVALID_HANDLE)
   {
      Print("ATR indicator not available for range validation. No orders placed.");
      g_orders_placed = true;
      return;
   }

   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);

   if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) < 1)
   {
      Print("Failed to get ATR value for range validation. No orders placed.");
      g_orders_placed = true;
      return;
   }

   double current_atr = atr_buffer[0];

   // Check if ATR is within acceptable limits for trading
   if(max_atr_threshold > 0 && current_atr > max_atr_threshold)
   {
      Print("Current ATR (", current_atr, ") exceeds maximum threshold (", max_atr_threshold, "). No orders placed.");
      g_orders_placed = true;
      return;
   }

   // Get symbol trading constraints for order validation
   double stop_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Calculate SL and TP
   double buy_sl = 0, buy_tp = 0, sell_sl = 0, sell_tp = 0;
   double point_value = _Point;
   
   // Get ATR value for ATR-based stops
   double atr_value = 0;
   if(use_atr_stops && atr_handle != INVALID_HANDLE)
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) >= 1)
         atr_value = atr_buffer[0];
   }
   
   // Calculate SL and TP based on selected method
   if(use_atr_stops && atr_value > 0)
   {
      // ATR-based stops
      if(atr_sl_multiplier > 0)
      {
         buy_sl = g_high_price - (atr_value * atr_sl_multiplier);
         sell_sl = g_low_price + (atr_value * atr_sl_multiplier);
      }
      
      if(atr_tp_multiplier > 0)
      {
         buy_tp = g_high_price + (atr_value * atr_tp_multiplier);
         sell_tp = g_low_price - (atr_value * atr_tp_multiplier);
      }
   }
   else
   {
      // Fixed pips stops
      if(fixed_sl_pips > 0)
      {
         buy_sl = g_high_price - (fixed_sl_pips * point_value);
         sell_sl = g_low_price + (fixed_sl_pips * point_value);
      }
      
      if(profit_target_pips > 0)
      {
         buy_tp = g_high_price + (profit_target_pips * point_value);
         sell_tp = g_low_price - (profit_target_pips * point_value);
      }
   }
   
   // Fallback to percentage-based if no other method is available
   if(buy_sl == 0 && stop_loss > 0)
   {
      // Calculate SL based on range percentage
      buy_sl = g_high_price - (range_size * stop_loss / 100);
      sell_sl = g_low_price + (range_size * stop_loss / 100);
   }
   
   if(buy_tp == 0 && take_profit > 0)
   {
      buy_tp = g_high_price + (range_size * take_profit / 100);
      sell_tp = g_low_price - (range_size * take_profit / 100);
   }
   
   Print("Stop Loss Calculation - Buy SL: ", buy_sl, ", Sell SL: ", sell_sl,
         ", ATR-based: ", (use_atr_stops && atr_value > 0), ", ATR: ", atr_value);
   
   // Get current prices for trend confirmation
   double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Normalize all price values to correct digits
   g_high_price = NormalizeDouble(g_high_price, digits);
   g_low_price = NormalizeDouble(g_low_price, digits);
   buy_sl = NormalizeDouble(buy_sl, digits);
   buy_tp = NormalizeDouble(buy_tp, digits);
   sell_sl = NormalizeDouble(sell_sl, digits);
   sell_tp = NormalizeDouble(sell_tp, digits);
   current_ask = NormalizeDouble(current_ask, digits);
   current_bid = NormalizeDouble(current_bid, digits);

   // Check buy signal with enhanced confirmation
   bool buy_signal_confirmed = ConfirmTrendDirection(true);
   double buy_confidence = CalculateConfidenceMultiplier(true);
   
   // Apply confidence threshold
   if(use_risk_management && buy_confidence < min_confidence_threshold)
   {
      Print("Buy signal rejected: Confidence too low (", buy_confidence, " < ", min_confidence_threshold, ")");
      buy_signal_confirmed = false;
   }
   
   // Place buy stop order at the high of the range
   if(buy_signal_confirmed)
   {
      trade.SetExpertMagicNumber(magic_number);

      // Validate buy stop order price and stop loss
      bool buy_order_valid = true;
      string buy_error_msg = "";
      
      // Check if buy stop price is above current bid (required for buy stop)
      if(g_high_price <= current_bid)
      {
         buy_order_valid = false;
         buy_error_msg = "Buy stop price (" + DoubleToString(g_high_price, digits) + ") must be above current bid (" + DoubleToString(current_bid, digits) + ")";
      }
      
      // Check if stop loss is valid distance from order price
      if(stop_loss > 0 && buy_sl > 0)
      {
         double sl_distance = g_high_price - buy_sl;
         double min_sl_distance = stop_level * point;
         if(sl_distance < min_sl_distance)
         {
            buy_order_valid = false;
            buy_error_msg = "Buy stop SL distance (" + DoubleToString(sl_distance, digits) + ") below minimum (" + DoubleToString(min_sl_distance, digits) + ")";
         }
      }
      
      if(buy_order_valid)
      {
         // Calculate lot size with confidence multiplier
         g_lot_size = CalculateLotSize(range_size, buy_confidence);
         
         bool buy_success = trade.BuyStop(
            g_lot_size,
            g_high_price,
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
            Print("Buy Stop order placed at ", g_high_price, " with lot size ", g_lot_size, " (confidence: ", buy_confidence, ")");
         }
         else
         {
            Print("Failed to place Buy Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
      else
      {
         Print("Buy Stop order validation failed: ", buy_error_msg);
         g_buy_ticket = 0; // No buy order placed
      }
   }
   else
   {
      Print("Buy Stop order skipped - Enhanced trend confirmation failed");
      g_buy_ticket = 0; // No buy order placed
   }

   // Check sell signal with enhanced confirmation
   bool sell_signal_confirmed = ConfirmTrendDirection(false);
   double sell_confidence = CalculateConfidenceMultiplier(false);
   
   // Apply confidence threshold
   if(use_risk_management && sell_confidence < min_confidence_threshold)
   {
      Print("Sell signal rejected: Confidence too low (", sell_confidence, " < ", min_confidence_threshold, ")");
      sell_signal_confirmed = false;
   }
   
   // Place sell stop order at the low of the range
   if(sell_signal_confirmed)
   {
      // Validate sell stop order price and stop loss
      bool sell_order_valid = true;
      string sell_error_msg = "";
      
      // Check if sell stop price is below current ask (required for sell stop)
      if(g_low_price >= current_ask)
      {
         sell_order_valid = false;
         sell_error_msg = "Sell stop price (" + DoubleToString(g_low_price, digits) + ") must be below current ask (" + DoubleToString(current_ask, digits) + ")";
      }
      
      // Check if stop loss is valid distance from order price
      if(stop_loss > 0 && sell_sl > 0)
      {
         double sl_distance = sell_sl - g_low_price;
         double min_sl_distance = stop_level * point;
         if(sl_distance < min_sl_distance)
         {
            sell_order_valid = false;
            sell_error_msg = "Sell stop SL distance (" + DoubleToString(sl_distance, digits) + ") below minimum (" + DoubleToString(min_sl_distance, digits) + ")";
         }
      }
      
      if(sell_order_valid)
      {
         // Calculate lot size with confidence multiplier
         g_lot_size = CalculateLotSize(range_size, sell_confidence);
         
         bool sell_success = trade.SellStop(
            g_lot_size,
            g_low_price,
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
            Print("Sell Stop order placed at ", g_low_price, " with lot size ", g_lot_size, " (confidence: ", sell_confidence, ")");
         }
         else
         {
            Print("Failed to place Sell Stop order. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
         }
      }
      else
      {
         Print("Sell Stop order validation failed: ", sell_error_msg);
         g_sell_ticket = 0; // No sell order placed
      }
   }
   else
   {
      Print("Sell Stop order skipped - Enhanced trend confirmation failed");
      g_sell_ticket = 0; // No sell order placed
   }
    
   g_orders_placed = true;
}

//+------------------------------------------------------------------+
//| Manage open orders                                               |
//+------------------------------------------------------------------+
void ManageOrders()
{
   // If single breakout mode is enabled, check if one order has been triggered
   if(single_breakout_only)
   {
      bool buy_triggered = false;
      bool sell_triggered = false;
      
      // Get order information
      if(g_buy_ticket > 0)
      {
         // Check if the order still exists and if it's a market order (was triggered)
         if(OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_BUY) // Changed from pending to market = triggered
               buy_triggered = true;
         }
         else
         {
            // Check if it became a position (was triggered and is still open)
            if(PositionSelectByTicket(g_buy_ticket))
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                  buy_triggered = true;
            }
            else
            {
               g_buy_ticket = 0; // Order no longer exists
            }
         }
      }
      
      // Check if sell stop order has been triggered
      if(g_sell_ticket > 0)
      {
         // Check if the order still exists and if it's a market order (was triggered)
         if(OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_SELL) // Changed from pending to market = triggered
               sell_triggered = true;
         }
         else
         {
            // Check if it became a position (was triggered and is still open)
            if(PositionSelectByTicket(g_sell_ticket))
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                  sell_triggered = true;
            }
            else
            {
               g_sell_ticket = 0; // Order no longer exists
            }
         }
      }
      
      // If one order has been triggered, delete the other pending order
      if(buy_triggered && g_sell_ticket > 0)
      {
         if(OrderSelect(g_sell_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_SELL_STOP)
               trade.OrderDelete(g_sell_ticket);
         }
         g_sell_ticket = 0;
      }
      else if(sell_triggered && g_buy_ticket > 0)
      {
         if(OrderSelect(g_buy_ticket))
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(order_type == ORDER_TYPE_BUY_STOP)
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
   
   // Reset flags for next day
   g_range_calculated = false;
   g_orders_placed = false;
   g_buy_ticket = 0;
   g_sell_ticket = 0;
}

//+------------------------------------------------------------------+
//| Manage ATR-based trailing stop for open positions               |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(atr_period <= 0 || atr_multiplier <= 0 || atr_handle == INVALID_HANDLE)
      return;

   // Get current ATR values
   double atr_buffer[];
   ArraySetAsSeries(atr_buffer, true);

   if(CopyBuffer(atr_handle, 0, 0, 2, atr_buffer) < 2)
      return;

   double current_atr = atr_buffer[0];
   if(current_atr <= 0)
      return;

   // Get symbol trading constraints
   double stop_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

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
               profit_points = (current_price - position_open_price) / point;
            else
               profit_points = (position_open_price - current_price) / point;

            // Calculate required profit based on ATR (instead of fixed points)
            double required_profit = trailing_atr_multiplier * current_atr / point;
            
            // Increase required profit threshold to avoid premature trailing
            required_profit *= 2.0; // Double the threshold for safer trailing

            // If profit has not reached ATR-based threshold, skip
            if(profit_points < required_profit)
               continue;

            // Calculate new stop loss level based on ATR
            double new_sl = 0;
            double atr_distance = atr_multiplier * current_atr;

            if(position_type == POSITION_TYPE_BUY)
            {
               // For buy positions, trail below current price by ATR multiple
               new_sl = current_price - atr_distance;

               // Ensure stop loss is at least the minimum distance from current price
               double min_distance = stop_level * point;
               if(current_price - new_sl < min_distance)
                  new_sl = current_price - min_distance;

               // Normalize the stop loss price to correct digits
               new_sl = NormalizeDouble(new_sl, digits);

               // For ATR trailing stops, we want the highest value (most protective for longs)
               // Only update if the new SL is higher than current SL or no SL is set
               if(position_sl == 0 || new_sl > position_sl)
               {
                  // Additional validation: ensure new SL is not too close to current price
                  if(current_price - new_sl >= stop_level * point)
                  {
                     trade.PositionModify(position_ticket, new_sl, position_tp);
                     Print("ATR Trailing stop for BUY position #", position_ticket,
                           " - Current ATR: ", current_atr, ", ATR Distance: ", atr_distance,
                           " - Old SL: ", position_sl, " -> New SL: ", new_sl);
                  }
                  else
                  {
                     Print("ATR Trailing stop for BUY position #", position_ticket,
                           " - New SL too close to price. Required distance: ", stop_level * point,
                           ", Current distance: ", current_price - new_sl);
                  }
               }
            }
            else // SELL position
            {
               // For sell positions, trail above current price by ATR multiple
               new_sl = current_price + atr_distance;

               // Ensure stop loss is at least the minimum distance from current price
               double min_distance = stop_level * point;
               if(new_sl - current_price < min_distance)
                  new_sl = current_price + min_distance;

               // Normalize the stop loss price to correct digits
               new_sl = NormalizeDouble(new_sl, digits);

               // For ATR trailing stops on shorts, we want the lowest value (most protective for shorts)
               // Only update if the new SL is lower than current SL or no SL is set
               if(position_sl == 0 || new_sl < position_sl)
               {
                  // Additional validation: ensure new SL is not too close to current price
                  if(new_sl - current_price >= stop_level * point)
                  {
                     trade.PositionModify(position_ticket, new_sl, position_tp);
                     Print("ATR Trailing stop for SELL position #", position_ticket,
                           " - Current ATR: ", current_atr, ", ATR Distance: ", atr_distance,
                           " - Old SL: ", position_sl, " -> New SL: ", new_sl);
                  }
                  else
                  {
                     Print("ATR Trailing stop for SELL position #", position_ticket,
                           " - New SL too close to price. Required distance: ", stop_level * point,
                           ", Current distance: ", new_sl - current_price);
                  }
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