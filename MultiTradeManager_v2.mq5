//+------------------------------------------------------------------+
//|                                      MultiTradeManager.mq5       |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "Multi-Trade Manager v2.0 - CAppDialog Framework"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Trade Parameters ==="
input ulong Magic_Number = 12345;
input double Fixed_Lot_Size = 0.04;
input bool Half_Risk = false;
input double Stop_Loss_Price = 0.0;
input double Take_Profit_Price_1 = 0.0;
input double Take_Profit_Price_2 = 0.0;

input group "=== Display Settings ==="
input int Panel_X_Position = 5;
input int Panel_Y_Position = 85;
input color Panel_Background = clrWhiteSmoke;
input color Panel_Border = clrDarkBlue;

input group "=== Safety Settings ==="
input int Max_Total_Positions = 100;
input string Trade_Comment = "MultiTrade";
input datetime Order_Expiration = D'2025.12.31 23:59:59';

//--- Constants
#define COUNT_UPDATE_THRESHOLD 1000
#define GUI_UPDATE_THRESHOLD 100

//--- Global Variable Memory Keys (persist settings across timeframe changes)
#define GV_PREFIX "MTM_" + current_symbol + "_"
#define GV_LOT_SIZE GV_PREFIX + "LotSize"
#define GV_HALF_RISK GV_PREFIX + "HalfRisk"
#define GV_OPEN_PRICE GV_PREFIX + "OpenPrice"
#define GV_SL GV_PREFIX + "SL"
#define GV_TP1 GV_PREFIX + "TP1"
#define GV_TP2 GV_PREFIX + "TP2"
#define GV_DIRECTION GV_PREFIX + "Direction"
#define GV_EXECUTION GV_PREFIX + "Execution"

//--- Control IDs (start from 100 to avoid collision with CAppDialog internal IDs)
enum
{
   ID_BTN_BUY = 100,
   ID_BTN_SELL,
   ID_BTN_MARKET,
   ID_BTN_PENDING,
   ID_BTN_EXECUTE,
   ID_BTN_CLOSE_ALL,
   ID_BTN_CANCEL_PENDING,
   ID_BTN_HALF_RISK
};

//--- Trade direction and execution type
enum TRADE_DIRECTION
{
   TRADE_BUY = 0,
   TRADE_SELL = 1
};

enum EXECUTION_TYPE
{
   EXEC_MARKET = 0,
   EXEC_PENDING = 1
};


//--- Global variables
CTrade trade;
string current_symbol;
double current_bid = 0, current_ask = 0;
int total_positions = 0;
int total_pending_orders = 0;

double last_bid = 0, last_ask = 0;
uint last_price_update = 0;
uint last_count_update = 0;
uint last_gui_update = 0;

double symbol_point;
double symbol_pip_size;
int symbol_digits;
double symbol_tick_value;
double symbol_min_lot;
double symbol_max_lot;
double symbol_lot_step;
int symbol_stops_level;

//+------------------------------------------------------------------+
//| Multi-Trade Manager Dialog Class                                 |
//+------------------------------------------------------------------+
class CMultiTradeDialog : public CAppDialog
{
public:
   // Public members needed by external functions
   CEdit m_edit_lot_size, m_edit_open_price;
   CEdit m_edit_sl, m_edit_tp1, m_edit_tp2;
   bool m_half_risk_enabled;
   TRADE_DIRECTION m_selected_direction;
   EXECUTION_TYPE m_selected_execution;

private:
   // Control members - Buttons
   CButton m_btn_buy, m_btn_sell;
   CButton m_btn_market, m_btn_pending;
   CButton m_btn_execute, m_btn_close_all, m_btn_cancel_pending;
   CButton m_btn_half_risk;


   // Control members - Labels (static text)
   CLabel m_label_title, m_label_symbol;
   CLabel m_label_lot, m_label_half_risk_label, m_label_final_lot;
   CLabel m_label_exec_type, m_label_direction;
   CLabel m_label_open_price, m_label_sl;
   CLabel m_label_tp_header, m_label_tp1, m_label_tp2;

   // Control members - Dynamic labels (display values)
   CLabel m_label_final_lot_value;
   CLabel m_label_sl_amount, m_label_tp1_amount, m_label_tp2_amount;
   CLabel m_label_status;


public:
   CMultiTradeDialog(void);
   ~CMultiTradeDialog(void);
   
   virtual bool Create(const long chart, const string name, const int subwin,
                      const int x1, const int y1, const int x2, const int y2);
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   
   void UpdateLossProfitDisplay(void);
   void UpdateFinalLotDisplay(void);
   void UpdateStatus(string status, color clr);
   void UpdateDirectionButtons(void);
   void UpdateExecutionButtons(void);
   void UpdateOpenPriceVisibility(void);
   void UpdateHalfRiskButton(void);

protected:
   bool CreateControls(void);

   void OnClickBuy(void);
   void OnClickSell(void);
   void OnClickMarket(void);
   void OnClickPending(void);
   void OnClickExecute(void);
   void OnClickCloseAll(void);
   void OnClickCancelPending(void);
   void OnClickHalfRisk(void);

