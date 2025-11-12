//+------------------------------------------------------------------+
//|                                                     DBxEMA.mq5    |
//|                        Daily Breakout x EMA Strategy             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

CTrade trade;

//--- Input Parameters
input double risk_percentage = 1.0;        // Risk % per trade
input double rr_ratio = 2.0;               // Risk:Reward ratio
input int magic_number = 54321;            // Magic Number
input int ema_fast_period = 10;            // EMA Fast Period
input int ema_slow_period = 20;            // EMA Slow Period
input int confirm_candles = 3;             // Candles for confirmation

//--- Global Variables
double PrevHIGH = 0;
double PrevLOW = 0;
string DIRECTION = "NONE";
double BreakRestingHIGH = 0;
double BreakRestingLOW = 0;
double RejectBreakHIGH = 0;
double RejectBreakLOW = 0;
double RejectRestingHIGH = 0;
double RejectRestingLOW = 0;

int ema_fast_handle;
int ema_slow_handle;
double ema_fast_buffer[];
double ema_slow_buffer[];

datetime current_day = 0;
datetime last_check_time = 0;

int breakout_candles_count = 0;
datetime breakout_time = 0;
bool waiting_confirmation = false;
bool below_range_triggered = false;
double breakout_direction = 0; // 1 for up, -1 for down
datetime last_bearish_time = 0;
datetime last_bullish_time = 0;

string last_executed_direction = "NONE";
ulong current_position_ticket = 0;

double last_trade_sl_level = 0;
bool waiting_for_continuation = false;
datetime last_resting_update_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== DBxEMA EA Initialized ===");
   
   ema_fast_handle = iMA(_Symbol, PERIOD_M5, ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   ema_slow_handle = iMA(_Symbol, PERIOD_M5, ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema_fast_handle == INVALID_HANDLE || ema_slow_handle == INVALID_HANDLE)
   {
      Print("Failed to create EMA indicators");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(ema_fast_buffer, true);
   ArraySetAsSeries(ema_slow_buffer, true);
   
   trade.SetExpertMagicNumber(magic_number);
   
   ChartIndicatorAdd(ChartID(), 0, ema_fast_handle);
   ChartIndicatorAdd(ChartID(), 0, ema_slow_handle);
   
   GetPreviousDayRange();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(ema_fast_handle);
   IndicatorRelease(ema_slow_handle);
   
   ObjectDelete(0, "PrevHIGH_Line");
   ObjectDelete(0, "PrevLOW_Line");
   ObjectDelete(0, "PrevDay_00_Line");
   ObjectDelete(0, "CurrentDay_00_Line");
   
   Print("=== DBxEMA EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime today = StructToTime(dt);
   
   if(today != current_day)
   {
      current_day = today;
      GetPreviousDayRange();
      ResetDailyVariables();
   }
   
   if(PrevHIGH == 0 || PrevLOW == 0)
      return;
   
   if(CopyBuffer(ema_fast_handle, 0, 0, 10, ema_fast_buffer) < 10)
      return;
   if(CopyBuffer(ema_slow_handle, 0, 0, 10, ema_slow_buffer) < 10)
      return;
   
   CheckDirectionLogic();
   
   CheckForNewRestingLevel();
   
   CheckForContinuationTrade();
   
   DrawRangeLines();
}

//+------------------------------------------------------------------+
//| Get Previous Day High and Low from D1                            |
//+------------------------------------------------------------------+
void GetPreviousDayRange()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates);
   
   if(copied > 0)
   {
      PrevHIGH = rates[0].high;
      PrevLOW = rates[0].low;
      
      Print("Previous Day Range - HIGH: ", PrevHIGH, " LOW: ", PrevLOW);
   }
   else
   {
      Print("Failed to get previous day range");
   }
}

