//+------------------------------------------------------------------+
//|                                      Sessions.mq5                |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_NONE

// Input parameters
input color AsianSessionColor = 0xFFE6CC;      // Pastel peach
input color LondonSessionColor = 0xCCE5FF;     // Pastel blue
input color NewYorkSessionColor = 0xD4EDDA;    // Pastel mint green
input int SessionTransparency = 85;

input color AsianTextColor = 0xFF6600;         // Deep orange
input color LondonTextColor = 0x0066CC;        // Deep blue
input color NewYorkTextColor = 0x28A745;       // Deep green

// Indicator buffer
double DummyBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator buffer
   SetIndexBuffer(0, DummyBuffer, INDICATOR_DATA);

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
   // Draw session rectangles for visible bars
   DrawSessions();

   return(rates_total);
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

      // 1. Asian-only zone: 00:00 - 08:00 GMT
      DrawSessionRectangle("Asian_Only_" + TimeToString(currentDay),
                           currentDay,
                           currentDay + 8 * 3600,
                           AsianSessionColor,
                           AsianTextColor,
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
                           LondonTextColor,
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
                           NewYorkTextColor,
                           "NEW YORK");

      // Move to next day
      currentDay += 86400;
   }

   ChartRedraw();
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
      ObjectSetInteger(0, labelName, OBJPROP_BACK, true);  // Changed to true - text in background
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   }
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
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Redraw sessions on chart changes
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      DrawSessions();
   }
}

//+------------------------------------------------------------------+
//| Deinitialize                                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up all session rectangles and labels
   ObjectsDeleteAll(0, "Asian_");
   ObjectsDeleteAll(0, "London_");
   ObjectsDeleteAll(0, "NewYork_");
   ObjectsDeleteAll(0, "AsianLondon_");
   ObjectsDeleteAll(0, "LondonNY_");
   ChartRedraw();
}
//+------------------------------------------------------------------+