   void OnChangeEdit(void);
   void UpdateOpenPriceField(void);
   
   void ExecuteTrades(void);
   void ExecuteMarketTrades(int num_trades, double lot_size, double sl_price, double &tp_prices[]);
   void ExecutePendingTrades(int num_trades, double lot_size, double open_price, double sl_price, double &tp_prices[]);
};

//--- Global dialog instance
CMultiTradeDialog g_dialog;

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMultiTradeDialog::CMultiTradeDialog(void)
{
   m_selected_direction = TRADE_BUY;
   m_selected_execution = EXEC_MARKET;
   m_half_risk_enabled = Half_Risk;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMultiTradeDialog::~CMultiTradeDialog(void)
{
}

//+------------------------------------------------------------------+
//| Create Dialog                                                     |
//+------------------------------------------------------------------+
bool CMultiTradeDialog::Create(const long chart, const string name, const int subwin,
                               const int x1, const int y1, const int x2, const int y2)
{
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return false;
   
   if(!CreateControls())
      return false;
   
   // Initialize displays
   UpdateLossProfitDisplay();
   UpdateFinalLotDisplay();
   UpdateDirectionButtons();
   UpdateExecutionButtons();
   UpdateOpenPriceVisibility();
   UpdateHalfRiskButton();

   // Set dialog to start in maximized/expanded state
   Maximize();

   return true;
}

//+------------------------------------------------------------------+
//| Create all controls                                              |
//+------------------------------------------------------------------+
bool CMultiTradeDialog::CreateControls(void)
{
   int x_base = 10, y_pos = 10;
   int edit_width = 100, edit_height = 22;
   int button_width = 75, button_height = 22;
   
   // Title
   if(!m_label_title.Create(m_chart_id, "label_title", m_subwin, x_base, y_pos, x_base + 320, y_pos + 18))
      return false;
   m_label_title.Text("Multi-Trade Manager v2.0");
   m_label_title.Color(clrDarkBlue);
   if(!Add(m_label_title))
      return false;
   y_pos += 22;
   
   // Symbol
   if(!m_label_symbol.Create(m_chart_id, "label_symbol", m_subwin, x_base, y_pos, x_base + 320, y_pos + 18))
      return false;
   m_label_symbol.Text("Symbol: " + current_symbol);
   m_label_symbol.Color(clrBlack);
   if(!Add(m_label_symbol))
      return false;
   y_pos += 28;
   
   // Lot Size
   if(!m_label_lot.Create(m_chart_id, "label_lot", m_subwin, x_base, y_pos, x_base + 55, y_pos + 18))
      return false;
   m_label_lot.Text("Lot:");
   if(!Add(m_label_lot))
      return false;
   
   if(!m_edit_lot_size.Create(m_chart_id, "edit_lot_size", m_subwin, x_base + 58, y_pos, x_base + 58 + 55, y_pos + edit_height))
      return false;
   m_edit_lot_size.Text(DoubleToString(Fixed_Lot_Size, 2));
   if(!Add(m_edit_lot_size))
      return false;
   
   // Half Risk (same row)
   if(!m_label_half_risk_label.Create(m_chart_id, "label_half_risk", m_subwin, x_base + 125, y_pos, x_base + 185, y_pos + 18))
      return false;
   m_label_half_risk_label.Text("Half Risk:");
   if(!Add(m_label_half_risk_label))
      return false;
   
   if(!m_btn_half_risk.Create(m_chart_id, "btn_half_risk", m_subwin, x_base + 188, y_pos, x_base + 188 + 55, y_pos + button_height))
      return false;
   m_btn_half_risk.Text(m_half_risk_enabled ? "YES" : "NO");
   m_btn_half_risk.Id(ID_BTN_HALF_RISK);
   if(!Add(m_btn_half_risk))
      return false;
   y_pos += 26;
   
   // Final Lot
   if(!m_label_final_lot.Create(m_chart_id, "label_final_lot", m_subwin, x_base, y_pos, x_base + 58, y_pos + 18))
      return false;
   m_label_final_lot.Text("Final Lot:");
   if(!Add(m_label_final_lot))
      return false;
   
   if(!m_label_final_lot_value.Create(m_chart_id, "label_final_lot_value", m_subwin, x_base + 60, y_pos, x_base + 150, y_pos + 18))
      return false;
   m_label_final_lot_value.Text(DoubleToString(Fixed_Lot_Size, 2));
   m_label_final_lot_value.Color(clrBlue);
   if(!Add(m_label_final_lot_value))
      return false;
   y_pos += 26;

   // Execution type
   if(!m_label_exec_type.Create(m_chart_id, "label_exec_type", m_subwin, x_base, y_pos, x_base + 65, y_pos + 18))
      return false;
   m_label_exec_type.Text("Execution:");
   if(!Add(m_label_exec_type))
      return false;
   
   if(!m_btn_market.Create(m_chart_id, "btn_market", m_subwin, x_base + 68, y_pos, x_base + 68 + button_width, y_pos + button_height))
      return false;
   m_btn_market.Text("MARKET");
   m_btn_market.Id(ID_BTN_MARKET);
   if(!Add(m_btn_market))
      return false;

   if(!m_btn_pending.Create(m_chart_id, "btn_pending", m_subwin, x_base + 68 + button_width + 5, y_pos, x_base + 68 + button_width * 2 + 5, y_pos + button_height))
      return false;
   m_btn_pending.Text("PENDING");
   m_btn_pending.Id(ID_BTN_PENDING);
   if(!Add(m_btn_pending))
      return false;
   y_pos += 26;
   
   // Direction
   if(!m_label_direction.Create(m_chart_id, "label_direction", m_subwin, x_base, y_pos, x_base + 65, y_pos + 18))
      return false;
   m_label_direction.Text("Direction:");
   if(!Add(m_label_direction))
      return false;
   
   if(!m_btn_buy.Create(m_chart_id, "btn_buy", m_subwin, x_base + 68, y_pos, x_base + 68 + button_width, y_pos + button_height))
      return false;
   m_btn_buy.Text("BUY");
   m_btn_buy.Id(ID_BTN_BUY);
   if(!Add(m_btn_buy))
      return false;

   if(!m_btn_sell.Create(m_chart_id, "btn_sell", m_subwin, x_base + 68 + button_width + 5, y_pos, x_base + 68 + button_width * 2 + 5, y_pos + button_height))
      return false;
   m_btn_sell.Text("SELL");
   m_btn_sell.Id(ID_BTN_SELL);
   if(!Add(m_btn_sell))
      return false;
   y_pos += 26;

   // Open Price
   if(!m_label_open_price.Create(m_chart_id, "label_open_price", m_subwin, x_base, y_pos, x_base + 70, y_pos + 18))
      return false;
   m_label_open_price.Text("Open Price:");
   if(!Add(m_label_open_price))
      return false;
   
   if(!m_edit_open_price.Create(m_chart_id, "edit_open_price", m_subwin, x_base + 73, y_pos, x_base + 73 + 100, y_pos + edit_height))
      return false;
   m_edit_open_price.Text("0.00000");
   if(!Add(m_edit_open_price))
      return false;
   y_pos += 26;
   
   // Stop Loss
   if(!m_label_sl.Create(m_chart_id, "label_sl", m_subwin, x_base, y_pos, x_base + 25, y_pos + 18))
      return false;
   m_label_sl.Text("SL:");
   if(!Add(m_label_sl))
      return false;
   
   if(!m_edit_sl.Create(m_chart_id, "edit_sl", m_subwin, x_base + 28, y_pos, x_base + 28 + 100, y_pos + edit_height))
      return false;
   m_edit_sl.Text(DoubleToString(Stop_Loss_Price, 5));
   if(!Add(m_edit_sl))
      return false;
   
   if(!m_label_sl_amount.Create(m_chart_id, "label_sl_amount", m_subwin, x_base + 135, y_pos, x_base + 230, y_pos + 18))
      return false;
   m_label_sl_amount.Text("($0.00)");
   m_label_sl_amount.Color(clrRed);
   if(!Add(m_label_sl_amount))
      return false;
   y_pos += 26;
   
   // TP Header
   if(!m_label_tp_header.Create(m_chart_id, "label_tp_header", m_subwin, x_base, y_pos, x_base + 320, y_pos + 18))
      return false;
   m_label_tp_header.Text("Take Profit Levels:");
   m_label_tp_header.Color(clrDarkBlue);
   if(!Add(m_label_tp_header))
      return false;
   y_pos += 22;
   
   // TP1
   if(!m_label_tp1.Create(m_chart_id, "label_tp1", m_subwin, x_base, y_pos, x_base + 35, y_pos + 18))
      return false;
   m_label_tp1.Text("TP1:");
   if(!Add(m_label_tp1))
      return false;
   
   if(!m_edit_tp1.Create(m_chart_id, "edit_tp1", m_subwin, x_base + 38, y_pos, x_base + 38 + 100, y_pos + edit_height))
      return false;
   m_edit_tp1.Text(DoubleToString(Take_Profit_Price_1, 5));
   if(!Add(m_edit_tp1))
      return false;
   
   if(!m_label_tp1_amount.Create(m_chart_id, "label_tp1_amount", m_subwin, x_base + 145, y_pos, x_base + 240, y_pos + 18))
      return false;
   m_label_tp1_amount.Text("($0.00)");
   m_label_tp1_amount.Color(clrGreen);
   if(!Add(m_label_tp1_amount))
      return false;
   y_pos += 26;
   
   // TP2
   if(!m_label_tp2.Create(m_chart_id, "label_tp2", m_subwin, x_base, y_pos, x_base + 35, y_pos + 18))
      return false;
   m_label_tp2.Text("TP2:");
   if(!Add(m_label_tp2))
      return false;
   
   if(!m_edit_tp2.Create(m_chart_id, "edit_tp2", m_subwin, x_base + 38, y_pos, x_base + 38 + 100, y_pos + edit_height))
      return false;
   m_edit_tp2.Text(DoubleToString(Take_Profit_Price_2, 5));
   if(!Add(m_edit_tp2))
      return false;
   
   if(!m_label_tp2_amount.Create(m_chart_id, "label_tp2_amount", m_subwin, x_base + 145, y_pos, x_base + 240, y_pos + 18))
      return false;
   m_label_tp2_amount.Text("($0.00)");
   m_label_tp2_amount.Color(clrGreen);
   if(!Add(m_label_tp2_amount))
      return false;
   y_pos += 32;

   // Action buttons - Row 1: EXECUTE and CLOSE ALL
   int action_button_width = 125;  // Reduced from 150
   int button_margin = 7;

   if(!m_btn_execute.Create(m_chart_id, "btn_execute", m_subwin, x_base + 5, y_pos, x_base + 5 + action_button_width, y_pos + button_height))
      return false;
   m_btn_execute.Text("EXECUTE");
   m_btn_execute.Color(clrWhite);
   m_btn_execute.ColorBackground(clrBlue);
   m_btn_execute.Id(ID_BTN_EXECUTE);
   if(!Add(m_btn_execute))
      return false;

   if(!m_btn_close_all.Create(m_chart_id, "btn_close_all", m_subwin, x_base + 5 + action_button_width + button_margin, y_pos, x_base + 5 + action_button_width + button_margin + action_button_width, y_pos + button_height))
      return false;
   m_btn_close_all.Text("CLOSE ALL");
   m_btn_close_all.Color(clrWhite);
   m_btn_close_all.ColorBackground(clrRed);
   m_btn_close_all.Id(ID_BTN_CLOSE_ALL);
   if(!Add(m_btn_close_all))
      return false;
   y_pos += 26;

   // Action buttons - Row 2: CANCEL PENDING (width = EXECUTE + margin + CLOSE ALL)
   int cancel_button_width = action_button_width + button_margin + action_button_width;

   if(!m_btn_cancel_pending.Create(m_chart_id, "btn_cancel_pending", m_subwin, x_base + 5, y_pos, x_base + 5 + cancel_button_width, y_pos + button_height))
      return false;
   m_btn_cancel_pending.Text("CANCEL PENDING");
   m_btn_cancel_pending.Color(clrWhite);
   m_btn_cancel_pending.ColorBackground(clrOrange);
   m_btn_cancel_pending.Id(ID_BTN_CANCEL_PENDING);
   if(!Add(m_btn_cancel_pending))
      return false;
   y_pos += 28;
   
   // Status
   if(!m_label_status.Create(m_chart_id, "label_status", m_subwin, x_base, y_pos, x_base + 320, y_pos + 18))
      return false;
   m_label_status.Text("Ready");
   m_label_status.Color(clrGreen);
   if(!Add(m_label_status))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Event handler                                                     |
//+------------------------------------------------------------------+
bool CMultiTradeDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle edit field changes FIRST (before base class intercepts)
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      OnChangeEdit();
      // Don't return yet - let base class handle it too for proper state management
   }

   // Handle our custom button clicks
   if(id == CHARTEVENT_CUSTOM)
   {
      if(lparam == m_btn_buy.Id())
      {
         OnClickBuy();
         return true;
      }
      if(lparam == m_btn_sell.Id())
      {
         OnClickSell();
         return true;
      }
      if(lparam == m_btn_market.Id())
      {
         OnClickMarket();
         return true;
      }
      if(lparam == m_btn_pending.Id())
      {
         OnClickPending();
         return true;
      }
      if(lparam == m_btn_execute.Id())
      {
         OnClickExecute();
         return true;
      }
      if(lparam == m_btn_close_all.Id())
      {
         OnClickCloseAll();
         return true;
      }
      if(lparam == m_btn_cancel_pending.Id())
      {
         OnClickCancelPending();
         return true;
      }
      if(lparam == m_btn_half_risk.Id())
      {
         OnClickHalfRisk();
         return true;
      }
   }

   // Call base class to handle minimize/maximize/close and other internal events
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Button click handlers                                            |
//+------------------------------------------------------------------+
void CMultiTradeDialog::OnClickBuy(void)
{
   m_selected_direction = TRADE_BUY;
   UpdateDirectionButtons();
   UpdateOpenPriceField();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickSell(void)
{
   m_selected_direction = TRADE_SELL;
   UpdateDirectionButtons();
   UpdateOpenPriceField();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickMarket(void)
{
   m_selected_execution = EXEC_MARKET;
   UpdateExecutionButtons();
   UpdateOpenPriceVisibility();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickPending(void)
{
   m_selected_execution = EXEC_PENDING;
   UpdateExecutionButtons();
   UpdateOpenPriceVisibility();
   UpdateOpenPriceField();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickExecute(void)
{
   ExecuteTrades();
}

void CMultiTradeDialog::OnClickCloseAll(void)
{
   UpdateStatus("Closing positions...", clrBlue);
   
   int closed_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == current_symbol)
      {
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         string comment = PositionGetString(POSITION_COMMENT);
         if(magic == Magic_Number && StringFind(comment, Trade_Comment) >= 0)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            if(trade.PositionClose(ticket))
               closed_count++;
         }
      }
   }
   
   if(closed_count > 0)
      UpdateStatus("Closed " + IntegerToString(closed_count) + " positions", clrGreen);
   else
      UpdateStatus("No positions found", clrOrange);
}

void CMultiTradeDialog::OnClickCancelPending(void)
{
   UpdateStatus("Canceling orders...", clrBlue);
   
   int canceled_count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i))
      {
         if(OrderGetString(ORDER_SYMBOL) == current_symbol)
         {
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            string comment = OrderGetString(ORDER_COMMENT);
            if(magic == Magic_Number && StringFind(comment, Trade_Comment) >= 0)
            {
               ulong ticket = OrderGetInteger(ORDER_TICKET);
               if(trade.OrderDelete(ticket))
                  canceled_count++;
            }
         }
      }
   }
   
   if(canceled_count > 0)
      UpdateStatus("Canceled " + IntegerToString(canceled_count) + " orders", clrGreen);
   else
      UpdateStatus("No orders found", clrOrange);
}