//+------------------------------------------------------------------+
//| Reset Daily Variables                                            |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
   DIRECTION = "NONE";
   BreakRestingHIGH = 0;
   BreakRestingLOW = 0;
   RejectBreakHIGH = 0;
   RejectBreakLOW = 0;
   RejectRestingHIGH = 0;
   RejectRestingLOW = 0;
   breakout_candles_count = 0;
   breakout_time = 0;
   waiting_confirmation = false;
   below_range_triggered = false;
   breakout_direction = 0;
   last_bearish_time = 0;
   last_bullish_time = 0;
   last_executed_direction = "NONE";
   current_position_ticket = 0;
   last_trade_sl_level = 0;
   waiting_for_continuation = false;
   last_resting_update_time = 0;
   
   Print("Daily variables reset for new trading day");
}

//+------------------------------------------------------------------+
//| Check Direction Logic                                            |
//+------------------------------------------------------------------+
void CheckDirectionLogic()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 50, rates);
   if(copied < 50)
      return;
   
   double current_close = rates[0].close;
   double current_high = rates[0].high;
   double current_low = rates[0].low;
   
   // Check if we're in a new candle
   static datetime last_bar_time = 0;
   if(rates[0].time == last_bar_time)
      return;
   last_bar_time = rates[0].time;
   
   // BREAKOUT LOGIC - Price closes above PrevHIGH
   if(!waiting_confirmation && rates[1].close > PrevHIGH && (DIRECTION == "NONE" || DIRECTION == "LONG_REJECT"))
   {
      if(DIRECTION == "LONG_REJECT")
         Print("Transitioning from LONG_REJECT to potential LONG_BREAK");
      
      Print("Breakout above PrevHIGH detected at candle close: ", rates[1].close);
      DIRECTION = "NONE"; // Reset direction for new attempt
      waiting_confirmation = true;
      breakout_direction = 1;
      breakout_time = rates[1].time;
      breakout_candles_count = 0;
      below_range_triggered = false;
      last_bearish_time = 0;
   }
   
   // BREAKOUT LOGIC - Price closes below PrevLOW
   if(!waiting_confirmation && rates[1].close < PrevLOW && (DIRECTION == "NONE" || DIRECTION == "SHORT_REJECT"))
   {
      if(DIRECTION == "SHORT_REJECT")
         Print("Transitioning from SHORT_REJECT to potential SHORT_BREAK");
      
      Print("Breakout below PrevLOW detected at candle close: ", rates[1].close);
      DIRECTION = "NONE"; // Reset direction for new attempt
      waiting_confirmation = true;
      breakout_direction = -1;
      breakout_time = rates[1].time;
      breakout_candles_count = 0;
      below_range_triggered = false;
      last_bullish_time = 0;
   }
   
   // CONFIRMATION LOGIC for BREAKOUT ABOVE
   if(waiting_confirmation && breakout_direction == 1)
   {
      breakout_candles_count++;
      
      // Check if bearish candle closes back below PrevHIGH (rejection)
      if(rates[1].close < rates[1].open && rates[1].close < PrevHIGH)
      {
         Print("Rejection detected - Bearish candle closed below PrevHIGH");
         DIRECTION = "SHORT_REJECT";
         RejectBreakHIGH = GetHighestHigh(rates, breakout_time);
         waiting_confirmation = false;
         Print("DIRECTION set to SHORT_REJECT, RejectBreakHIGH: ", RejectBreakHIGH);
         return;
      }
      
      // Track last bearish candle
      if(rates[1].close < rates[1].open)
      {
         last_bearish_time = rates[1].time;
      }
      
      // Check if bullish candle comes right after bearish without closing below
      if(rates[1].close > rates[1].open && last_bearish_time == rates[2].time)
      {
         if(breakout_candles_count >= confirm_candles)
         {
            Print("Breakout confirmed - Bullish candle after bearish, no close below PrevHIGH");
            DIRECTION = "LONG_BREAK";
            BreakRestingLOW = GetLowestLowSinceBreakout(rates, breakout_time);
            waiting_confirmation = false;
            Print("DIRECTION set to LONG_BREAK, BreakRestingLOW: ", BreakRestingLOW);
            return;
         }
      }
   }
   
   // CONFIRMATION LOGIC for BREAKOUT BELOW
   if(waiting_confirmation && breakout_direction == -1)
   {
      breakout_candles_count++;
      
      // Check if bullish candle closes back above PrevLOW (rejection)
      if(rates[1].close > rates[1].open && rates[1].close > PrevLOW)
      {
         Print("Rejection detected - Bullish candle closed above PrevLOW");
         DIRECTION = "LONG_REJECT";
         RejectBreakLOW = GetLowestLow(rates, breakout_time);
         waiting_confirmation = false;
         Print("DIRECTION set to LONG_REJECT, RejectBreakLOW: ", RejectBreakLOW);
         return;
      }
      
      // Track last bullish candle
      if(rates[1].close > rates[1].open)
      {
         last_bullish_time = rates[1].time;
      }
      
      // Check if bearish candle comes right after bullish without closing above
      if(rates[1].close < rates[1].open && last_bullish_time == rates[2].time)
      {
         if(breakout_candles_count >= confirm_candles)
         {
            Print("Breakout confirmed - Bearish candle after bullish, no close above PrevLOW");
            DIRECTION = "SHORT_BREAK";
            BreakRestingHIGH = GetHighestHighSinceBreakout(rates, breakout_time);
            waiting_confirmation = false;
            Print("DIRECTION set to SHORT_BREAK, BreakRestingHIGH: ", BreakRestingHIGH);
            return;
         }
      }
   }
   
   // Only update resting levels when actual consolidation is detected
   // Don't continuously update - let CheckForNewRestingLevel() handle it
   
   // Update resting levels for REJECT scenarios
   if(DIRECTION == "SHORT_REJECT")
   {
      // Continuously update RejectRestingHIGH with latest bounce high
      double latest_high = GetRecentHighSinceLastTrade(rates);
      if(latest_high < PrevHIGH) // Must be below PrevHIGH (inside range)
      {
         if(latest_high > RejectRestingHIGH || RejectRestingHIGH == 0)
            RejectRestingHIGH = latest_high;
      }
      
      // SHORT_REJECT can transition to:
      // 1. LONG_BREAK (reversal - price breaks above PrevHIGH again)
      // 2. SHORT_BREAK (continuation - price breaks below PrevLOW for downside continuation)
      
      if(rates[1].close > PrevHIGH)
      {
         Print("SHORT_REJECT transitioning to LONG_BREAK attempt (reversal)");
         DIRECTION = "NONE";
         waiting_confirmation = true;
         breakout_direction = 1;
         breakout_time = rates[1].time;
         breakout_candles_count = 0;
         last_bearish_time = 0;
      }
      else if(rates[1].close < PrevLOW)
      {
         Print("SHORT_REJECT transitioning to SHORT_BREAK attempt (continuation)");
         DIRECTION = "NONE";
         waiting_confirmation = true;
         breakout_direction = -1;
         breakout_time = rates[1].time;
         breakout_candles_count = 0;
         last_bullish_time = 0;
      }
   }
   if(DIRECTION == "LONG_REJECT")
   {
      // Continuously update RejectRestingLOW with latest bounce low
      double latest_low = GetRecentLowSinceLastTrade(rates);
      if(latest_low > PrevLOW) // Must be above PrevLOW (inside range)
      {
         if(latest_low < RejectRestingLOW || RejectRestingLOW == 0)
            RejectRestingLOW = latest_low;
      }
      
      // LONG_REJECT can transition to:
      // 1. SHORT_BREAK (reversal - price breaks below PrevLOW again)
      // 2. LONG_BREAK (continuation - price breaks above PrevHIGH for upside continuation)
      
      if(rates[1].close < PrevLOW)
      {
         Print("LONG_REJECT transitioning to SHORT_BREAK attempt (reversal)");
         DIRECTION = "NONE";
         waiting_confirmation = true;
         breakout_direction = -1;
         breakout_time = rates[1].time;
         breakout_candles_count = 0;
         last_bullish_time = 0;
      }
      else if(rates[1].close > PrevHIGH)
      {
         Print("LONG_REJECT transitioning to LONG_BREAK attempt (continuation)");
         DIRECTION = "NONE";
         waiting_confirmation = true;
         breakout_direction = 1;
         breakout_time = rates[1].time;
         breakout_candles_count = 0;
         last_bearish_time = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Get Highest High Since Breakout                                 |
//+------------------------------------------------------------------+
double GetHighestHighSinceBreakout(MqlRates &rates[], datetime since_time)
{
   double highest = 0;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time >= since_time)
      {
         if(rates[i].high > highest)
            highest = rates[i].high;
      }
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get Lowest Low Since Breakout                                   |
//+------------------------------------------------------------------+
double GetLowestLowSinceBreakout(MqlRates &rates[], datetime since_time)
{
   double lowest = 999999;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time >= since_time)
      {
         if(rates[i].low < lowest)
            lowest = rates[i].low;
      }
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| Get Highest High (for rejection scenario)                        |
//+------------------------------------------------------------------+
double GetHighestHigh(MqlRates &rates[], datetime since_time)
{
   double highest = 0;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time >= since_time && rates[i].close > PrevHIGH)
      {
         if(rates[i].high > highest)
            highest = rates[i].high;
      }
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get Lowest Low (for rejection scenario)                          |
//+------------------------------------------------------------------+
double GetLowestLow(MqlRates &rates[], datetime since_time)
{
   double lowest = 999999;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time >= since_time && rates[i].close < PrevLOW)
      {
         if(rates[i].low < lowest)
            lowest = rates[i].low;
      }
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| Get Recent High Since Last Trade (for ongoing consolidations)    |
//+------------------------------------------------------------------+
double GetRecentHighSinceLastTrade(MqlRates &rates[])
{
   double highest = 0;
   // Look at last 10-20 candles for recent consolidation high
   int lookback = MathMin(20, ArraySize(rates));
   
   for(int i = 0; i < lookback; i++)
   {
      if(rates[i].high > highest)
         highest = rates[i].high;
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get Recent Low Since Last Trade (for ongoing consolidations)     |
//+------------------------------------------------------------------+
double GetRecentLowSinceLastTrade(MqlRates &rates[])
{
   double lowest = 999999;
   // Look at last 10-20 candles for recent consolidation low
   int lookback = MathMin(20, ArraySize(rates));
   
   for(int i = 0; i < lookback; i++)
   {
      if(rates[i].low < lowest)
         lowest = rates[i].low;
   }
   return lowest;
}

//+------------------------------------------------------------------+
//| Check for New Resting Level Formation                            |
//+------------------------------------------------------------------+
void CheckForNewRestingLevel()
{
   if(DIRECTION == "NONE")
      return;
   
   // Reset last_trade_sl_level if DIRECTION type changed (e.g., from LONG_BREAK to SHORT_REJECT)
   if(DIRECTION != last_executed_direction)
   {
      last_trade_sl_level = 0;
      Print("DIRECTION changed from ", last_executed_direction, " to ", DIRECTION, " - Reset last_trade_sl_level");
   }
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 30, rates);
   if(copied < 30)
      return;
   
   // Detect actual consolidation patterns
   double new_resting_level = 0;
   bool consolidation_detected = false;
   
   if(DIRECTION == "LONG_BREAK")
   {
      // Look for pullback pattern: price should have gone down then back up
      // Find the lowest low in recent candles (last 10-20 candles)
      double recent_low = rates[1].low;
      for(int i = 2; i < 20; i++)
      {
         if(rates[i].low < recent_low)
            recent_low = rates[i].low;
      }
      
      // Only valid if this low is HIGHER than the last trade SL (higher low = valid pullback)
      if(last_trade_sl_level == 0 || recent_low > last_trade_sl_level + _Point * 10)
      {
         new_resting_level = recent_low;
         consolidation_detected = true;
         BreakRestingLOW = recent_low;
      }
   }
   else if(DIRECTION == "SHORT_BREAK")
   {
      // Look for bounce pattern: price should have gone up then back down
      // Find the highest high in recent candles (last 10-20 candles)
      double recent_high = rates[1].high;
      for(int i = 2; i < 20; i++)
      {
         if(rates[i].high > recent_high)
            recent_high = rates[i].high;
      }
      
      // Only valid if this high is LOWER than the last trade SL (lower high = valid bounce)
      if(last_trade_sl_level == 0 || recent_high < last_trade_sl_level - _Point * 10)
      {
         new_resting_level = recent_high;
         consolidation_detected = true;
         BreakRestingHIGH = recent_high;
      }
   }
   else if(DIRECTION == "LONG_REJECT")
   {
      double recent_low = rates[1].low;
      for(int i = 2; i < 20; i++)
      {
         if(rates[i].low < recent_low)
            recent_low = rates[i].low;
      }
      
      if(recent_low > PrevLOW && (last_trade_sl_level == 0 || recent_low > last_trade_sl_level + _Point * 10))
      {
         new_resting_level = recent_low;
         consolidation_detected = true;
         RejectRestingLOW = recent_low;
      }
   }
   else if(DIRECTION == "SHORT_REJECT")
   {
      double recent_high = rates[1].high;
      for(int i = 2; i < 20; i++)
      {
         if(rates[i].high > recent_high)
            recent_high = rates[i].high;
      }
      
      if(recent_high < PrevHIGH && (last_trade_sl_level == 0 || recent_high < last_trade_sl_level - _Point * 10))
      {
         new_resting_level = recent_high;
         consolidation_detected = true;
         RejectRestingHIGH = recent_high;
      }
   }
   
   // Only set waiting_for_continuation if we detected a valid NEW consolidation
   if(consolidation_detected)
   {
      if(last_trade_sl_level == 0)
      {
         waiting_for_continuation = true;
         Print("Initial resting level detected for ", DIRECTION, " at ", new_resting_level);
      }
      else
      {
         waiting_for_continuation = true;
         Print("NEW consolidation batch detected for ", DIRECTION, " - Old SL: ", last_trade_sl_level, " New SL: ", new_resting_level);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for Continuation Trade Signal                              |
//+------------------------------------------------------------------+
void CheckForContinuationTrade()
{
   if(!waiting_for_continuation || DIRECTION == "NONE")
      return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 5, rates);
   if(copied < 5)
      return;
   
   // Check for continuation candle
   bool continuation_candle = false;
   
   static datetime last_candle_check = 0;
   if(rates[1].time == last_candle_check)
      return; // Already checked this candle
   last_candle_check = rates[1].time;
   
   if(DIRECTION == "LONG_BREAK" || DIRECTION == "LONG_REJECT")
   {
      // Wait for bullish candle after pullback
      if(rates[1].close > rates[1].open)
      {
         continuation_candle = true;
         Print("Bullish continuation candle detected for ", DIRECTION, " at ", rates[1].time);
      }
   }
   else if(DIRECTION == "SHORT_BREAK" || DIRECTION == "SHORT_REJECT")
   {
      // Wait for bearish candle after bounce
      if(rates[1].close < rates[1].open)
      {
         continuation_candle = true;
         Print("Bearish continuation candle detected for ", DIRECTION, " at ", rates[1].time);
      }
   }
   
   // If continuation candle found, check EMA and execute trade
   if(continuation_candle)
   {
      if(CheckEMAConditions())
      {
         ExecuteTrade();
         waiting_for_continuation = false;
      }
      else
      {
         Print("Continuation candle found but EMA conditions not met. Waiting...");
      }
   }
}

//+------------------------------------------------------------------+
//| Check EMA Conditions Based on Direction                          |
//+------------------------------------------------------------------+
bool CheckEMAConditions()
{
   if(ArraySize(ema_fast_buffer) < 2 || ArraySize(ema_slow_buffer) < 2)
   {
      Print("Not enough EMA data for comparison");
      return false;
   }
   
   double ema_fast_current = ema_fast_buffer[0];
   double ema_slow_current = ema_slow_buffer[0];
   double ema_fast_prev = ema_fast_buffer[1];
   double ema_slow_prev = ema_slow_buffer[1];
   
   bool ema_fast_rising = ema_fast_current > ema_fast_prev;
   bool ema_slow_rising = ema_slow_current > ema_slow_prev;
   
   // For LONG trades: EMA10 must be above EMA20 AND both rising
   if(DIRECTION == "LONG_BREAK" || DIRECTION == "LONG_REJECT")
   {
      if(ema_fast_current > ema_slow_current && ema_fast_rising && ema_slow_rising)
      {
         Print("EMA conditions met for ", DIRECTION, " - EMA10 above EMA20, both rising");
         return true;
      }
      else
      {
         Print("EMA conditions NOT met for ", DIRECTION, 
               " - EMA10>EMA20: ", (ema_fast_current > ema_slow_current),
               ", EMA10 rising: ", ema_fast_rising,
               ", EMA20 rising: ", ema_slow_rising);
         return false;
      }
   }
   
   // For SHORT trades: EMA10 must be below EMA20 AND both falling
   if(DIRECTION == "SHORT_BREAK" || DIRECTION == "SHORT_REJECT")
   {
      if(ema_fast_current < ema_slow_current && !ema_fast_rising && !ema_slow_rising)
      {
         Print("EMA conditions met for ", DIRECTION, " - EMA10 below EMA20, both falling");
         return true;
      }
      else
      {
         Print("EMA conditions NOT met for ", DIRECTION,
               " - EMA10<EMA20: ", (ema_fast_current < ema_slow_current),
               ", EMA10 falling: ", !ema_fast_rising,
               ", EMA20 falling: ", !ema_slow_rising);
         return false;
      }
   }
   
   return false;
}



//+------------------------------------------------------------------+
//| Execute Trade Based on Direction                                 |
//+------------------------------------------------------------------+
void ExecuteTrade()
{
   double sl_price = 0;
   double tp_price = 0;
   double lot_size = 0;
   bool is_buy = false;
   string comment = "";
   
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(DIRECTION == "LONG_BREAK")
   {
      is_buy = true;
      
      // SL: Choose closest safe level between PrevHIGH and BreakRestingLOW
      if(BreakRestingLOW > PrevHIGH)
         sl_price = BreakRestingLOW;
      else
         sl_price = PrevHIGH;
         
      comment = "LONG_BREAK";
   }
   else if(DIRECTION == "SHORT_BREAK")
   {
      is_buy = false;
      current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // SL: Choose closest safe level between PrevLOW and BreakRestingHIGH
      if(BreakRestingHIGH < PrevLOW)
         sl_price = BreakRestingHIGH;
      else
         sl_price = PrevLOW;
         
      comment = "SHORT_BREAK";
   }
   else if(DIRECTION == "LONG_REJECT")
   {
      is_buy = true;
      
      // SL: Choose the best from RejectBreakLOW, RejectRestingLOW, or PrevLOW
      double distance_to_prev = current_price - PrevLOW;
      double reasonable_distance = 200 * _Point; // 20 pips
      
      if(distance_to_prev < reasonable_distance)
         sl_price = PrevLOW;
      else if(RejectRestingLOW > 0)
         sl_price = RejectRestingLOW;
      else
         sl_price = RejectBreakLOW;
         
      comment = "LONG_REJECT";
   }
   else if(DIRECTION == "SHORT_REJECT")
   {
      is_buy = false;
      current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // SL: Choose the best from RejectBreakHIGH, RejectRestingHIGH, or PrevHIGH
      double distance_to_prev = PrevHIGH - current_price;
      double reasonable_distance = 200 * _Point; // 20 pips
      
      if(distance_to_prev < reasonable_distance)
         sl_price = PrevHIGH;
      else if(RejectRestingHIGH > 0)
         sl_price = RejectRestingHIGH;
      else
         sl_price = RejectBreakHIGH;
         
      comment = "SHORT_REJECT";
   }
   else
   {
      return;
   }
   
   double sl_distance = MathAbs(current_price - sl_price);
   double sl_points = sl_distance / _Point;
   
   // Calculate lot size based on risk
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (risk_percentage / 100.0);
   
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(sl_points > 0 && tick_value > 0)
   {
      lot_size = risk_amount / (sl_points * tick_value);
      
      double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      lot_size = MathFloor(lot_size / lot_step) * lot_step;
      
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(lot_size < min_lot) lot_size = min_lot;
      if(lot_size > max_lot) lot_size = max_lot;
   }
   else
   {
      Print("Invalid SL calculation");
      return;
   }
   
   // Calculate TP based on R:R ratio
   double tp_distance = sl_distance * rr_ratio;
   
   if(is_buy)
   {
      tp_price = current_price + tp_distance;
   }
   else
   {
      tp_price = current_price - tp_distance;
   }
   
   Print("=== Trade Execution ===");
   Print("Direction: ", DIRECTION);
   Print("Entry: ", current_price);
   Print("SL: ", sl_price, " (", sl_points, " points)");
   Print("TP: ", tp_price);
   Print("Risk Amount: $", risk_amount);
   Print("Lot Size: ", lot_size);
   Print("======================");
   
   bool result = false;
   if(is_buy)
   {
      result = trade.Buy(lot_size, _Symbol, current_price, sl_price, tp_price, comment);
   }
   else
   {
      result = trade.Sell(lot_size, _Symbol, current_price, sl_price, tp_price, comment);
   }
   
   if(result)
   {
      last_executed_direction = DIRECTION;
      last_trade_sl_level = sl_price;
      current_position_ticket = trade.ResultOrder();
      Print("Trade executed successfully. Ticket: ", current_position_ticket, " | Direction: ", DIRECTION, " | SL: ", sl_price);
   }
   else
   {
      Print("Trade failed. Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Draw Range Lines                                                  |
//+------------------------------------------------------------------+
void DrawRangeLines()
{
   if(PrevHIGH > 0)
   {
      ObjectDelete(0, "PrevHIGH_Line");
      ObjectCreate(0, "PrevHIGH_Line", OBJ_HLINE, 0, 0, PrevHIGH);
      ObjectSetInteger(0, "PrevHIGH_Line", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "PrevHIGH_Line", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "PrevHIGH_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "PrevHIGH_Line", OBJPROP_TEXT, "Prev HIGH");
   }
   
   if(PrevLOW > 0)
   {
      ObjectDelete(0, "PrevLOW_Line");
      ObjectCreate(0, "PrevLOW_Line", OBJ_HLINE, 0, 0, PrevLOW);
      ObjectSetInteger(0, "PrevLOW_Line", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, "PrevLOW_Line", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "PrevLOW_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "PrevLOW_Line", OBJPROP_TEXT, "Prev LOW");
   }
   
   // Draw vertical line at previous day 00:00
   MqlDateTime dt;
   TimeToStruct(current_day, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime prev_day_midnight = StructToTime(dt) - 86400; // Subtract 24 hours
   
   ObjectDelete(0, "PrevDay_00_Line");
   ObjectCreate(0, "PrevDay_00_Line", OBJ_VLINE, 0, prev_day_midnight, 0);
   ObjectSetInteger(0, "PrevDay_00_Line", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "PrevDay_00_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "PrevDay_00_Line", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "PrevDay_00_Line", OBJPROP_TEXT, "Previous Day 00:00");
   
   // Draw vertical line at current day 00:00
   datetime current_day_midnight = StructToTime(dt);
   
   ObjectDelete(0, "CurrentDay_00_Line");
   ObjectCreate(0, "CurrentDay_00_Line", OBJ_VLINE, 0, current_day_midnight, 0);
   ObjectSetInteger(0, "CurrentDay_00_Line", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "CurrentDay_00_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "CurrentDay_00_Line", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "CurrentDay_00_Line", OBJPROP_TEXT, "Current Day 00:00");
}
//+------------------------------------------------------------------+
