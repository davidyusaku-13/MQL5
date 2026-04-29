//+------------------------------------------------------------------+
//|                                                     BB RSI EA.mq5 |
//| Bollinger Bands mean-reversion with RSI confirmation              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

CTrade trade;

input group "=== Trade Settings ==="
input ulong           magic_number = 20260428;        // Magic Number
input bool            autolot = false;                // Use autolot based on balance
input double          base_balance = 100.0;           // Base balance for lot calculation
input double          lot = 0.01;                     // Lot size for each base_balance unit
input double          min_lot = 0.01;                 // Minimum lot size
input double          max_lot = 10.0;                 // Maximum lot size

input group "=== Signal Settings ==="
input ENUM_TIMEFRAMES signal_timeframe = PERIOD_CURRENT; // Signal timeframe
input int             bb_length = 20;                 // Bollinger Bands length
input double          bb_deviation = 2.0;             // Bollinger Bands deviation
input int             rsi_length = 14;                // RSI length
input double          rsi_oversold = 30.0;            // RSI oversold level
input double          rsi_overbought = 70.0;          // RSI overbought level

input group "=== Risk Settings ==="
input int             stop_loss_points = 0;           // Protective Stop Loss in points (0=off)
input int             take_profit_points = 0;         // Protective Take Profit in points (0=off)
input int             max_spread_points = 0;          // Maximum spread in points (0=off)
input string          trade_comment = "BB_RSI_EA";    // Trade comment