void CMultiTradeDialog::OnClickHalfRisk(void)
{
   m_half_risk_enabled = !m_half_risk_enabled;
   UpdateHalfRiskButton();
   UpdateFinalLotDisplay();
   UpdateLossProfitDisplay();
   SaveSettings();
}

//+------------------------------------------------------------------+
//| Edit change handler                                              |
//+------------------------------------------------------------------+
void CMultiTradeDialog::OnChangeEdit(void)
{
   UpdateFinalLotDisplay();
   UpdateLossProfitDisplay();
   SaveSettings();
}

//+------------------------------------------------------------------+
//| Update button states                                             |
//+------------------------------------------------------------------+
void CMultiTradeDialog::UpdateDirectionButtons(void)
{
   if(m_selected_direction == TRADE_BUY)
   {
      m_btn_buy.ColorBackground(clrLimeGreen);
      m_btn_sell.ColorBackground(clrWhite);
   }
   else
   {
      m_btn_buy.ColorBackground(clrWhite);
      m_btn_sell.ColorBackground(clrCrimson);
   }
}

void CMultiTradeDialog::UpdateExecutionButtons(void)
{
   if(m_selected_execution == EXEC_MARKET)
   {
      m_btn_market.ColorBackground(clrDodgerBlue);
      m_btn_pending.ColorBackground(clrWhite);
   }
   else
   {
      m_btn_market.ColorBackground(clrWhite);
      m_btn_pending.ColorBackground(clrOrange);
   }
}

