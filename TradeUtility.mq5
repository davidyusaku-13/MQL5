//+------------------------------------------------------------------+
//|                                                TradeUtility.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\ComboBox.mqh>
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Custom Dialog Class                                              |
//+------------------------------------------------------------------+
class CTradeUtilityDialog : public CAppDialog
{
private:
   // Labels
   CLabel            m_lblSymbol;
   CLabel            m_lblMinLot;
   CLabel            m_lblRiskPercent;
   CLabel            m_lblOrderType;
   CLabel            m_lblEntryPrice;
   CLabel            m_lblOrderCount;
   CLabel            m_lblLotSize;
   CLabel            m_lblSL;
   CLabel            m_lblSLValue;
   CLabel            m_lblTP1;
   CLabel            m_lblTP1Value;
   CLabel            m_lblTP2;
   CLabel            m_lblTP2Value;
   CLabel            m_lblTP3;
   CLabel            m_lblTP3Value;
   CLabel            m_lblTP4;
   CLabel            m_lblTP4Value;
   CLabel            m_lblBreakeven;

   // Display fields
   CEdit             m_edtSymbol;
   CEdit             m_edtMinLot;
   CEdit             m_edtRiskPercent;
   CEdit             m_edtEntryPrice;
   CEdit             m_edtLotSize;
   CEdit             m_edtSL;
   CEdit             m_edtTP1;
   CEdit             m_edtTP2;
   CEdit             m_edtTP3;
   CEdit             m_edtTP4;

   // Dropdowns
   CComboBox         m_cmbOrderType;
   CComboBox         m_cmbOrderCount;
   CComboBox         m_cmbBreakeven;

   // Buttons
   CButton           m_btnBuy;
   CButton           m_btnSell;
   CButton           m_btnCancelAll;
   CButton           m_btnCloseAll;

   // Internal variables
   bool              m_isMarketOrder;
   int               m_orderCount;

   // Breakeven tracking structures
   struct TradeSetup
   {
      string         symbol;        // Symbol this setup belongs to
      ulong          magicNumber;
      double         tp1;
      double         tp2;
      string         beMode;        // "Disabled", "After TP1", "After TP2"
      bool           beActivated;
   };

   TradeSetup        m_tradeSetups[];
   int               m_setupCount;

public:
                     CTradeUtilityDialog();
                    ~CTradeUtilityDialog();
   virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);
   virtual void      OnTick();