int g_bands_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
datetime g_last_signal_bar_time = 0;
ENUM_TIMEFRAMES g_signal_timeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Resolve current timeframe input                                   |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetSignalTimeframe()
{
   if(signal_timeframe == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;

   return signal_timeframe;
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
//| Clamp and normalize lot size to input and symbol limits           |
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
//| Calculate lot size                                                |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(autolot)
   {
      double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double balance_ratio = account_balance / base_balance;
      double lot_size = NormalizeLotSize(balance_ratio * lot);

      Print("Autolot calculation - Balance: ", account_balance,
            ", Base balance: ", base_balance,
            ", Balance ratio: ", balance_ratio,
            ", Base lot: ", lot,
            ", Calculated lot: ", lot_size);
      return lot_size;
   }

   return NormalizeLotSize(lot);
}

//+------------------------------------------------------------------+
//| Validate EA inputs                                                |
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

   if(bb_length < 2 || bb_deviation <= 0)
   {
      Print("Invalid Bollinger Bands inputs. bb_length must be >= 2 and bb_deviation must be > 0.");
      return false;
   }

   if(rsi_length < 2 || rsi_oversold <= 0 || rsi_overbought >= 100 || rsi_oversold >= rsi_overbought)
   {
      Print("Invalid RSI inputs. rsi_length must be >= 2 and levels must satisfy 0 < oversold < overbought < 100.");
      return false;
   }

   if(stop_loss_points < 0 || take_profit_points < 0 || max_spread_points < 0)
   {
      Print("Invalid risk inputs. stop_loss_points, take_profit_points, and max_spread_points cannot be negative.");
      return false;
   }

   if(NormalizeLotSize(lot) <= 0)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check spread filter                                               |
//+------------------------------------------------------------------+
bool IsSpreadAllowed()
{
   if(max_spread_points <= 0)
      return true;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
   {
      Print("Invalid Bid/Ask. Bid: ", bid, ", Ask: ", ask);
      return false;
   }

   double spread_points = (ask - bid) / _Point;
   if(spread_points > max_spread_points)
   {
      Print("Signal skipped. Spread ", spread_points, " points exceeds max ", max_spread_points, " points.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if position belongs to this EA                              |
//+------------------------------------------------------------------+
bool IsOurPosition()
{
   return (PositionGetInteger(POSITION_MAGIC) == (long)magic_number &&
           PositionGetString(POSITION_SYMBOL) == _Symbol);
}

//+------------------------------------------------------------------+
//| Find first position for this EA                                   |
//+------------------------------------------------------------------+
bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket <= 0)
         continue;

      if(IsOurPosition())
      {
         ticket = position_ticket;
         position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         return true;
      }
   }

   ticket = 0;
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions for this EA                                   |
//+------------------------------------------------------------------+
bool CloseOurPositions(string reason)
{
   bool all_closed = true;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket <= 0)
         continue;

      if(!IsOurPosition())
         continue;

      if(trade.PositionClose(position_ticket))
      {
         Print("Closed position #", position_ticket, ". Reason: ", reason);
      }
      else
      {
         all_closed = false;
         Print("Failed to close position #", position_ticket,
               ". Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
      }
   }

   return all_closed;
}

//+------------------------------------------------------------------+
//| Calculate protective SL/TP from current market price              |
//+------------------------------------------------------------------+
bool CalculateStops(ENUM_POSITION_TYPE position_type, double &sl, double &tp)
{
   sl = 0;
   tp = 0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_distance = MathMax(stop_level, freeze_level) * _Point;

   if(bid <= 0 || ask <= 0)
   {
      Print("Invalid Bid/Ask. Bid: ", bid, ", Ask: ", ask);
      return false;
   }

   double entry_price = (position_type == POSITION_TYPE_BUY) ? ask : bid;

   if(position_type == POSITION_TYPE_BUY)
   {
      if(stop_loss_points > 0)
      {
         sl = NormalizePrice(entry_price - stop_loss_points * _Point);
         if(sl >= bid - min_distance)
         {
            Print("Buy SL too close to market. SL: ", sl, ", Bid: ", bid,
                  ", Min distance points: ", MathMax(stop_level, freeze_level));
            return false;
         }
      }

      if(take_profit_points > 0)
      {
         tp = NormalizePrice(entry_price + take_profit_points * _Point);
         if(tp <= bid + min_distance)
         {
            Print("Buy TP too close to market. TP: ", tp, ", Bid: ", bid,
                  ", Min distance points: ", MathMax(stop_level, freeze_level));
            return false;
         }
      }
   }
   else
   {
      if(stop_loss_points > 0)
      {
         sl = NormalizePrice(entry_price + stop_loss_points * _Point);
         if(sl <= ask + min_distance)
         {
            Print("Sell SL too close to market. SL: ", sl, ", Ask: ", ask,
                  ", Min distance points: ", MathMax(stop_level, freeze_level));
            return false;
         }
      }

      if(take_profit_points > 0)
      {
         tp = NormalizePrice(entry_price - take_profit_points * _Point);
         if(tp >= ask - min_distance)
         {
            Print("Sell TP too close to market. TP: ", tp, ", Ask: ", ask,
                  ", Min distance points: ", MathMax(stop_level, freeze_level));
            return false;
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Open market trade                                                 |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_POSITION_TYPE position_type, datetime signal_time)
{
   if(!IsSpreadAllowed())
      return false;

   double lot_size = CalculateLotSize();
   if(lot_size <= 0)
   {
      Print("Signal skipped. Lot size calculation failed.");
      return false;
   }

   double sl = 0;
   double tp = 0;
   if(!CalculateStops(position_type, sl, tp))
      return false;

   trade.SetExpertMagicNumber(magic_number);

   bool success = false;
   if(position_type == POSITION_TYPE_BUY)
   {
      success = trade.Buy(lot_size, _Symbol, 0, sl, tp, trade_comment);
      if(success)
         Print("Buy opened from BB+RSI signal bar ", TimeToString(signal_time), " with lot size ", lot_size);
      else
         Print("Failed to open Buy. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
   }
   else
   {
      success = trade.Sell(lot_size, _Symbol, 0, sl, tp, trade_comment);
      if(success)
         Print("Sell opened from BB+RSI signal bar ", TimeToString(signal_time), " with lot size ", lot_size);
      else
         Print("Failed to open Sell. Error: ", trade.ResultRetcode(), ", ", trade.ResultRetcodeDescription());
   }

   return success;
}

//+------------------------------------------------------------------+
//| Copy closed-bar market and indicator data                         |
//+------------------------------------------------------------------+
bool CopySignalData(MqlRates &rates[], double &basis[], double &upper[], double &lower[], double &rsi[])
{
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(basis, true);
   ArraySetAsSeries(upper, true);
   ArraySetAsSeries(lower, true);
   ArraySetAsSeries(rsi, true);

   if(CopyRates(_Symbol, g_signal_timeframe, 0, 3, rates) != 3)
      return false;

   if(CopyBuffer(g_bands_handle, 0, 0, 3, basis) != 3)
      return false;

   if(CopyBuffer(g_bands_handle, 1, 0, 3, upper) != 3)
      return false;

   if(CopyBuffer(g_bands_handle, 2, 0, 3, lower) != 3)
      return false;

   if(CopyBuffer(g_rsi_handle, 0, 0, 3, rsi) != 3)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   g_signal_timeframe = GetSignalTimeframe();
   g_last_signal_bar_time = 0;

   trade.SetExpertMagicNumber(magic_number);

   g_bands_handle = iBands(_Symbol, g_signal_timeframe, bb_length, 0, bb_deviation, PRICE_CLOSE);
   if(g_bands_handle == INVALID_HANDLE)
   {
      Print("Failed to create Bollinger Bands handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   g_rsi_handle = iRSI(_Symbol, g_signal_timeframe, rsi_length, PRICE_CLOSE);
   if(g_rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create RSI handle. Error: ", GetLastError());
      IndicatorRelease(g_bands_handle);
      g_bands_handle = INVALID_HANDLE;
      return INIT_FAILED;
   }

   Print("BB RSI EA initialized. Symbol: ", _Symbol,
         ", Timeframe: ", EnumToString(g_signal_timeframe),
         ", BB: ", bb_length, "/", bb_deviation,
         ", RSI: ", rsi_length, " ", rsi_oversold, "/", rsi_overbought);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_bands_handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_bands_handle);
      g_bands_handle = INVALID_HANDLE;
   }

   if(g_rsi_handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_rsi_handle);
      g_rsi_handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_bands_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE)
      return;

   MqlRates rates[];
   double basis[];
   double upper[];
   double lower[];
   double rsi[];

   if(!CopySignalData(rates, basis, upper, lower, rsi))
      return;

   datetime signal_bar_time = rates[1].time;
   if(signal_bar_time <= 0 || signal_bar_time == g_last_signal_bar_time)
      return;

   g_last_signal_bar_time = signal_bar_time;

   bool buy_signal = (rates[2].close <= lower[2] &&
                      rates[1].close > lower[1] &&
                      rsi[2] <= rsi_oversold &&
                      rsi[1] > rsi_oversold);

   bool sell_signal = (rates[2].close >= upper[2] &&
                       rates[1].close < upper[1] &&
                       rsi[2] >= rsi_overbought &&
                       rsi[1] < rsi_overbought);

   bool buy_exit = (rates[2].close >= basis[2] && rates[1].close < basis[1]);
   bool sell_exit = (rates[2].close <= basis[2] && rates[1].close > basis[1]);

   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   bool has_position = SelectOurPosition(position_ticket, position_type);

   if(has_position)
   {
      if(position_type == POSITION_TYPE_BUY && (buy_exit || sell_signal))
      {
         string reason = buy_exit ? "Buy exit: close crossed below BB basis" : "Buy exit: opposite sell signal";
         CloseOurPositions(reason);
      }
      else if(position_type == POSITION_TYPE_SELL && (sell_exit || buy_signal))
      {
         string reason = sell_exit ? "Sell exit: close crossed above BB basis" : "Sell exit: opposite buy signal";
         CloseOurPositions(reason);
      }

      return;
   }

   if(buy_signal && sell_signal)
   {
      Print("Signal skipped. Buy and sell signals on same closed bar: ", TimeToString(signal_bar_time));
      return;
   }

   if(buy_signal)
   {
      Print("Buy signal. Bar: ", TimeToString(signal_bar_time),
            ", Close: ", rates[1].close,
            ", Lower BB: ", lower[1],
            ", RSI: ", rsi[1]);
      OpenTrade(POSITION_TYPE_BUY, signal_bar_time);
   }
   else if(sell_signal)
   {
      Print("Sell signal. Bar: ", TimeToString(signal_bar_time),
            ", Close: ", rates[1].close,
            ", Upper BB: ", upper[1],
            ", RSI: ", rsi[1]);
      OpenTrade(POSITION_TYPE_SELL, signal_bar_time);
   }
}