void CMultiTradeDialog::UpdateHalfRiskButton(void)
{
   if(m_half_risk_enabled)
   {
      m_btn_half_risk.Text("YES");
      m_btn_half_risk.ColorBackground(clrLimeGreen);
   }
   else
   {
      m_btn_half_risk.Text("NO");
      m_btn_half_risk.ColorBackground(clrCrimson);
   }
}

void CMultiTradeDialog::UpdateOpenPriceVisibility(void)
{
   if(m_selected_execution == EXEC_MARKET)
   {
      m_label_open_price.Color(clrLightGray);
      m_edit_open_price.ReadOnly(true);
      m_edit_open_price.Text("N/A (Market)");
      m_edit_open_price.ColorBackground(clrLightGray);
   }
   else
   {
      m_label_open_price.Color(clrBlack);
      m_edit_open_price.ReadOnly(false);
      m_edit_open_price.ColorBackground(clrWhite);
      UpdateOpenPriceField();
   }
}

void CMultiTradeDialog::UpdateOpenPriceField(void)
{
   if(m_selected_execution == EXEC_PENDING)
   {
      double suggested_price = (m_selected_direction == TRADE_BUY) ? 
         current_ask - (50 * symbol_point) : current_bid + (50 * symbol_point);
      m_edit_open_price.Text(DoubleToString(suggested_price, symbol_digits));
   }
}

