//+------------------------------------------------------------------+
//|                                                     Sessions.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

input color TokyoColor = clrTomato;
input color LondonColor = clrDodgerBlue;
input color NewYorkColor = clrDeepPink;
input int DaysBack = 30;

struct SessionTime
{
   int startHour;
   int startMinute;
   int endHour;
   int endMinute;
   string name;
   color clr;
};

SessionTime sessions[3];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   sessions[0].name = "Tokyo";
   sessions[0].startHour = 0;
   sessions[0].startMinute = 0;
   sessions[0].endHour = 9;
   sessions[0].endMinute = 0;
   sessions[0].clr = TokyoColor;
   
   sessions[1].name = "London";
   sessions[1].startHour = 8;
   sessions[1].startMinute = 0;
   sessions[1].endHour = 17;
   sessions[1].endMinute = 0;
   sessions[1].clr = LondonColor;
   
   sessions[2].name = "NewYork";
   sessions[2].startHour = 13;
   sessions[2].startMinute = 0;
   sessions[2].endHour = 22;
   sessions[2].endMinute = 0;
   sessions[2].clr = NewYorkColor;
   
   DrawSessions();
   CreateSessionLegend();
   
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
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Draw session rectangles                                          |
//+------------------------------------------------------------------+
void DrawSessions()
{
   datetime currentTime = TimeCurrent();
   datetime startDate = currentTime - DaysBack * 86400;
   
   for(int day = 0; day < DaysBack; day++)
   {
      datetime dayStart = startDate + day * 86400;
      MqlDateTime dt;
      TimeToStruct(dayStart, dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      dayStart = StructToTime(dt);
      
      for(int i = 0; i < 3; i++)
      {
         datetime sessionStart = dayStart + sessions[i].startHour * 3600 + sessions[i].startMinute * 60;
         datetime sessionEnd = dayStart + sessions[i].endHour * 3600 + sessions[i].endMinute * 60;
         
         double highPrice = 0;
         double lowPrice = DBL_MAX;
         
         int startBar = iBarShift(_Symbol, PERIOD_CURRENT, sessionStart);
         int endBar = iBarShift(_Symbol, PERIOD_CURRENT, sessionEnd);
         
         if(startBar < 0 || endBar < 0) continue;
         
         for(int bar = endBar; bar <= startBar; bar++)
         {
            double high = iHigh(_Symbol, PERIOD_CURRENT, bar);
            double low = iLow(_Symbol, PERIOD_CURRENT, bar);
            
            if(high > highPrice) highPrice = high;
            if(low < lowPrice) lowPrice = low;
         }
         
         if(highPrice > 0 && lowPrice < DBL_MAX)
         {
            string objName = sessions[i].name + "_" + TimeToString(sessionStart, TIME_DATE);
            
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, sessionStart, highPrice, sessionEnd, lowPrice);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, sessions[i].clr);
            ObjectSetInteger(0, objName, OBJPROP_FILL, true);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, sessions[i].name + " Session");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Create session legend                                            |
//+------------------------------------------------------------------+
void CreateSessionLegend()
{
   int xOffset = 10;
   int yOffset = 30;
   int lineHeight = 20;
   
   for(int i = 0; i < 3; i++)
   {
      string labelName = "SessionLegend_" + sessions[i].name;
      
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetString(0, labelName, OBJPROP_TEXT, sessions[i].name);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, sessions[i].clr);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xOffset);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yOffset + (i * lineHeight));
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Cleanup on deinit                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = ObjectsTotal(0, 0, OBJ_RECTANGLE) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_RECTANGLE);
      if(StringFind(objName, "Tokyo_") >= 0 || 
         StringFind(objName, "London_") >= 0 || 
         StringFind(objName, "NewYork_") >= 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   for(int i = ObjectsTotal(0, 0, OBJ_LABEL) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_LABEL);
      if(StringFind(objName, "SessionLegend_") >= 0)
      {
         ObjectDelete(0, objName);
      }
   }
}
//+------------------------------------------------------------------+
