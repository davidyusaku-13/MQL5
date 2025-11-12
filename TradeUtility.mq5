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
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input int FontSize = 10;                    // Font size for all UI elements
input int AutoSaveIntervalSeconds = 30;     // Auto-save interval (0 = disabled)

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
   int               m_fontSize;

   // Symbol change detection and input preservation
   string            m_currentSymbol;
   string            m_savedRiskPercent;
   string            m_savedOrderType;
   string            m_savedEntryPrice;
   string            m_savedOrderCount;
   string            m_savedSL;
   string            m_savedTP1;
   string            m_savedTP2;
   string            m_savedTP3;
   string            m_savedTP4;
   string            m_savedBreakeven;

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
   string            m_persistenceFile;
   string            m_inputsFile;
   datetime          m_lastSaveTime;
   int               m_saveIntervalSeconds;

public:
                     CTradeUtilityDialog();
                    ~CTradeUtilityDialog();
   virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);
   void              SetFontSize(int fontSize) { m_fontSize = fontSize; }
   virtual void      OnTick();
   void              ReconstructSetups();
   void              CleanupCompletedSetups();
   void              SaveSetupsToDisk();
   void              LoadSetupsFromDisk();
   void              RefreshSetupsFromOrders();
   void              PeriodicSave();
   void              SaveInputValues();
   void              RestoreInputValues();
   void              SaveInputsToDisk();
   void              LoadInputsFromDisk();

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
   void              SetComboBoxFontSize(CComboBox &combobox, int fontSize);
   virtual bool      OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeUtilityDialog::CTradeUtilityDialog()
{
   m_isMarketOrder = true;
   m_orderCount = 2;
   m_fontSize = 10;
   m_setupCount = 0;
   ArrayResize(m_tradeSetups, 0);
   m_persistenceFile = "TradeUtility_Setups.csv";
   m_inputsFile = "TradeUtility_Inputs.csv";
   m_lastSaveTime = 0;
   m_saveIntervalSeconds = AutoSaveIntervalSeconds;  // From input parameter
   
   // Initialize symbol tracking (defaults - will be loaded from disk if available)
   m_currentSymbol = _Symbol;
   m_savedRiskPercent = "1.0";
   m_savedOrderType = "MARKET";
   m_savedEntryPrice = "0.00000";
   m_savedOrderCount = "2";
   m_savedSL = "0.00";
   m_savedTP1 = "0.00";
   m_savedTP2 = "0.00";
   m_savedTP3 = "0.00";
   m_savedTP4 = "0.00";
   m_savedBreakeven = "After TP1";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeUtilityDialog::~CTradeUtilityDialog()
  {
  }

//+------------------------------------------------------------------+
//| Set font size for ComboBox internal objects                      |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::SetComboBoxFontSize(CComboBox &combobox, int fontSize)
  {
   string combobox_name = combobox.Name();
   
   // Set font size for the Edit control (main text field)
   string edit_name = combobox_name + "Edit";
   ObjectSetInteger(m_chart_id, edit_name, OBJPROP_FONTSIZE, fontSize);
   
   // Note: The dropdown button (BmpButton) and ListView don't support font size changes
   // as they use bitmap images and have their own internal structure
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
   
   // Load saved inputs from disk for current symbol
   LoadInputsFromDisk();
   
   // Restore the loaded values to UI
   RestoreInputValues();
   
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
   m_lblSymbol.FontSize(m_fontSize);
   if(!Add(m_lblSymbol))
      return false;

   if(!m_edtSymbol.Create(m_chart_id, m_name+"EdtSymbol", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtSymbol.ReadOnly(true);
   m_edtSymbol.ColorBackground(C'240,240,240');
   m_edtSymbol.FontSize(m_fontSize);
   if(!Add(m_edtSymbol))
      return false;

   y += row_height;

   // Min Allowed Lot
   if(!m_lblMinLot.Create(m_chart_id, m_name+"LblMinLot", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblMinLot.Text("Min. Allowed Lot:");
   m_lblMinLot.FontSize(m_fontSize);
   if(!Add(m_lblMinLot))
      return false;

   if(!m_edtMinLot.Create(m_chart_id, m_name+"EdtMinLot", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtMinLot.ReadOnly(true);
   m_edtMinLot.ColorBackground(C'240,240,240');
   m_edtMinLot.FontSize(m_fontSize);
   if(!Add(m_edtMinLot))
      return false;

   y += row_height;

   // Risk % of Balance
   if(!m_lblRiskPercent.Create(m_chart_id, m_name+"LblRiskPercent", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblRiskPercent.Text("Risk % of Balance:");
   m_lblRiskPercent.FontSize(m_fontSize);
   if(!Add(m_lblRiskPercent))
      return false;

   if(!m_edtRiskPercent.Create(m_chart_id, m_name+"EdtRiskPercent", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtRiskPercent.Text("1.0");
   m_edtRiskPercent.ReadOnly(false);
   m_edtRiskPercent.FontSize(m_fontSize);
   if(!Add(m_edtRiskPercent))
      return false;

   y += row_height;

   // Order Type
   if(!m_lblOrderType.Create(m_chart_id, m_name+"LblOrderType", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblOrderType.Text("Order Type:");
   m_lblOrderType.FontSize(m_fontSize);
   if(!Add(m_lblOrderType))
      return false;

   if(!m_cmbOrderType.Create(m_chart_id, m_name+"CmbOrderType", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbOrderType.ItemAdd("MARKET");
   m_cmbOrderType.ItemAdd("PENDING");
   m_cmbOrderType.Select(0);
   SetComboBoxFontSize(m_cmbOrderType, m_fontSize);
   if(!Add(m_cmbOrderType))
      return false;

   y += row_height;

   // Entry Price
   if(!m_lblEntryPrice.Create(m_chart_id, m_name+"LblEntryPrice", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblEntryPrice.Text("Entry Price:");
   m_lblEntryPrice.FontSize(m_fontSize);
   if(!Add(m_lblEntryPrice))
      return false;

   if(!m_edtEntryPrice.Create(m_chart_id, m_name+"EdtEntryPrice", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtEntryPrice.Text("0.00000");
   m_edtEntryPrice.FontSize(m_fontSize);
   if(!Add(m_edtEntryPrice))
      return false;

   y += row_height;

   // Order Count
   if(!m_lblOrderCount.Create(m_chart_id, m_name+"LblOrderCount", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblOrderCount.Text("Order Count:");
   m_lblOrderCount.FontSize(m_fontSize);
   if(!Add(m_lblOrderCount))
      return false;

   if(!m_cmbOrderCount.Create(m_chart_id, m_name+"CmbOrderCount", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbOrderCount.ItemAdd("1");
   m_cmbOrderCount.ItemAdd("2");
   m_cmbOrderCount.ItemAdd("3");
   m_cmbOrderCount.ItemAdd("4");
   m_cmbOrderCount.Select(1);
   SetComboBoxFontSize(m_cmbOrderCount, m_fontSize);
   if(!Add(m_cmbOrderCount))
      return false;

   y += row_height;

   // Lot Size
   if(!m_lblLotSize.Create(m_chart_id, m_name+"LblLotSize", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblLotSize.Text("Lot Size:");
   m_lblLotSize.FontSize(m_fontSize);
   if(!Add(m_lblLotSize))
      return false;

   if(!m_edtLotSize.Create(m_chart_id, m_name+"EdtLotSize", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtLotSize.ReadOnly(true);
   m_edtLotSize.ColorBackground(C'240,240,240');
   m_edtLotSize.Text("0.00");
   m_edtLotSize.FontSize(m_fontSize);
   if(!Add(m_edtLotSize))
      return false;

   y += row_height;

   // SL
   if(!m_lblSL.Create(m_chart_id, m_name+"LblSL", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblSL.Text("SL");
   m_lblSL.FontSize(m_fontSize);
   if(!Add(m_lblSL))
      return false;

   if(!m_lblSLValue.Create(m_chart_id, m_name+"LblSLValue", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblSLValue.Text("$0.00 (Total)");
   m_lblSLValue.Color(clrRed);
   m_lblSLValue.FontSize(m_fontSize);
   if(!Add(m_lblSLValue))
      return false;

   if(!m_edtSL.Create(m_chart_id, m_name+"EdtSL", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtSL.Text("0.00");
   m_edtSL.Color(clrRed);
   m_edtSL.FontSize(m_fontSize);
   if(!Add(m_edtSL))
      return false;

   y += row_height;

   // TP1
   if(!m_lblTP1.Create(m_chart_id, m_name+"LblTP1", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP1.Text("TP1");
   m_lblTP1.FontSize(m_fontSize);
   if(!Add(m_lblTP1))
      return false;

   if(!m_lblTP1Value.Create(m_chart_id, m_name+"LblTP1Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP1Value.Text("$0.00");
   m_lblTP1Value.Color(clrGreen);
   m_lblTP1Value.FontSize(m_fontSize);
   if(!Add(m_lblTP1Value))
      return false;

   if(!m_edtTP1.Create(m_chart_id, m_name+"EdtTP1", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP1.Text("0.00");
   m_edtTP1.Color(clrGreen);
   m_edtTP1.FontSize(m_fontSize);
   if(!Add(m_edtTP1))
      return false;

   y += row_height;

   // TP2
   if(!m_lblTP2.Create(m_chart_id, m_name+"LblTP2", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP2.Text("TP2");
   m_lblTP2.FontSize(m_fontSize);
   if(!Add(m_lblTP2))
      return false;

   if(!m_lblTP2Value.Create(m_chart_id, m_name+"LblTP2Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP2Value.Text("$0.00");
   m_lblTP2Value.Color(clrGreen);
   m_lblTP2Value.FontSize(m_fontSize);
   if(!Add(m_lblTP2Value))
      return false;

   if(!m_edtTP2.Create(m_chart_id, m_name+"EdtTP2", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP2.Text("0.00");
   m_edtTP2.Color(clrGreen);
   m_edtTP2.ReadOnly(true);
   m_edtTP2.ColorBackground(C'240,240,240');
   m_edtTP2.FontSize(m_fontSize);
   if(!Add(m_edtTP2))
      return false;

   y += row_height;

   // TP3
   if(!m_lblTP3.Create(m_chart_id, m_name+"LblTP3", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP3.Text("TP3");
   m_lblTP3.FontSize(m_fontSize);
   if(!Add(m_lblTP3))
      return false;

   if(!m_lblTP3Value.Create(m_chart_id, m_name+"LblTP3Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP3Value.Text("$0.00");
   m_lblTP3Value.Color(clrGreen);
   m_lblTP3Value.FontSize(m_fontSize);
   if(!Add(m_lblTP3Value))
      return false;

   if(!m_edtTP3.Create(m_chart_id, m_name+"EdtTP3", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP3.Text("0.00");
   m_edtTP3.Color(clrGreen);
   m_edtTP3.ReadOnly(true);
   m_edtTP3.ColorBackground(C'240,240,240');
   m_edtTP3.FontSize(m_fontSize);
   if(!Add(m_edtTP3))
      return false;

   y += row_height;

   // TP4
   if(!m_lblTP4.Create(m_chart_id, m_name+"LblTP4", m_subwin, x1, y, x1+30, y+20))
      return false;
   m_lblTP4.Text("TP4");
   m_lblTP4.FontSize(m_fontSize);
   if(!Add(m_lblTP4))
      return false;

   if(!m_lblTP4Value.Create(m_chart_id, m_name+"LblTP4Value", m_subwin, x1+35, y, x2, y+20))
      return false;
   m_lblTP4Value.Text("$0.00");
   m_lblTP4Value.Color(clrGreen);
   m_lblTP4Value.FontSize(m_fontSize);
   if(!Add(m_lblTP4Value))
      return false;

   if(!m_edtTP4.Create(m_chart_id, m_name+"EdtTP4", m_subwin, x3, y, x4, y+20))
      return false;
   m_edtTP4.Text("0.00");
   m_edtTP4.Color(clrGreen);
   m_edtTP4.ReadOnly(true);
   m_edtTP4.ColorBackground(C'240,240,240');
   m_edtTP4.FontSize(m_fontSize);
   if(!Add(m_edtTP4))
      return false;

   y += row_height;

   // Breakeven
   if(!m_lblBreakeven.Create(m_chart_id, m_name+"LblBreakeven", m_subwin, x1, y, x2, y+20))
      return false;
   m_lblBreakeven.Text("Breakeven:");
   m_lblBreakeven.FontSize(m_fontSize);
   if(!Add(m_lblBreakeven))
      return false;

   if(!m_cmbBreakeven.Create(m_chart_id, m_name+"CmbBreakeven", m_subwin, x3, y, x4, y+20))
      return false;
   m_cmbBreakeven.ItemAdd("Disabled");
   m_cmbBreakeven.ItemAdd("After TP1");
   m_cmbBreakeven.ItemAdd("After TP2");
   m_cmbBreakeven.Select(1);
   SetComboBoxFontSize(m_cmbBreakeven, m_fontSize);
   if(!Add(m_cmbBreakeven))
      return false;

   y += row_height + 10;

   // BUY Button
   if(!m_btnBuy.Create(m_chart_id, m_name+"BtnBuy", m_subwin, x1, y, 175, y+30))
      return false;
   m_btnBuy.Text("BUY NOW");
   m_btnBuy.ColorBackground(clrDodgerBlue);
   m_btnBuy.Color(clrWhite);
   m_btnBuy.FontSize(m_fontSize);
   if(!Add(m_btnBuy))
      return false;

   // SELL Button
   if(!m_btnSell.Create(m_chart_id, m_name+"BtnSell", m_subwin, 185, y, x4, y+30))
      return false;
   m_btnSell.Text("SELL NOW");
   m_btnSell.ColorBackground(clrCrimson);
   m_btnSell.Color(clrWhite);
   m_btnSell.FontSize(m_fontSize);
   if(!Add(m_btnSell))
      return false;

   y += 40;

   // Cancel All Button
   if(!m_btnCancelAll.Create(m_chart_id, m_name+"BtnCancelAll", m_subwin, x1, y, 175, y+30))
      return false;
   m_btnCancelAll.Text("Cancel All Orders");
   m_btnCancelAll.ColorBackground(C'192,192,192');
   m_btnCancelAll.Color(clrBlack);
   m_btnCancelAll.FontSize(m_fontSize);
   if(!Add(m_btnCancelAll))
      return false;

   // Close All Button
   if(!m_btnCloseAll.Create(m_chart_id, m_name+"BtnCloseAll", m_subwin, 185, y, x4, y+30))
      return false;
   m_btnCloseAll.Text("Close All Positions");
   m_btnCloseAll.ColorBackground(C'192,192,192');
   m_btnCloseAll.Color(clrBlack);
   m_btnCloseAll.FontSize(m_fontSize);
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
      // Don't reset Entry Price - preserve existing value (important for restoring saved inputs)
      // Only reset if it's truly empty/invalid
      string currentEntryPrice = m_edtEntryPrice.Text();
      if(StringLen(currentEntryPrice) == 0)
      {
         m_edtEntryPrice.Text("0.00000");
      }
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

   // Divide risk amount by order count (so total risk is split across all orders)
   double riskPerOrder = riskAmount / m_orderCount;

   // Get SL and entry prices
   double slPrice = StringToDouble(m_edtSL.Text());
   double entryPrice = StringToDouble(m_edtEntryPrice.Text());

   double lotSize = 0;
   double minLot = GetMinLot();

   // If SL is not set, use fixed ratio: minimum allowed lot per $1000 balance
   if(slPrice == 0)
   {
      lotSize = balance / 1000.0 * minLot / m_orderCount;
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
         // SL is same as entry, use minimum allowed lot per $1000 ratio
         lotSize = balance / 1000.0 * minLot / m_orderCount;
      }
      else
      {
         // Get tick value and size
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

         // Calculate lot size based on risk per order
         lotSize = riskPerOrder / (slDistance / tickSize * tickValue);
      }
   }

   // Round to symbol's lot step
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   // Apply min/max constraints
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
      m_lblSLValue.Text("$0.00 (Total)");
      m_lblTP1Value.Text("$0.00");
      m_lblTP2Value.Text("$0.00");
      m_lblTP3Value.Text("$0.00");
      m_lblTP4Value.Text("$0.00");
      return;
   }

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   // Calculate SL dollar value (TOTAL across all orders)
   double slPrice = StringToDouble(m_edtSL.Text());
   if(slPrice != 0)
   {
      double slDistance = MathAbs(entryPrice - slPrice);
      double slDollar = (slDistance / tickSize) * tickValue * lotSize * m_orderCount;
      m_lblSLValue.Text("$" + DoubleToString(slDollar, 2) + " (Total)");
   }
   else
   {
      m_lblSLValue.Text("$0.00 (Total)");
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
//| Reconstruct trade setups from existing positions                 |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::ReconstructSetups()
{
   Print("========================================");
   Print("EA INITIALIZED - Reconstructing Trade Setups");
   Print("========================================");

   // Step 1: Load from disk first (has full TP1/TP2/BE data)
   LoadSetupsFromDisk();

   int totalPositions = PositionsTotal();
   int totalOrders = OrdersTotal();
   Print("Total open positions found: ", totalPositions);
   Print("Total pending orders found: ", totalOrders);

   // Step 2: Update loaded setups with fresh data from orders/positions
   Print("Updating loaded setups with current order/position data...");
   for(int s = 0; s < m_setupCount; s++)
   {
      // Collect TP values from ALL orders with this magic number
      double tpValues[4] = {0, 0, 0, 0};  // TP1, TP2, TP3, TP4
      int tpIndex = 0;

      // Scan pending orders for TP values
      for(int j = 0; j < totalOrders; j++)
      {
         ulong ticket = OrderGetTicket(j);
         if(ticket > 0)
         {
            if(OrderGetString(ORDER_SYMBOL) == m_tradeSetups[s].symbol &&
               OrderGetInteger(ORDER_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double orderTP = OrderGetDouble(ORDER_TP);
               if(orderTP > 0 && tpIndex < 4)
               {
                  tpValues[tpIndex] = orderTP;
                  tpIndex++;
               }
            }
         }
      }

      // Scan open positions for TP values (for filled orders)
      for(int p = 0; p < totalPositions; p++)
      {
         ulong pTicket = PositionGetTicket(p);
         if(pTicket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double posTP = PositionGetDouble(POSITION_TP);
               if(posTP > 0 && tpIndex < 4)
               {
                  tpValues[tpIndex] = posTP;
                  tpIndex++;
               }
            }
         }
      }

      // Update TP values if we found any from orders/positions
      if(tpValues[0] > 0) m_tradeSetups[s].tp1 = tpValues[0];
      if(tpValues[1] > 0) m_tradeSetups[s].tp2 = tpValues[1];

      // Check if breakeven already activated by examining positions
      for(int p = 0; p < totalPositions; p++)
      {
         ulong pTicket = PositionGetTicket(p);
         if(pTicket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentSL = PositionGetDouble(POSITION_SL);

               // Check if SL is at or very close to entry (within 1 pip tolerance)
               if(currentSL > 0 && MathAbs(currentSL - entryPrice) < 0.0001)
               {
                  m_tradeSetups[s].beActivated = true;
                  break;
               }
            }
         }
      }

      if(tpValues[0] > 0 || tpValues[1] > 0)
      {
         Print("  Updated Setup #", s+1, ": ", m_tradeSetups[s].symbol,
               " TP1=", DoubleToString(m_tradeSetups[s].tp1, 5),
               " TP2=", DoubleToString(m_tradeSetups[s].tp2, 5));
      }
   }

   // Save updated setups back to disk if any were updated
   if(m_setupCount > 0)
      SaveSetupsToDisk();

   // Array to track which magic numbers we've already added (from disk or orders/positions)
   ulong processedMagicNumbers[];
   int processedCount = 0;

   // Mark all magic numbers loaded from disk as already processed
   for(int i = 0; i < m_setupCount; i++)
   {
      ArrayResize(processedMagicNumbers, processedCount + 1);
      processedMagicNumbers[processedCount] = m_tradeSetups[i].magicNumber;
      processedCount++;
   }

   // PART 1: Scan all PENDING ORDERS to find TradeUtility orders
   for(int i = 0; i < totalOrders; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         string orderComment = OrderGetString(ORDER_COMMENT);
         ulong orderMagic = OrderGetInteger(ORDER_MAGIC);
         double orderTP = OrderGetDouble(ORDER_TP);
         string orderSymbol = OrderGetString(ORDER_SYMBOL);

         // Check if this is a TradeUtility order by comment
         if(StringFind(orderComment, "TradeUtility") < 0)
            continue;  // Not a TradeUtility order

         // Check if we already processed this magic number
         bool alreadyProcessed = false;
         for(int j = 0; j < processedCount; j++)
         {
            if(processedMagicNumbers[j] == orderMagic)
            {
               alreadyProcessed = true;
               break;
            }
         }

         if(!alreadyProcessed)
         {
            // Collect TP values from ALL orders with this magic number
            double tpValues[4] = {0, 0, 0, 0};  // TP1, TP2, TP3, TP4
            int tpIndex = 0;

            for(int j = 0; j < totalOrders; j++)
            {
               ulong scanTicket = OrderGetTicket(j);
               if(scanTicket > 0)
               {
                  if(OrderGetString(ORDER_SYMBOL) == orderSymbol &&
                     OrderGetInteger(ORDER_MAGIC) == orderMagic)
                  {
                     double orderTP = OrderGetDouble(ORDER_TP);
                     if(orderTP > 0 && tpIndex < 4)
                     {
                        tpValues[tpIndex] = orderTP;
                        tpIndex++;
                     }
                  }
               }
            }

            // Create setup using ACTUAL order properties
            TradeSetup newSetup;
            newSetup.symbol = orderSymbol;  // Use actual order symbol
            newSetup.magicNumber = orderMagic;  // Use actual order magic
            newSetup.tp1 = tpValues[0];  // Use TP from first order with this magic
            newSetup.tp2 = tpValues[1];  // Use TP from second order with this magic
            newSetup.beMode = "Disabled";  // Default - actual BE mode loaded from CSV if available
            newSetup.beActivated = false;  // Pending orders can't have BE activated yet

            ArrayResize(m_tradeSetups, m_setupCount + 1);
            m_tradeSetups[m_setupCount] = newSetup;
            m_setupCount++;

            // Mark as processed (using ACTUAL magic number)
            ArrayResize(processedMagicNumbers, processedCount + 1);
            processedMagicNumbers[processedCount] = orderMagic;
            processedCount++;

            Print("  Setup #", m_setupCount, " RECONSTRUCTED (from PENDING ORDER):");
            Print("    Symbol: ", orderSymbol);
            Print("    Magic Number: ", orderMagic, " (from order properties)");
            Print("    TP1: ", DoubleToString(newSetup.tp1, 5), (newSetup.tp1 > 0 ? " (from ORDER_TP)" : " (no TP set)"));
            Print("    TP2: ", DoubleToString(newSetup.tp2, 5), (newSetup.tp2 > 0 ? " (from ORDER_TP)" : " (no TP set)"));
            Print("    Breakeven Mode: ", newSetup.beMode, " (default - loaded from CSV if saved)");
            Print("    Status: Pending (not yet filled)");
            Print("    ---");
         }
      }
   }

   // PART 2: Scan all OPEN POSITIONS to find TradeUtility positions
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posComment = PositionGetString(POSITION_COMMENT);
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         ulong posMagic = PositionGetInteger(POSITION_MAGIC);

         // Check if this is a TradeUtility position by comment
         if(StringFind(posComment, "TradeUtility") < 0)
            continue;  // Not a TradeUtility position

         // Check if we already processed this magic number
         bool alreadyProcessed = false;
         for(int j = 0; j < processedCount; j++)
         {
            if(processedMagicNumbers[j] == posMagic)
            {
               alreadyProcessed = true;
               break;
            }
         }

         if(!alreadyProcessed)
         {
            // Collect TP values from ALL positions with this magic number
            double tpValues[4] = {0, 0, 0, 0};  // TP1, TP2, TP3, TP4
            int tpIndex = 0;

            for(int p = 0; p < totalPositions; p++)
            {
               ulong scanTicket = PositionGetTicket(p);
               if(scanTicket > 0)
               {
                  if(PositionGetString(POSITION_SYMBOL) == posSymbol &&
                     PositionGetInteger(POSITION_MAGIC) == posMagic)
                  {
                     double posTP = PositionGetDouble(POSITION_TP);
                     if(posTP > 0 && tpIndex < 4)
                     {
                        tpValues[tpIndex] = posTP;
                        tpIndex++;
                     }
                  }
               }
            }

            // Create setup using ACTUAL position properties
            TradeSetup newSetup;
            newSetup.symbol = posSymbol;  // Use actual position symbol
            newSetup.magicNumber = posMagic;  // Use actual position magic
            newSetup.tp1 = tpValues[0];  // Use TP from first position with this magic
            newSetup.tp2 = tpValues[1];  // Use TP from second position with this magic
            newSetup.beMode = "Disabled";  // Default - actual BE mode loaded from CSV if available
            newSetup.beActivated = false;

            // Check if breakeven already activated by examining positions
            // If any position with this magic has SL at entry price, it's activated
            for(int p = 0; p < totalPositions; p++)
            {
               ulong pTicket = PositionGetTicket(p);
               if(pTicket > 0)
               {
                  if(PositionGetString(POSITION_SYMBOL) == posSymbol &&
                     PositionGetInteger(POSITION_MAGIC) == posMagic)
                  {
                     double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                     double currentSL = PositionGetDouble(POSITION_SL);

                     // Check if SL is at or very close to entry (within 1 pip tolerance)
                     if(currentSL > 0 && MathAbs(currentSL - entryPrice) < 0.0001)
                     {
                        newSetup.beActivated = true;
                        break;
                     }
                  }
               }
            }

            ArrayResize(m_tradeSetups, m_setupCount + 1);
            m_tradeSetups[m_setupCount] = newSetup;
            m_setupCount++;

            // Mark as processed (using ACTUAL magic number)
            ArrayResize(processedMagicNumbers, processedCount + 1);
            processedMagicNumbers[processedCount] = posMagic;
            processedCount++;

            Print("  Setup #", m_setupCount, " RECONSTRUCTED (from OPEN POSITION):");
            Print("    Symbol: ", posSymbol);
            Print("    Magic Number: ", posMagic, " (from position properties)");
            Print("    TP1: ", DoubleToString(newSetup.tp1, 5), (newSetup.tp1 > 0 ? " (from POSITION_TP)" : " (no TP set)"));
            Print("    TP2: ", DoubleToString(newSetup.tp2, 5), (newSetup.tp2 > 0 ? " (from POSITION_TP)" : " (no TP set)"));
            Print("    Breakeven Mode: ", newSetup.beMode, " (default - loaded from CSV if saved)");
            Print("    Breakeven Activated: ", (newSetup.beActivated ? "YES" : "NO"));
            Print("    ---");
         }
      }
   }

   Print("========================================");
   if(m_setupCount > 0)
   {
      Print("RECONSTRUCTION COMPLETE");
      Print("Total setups being monitored: ", m_setupCount);
      Print("Persistent monitoring is ACTIVE");
   }
   else
   {
      Print("No TradeUtility orders or positions found");
      Print("No active monitoring setups");
   }
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Remove setups that no longer have pending orders or positions   |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::CleanupCompletedSetups()
{
   if(m_setupCount == 0)
      return;

   int totalPositions = PositionsTotal();
   int totalOrders = OrdersTotal();

   // Check each setup to see if it still has pending orders or positions
   for(int s = m_setupCount - 1; s >= 0; s--)
   {
      bool hasOrders = false;
      bool hasPositions = false;

      // Check for pending orders
      for(int i = 0; i < totalOrders; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0)
         {
            if(OrderGetString(ORDER_SYMBOL) == m_tradeSetups[s].symbol &&
               OrderGetInteger(ORDER_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               hasOrders = true;
               break;
            }
         }
      }

      // Check for open positions
      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               hasPositions = true;
               break;
            }
         }
      }

      // If no orders or positions found, remove this setup
      if(!hasOrders && !hasPositions)
      {
         Print("Removing completed setup: Symbol=", m_tradeSetups[s].symbol,
               " Magic=", m_tradeSetups[s].magicNumber);

         // Shift array elements down
         for(int j = s; j < m_setupCount - 1; j++)
         {
            m_tradeSetups[j] = m_tradeSetups[j + 1];
         }

         m_setupCount--;
         ArrayResize(m_tradeSetups, m_setupCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Save trade setups to CSV file for persistence                    |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::SaveSetupsToDisk()
{
   int fileHandle = FileOpen(m_persistenceFile, FILE_WRITE|FILE_TXT|FILE_ANSI);

   if(fileHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to open persistence file for writing: ", m_persistenceFile, " Error: ", GetLastError());
      return;
   }

   // Write CSV header
   FileWriteString(fileHandle, "Symbol,MagicNumber,TP1,TP2,BEMode,BEActivated\n");

   // Write each setup
   for(int i = 0; i < m_setupCount; i++)
   {
      string line = m_tradeSetups[i].symbol + ",";
      line += IntegerToString(m_tradeSetups[i].magicNumber) + ",";
      line += DoubleToString(m_tradeSetups[i].tp1, 5) + ",";
      line += DoubleToString(m_tradeSetups[i].tp2, 5) + ",";
      line += m_tradeSetups[i].beMode + ",";
      line += IntegerToString(m_tradeSetups[i].beActivated ? 1 : 0) + "\n";

      FileWriteString(fileHandle, line);
   }

   FileClose(fileHandle);
   Print("Saved ", m_setupCount, " trade setup(s) to disk: ", m_persistenceFile);
}

//+------------------------------------------------------------------+
//| Load trade setups from CSV file                                  |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::LoadSetupsFromDisk()
{
   if(!FileIsExist(m_persistenceFile))
   {
      Print("No persistence file found - starting fresh");
      return;
   }

   int fileHandle = FileOpen(m_persistenceFile, FILE_READ|FILE_TXT|FILE_ANSI);

   if(fileHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to open persistence file for reading: ", m_persistenceFile, " Error: ", GetLastError());
      return;
   }

   Print("========================================");
   Print("LOADING TRADE SETUPS FROM DISK");
   Print("========================================");

   // Skip header line
   string header = FileReadString(fileHandle);

   // Clear existing setups
   ArrayResize(m_tradeSetups, 0);
   m_setupCount = 0;

   // Read each line
   while(!FileIsEnding(fileHandle))
   {
      string line = FileReadString(fileHandle);

      if(StringLen(line) == 0)
         continue;  // Skip empty lines

      // Parse CSV line
      string fields[];
      int fieldCount = StringSplit(line, ',', fields);

      if(fieldCount < 6)
      {
         Print("WARNING: Skipping invalid line in persistence file: ", line);
         continue;
      }

      // Create setup from parsed data
      TradeSetup setup;
      setup.symbol = fields[0];
      setup.magicNumber = (ulong)StringToInteger(fields[1]);
      setup.tp1 = StringToDouble(fields[2]);
      setup.tp2 = StringToDouble(fields[3]);
      setup.beMode = fields[4];
      setup.beActivated = (StringToInteger(fields[5]) == 1);

      // Add to array
      ArrayResize(m_tradeSetups, m_setupCount + 1);
      m_tradeSetups[m_setupCount] = setup;
      m_setupCount++;

      Print("  Setup #", m_setupCount, " LOADED FROM DISK:");
      Print("    Symbol: ", setup.symbol);
      Print("    Magic Number: ", setup.magicNumber);
      Print("    TP1: ", DoubleToString(setup.tp1, 5));
      Print("    TP2: ", DoubleToString(setup.tp2, 5));
      Print("    Breakeven Mode: ", setup.beMode);
      Print("    Breakeven Activated: ", (setup.beActivated ? "YES" : "NO"));
      Print("    ---");
   }

   FileClose(fileHandle);

   Print("========================================");
   if(m_setupCount > 0)
   {
      Print("LOAD COMPLETE");
      Print("Total setups loaded from disk: ", m_setupCount);
   }
   else
   {
      Print("No setups found in persistence file");
   }
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Refresh setup TP values from current orders/positions           |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::RefreshSetupsFromOrders()
{
   if(m_setupCount == 0)
      return;

   int totalPositions = PositionsTotal();
   int totalOrders = OrdersTotal();

   // Update each setup with fresh data from orders/positions
   for(int s = 0; s < m_setupCount; s++)
   {
      // Collect TP values from ALL orders with this magic number
      double tpValues[4] = {0, 0, 0, 0};  // TP1, TP2, TP3, TP4
      int tpIndex = 0;

      // Scan pending orders for TP values
      for(int j = 0; j < totalOrders; j++)
      {
         ulong ticket = OrderGetTicket(j);
         if(ticket > 0)
         {
            if(OrderGetString(ORDER_SYMBOL) == m_tradeSetups[s].symbol &&
               OrderGetInteger(ORDER_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double orderTP = OrderGetDouble(ORDER_TP);
               if(orderTP > 0 && tpIndex < 4)
               {
                  tpValues[tpIndex] = orderTP;
                  tpIndex++;
               }
            }
         }
      }

      // Scan open positions for TP values (for filled orders)
      for(int p = 0; p < totalPositions; p++)
      {
         ulong pTicket = PositionGetTicket(p);
         if(pTicket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double posTP = PositionGetDouble(POSITION_TP);
               if(posTP > 0 && tpIndex < 4)
               {
                  tpValues[tpIndex] = posTP;
                  tpIndex++;
               }
            }
         }
      }

      // Update TP values if we found any from orders/positions
      if(tpValues[0] > 0) m_tradeSetups[s].tp1 = tpValues[0];
      if(tpValues[1] > 0) m_tradeSetups[s].tp2 = tpValues[1];

      // Check if breakeven already activated by examining positions
      for(int p = 0; p < totalPositions; p++)
      {
         ulong pTicket = PositionGetTicket(p);
         if(pTicket > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == m_tradeSetups[s].symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_tradeSetups[s].magicNumber)
            {
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentSL = PositionGetDouble(POSITION_SL);

               // Check if SL is at or very close to entry (within 1 pip tolerance)
               if(currentSL > 0 && MathAbs(currentSL - entryPrice) < 0.0001)
               {
                  m_tradeSetups[s].beActivated = true;
                  break;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Periodic save (called from timer)                                |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::PeriodicSave()
{
   // Skip if auto-save is disabled (interval set to 0)
   if(m_saveIntervalSeconds <= 0)
      return;

   datetime currentTime = TimeCurrent();

   // Check if enough time has passed since last save
   if(currentTime - m_lastSaveTime >= m_saveIntervalSeconds)
   {
      if(m_setupCount > 0)
      {
         // Refresh TP values from orders before saving
         RefreshSetupsFromOrders();

         // Save to disk
         SaveSetupsToDisk();

         m_lastSaveTime = currentTime;
      }
   }
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

   // Save to disk immediately after adding new setup
   SaveSetupsToDisk();

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

      // Simple readable comment: "TradeUtility BTCUSD #1"
      string comment = "TradeUtility " + _Symbol + " #" + IntegerToString(i + 1);

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

   // Save to disk immediately after adding new setup
   SaveSetupsToDisk();

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

      // Simple readable comment: "TradeUtility BTCUSD #1"
      string comment = "TradeUtility " + _Symbol + " #" + IntegerToString(i + 1);

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

            // Save to disk after breakeven activation
            SaveSetupsToDisk();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Save current input values to memory                              |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::SaveInputValues()
{
   // Use .Text() method consistently for all input fields
   m_savedRiskPercent = m_edtRiskPercent.Text();
   m_savedOrderType = m_cmbOrderType.Select();
   m_savedEntryPrice = m_edtEntryPrice.Text();
   m_savedOrderCount = m_cmbOrderCount.Select();
   m_savedSL = m_edtSL.Text();
   m_savedTP1 = m_edtTP1.Text();
   m_savedTP2 = m_edtTP2.Text();
   m_savedTP3 = m_edtTP3.Text();
   m_savedTP4 = m_edtTP4.Text();
   m_savedBreakeven = m_cmbBreakeven.Select();
   
   // Save to disk immediately
   SaveInputsToDisk();
}

//+------------------------------------------------------------------+
//| Restore saved input values from memory to UI                     |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::RestoreInputValues()
{
   m_edtRiskPercent.Text(m_savedRiskPercent);
   
   // Restore order type combo box
   if(m_savedOrderType == "MARKET")
      m_cmbOrderType.Select(0);
   else
      m_cmbOrderType.Select(1);
   OnChangeOrderType();
   
   // IMPORTANT: Restore Entry Price AFTER OnChangeOrderType() 
   // OnChangeOrderType() now preserves existing values (only resets empty fields)
   m_edtEntryPrice.Text(m_savedEntryPrice);
   
   // Restore order count combo box
   if(m_savedOrderCount == "1")
      m_cmbOrderCount.Select(0);
   else if(m_savedOrderCount == "2")
      m_cmbOrderCount.Select(1);
   else if(m_savedOrderCount == "3")
      m_cmbOrderCount.Select(2);
   else if(m_savedOrderCount == "4")
      m_cmbOrderCount.Select(3);
   OnChangeOrderCount();
   
   m_edtSL.Text(m_savedSL);
   m_edtTP1.Text(m_savedTP1);
   m_edtTP2.Text(m_savedTP2);
   m_edtTP3.Text(m_savedTP3);
   m_edtTP4.Text(m_savedTP4);
   
   // Restore breakeven combo box
   if(m_savedBreakeven == "Disabled")
      m_cmbBreakeven.Select(0);
   else if(m_savedBreakeven == "After TP1")
      m_cmbBreakeven.Select(1);
   else if(m_savedBreakeven == "After TP2")
      m_cmbBreakeven.Select(2);
   
   // Recalculate lot size and dollar values after restoring
   CalculateLotSize();
   UpdateDollarValues();
}

//+------------------------------------------------------------------+
//| Save input values to disk (per symbol)                           |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::SaveInputsToDisk()
{
   // Read existing file and update only current symbol's entry
   string lines[];
   int lineCount = 0;
   bool symbolFound = false;
   
   // Read existing file if it exists
   if(FileIsExist(m_inputsFile))
   {
      int fileHandle = FileOpen(m_inputsFile, FILE_READ|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE)
      {
         // Read header
         if(!FileIsEnding(fileHandle))
         {
            ArrayResize(lines, lineCount + 1);
            lines[lineCount] = FileReadString(fileHandle);
            lineCount++;
         }
         
         // Read all data lines
         while(!FileIsEnding(fileHandle))
         {
            string line = FileReadString(fileHandle);
            if(StringLen(line) > 0)
            {
               string fields[];
               int fieldCount = StringSplit(line, ',', fields);
               
               if(fieldCount > 0 && fields[0] == m_currentSymbol)
               {
                  // Update this symbol's line
                  string newLine = m_currentSymbol + ",";
                  newLine += m_savedRiskPercent + ",";
                  newLine += m_savedOrderType + ",";
                  newLine += m_savedEntryPrice + ",";
                  newLine += m_savedOrderCount + ",";
                  newLine += m_savedSL + ",";
                  newLine += m_savedTP1 + ",";
                  newLine += m_savedTP2 + ",";
                  newLine += m_savedTP3 + ",";
                  newLine += m_savedTP4 + ",";
                  newLine += m_savedBreakeven;
                  
                  ArrayResize(lines, lineCount + 1);
                  lines[lineCount] = newLine;
                  lineCount++;
                  symbolFound = true;
               }
               else
               {
                  // Keep other symbol's lines
                  ArrayResize(lines, lineCount + 1);
                  lines[lineCount] = line;
                  lineCount++;
               }
            }
         }
         FileClose(fileHandle);
      }
   }
   else
   {
      // Create new file with header
      ArrayResize(lines, 1);
      lines[0] = "Symbol,RiskPercent,OrderType,EntryPrice,OrderCount,SL,TP1,TP2,TP3,TP4,Breakeven";
      lineCount = 1;
   }
   
   // If symbol not found, add new line
   if(!symbolFound)
   {
      string newLine = m_currentSymbol + ",";
      newLine += m_savedRiskPercent + ",";
      newLine += m_savedOrderType + ",";
      newLine += m_savedEntryPrice + ",";
      newLine += m_savedOrderCount + ",";
      newLine += m_savedSL + ",";
      newLine += m_savedTP1 + ",";
      newLine += m_savedTP2 + ",";
      newLine += m_savedTP3 + ",";
      newLine += m_savedTP4 + ",";
      newLine += m_savedBreakeven;
      
      ArrayResize(lines, lineCount + 1);
      lines[lineCount] = newLine;
      lineCount++;
   }
   
   // Write all lines back to file
   int fileHandle = FileOpen(m_inputsFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
   {
      for(int i = 0; i < lineCount; i++)
      {
         FileWriteString(fileHandle, lines[i] + "\n");
      }
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Load input values from disk (for current symbol)                 |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::LoadInputsFromDisk()
{
   // Reset to defaults first (important for new symbols with no saved data)
   m_savedRiskPercent = "1.0";
   m_savedOrderType = "MARKET";
   m_savedEntryPrice = "0.00000";
   m_savedOrderCount = "2";
   m_savedSL = "0.00";
   m_savedTP1 = "0.00";
   m_savedTP2 = "0.00";
   m_savedTP3 = "0.00";
   m_savedTP4 = "0.00";
   m_savedBreakeven = "After TP1";
   
   if(!FileIsExist(m_inputsFile))
      return;
   
   int fileHandle = FileOpen(m_inputsFile, FILE_READ|FILE_TXT|FILE_ANSI);
   if(fileHandle == INVALID_HANDLE)
      return;
   
   // Skip header
   if(!FileIsEnding(fileHandle))
      FileReadString(fileHandle);
   
   // Read all lines and find current symbol
   while(!FileIsEnding(fileHandle))
   {
      string line = FileReadString(fileHandle);
      if(StringLen(line) == 0)
         continue;
      
      string fields[];
      int fieldCount = StringSplit(line, ',', fields);
      
      if(fieldCount >= 11 && fields[0] == m_currentSymbol)
      {
         // Found saved inputs for this symbol - override defaults
         m_savedRiskPercent = fields[1];
         m_savedOrderType = fields[2];
         m_savedEntryPrice = fields[3];
         m_savedOrderCount = fields[4];
         m_savedSL = fields[5];
         m_savedTP1 = fields[6];
         m_savedTP2 = fields[7];
         m_savedTP3 = fields[8];
         m_savedTP4 = fields[9];
         m_savedBreakeven = fields[10];
         break;
      }
   }
   
   FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| OnTick - Update entry price if market order                      |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnTick()
{
   // Detect symbol change
   if(_Symbol != m_currentSymbol)
   {
      Print("Symbol changed from ", m_currentSymbol, " to ", _Symbol);
      
      // IMPORTANT: Save OLD symbol's inputs before switching
      SaveInputValues();
      
      // Update to new symbol
      m_currentSymbol = _Symbol;
      
      // Update symbol info
      UpdateSymbolInfo();
      
      // Load saved inputs from disk for new symbol (resets to defaults if not found)
      LoadInputsFromDisk();
      
      // Restore the loaded values to UI
      RestoreInputValues();
      
      // Recalculate
      CalculateLotSize();
      UpdateDollarValues();
   }
   
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
         SaveInputValues();  // Save to disk
         return true;
      }

      if(sparam == m_cmbOrderCount.Name())
      {
         OnChangeOrderCount();
         SaveInputValues();  // Save to disk
         return true;
      }
      
      if(sparam == m_cmbBreakeven.Name())
      {
         SaveInputValues();  // Save to disk
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
         SaveInputValues();  // Save to disk
         return true;
      }

      // Update dollar values when TP fields change
      if(sparam == m_edtTP1.Name() ||
         sparam == m_edtTP2.Name() ||
         sparam == m_edtTP3.Name() ||
         sparam == m_edtTP4.Name())
      {
         UpdateDollarValues();
         SaveInputValues();  // Save to disk
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
   // Set font size from input parameter
   AppWindow.SetFontSize(FontSize);

   // Create the panel (increased height to accommodate all controls)
   if(!AppWindow.Create(0, "Trade Utility Panel", 0, 20, 20, 380, 580))
      return(INIT_FAILED);

   // Run the panel
   AppWindow.Run();

   // Reconstruct trade setups from existing positions
   AppWindow.ReconstructSetups();

   // Set up a timer to update entry price every 100ms (10 times per second)
   EventSetMillisecondTimer(100);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save current input values to disk before shutdown (important for timeframe changes)
   AppWindow.SaveInputValues();
   
   // Save setups to disk before shutdown
   AppWindow.SaveSetupsToDisk();

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

   // Periodically cleanup completed setups (positions that were closed)
   AppWindow.CleanupCompletedSetups();

   // Periodic save (every 30 seconds by default)
   AppWindow.PeriodicSave();
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