//+------------------------------------------------------------------+
//| Update displays                                                   |
//+------------------------------------------------------------------+
void CMultiTradeDialog::UpdateFinalLotDisplay(void)
{
   double base_lot = StringToDouble(m_edit_lot_size.Text());
   double adjusted = m_half_risk_enabled ? base_lot / 2.0 : base_lot;
   
   if(symbol_lot_step > 0)
      adjusted = MathRound(adjusted / symbol_lot_step) * symbol_lot_step;
   if(adjusted < symbol_min_lot) adjusted = symbol_min_lot;
   if(adjusted > symbol_max_lot) adjusted = symbol_max_lot;
   
   m_label_final_lot_value.Text(DoubleToString(adjusted, 2));
}

void CMultiTradeDialog::UpdateLossProfitDisplay(void)
{
   if(current_bid <= 0 || current_ask <= 0) return;
   
   double base_lot = StringToDouble(m_edit_lot_size.Text());
   double adjusted_lot = m_half_risk_enabled ? base_lot / 2.0 : base_lot;
   
   if(symbol_lot_step > 0)
      adjusted_lot = MathRound(adjusted_lot / symbol_lot_step) * symbol_lot_step;
   if(adjusted_lot < symbol_min_lot) adjusted_lot = symbol_min_lot;
   if(adjusted_lot > symbol_max_lot) adjusted_lot = symbol_max_lot;
   
   double sl_price = StringToDouble(m_edit_sl.Text());
   double reference_price;
   
   if(m_selected_execution == EXEC_PENDING)
   {
      reference_price = StringToDouble(m_edit_open_price.Text());
      if(reference_price <= 0)
         reference_price = (m_selected_direction == TRADE_BUY) ? current_ask : current_bid;
   }
   else
   {
      reference_price = (m_selected_direction == TRADE_BUY) ? current_ask : current_bid;
   }
   
   // SL amount
   if(sl_price > 0)
   {
      double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
      double ticks = MathAbs(reference_price - sl_price) / tick_size;
      double loss = adjusted_lot * ticks * tick_value;
      m_label_sl_amount.Text("($" + DoubleToString(loss, 2) + ")");
   }
   else
   {
      m_label_sl_amount.Text("($0.00)");
   }
   
   // TP amounts
   double tp_prices[2];
   tp_prices[0] = StringToDouble(m_edit_tp1.Text());
   tp_prices[1] = StringToDouble(m_edit_tp2.Text());
   
   for(int i = 0; i < 2; i++)
   {
      if(tp_prices[i] > 0)
      {
         double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
         double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
         double ticks = MathAbs(tp_prices[i] - reference_price) / tick_size;
         double profit = adjusted_lot * ticks * tick_value;
         
         if(i == 0)
            m_label_tp1_amount.Text("($" + DoubleToString(profit, 2) + ")");
         else
            m_label_tp2_amount.Text("($" + DoubleToString(profit, 2) + ")");
      }
      else
      {
         if(i == 0)
            m_label_tp1_amount.Text("($0.00)");
         else
            m_label_tp2_amount.Text("($0.00)");
      }
   }
}

