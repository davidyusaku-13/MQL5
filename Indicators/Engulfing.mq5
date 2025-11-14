//+------------------------------------------------------------------+
//|                                                    Engulfing.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot Bullish Engulfing
#property indicator_label1  "Bullish Engulfing"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot Bearish Engulfing
#property indicator_label2  "Bearish Engulfing"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Input parameters
input int ArrowOffset = 10;  // Arrow offset in points from high/low
input bool ShowAlerts = true; // Show alerts when pattern detected

//--- Indicator buffers
double BullishBuffer[];
double BearishBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, BullishBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishBuffer, INDICATOR_DATA);

   //--- Set arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down arrow

   //--- Set empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   //--- Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "Engulfing Patterns");

   //--- Set digits
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check if we have enough bars
   if(rates_total < 2)
      return(0);

   //--- Set array as series
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(BullishBuffer, true);
   ArraySetAsSeries(BearishBuffer, true);

   //--- Calculate start position
   int start;
   if(prev_calculated == 0)
      start = 1; // Start from bar 1 (we need bar 0 and 1 for comparison)
   else
      start = prev_calculated - 1;

   //--- Main calculation loop
   for(int i = start; i < rates_total - 1 && !IsStopped(); i++)
   {
      //--- Initialize buffers
      BullishBuffer[i] = 0.0;
      BearishBuffer[i] = 0.0;

      //--- Current candle (i) and previous candle (i+1)
      double curr_open = open[i];
      double curr_close = close[i];
      double curr_high = high[i];
      double curr_low = low[i];

      double prev_open = open[i+1];
      double prev_close = close[i+1];
      double prev_high = high[i+1];
      double prev_low = low[i+1];

      //--- Check for Bullish Engulfing Pattern
      // Previous candle is bearish (close < open)
      // Current candle is bullish (close > open)
      // Current candle's body engulfs previous candle's body
      if(prev_close < prev_open && // Previous candle is bearish
         curr_close > curr_open && // Current candle is bullish
         curr_open < prev_close &&  // Current open is below previous close
         curr_close > prev_open)    // Current close is above previous open
      {
         BullishBuffer[i] = curr_low - (ArrowOffset * _Point);

         // Alert only on the most recent completed bar
         if(ShowAlerts && i == 1)
         {
            Alert("Bullish Engulfing detected on ", _Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period), " at ", TimeToString(time[i]));
         }
      }

      //--- Check for Bearish Engulfing Pattern
      // Previous candle is bullish (close > open)
      // Current candle is bearish (close < open)
      // Current candle's body engulfs previous candle's body
      if(prev_close > prev_open && // Previous candle is bullish
         curr_close < curr_open && // Current candle is bearish
         curr_open > prev_close &&  // Current open is above previous close
         curr_close < prev_open)    // Current close is below previous open
      {
         BearishBuffer[i] = curr_high + (ArrowOffset * _Point);

         // Alert only on the most recent completed bar
         if(ShowAlerts && i == 1)
         {
            Alert("Bearish Engulfing detected on ", _Symbol, " ", EnumToString((ENUM_TIMEFRAMES)_Period), " at ", TimeToString(time[i]));
         }
      }
   }

   //--- Return value of prev_calculated for next call
   return(rates_total);
}
//+------------------------------------------------------------------+