protected:
   virtual bool      CreateControls();
   virtual void      OnChangeOrderType();
   virtual void      OnChangeOrderCount();
   void              UpdateButtonLabels();
   void              UpdateTPFields();
   void              UpdateSymbolInfo();
   void              CalculateLotSize();
   void              UpdateDollarValues();
   void              OnClickBuy();
   void              OnClickSell();
   void              OnClickCancelAll();
   void              OnClickCloseAll();
   void              ProcessBreakeven();
   bool              ValidatePendingPrice(bool isBuy, double entryPrice);
   double            GetMinLot();
   ulong             GetMagicNumberForSymbol(string symbol);
   virtual bool      OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeUtilityDialog::CTradeUtilityDialog()
{
   m_isMarketOrder = true;
   m_orderCount = 1;
   m_setupCount = 0;
   ArrayResize(m_tradeSetups, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeUtilityDialog::~CTradeUtilityDialog()
{
}

//+------------------------------------------------------------------+
//| Create                                                            |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
{
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;

   if(!CreateControls())
      return false;

   UpdateSymbolInfo();
   UpdateButtonLabels();
   UpdateTPFields();

   return true;
}

//+------------------------------------------------------------------+
//| Create all controls                                               |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::CreateControls()
{
   int x1 = 10, x2 = 150;
   int x3 = 160, x4 = 340;
   int y = 10;
   int row_height = 30;

   // Symbol
   if(!m_lblSymbol.Create(m_chart_id, m_name+"LblSymbol", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblSymbol.Text("Symbol:");
   if(!Add(m_lblSymbol))
      return false;

   if(!m_edtSymbol.Create(m_chart_id, m_name+"EdtSymbol", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtSymbol.ReadOnly(true);
   m_edtSymbol.ColorBackground(C'240,240,240');
   if(!Add(m_edtSymbol))
      return false;

   y += row_height;

   // Min Allowed Lot
   if(!m_lblMinLot.Create(m_chart_id, m_name+"LblMinLot", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblMinLot.Text("Min. Allowed Lot:");
   if(!Add(m_lblMinLot))
      return false;

   if(!m_edtMinLot.Create(m_chart_id, m_name+"EdtMinLot", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtMinLot.ReadOnly(true);
   m_edtMinLot.ColorBackground(C'240,240,240');
   if(!Add(m_edtMinLot))
      return false;

   y += row_height;

   // Risk % of Balance
   if(!m_lblRiskPercent.Create(m_chart_id, m_name+"LblRiskPercent", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblRiskPercent.Text("Risk % of Balance:");
   if(!Add(m_lblRiskPercent))
      return false;

   if(!m_edtRiskPercent.Create(m_chart_id, m_name+"EdtRiskPercent", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtRiskPercent.Text("1.0");
   m_edtRiskPercent.ReadOnly(false);
   if(!Add(m_edtRiskPercent))
      return false;

   y += row_height;

   // Order Type
   if(!m_lblOrderType.Create(m_chart_id, m_name+"LblOrderType", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblOrderType.Text("Order Type:");
   if(!Add(m_lblOrderType))
      return false;

   if(!m_cmbOrderType.Create(m_chart_id, m_name+"CmbOrderType", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbOrderType.ItemAdd("MARKET");
   m_cmbOrderType.ItemAdd("PENDING");
   m_cmbOrderType.Select(0);
   if(!Add(m_cmbOrderType))
      return false;

   y += row_height;

   // Entry Price
   if(!m_lblEntryPrice.Create(m_chart_id, m_name+"LblEntryPrice", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblEntryPrice.Text("Entry Price:");
   if(!Add(m_lblEntryPrice))
      return false;

   if(!m_edtEntryPrice.Create(m_chart_id, m_name+"EdtEntryPrice", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtEntryPrice.Text("0.00000");
   if(!Add(m_edtEntryPrice))
      return false;

   y += row_height;

   // Order Count
   if(!m_lblOrderCount.Create(m_chart_id, m_name+"LblOrderCount", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblOrderCount.Text("Order Count:");
   if(!Add(m_lblOrderCount))
      return false;

   if(!m_cmbOrderCount.Create(m_chart_id, m_name+"CmbOrderCount", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbOrderCount.ItemAdd("1");
   m_cmbOrderCount.ItemAdd("2");
   m_cmbOrderCount.ItemAdd("3");
   m_cmbOrderCount.ItemAdd("4");
   m_cmbOrderCount.Select(0);
   if(!Add(m_cmbOrderCount))
      return false;

   y += row_height;

   // Lot Size
   if(!m_lblLotSize.Create(m_chart_id, m_name+"LblLotSize", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblLotSize.Text("Lot Size:");
   if(!Add(m_lblLotSize))
      return false;

   if(!m_edtLotSize.Create(m_chart_id, m_name+"EdtLotSize", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtLotSize.ReadOnly(true);
   m_edtLotSize.ColorBackground(C'240,240,240');
   m_edtLotSize.Text("0.00");
   if(!Add(m_edtLotSize))
      return false;

   y += row_height;

   // SL
   if(!m_lblSL.Create(m_chart_id, m_name+"LblSL", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblSL.Text("SL");
   if(!Add(m_lblSL))
      return false;

   if(!m_lblSLValue.Create(m_chart_id, m_name+"LblSLValue", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblSLValue.Text("$0.00");
   m_lblSLValue.Color(clrRed);
   if(!Add(m_lblSLValue))
      return false;

   if(!m_edtSL.Create(m_chart_id, m_name+"EdtSL", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtSL.Text("0.00");
   m_edtSL.Color(clrRed);
   if(!Add(m_edtSL))
      return false;

   y += row_height;

   // TP1
   if(!m_lblTP1.Create(m_chart_id, m_name+"LblTP1", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP1.Text("TP1");
   if(!Add(m_lblTP1))
      return false;

   if(!m_lblTP1Value.Create(m_chart_id, m_name+"LblTP1Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP1Value.Text("$0.00");
   m_lblTP1Value.Color(clrGreen);
   if(!Add(m_lblTP1Value))
      return false;

   if(!m_edtTP1.Create(m_chart_id, m_name+"EdtTP1", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP1.Text("0.00");
   m_edtTP1.Color(clrGreen);
   if(!Add(m_edtTP1))
      return false;

   y += row_height;

   // TP2
   if(!m_lblTP2.Create(m_chart_id, m_name+"LblTP2", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP2.Text("TP2");
   if(!Add(m_lblTP2))
      return false;

   if(!m_lblTP2Value.Create(m_chart_id, m_name+"LblTP2Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP2Value.Text("$0.00");
   m_lblTP2Value.Color(clrGreen);
   if(!Add(m_lblTP2Value))
      return false;

   if(!m_edtTP2.Create(m_chart_id, m_name+"EdtTP2", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP2.Text("0.00");
   m_edtTP2.Color(clrGreen);
   m_edtTP2.ReadOnly(true);
   m_edtTP2.ColorBackground(C'240,240,240');
   if(!Add(m_edtTP2))
      return false;

   y += row_height;

   // TP3
   if(!m_lblTP3.Create(m_chart_id, m_name+"LblTP3", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP3.Text("TP3");
   if(!Add(m_lblTP3))
      return false;

   if(!m_lblTP3Value.Create(m_chart_id, m_name+"LblTP3Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP3Value.Text("$0.00");
   m_lblTP3Value.Color(clrGreen);
   if(!Add(m_lblTP3Value))
      return false;

   if(!m_edtTP3.Create(m_chart_id, m_name+"EdtTP3", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP3.Text("0.00");
   m_edtTP3.Color(clrGreen);
   m_edtTP3.ReadOnly(true);
   m_edtTP3.ColorBackground(C'240,240,240');
   if(!Add(m_edtTP3))
      return false;

   y += row_height;

   // TP4
   if(!m_lblTP4.Create(m_chart_id, m_name+"LblTP4", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP4.Text("TP4");
   if(!Add(m_lblTP4))
      return false;

   if(!m_lblTP4Value.Create(m_chart_id, m_name+"LblTP4Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP4Value.Text("$0.00");
   m_lblTP4Value.Color(clrGreen);
   if(!Add(m_lblTP4Value))
      return false;

   if(!m_edtTP4.Create(m_chart_id, m_name+"EdtTP4", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP4.Text("0.00");
   m_edtTP4.Color(clrGreen);
   m_edtTP4.ReadOnly(true);
   m_edtTP4.ColorBackground(C'240,240,240');
   if(!Add(m_edtTP4))
      return false;

   y += row_height;

   // Breakeven
   if(!m_lblBreakeven.Create(m_chart_id, m_name+"LblBreakeven", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblBreakeven.Text("Breakeven:");
   if(!Add(m_lblBreakeven))
      return false;

   if(!m_cmbBreakeven.Create(m_chart_id, m_name+"CmbBreakeven", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbBreakeven.ItemAdd("Disabled");
   m_cmbBreakeven.ItemAdd("After TP1");
   m_cmbBreakeven.ItemAdd("After TP2");
   m_cmbBreakeven.Select(0);
   if(!Add(m_cmbBreakeven))
      return false;

   y += row_height + 10;

   // BUY Button
   if(!m_btnBuy.Create(m_chart_id, m_name+"BtnBuy", m_subwin, x1, y, 175, y+30))
      return false;
   m_btnBuy.Text("BUY NOW");
   m_btnBuy.ColorBackground(clrDodgerBlue);
   m_btnBuy.Color(clrWhite);
   if(!Add(m_btnBuy))
      return false;

   // SELL Button
   if(!m_btnSell.Create(m_chart_id, m_name+"BtnSell", m_subwin, 185, y, x4, y+30))
      return false;
   m_btnSell.Text("SELL NOW");
   m_btnSell.ColorBackground(clrCrimson);
   m_btnSell.Color(clrWhite);
   if(!Add(m_btnSell))
      return false;

   y += 40;

   // Cancel All Button
   if(!m_btnCancelAll.Create(m_chart_id, m_name+"BtnCancelAll", m_subwin, x1, y, 175, y+30))
      return false;
   m_btnCancelAll.Text("Cancel All Orders");
   m_btnCancelAll.ColorBackground(C'192,192,192');
   m_btnCancelAll.Color(clrBlack);
   if(!Add(m_btnCancelAll))
      return false;

   // Close All Button
   if(!m_btnCloseAll.Create(m_chart_id, m_name+"BtnCloseAll", m_subwin, 185, y, x4, y+30))
      return false;
   m_btnCloseAll.Text("Close All Positions");
   m_btnCloseAll.ColorBackground(C'192,192,192');
   m_btnCloseAll.Color(clrBlack);
   if(!Add(m_btnCloseAll))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Update symbol information                                         |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::UpdateSymbolInfo()
{
   string symbol = _Symbol;
   m_edtSymbol.Text(symbol);

   double minLot = GetMinLot();
   m_edtMinLot.Text(DoubleToString(minLot, 2));
}

//+------------------------------------------------------------------+
//| Get minimum lot size for current symbol                          |
//+------------------------------------------------------------------+
double CTradeUtilityDialog::GetMinLot()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
}

//+------------------------------------------------------------------+
//| Update button labels based on order type                         |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::UpdateButtonLabels()
{
   if(m_isMarketOrder)
   {
      m_btnBuy.Text("BUY NOW");
      m_btnSell.Text("SELL NOW");
   }
   else
   {
      m_btnBuy.Text("BUY LIMIT");
      m_btnSell.Text("SELL LIMIT");
   }
}

//+------------------------------------------------------------------+
//| Update TP fields based on order count                            |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::UpdateTPFields()
{
   // TP2
   if(m_orderCount >= 2)
   {
      m_edtTP2.ReadOnly(false);
      m_edtTP2.ColorBackground(clrWhite);
   }
   else
   {
      m_edtTP2.ReadOnly(true);
      m_edtTP2.ColorBackground(C'240,240,240');
   }

   // TP3
   if(m_orderCount >= 3)
   {
      m_edtTP3.ReadOnly(false);
      m_edtTP3.ColorBackground(clrWhite);
   }
   else
   {
      m_edtTP3.ReadOnly(true);
      m_edtTP3.ColorBackground(C'240,240,240');
   }

   // TP4
   if(m_orderCount >= 4)
   {
      m_edtTP4.ReadOnly(false);
      m_edtTP4.ColorBackground(clrWhite);
   }
   else
   {
      m_edtTP4.ReadOnly(true);
      m_edtTP4.ColorBackground(C'240,240,240');
   }
}

//+------------------------------------------------------------------+
//| Handle order type change                                         |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnChangeOrderType()
{
   string selectedType = m_cmbOrderType.Select();
   m_isMarketOrder = (selectedType == "MARKET");

   if(m_isMarketOrder)
   {
      // Market order - entry price updates with tick, read-only
      m_edtEntryPrice.ReadOnly(true);
      m_edtEntryPrice.ColorBackground(C'240,240,240');
   }
   else
   {
      // Pending order - user can input price
      m_edtEntryPrice.ReadOnly(false);
      m_edtEntryPrice.ColorBackground(clrWhite);
      m_edtEntryPrice.Text("0.00000");
   }

   UpdateButtonLabels();
}

//+------------------------------------------------------------------+
//| Handle order count change                                        |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnChangeOrderCount()
{
   string selectedCount = m_cmbOrderCount.Select();
   m_orderCount = (int)StringToInteger(selectedCount);

   UpdateTPFields();
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk and SL                          |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::CalculateLotSize()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPercent = StringToDouble(m_edtRiskPercent.Text());
   double riskAmount = balance * riskPercent / 100.0;

   // Get SL and entry prices
   double slPrice = StringToDouble(m_edtSL.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());

   double lotSize = 0;

   // If SL is not set, use fixed ratio: 0.01 lot per $1000 balance
   if(slPrice == 0)
   {
      lotSize = balance / 1000.0 * 0.01;
   }
   else if(entryPrice == 0)
   {
      m_edtLotSize.Text("0.00");
      return;
   }
   else
   {
      // Calculate SL distance
      double slDistance = MathAbs(entryPrice - slPrice);

      if(slDistance == 0)
      {
         // SL is same as entry, use default ratio
         lotSize = balance / 1000.0 * 0.01;
      }
      else
      {
         // Get tick value and size
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

         // Calculate lot size based on risk
         lotSize = riskAmount / (slDistance / tickSize * tickValue);
      }
   }

   // Round to symbol's lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   // Apply min/max constraints
   double minLot = GetMinLot();
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   m_edtLotSize.Text(DoubleToString(lotSize, 2));
}

//+------------------------------------------------------------------+
//| Update dollar values for SL and TPs                              |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::UpdateDollarValues()
{
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double lotSize = StringToDouble(m_edtLotSize.Text());

   if(entryPrice == 0 || lotSize == 0)
   {
      m_lblSLValue.Text("$0.00");
      m_lblTP1Value.Text("$0.00");
      m_lblTP2Value.Text("$0.00");
      m_lblTP3Value.Text("$0.00");
      m_lblTP4Value.Text("$0.00");
      return;
   }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   // Calculate SL dollar value
   double slPrice = StringToDouble(m_edtSL.Text());
   if(slPrice != 0)
   {
      double slDistance = MathAbs(entryPrice - slPrice);
      double slDollar = (slDistance / tickSize) * tickValue * lotSize;
      m_lblSLValue.Text("$" + DoubleToString(slDollar, 2));
   }
   else
   {
      m_lblSLValue.Text("$0.00");
   }

   // Calculate TP1 dollar value
   double tp1Price = StringToDouble(m_edtTP1.Text());
   if(tp1Price != 0)
   {
      double tp1Distance = MathAbs(tp1Price - entryPrice);
      double tp1Dollar = (tp1Distance / tickSize) * tickValue * lotSize;
      m_lblTP1Value.Text("$" + DoubleToString(tp1Dollar, 2));
   }
   else
   {
      m_lblTP1Value.Text("$0.00");
   }

   // Calculate TP2 dollar value
   double tp2Price = StringToDouble(m_edtTP2.Text());
   if(tp2Price != 0 && m_orderCount >= 2)
   {
      double tp2Distance = MathAbs(tp2Price - entryPrice);
      double tp2Dollar = (tp2Distance / tickSize) * tickValue * lotSize;
      m_lblTP2Value.Text("$" + DoubleToString(tp2Dollar, 2));
   }
   else
   {
      m_lblTP2Value.Text("$0.00");
   }

   // Calculate TP3 dollar value
   double tp3Price = StringToDouble(m_edtTP3.Text());
   if(tp3Price != 0 && m_orderCount >= 3)
   {
      double tp3Distance = MathAbs(tp3Price - entryPrice);
      double tp3Dollar = (tp3Distance / tickSize) * tickValue * lotSize;
      m_lblTP3Value.Text("$" + DoubleToString(tp3Dollar, 2));
   }
   else
   {
      m_lblTP3Value.Text("$0.00");
   }

   // Calculate TP4 dollar value
   double tp4Price = StringToDouble(m_edtTP4.Text());
   if(tp4Price != 0 && m_orderCount >= 4)
   {
      double tp4Distance = MathAbs(tp4Price - entryPrice);
      double tp4Dollar = (tp4Distance / tickSize) * tickValue * lotSize;
      m_lblTP4Value.Text("$" + DoubleToString(tp4Dollar, 2));
   }
   else
   {
      m_lblTP4Value.Text("$0.00");
   }
}

//+------------------------------------------------------------------+
//| Generate magic number for symbol (with symbol-specific range)    |
//+------------------------------------------------------------------+
ulong CTradeUtilityDialog::GetMagicNumberForSymbol(string symbol)
{
   // Create a hash from the symbol name to get a unique identifier (0-99)
   int symbolHash = 0;
   for(int i = 0; i < StringLen(symbol); i++)
   {
      symbolHash += (int)StringGetCharacter(symbol, i);
   }
   symbolHash = symbolHash % 100;  // Limit to 0-99

   // Get current tick count (milliseconds since system start)
   // This provides much better precision than TimeLocal() (seconds)
   // allowing multiple setups per second without collision
   ulong tickCount = GetTickCount64();

   // Combine: First 2 digits = symbol hash, rest = tick count
   // This ensures different symbols have different magic number ranges
   // while guaranteeing uniqueness even for rapid consecutive setups
   // Format: [SymbolHash 00-99][TickCount milliseconds]
   ulong magicNumber = ((ulong)symbolHash * 100000000000000) + (tickCount % 100000000000000);

   return magicNumber;
}

//+------------------------------------------------------------------+
//| Validate pending order price                                     |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::ValidatePendingPrice(bool isBuy, double entryPrice)
{
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(isBuy && entryPrice >= currentPrice)
   {
      Alert("Invalid BUY LIMIT price. Entry price (", entryPrice, ") must be below current ASK (", currentPrice, ")");
      return false;
   }

   if(!isBuy && entryPrice <= currentPrice)
   {
      Alert("Invalid SELL LIMIT price. Entry price (", entryPrice, ") must be above current BID (", currentPrice, ")");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Handle BUY button click                                          |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnClickBuy()
{
   CTrade trade;

   // Get trade parameters
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double lotSize = StringToDouble(m_edtLotSize.Text());
   double slPrice = StringToDouble(m_edtSL.Text());
   double tp1Price = StringToDouble(m_edtTP1.Text());
   double tp2Price = StringToDouble(m_edtTP2.Text());
   double tp3Price = StringToDouble(m_edtTP3.Text());
   double tp4Price = StringToDouble(m_edtTP4.Text());

   // Validate lot size
   if(lotSize <= 0)
   {
      Alert("Invalid lot size. Please check your risk settings and SL.");
      return;
   }

   // For PENDING orders, validate entry price
   if(!m_isMarketOrder)
   {
      if(entryPrice <= 0)
      {
         Alert("Please enter a valid entry price for LIMIT order.");
         return;
      }

      if(!ValidatePendingPrice(true, entryPrice))
         return;
   }

   // Generate unique magic number for this trade setup (symbol-specific range)
   ulong magicNumber = GetMagicNumberForSymbol(_Symbol);

   // Store this trade setup information for breakeven tracking
   TradeSetup newSetup;
   newSetup.symbol = _Symbol;           // Store the symbol for this setup
   newSetup.magicNumber = magicNumber;
   newSetup.tp1 = tp1Price;
   newSetup.tp2 = tp2Price;
   newSetup.beMode = m_cmbBreakeven.Select();
   newSetup.beActivated = false;

   // Add to array
   ArrayResize(m_tradeSetups, m_setupCount + 1);
   m_tradeSetups[m_setupCount] = newSetup;
   m_setupCount++;

   // Set magic number for CTrade
   trade.SetExpertMagicNumber(magicNumber);

   // Place orders based on order count
   for(int i = 0; i < m_orderCount; i++)
   {
      double tpPrice = 0;

      // Assign TP based on order index
      if(i == 0 && tp1Price > 0) tpPrice = tp1Price;
      else if(i == 1 && tp2Price > 0) tpPrice = tp2Price;
      else if(i == 2 && tp3Price > 0) tpPrice = tp3Price;
      else if(i == 3 && tp4Price > 0) tpPrice = tp4Price;

      string comment = "TradeUtility #" + IntegerToString(i + 1) + " [" + _Symbol + "]";

      bool result = false;
      if(m_isMarketOrder)
      {
         // Market order - use current ASK price
         result = trade.Buy(lotSize, _Symbol, 0, slPrice, tpPrice, comment);
      }
      else
      {
         // Pending LIMIT order
         result = trade.BuyLimit(lotSize, entryPrice, _Symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, comment);
      }

      if(result)
      {
         Print("BUY Order #", i + 1, " placed successfully. Ticket: ", trade.ResultOrder());
      }
      else
      {
         Alert("Failed to place BUY order #", i + 1, ". Error: ", trade.ResultRetcodeDescription());
      }
   }

   Print("Trade execution completed. ", m_orderCount, " BUY order(s) placed.");
}

//+------------------------------------------------------------------+
//| Handle SELL button click                                         |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnClickSell()
{
   CTrade trade;

   // Get trade parameters
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());
   double lotSize = StringToDouble(m_edtLotSize.Text());
   double slPrice = StringToDouble(m_edtSL.Text());
   double tp1Price = StringToDouble(m_edtTP1.Text());
   double tp2Price = StringToDouble(m_edtTP2.Text());
   double tp3Price = StringToDouble(m_edtTP3.Text());
   double tp4Price = StringToDouble(m_edtTP4.Text());

   // Validate lot size
   if(lotSize <= 0)
   {
      Alert("Invalid lot size. Please check your risk settings and SL.");
      return;
   }

   // For PENDING orders, validate entry price
   if(!m_isMarketOrder)
   {
      if(entryPrice <= 0)
      {
         Alert("Please enter a valid entry price for LIMIT order.");
         return;
      }

      if(!ValidatePendingPrice(false, entryPrice))
         return;
   }

   // Generate unique magic number for this trade setup (symbol-specific range)
   ulong magicNumber = GetMagicNumberForSymbol(_Symbol);

   // Store this trade setup information for breakeven tracking
   TradeSetup newSetup;
   newSetup.symbol = _Symbol;           // Store the symbol for this setup
   newSetup.magicNumber = magicNumber;
   newSetup.tp1 = tp1Price;
   newSetup.tp2 = tp2Price;
   newSetup.beMode = m_cmbBreakeven.Select();
   newSetup.beActivated = false;

   // Add to array
   ArrayResize(m_tradeSetups, m_setupCount + 1);
   m_tradeSetups[m_setupCount] = newSetup;
   m_setupCount++;

   // Set magic number for CTrade
   trade.SetExpertMagicNumber(magicNumber);

   // Place orders based on order count
   for(int i = 0; i < m_orderCount; i++)
   {
      double tpPrice = 0;

      // Assign TP based on order index
      if(i == 0 && tp1Price > 0) tpPrice = tp1Price;
      else if(i == 1 && tp2Price > 0) tpPrice = tp2Price;
      else if(i == 2 && tp3Price > 0) tpPrice = tp3Price;
      else if(i == 3 && tp4Price > 0) tpPrice = tp4Price;

      string comment = "TradeUtility #" + IntegerToString(i + 1) + " [" + _Symbol + "]";

      bool result = false;
      if(m_isMarketOrder)
      {
         // Market order - use current BID price
         result = trade.Sell(lotSize, _Symbol, 0, slPrice, tpPrice, comment);
      }
      else
      {
         // Pending LIMIT order
         result = trade.SellLimit(lotSize, entryPrice, _Symbol, slPrice, tpPrice, ORDER_TIME_GTC, 0, comment);
      }

      if(result)
      {
         Print("SELL Order #", i + 1, " placed successfully. Ticket: ", trade.ResultOrder());
      }
      else
      {
         Alert("Failed to place SELL order #", i + 1, ". Error: ", trade.ResultRetcodeDescription());
      }
   }

   Print("Trade execution completed. ", m_orderCount, " SELL order(s) placed.");
}

//+------------------------------------------------------------------+
//| Handle Cancel All Orders button click                            |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnClickCancelAll()
{
   CTrade trade;
   int totalOrders = OrdersTotal();
   int canceledCount = 0;
   int failedCount = 0;

   // Loop through all pending orders for the current symbol
   for(int i = totalOrders - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         // Check if order is for current symbol
         if(OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            if(trade.OrderDelete(ticket))
            {
               canceledCount++;
               Print("Pending order canceled. Ticket: ", ticket);
            }
            else
            {
               failedCount++;
               Print("Failed to cancel order. Ticket: ", ticket, " Error: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }

   if(failedCount > 0)
   {
      Alert("Failed to cancel ", failedCount, " order(s). Check Experts log.");
   }

   Print("Cancel All completed. ", canceledCount, " pending order(s) canceled for ", _Symbol);
}

//+------------------------------------------------------------------+
//| Handle Close All Positions button click                          |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnClickCloseAll()
{
   CTrade trade;
   int totalPositions = PositionsTotal();
   int closedCount = 0;
   int failedCount = 0;

   // Loop through all open positions for the current symbol
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         // Check if position is for current symbol
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            if(trade.PositionClose(ticket))
            {
               closedCount++;
               Print("Position closed. Ticket: ", ticket);
            }
            else
            {
               failedCount++;
               Print("Failed to close position. Ticket: ", ticket, " Error: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }

   if(failedCount > 0)
   {
      Alert("Failed to close ", failedCount, " position(s). Check Experts log.");
   }

   Print("Close All completed. ", closedCount, " position(s) closed for ", _Symbol);
}

//+------------------------------------------------------------------+
//| Process Breakeven Logic for All Trade Setups (All Symbols)       |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::ProcessBreakeven()
{
   if(m_setupCount == 0)
      return;

   int totalPositions = PositionsTotal();

   // Loop through all trade setups (across all symbols)
   for(int s = 0; s < m_setupCount; s++)
   {
      // Skip if already activated or disabled
      if(m_tradeSetups[s].beActivated || m_tradeSetups[s].beMode == "Disabled")
         continue;

      // Get the TP level to check based on this setup's mode
      double tpLevel = 0;
      if(m_tradeSetups[s].beMode == "After TP1")
         tpLevel = m_tradeSetups[s].tp1;
      else if(m_tradeSetups[s].beMode == "After TP2")
         tpLevel = m_tradeSetups[s].tp2;

      // Skip if TP level is not set
      if(tpLevel == 0)
         continue;

      // Get current price for THIS setup's symbol
      double currentBid = SymbolInfoDouble(m_tradeSetups[s].symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(m_tradeSetups[s].symbol, SYMBOL_ASK);

      // Check if any position with this magic number reached TP
      bool priceReachedTP = false;

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            // Check if position belongs to this setup's symbol
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol)
            {
               ulong posMagic = PositionGetInteger(POSITION_MAGIC);

               if(posMagic == m_tradeSetups[s].magicNumber)
               {
                  // Verify this is a TradeUtility position using comment
                  string posComment = PositionGetString(POSITION_COMMENT);
                  if(StringFind(posComment, "TradeUtility") < 0)
                     continue;  // Skip if not created by this EA

                  long posType = PositionGetInteger(POSITION_TYPE);

                  // Check if price has reached TP level
                  if(posType == POSITION_TYPE_BUY && currentBid >= tpLevel)
                  {
                     priceReachedTP = true;
                     break;
                  }
                  else if(posType == POSITION_TYPE_SELL && currentAsk <= tpLevel)
                  {
                     priceReachedTP = true;
                     break;
                  }
               }
            }
         }
      }

      // If price reached TP, move all positions with this magic number to breakeven
      if(priceReachedTP)
      {
         CTrade trade;
         int movedCount = 0;

         for(int i = 0; i < totalPositions; i++)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
               // Check if position belongs to this setup's symbol
               if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol)
               {
                  ulong posMagic = PositionGetInteger(POSITION_MAGIC);

                  if(posMagic == m_tradeSetups[s].magicNumber)
                  {
                     // Verify this is a TradeUtility position using comment
                     string posComment = PositionGetString(POSITION_COMMENT);
                     if(StringFind(posComment, "TradeUtility") < 0)
                        continue;  // Skip if not created by this EA

                     double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                     double currentSL = PositionGetDouble(POSITION_SL);
                     double currentTP = PositionGetDouble(POSITION_TP);
                     long posType = PositionGetInteger(POSITION_TYPE);

                     // Only move SL if it's not already at or better than breakeven
                     bool shouldMove = false;
                     if(posType == POSITION_TYPE_BUY && (currentSL == 0 || currentSL < entryPrice))
                        shouldMove = true;
                     else if(posType == POSITION_TYPE_SELL && (currentSL == 0 || currentSL > entryPrice))
                        shouldMove = true;

                     if(shouldMove)
                     {
                        if(trade.PositionModify(ticket, entryPrice, currentTP))
                        {
                           movedCount++;
                           Print("Position moved to breakeven. Ticket: ", ticket, " Symbol: ", m_tradeSetups[s].symbol, " Magic: ", posMagic, " Entry: ", entryPrice);
                        }
                        else
                        {
                           Print("Failed to move position to breakeven. Ticket: ", ticket, " Error: ", trade.ResultRetcodeDescription());
                        }
                     }
                  }
               }
            }
         }

         if(movedCount > 0)
         {
            m_tradeSetups[s].beActivated = true;
            Print("Breakeven activated for setup #", s+1, " [", m_tradeSetups[s].symbol, "]. ", movedCount, " position(s) moved to breakeven (", m_tradeSetups[s].beMode, ", Magic: ", m_tradeSetups[s].magicNumber, ")");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick - Update entry price if market order                      |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnTick()
{
   if(m_isMarketOrder)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      m_edtEntryPrice.Text(DoubleToString(bid, digits));

      // Recalculate lot size and update dollar values for MARKET orders
      CalculateLotSize();
      UpdateDollarValues();
   }

   // Process breakeven logic
   ProcessBreakeven();
}

//+------------------------------------------------------------------+
//| Event handler                                                     |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle button clicks (Event ID 1000 for CButton controls)
   if(id == 1000)
   {
      if(sparam == m_btnBuy.Name())
      {
         OnClickBuy();
         return true;
      }

      if(sparam == m_btnSell.Name())
      {
         OnClickSell();
         return true;
      }

      if(sparam == m_btnCancelAll.Name())
      {
         OnClickCancelAll();
         return true;
      }

      if(sparam == m_btnCloseAll.Name())
      {
         OnClickCloseAll();
         return true;
      }
   }

   // Event ID 1004 = Custom control event (combo box selection)
   if(id == 1004)
   {
      if(sparam == m_cmbOrderType.Name())
      {
         OnChangeOrderType();
         return true;
      }

      if(sparam == m_cmbOrderCount.Name())
      {
         OnChangeOrderCount();
         return true;
      }
   }

   // Event ID 1 = CHARTEVENT_OBJECT_ENDEDIT (when user finishes editing a field)
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      // Recalculate lot size when Risk %, SL, or Entry Price changes
      if(sparam == m_edtRiskPercent.Name() ||
         sparam == m_edtSL.Name() ||
         sparam == m_edtEntryPrice.Name())
      {
         CalculateLotSize();
         UpdateDollarValues();
         return true;
      }

      // Update dollar values when TP fields change
      if(sparam == m_edtTP1.Name() ||
         sparam == m_edtTP2.Name() ||
         sparam == m_edtTP3.Name() ||
         sparam == m_edtTP4.Name())
      {
         UpdateDollarValues();
         return true;
      }
   }

   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTradeUtilityDialog AppWindow;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create the panel (increased height to accommodate all controls)
   if(!AppWindow.Create(0, "Trade Utility Panel", 0, 20, 20, 380, 580))
      return(INIT_FAILED);

   // Run the panel
   AppWindow.Run();

   // Set up a timer to update entry price every 100ms (10 times per second)
   EventSetMillisecondTimer(100);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Kill the timer
   EventKillTimer();

   // Destroy the panel
   AppWindow.Destroy(reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   AppWindow.OnTick();
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Update entry price and recalculate lot size periodically
   AppWindow.OnTick();
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Pass events to the panel
   AppWindow.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