void CMultiTradeDialog::UpdateStatus(string status, color clr)
{
   m_label_status.Text(status);
   m_label_status.Color(clr);
}

//+------------------------------------------------------------------+
//| Execute trades (simplified for v2)                               |
//+------------------------------------------------------------------+
void CMultiTradeDialog::ExecuteTrades(void)
{
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
   {
      UpdateStatus("Trading disabled in terminal", clrRed);
      return;
   }
   
   double base_lot = StringToDouble(m_edit_lot_size.Text());
   double adjusted_lot = m_half_risk_enabled ? base_lot / 2.0 : base_lot;

   // Normalize lot size to broker requirements
   if(symbol_lot_step > 0)
      adjusted_lot = MathRound(adjusted_lot / symbol_lot_step) * symbol_lot_step;
   if(adjusted_lot < symbol_min_lot) adjusted_lot = symbol_min_lot;
   if(adjusted_lot > symbol_max_lot) adjusted_lot = symbol_max_lot;

   if(adjusted_lot < symbol_min_lot || adjusted_lot > symbol_max_lot)
   {
      UpdateStatus("Invalid lot size", clrRed);
      return;
   }

   double tp_prices[2];
   tp_prices[0] = StringToDouble(m_edit_tp1.Text());
   tp_prices[1] = StringToDouble(m_edit_tp2.Text());

   double sl_price = StringToDouble(m_edit_sl.Text());
   double open_price = StringToDouble(m_edit_open_price.Text());

   // Hardcoded: Always open 2 trades (1 with TP1, 1 with TP2)
   int num_trades = 2;

   if(m_selected_execution == EXEC_MARKET)
   {
      ExecuteMarketTrades(num_trades, adjusted_lot, sl_price, tp_prices);
   }
   else
   {
      ExecutePendingTrades(num_trades, adjusted_lot, open_price, sl_price, tp_prices);
   }
}

void CMultiTradeDialog::ExecuteMarketTrades(int num_trades, double lot_size, double sl_price, double &tp_prices[])
{
   UpdateStatus("Executing market trades...", clrBlue);

   int successful_trades = 0;
   string risk_type = m_half_risk_enabled ? " (Half Risk)" : " (Normal Risk)";

   for(int i = 0; i < num_trades; i++)
   {
      // Get TP for this trade using improved logic
      double tp_for_trade = GetTakeProfitForTrade(i, num_trades, tp_prices);

      bool result = false;
      string comment = Trade_Comment + " Market #" + IntegerToString(i + 1);

      // Retry loop for transient failures
      int attempts = 0;
      int max_attempts = 2;
      while(attempts <= max_attempts)
      {
         attempts++;
         if(m_selected_direction == TRADE_BUY)
            result = trade.Buy(lot_size, current_symbol, 0, sl_price, tp_for_trade, comment);
         else
            result = trade.Sell(lot_size, current_symbol, 0, sl_price, tp_for_trade, comment);

         if(result)
            break;

         PrintFormat("[WARN] Trade attempt %d failed (ret=%d desc=%s). Comment=%s",
                    attempts, trade.ResultRetcode(), trade.ResultRetcodeDescription(), comment);
         Sleep(50);
      }

      if(result)
      {
         successful_trades++;
         ulong ticket = trade.ResultOrder();
         Print("Market trade ", i + 1, " executed successfully. Ticket: ", ticket,
               " TP: ", tp_for_trade, " Lots: ", lot_size, risk_type);
      }
      else
      {
         Print("[ERROR] Market trade ", i + 1, " failed after ", max_attempts + 1, " attempts. Ret=",
               trade.ResultRetcode(), " Desc=", trade.ResultRetcodeDescription());
      }
   }

   //--- Update status
   if(successful_trades == num_trades)
      UpdateStatus(IntegerToString(successful_trades) + " trades opened", clrGreen);
   else if(successful_trades > 0)
      UpdateStatus(IntegerToString(successful_trades) + "/" + IntegerToString(num_trades) + " trades opened", clrOrange);
   else
      UpdateStatus("All trades failed", clrRed);
}

void CMultiTradeDialog::ExecutePendingTrades(int num_trades, double lot_size, double open_price, double sl_price, double &tp_prices[])
{
   UpdateStatus("Placing orders...", clrBlue);

   string risk_type = m_half_risk_enabled ? " (Half Risk)" : " (Normal Risk)";

   // Determine order type based on direction and price
   ENUM_ORDER_TYPE order_type;
   if(m_selected_direction == TRADE_BUY)
      order_type = (open_price > current_ask) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_BUY_LIMIT;
   else
      order_type = (open_price < current_bid) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_SELL_LIMIT;

   int successful = 0;
   for(int i = 0; i < num_trades; i++)
   {
      // Get TP for this trade using improved logic
      double tp_for_trade = GetTakeProfitForTrade(i, num_trades, tp_prices);

      bool result = false;
      string comment = Trade_Comment + " Pending #" + IntegerToString(i + 1);

      // Retry loop for transient failures
      int attempts = 0;
      int max_attempts = 2;
      while(attempts <= max_attempts)
      {
         attempts++;
         result = trade.OrderOpen(current_symbol, order_type, lot_size, 0, open_price, sl_price, tp_for_trade,
                                 ORDER_TIME_SPECIFIED, Order_Expiration, comment);
         if(result)
            break;

         PrintFormat("[WARN] Order attempt %d failed (ret=%d desc=%s). Comment=%s",
                    attempts, trade.ResultRetcode(), trade.ResultRetcodeDescription(), comment);
         Sleep(50);
      }

      if(result)
      {
         successful++;
         ulong order_ticket = trade.ResultOrder();
         Print("Pending order ", i + 1, " placed successfully. Ticket: ", order_ticket,
               " Entry: ", open_price, " TP: ", tp_for_trade, " Lots: ", lot_size, risk_type);
      }
      else
      {
         Print("[ERROR] Pending order ", i + 1, " failed after ", max_attempts + 1, " attempts. Ret=",
               trade.ResultRetcode(), " Desc=", trade.ResultRetcodeDescription());
      }
   }

   //--- Update status
   if(successful == num_trades)
      UpdateStatus(IntegerToString(successful) + " orders placed", clrGreen);
   else if(successful > 0)
      UpdateStatus(IntegerToString(successful) + "/" + IntegerToString(num_trades) + " orders placed", clrOrange);
   else
      UpdateStatus("All orders failed", clrRed);
}

//+------------------------------------------------------------------+
//| Helper functions (preserved from original)                       |
//+------------------------------------------------------------------+
double GetTakeProfitForTrade(int trade_index, int total_trades, double &tp_prices[])
{
   double tp1 = tp_prices[0];
   double tp2 = tp_prices[1];

   bool tp1_set = (tp1 > 0);
   bool tp2_set = (tp2 > 0);

   if(tp1_set && !tp2_set) return tp1;
   if(!tp1_set && tp2_set) return tp2;
   if(!tp1_set && !tp2_set) return 0.0;
   if(total_trades == 1) return tp1;

   return (trade_index % 2 == 0) ? tp1 : tp2;
}

void InitializeSymbolData()
{
   current_symbol = Symbol();
   symbol_point = SymbolInfoDouble(current_symbol, SYMBOL_POINT);
   symbol_digits = (int)SymbolInfoInteger(current_symbol, SYMBOL_DIGITS);
   symbol_tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
   symbol_min_lot = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MIN);
   symbol_max_lot = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_MAX);
   symbol_lot_step = SymbolInfoDouble(current_symbol, SYMBOL_VOLUME_STEP);
   symbol_stops_level = (int)SymbolInfoInteger(current_symbol, SYMBOL_TRADE_STOPS_LEVEL);

   if(symbol_digits == 2 || symbol_digits == 4)
      symbol_pip_size = symbol_point * 10.0;
   else if(symbol_digits == 3 || symbol_digits == 5)
      symbol_pip_size = symbol_point * 10.0;
   else if(symbol_digits == 1)
      symbol_pip_size = symbol_point * 10.0;
   else
      symbol_pip_size = symbol_point;

   current_bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
   current_ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);
   last_bid = current_bid;
   last_ask = current_ask;
}

//+------------------------------------------------------------------+
//| Save GUI Settings to Global Variables                            |
//+------------------------------------------------------------------+
void SaveSettings()
{
   GlobalVariableSet(GV_LOT_SIZE, StringToDouble(g_dialog.m_edit_lot_size.Text()));
   GlobalVariableSet(GV_HALF_RISK, g_dialog.m_half_risk_enabled ? 1.0 : 0.0);
   GlobalVariableSet(GV_OPEN_PRICE, StringToDouble(g_dialog.m_edit_open_price.Text()));
   GlobalVariableSet(GV_SL, StringToDouble(g_dialog.m_edit_sl.Text()));
   GlobalVariableSet(GV_TP1, StringToDouble(g_dialog.m_edit_tp1.Text()));
   GlobalVariableSet(GV_TP2, StringToDouble(g_dialog.m_edit_tp2.Text()));
   GlobalVariableSet(GV_DIRECTION, (double)g_dialog.m_selected_direction);
   GlobalVariableSet(GV_EXECUTION, (double)g_dialog.m_selected_execution);

   Print("[MEMORY] Settings saved to global variables");
}

//+------------------------------------------------------------------+
//| Load GUI Settings from Global Variables                          |
//+------------------------------------------------------------------+
void LoadSettings()
{
   // Check if saved settings exist
   if(!GlobalVariableCheck(GV_LOT_SIZE))
   {
      Print("[MEMORY] No saved settings found. Using input parameters.");
      return;
   }

   // Load values from global variables
   double lot_size = GlobalVariableGet(GV_LOT_SIZE);
   bool half_risk = (GlobalVariableGet(GV_HALF_RISK) > 0.5);
   double open_price = GlobalVariableGet(GV_OPEN_PRICE);
   double sl = GlobalVariableGet(GV_SL);
   double tp1 = GlobalVariableGet(GV_TP1);
   double tp2 = GlobalVariableGet(GV_TP2);
   int direction = (int)GlobalVariableGet(GV_DIRECTION);
   int execution = (int)GlobalVariableGet(GV_EXECUTION);

   // Apply to GUI
   g_dialog.m_edit_lot_size.Text(DoubleToString(lot_size, 2));
   g_dialog.m_half_risk_enabled = half_risk;
   g_dialog.m_edit_open_price.Text(DoubleToString(open_price, symbol_digits));
   g_dialog.m_edit_sl.Text(DoubleToString(sl, 5));
   g_dialog.m_edit_tp1.Text(DoubleToString(tp1, 5));
   g_dialog.m_edit_tp2.Text(DoubleToString(tp2, 5));
   g_dialog.m_selected_direction = (TRADE_DIRECTION)direction;
   g_dialog.m_selected_execution = (EXECUTION_TYPE)execution;

   // Update displays
   g_dialog.UpdateFinalLotDisplay();
   g_dialog.UpdateLossProfitDisplay();
   g_dialog.UpdateDirectionButtons();
   g_dialog.UpdateExecutionButtons();
   g_dialog.UpdateOpenPriceVisibility();
   g_dialog.UpdateHalfRiskButton();

   Print("[MEMORY] Settings loaded from global variables");
}

int CountMyPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == current_symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == Magic_Number)
         {
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, Trade_Comment) >= 0)
               count++;
         }
      }
   }
   return count;
}

int CountMyPendingOrders()
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == current_symbol)
      {
         if(OrderGetInteger(ORDER_MAGIC) == Magic_Number)
         {
            string comment = OrderGetString(ORDER_COMMENT);
            if(StringFind(comment, Trade_Comment) >= 0)
               count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   InitializeSymbolData();
   
   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(current_symbol);
   
   if(!g_dialog.Create(0, "MultiTradeManager", 0, Panel_X_Position, Panel_Y_Position,
                        Panel_X_Position + 330, Panel_Y_Position + 450))
   {
      Print("Failed to create dialog");
      return INIT_FAILED;
   }
   
   if(!g_dialog.Run())
   {
      Print("Failed to run dialog");
      return INIT_FAILED;
   }

   // Load saved settings (if any)
   LoadSettings();

   Print("=== MultiTradeManager EA v2.0 Initialized ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_dialog.Destroy(reason);
   Print("MultiTradeManager EA v2.0 deinitialized");
}

//+------------------------------------------------------------------+
//| Trade Transaction Event Handler                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Placeholder for future transaction handling if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   uint current_time = GetTickCount();

   current_bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
   current_ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);

   if(current_time - last_count_update > COUNT_UPDATE_THRESHOLD)
   {
      total_positions = CountMyPositions();
      total_pending_orders = CountMyPendingOrders();
      last_count_update = current_time;
   }

   if(current_time - last_gui_update > GUI_UPDATE_THRESHOLD)
   {
      // Update dollar values in real-time for MARKET mode
      // (PENDING mode uses static Open Price, so no need to update)
      if(g_dialog.m_selected_execution == EXEC_MARKET)
      {
         g_dialog.UpdateLossProfitDisplay();
      }

      ChartRedraw();
      last_gui_update = current_time;
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Filter out events that should NOT minimize dialog
   // These events typically cause auto-minimize if passed to ChartEvent
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      // Symbol or timeframe changed - skip dialog event processing to prevent auto-minimize
      return;
   }

   // Use ChartEvent for proper state management, but filter problematic events
   g_dialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
