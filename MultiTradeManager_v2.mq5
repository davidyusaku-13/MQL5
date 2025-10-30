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
input int Number_Of_Trades = 2;
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

input group "=== Breakeven Settings ==="
input double Breakeven_Buffer_Pips = 5.0;

input group "=== Safety Settings ==="
input int Max_Total_Positions = 100;
input string Trade_Comment = "MultiTrade";
input datetime Order_Expiration = D'2025.12.31 23:59:59';

//--- Constants
#define COUNT_UPDATE_THRESHOLD 1000
#define GUI_UPDATE_THRESHOLD 100
#define PENDING_BE_TIMEOUT 86400

//--- Global Variable Memory Keys (persist settings across timeframe changes)
#define GV_PREFIX "MTM_" + current_symbol + "_"
#define GV_LOT_SIZE GV_PREFIX + "LotSize"
#define GV_TRADES GV_PREFIX + "Trades"
#define GV_HALF_RISK GV_PREFIX + "HalfRisk"
#define GV_BE_BUFFER GV_PREFIX + "BEBuffer"
#define GV_OPEN_PRICE GV_PREFIX + "OpenPrice"
#define GV_SL GV_PREFIX + "SL"
#define GV_TP1 GV_PREFIX + "TP1"
#define GV_TP2 GV_PREFIX + "TP2"
#define GV_DIRECTION GV_PREFIX + "Direction"
#define GV_EXECUTION GV_PREFIX + "Execution"

//--- Control IDs
enum
{
   ID_BTN_BUY = 1,
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

//--- Trade Group Structure
struct TradeGroup
{
   string group_id;
   datetime created_time;
   double entry_price;
   bool breakeven_moved;
   int total_trades;
   ulong tp1_tickets[];
   ulong tp2_tickets[];
};

struct PendingBETicket
{
   ulong ticket;
   double entry_price;
   TRADE_DIRECTION direction;
   datetime created_time;
   bool has_tp1;
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

TradeGroup active_groups[];
int active_group_count = 0;

PendingBETicket pending_be_cache[];
int pending_be_count = 0;

//+------------------------------------------------------------------+
//| Multi-Trade Manager Dialog Class                                 |
//+------------------------------------------------------------------+
class CMultiTradeDialog : public CAppDialog
{
public:
   // Public members needed by external functions
   CEdit m_edit_be_buffer;
   CEdit m_edit_lot_size, m_edit_trades, m_edit_open_price;
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
   CLabel m_label_be_buffer, m_label_be_pips, m_label_be_level;
   CLabel m_label_exec_type, m_label_direction, m_label_trades;
   CLabel m_label_trades_note, m_label_open_price, m_label_sl;
   CLabel m_label_tp_header, m_label_tp1, m_label_tp2;

   // Control members - Dynamic labels (display values)
   CLabel m_label_final_lot_value, m_label_be_level_value;
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
   void UpdateBELevelDisplay(void);
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
   UpdateBELevelDisplay();
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
   
   // BE Buffer
   if(!m_label_be_buffer.Create(m_chart_id, "label_be_buffer", m_subwin, x_base, y_pos, x_base + 65, y_pos + 18))
      return false;
   m_label_be_buffer.Text("BE Buffer:");
   if(!Add(m_label_be_buffer))
      return false;
   
   if(!m_edit_be_buffer.Create(m_chart_id, "edit_be_buffer", m_subwin, x_base + 68, y_pos, x_base + 68 + 40, y_pos + edit_height))
      return false;
   m_edit_be_buffer.Text(DoubleToString(Breakeven_Buffer_Pips, 1));
   if(!Add(m_edit_be_buffer))
      return false;
   
   if(!m_label_be_pips.Create(m_chart_id, "label_be_pips", m_subwin, x_base + 112, y_pos, x_base + 140, y_pos + 18))
      return false;
   m_label_be_pips.Text("pips");
   m_label_be_pips.Color(clrGray);
   if(!Add(m_label_be_pips))
      return false;
   
   // BE Level (same row)
   if(!m_label_be_level.Create(m_chart_id, "label_be_level", m_subwin, x_base + 150, y_pos, x_base + 200, y_pos + 18))
      return false;
   m_label_be_level.Text("BE Level:");
   if(!Add(m_label_be_level))
      return false;
   
   if(!m_label_be_level_value.Create(m_chart_id, "label_be_level_value", m_subwin, x_base + 203, y_pos, x_base + 310, y_pos + 18))
      return false;
   m_label_be_level_value.Text("---");
   m_label_be_level_value.Color(clrDarkOrange);
   if(!Add(m_label_be_level_value))
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
   
   // Trades
   if(!m_label_trades.Create(m_chart_id, "label_trades", m_subwin, x_base, y_pos, x_base + 50, y_pos + 18))
      return false;
   m_label_trades.Text("Trades:");
   if(!Add(m_label_trades))
      return false;
   
   if(!m_edit_trades.Create(m_chart_id, "edit_trades", m_subwin, x_base + 53, y_pos, x_base + 53 + 60, y_pos + edit_height))
      return false;
   m_edit_trades.Text(IntegerToString(Number_Of_Trades));
   if(!Add(m_edit_trades))
      return false;
   
   if(!m_label_trades_note.Create(m_chart_id, "label_trades_note", m_subwin, x_base + 120, y_pos, x_base + 320, y_pos + 18))
      return false;
   m_label_trades_note.Text("(any number)");
   m_label_trades_note.Color(clrBlue);
   if(!Add(m_label_trades_note))
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
   
   // Action buttons
   if(!m_btn_execute.Create(m_chart_id, "btn_execute", m_subwin, x_base + 5, y_pos, x_base + 5 + 100, y_pos + button_height))
      return false;
   m_btn_execute.Text("EXECUTE");
   m_btn_execute.Color(clrWhite);
   m_btn_execute.ColorBackground(clrBlue);
   m_btn_execute.Id(ID_BTN_EXECUTE);
   if(!Add(m_btn_execute))
      return false;

   if(!m_btn_close_all.Create(m_chart_id, "btn_close_all", m_subwin, x_base + 112, y_pos, x_base + 112 + 100, y_pos + button_height))
      return false;
   m_btn_close_all.Text("CLOSE ALL");
   m_btn_close_all.Color(clrWhite);
   m_btn_close_all.ColorBackground(clrRed);
   m_btn_close_all.Id(ID_BTN_CLOSE_ALL);
   if(!Add(m_btn_close_all))
      return false;

   if(!m_btn_cancel_pending.Create(m_chart_id, "btn_cancel_pending", m_subwin, x_base + 219, y_pos, x_base + 219 + 90, y_pos + button_height))
      return false;
   m_btn_cancel_pending.Text("CANCEL");
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
   // Handle button clicks - ON_CLICK event (ON_CLICK=0, so id==CHARTEVENT_CUSTOM)
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_buy.Id())
   {
      OnClickBuy();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_sell.Id())
   {
      OnClickSell();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_market.Id())
   {
      OnClickMarket();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_pending.Id())
   {
      OnClickPending();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_execute.Id())
   {
      OnClickExecute();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_close_all.Id())
   {
      OnClickCloseAll();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_cancel_pending.Id())
   {
      OnClickCancelPending();
      return true;
   }
   if(id == CHARTEVENT_CUSTOM && lparam == m_btn_half_risk.Id())
   {
      OnClickHalfRisk();
      return true;
   }

   // Handle edit field changes
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      OnChangeEdit();
      return true;
   }

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
   UpdateBELevelDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickSell(void)
{
   m_selected_direction = TRADE_SELL;
   UpdateDirectionButtons();
   UpdateOpenPriceField();
   UpdateLossProfitDisplay();
   UpdateBELevelDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickMarket(void)
{
   m_selected_execution = EXEC_MARKET;
   UpdateExecutionButtons();
   UpdateOpenPriceVisibility();
   UpdateLossProfitDisplay();
   UpdateBELevelDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnClickPending(void)
{
   m_selected_execution = EXEC_PENDING;
   UpdateExecutionButtons();
   UpdateOpenPriceVisibility();
   UpdateOpenPriceField();
   UpdateLossProfitDisplay();
   UpdateBELevelDisplay();
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
   UpdateBELevelDisplay();
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

void CMultiTradeDialog::UpdateBELevelDisplay(void)
{
   if(current_bid <= 0 || current_ask <= 0)
   {
      m_label_be_level_value.Text("---");
      return;
   }
   
   double entry_price = (m_selected_execution == EXEC_PENDING) ?
      StringToDouble(m_edit_open_price.Text()) :
      ((m_selected_direction == TRADE_BUY) ? current_ask : current_bid);
   
   if(entry_price <= 0)
   {
      m_label_be_level_value.Text("---");
      return;
   }
   
   double buffer_pips = StringToDouble(m_edit_be_buffer.Text());
   double buffer_in_price = buffer_pips * symbol_pip_size;
   
   double be_level = (m_selected_direction == TRADE_BUY) ?
      entry_price + buffer_in_price :
      entry_price - buffer_in_price;
   
   m_label_be_level_value.Text(DoubleToString(be_level, symbol_digits));
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
   int num_trades = (int)StringToInteger(m_edit_trades.Text());
   
   if(adjusted_lot < symbol_min_lot || adjusted_lot > symbol_max_lot)
   {
      UpdateStatus("Invalid lot size", clrRed);
      return;
   }
   
   if(num_trades <= 0 || num_trades > Max_Total_Positions)
   {
      UpdateStatus("Invalid trade count", clrRed);
      return;
   }
   
   double tp_prices[2];
   tp_prices[0] = StringToDouble(m_edit_tp1.Text());
   tp_prices[1] = StringToDouble(m_edit_tp2.Text());
   
   double sl_price = StringToDouble(m_edit_sl.Text());
   double open_price = StringToDouble(m_edit_open_price.Text());
   
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
   string direction_str = m_selected_direction == TRADE_BUY ? "BUY" : "SELL";

   // Arrays to track tickets for group creation
   ulong tp1_tickets[];
   ulong tp2_tickets[];
   if(ArrayResize(tp1_tickets, num_trades) < 0)
   {
      Print("[ERROR] Failed to allocate tp1_tickets array");
      return;
   }
   if(ArrayResize(tp2_tickets, num_trades) < 0)
   {
      Print("[ERROR] Failed to allocate tp2_tickets array");
      return;
   }
   int tp1_count = 0;
   int tp2_count = 0;
   double total_entry = 0;
   int no_tp_count = 0;  // Track positions without TP

   for(int i = 0; i < num_trades; i++)
   {
      // Get TP for this trade using improved logic
      double tp_for_trade = GetTakeProfitForTrade(i, num_trades, tp_prices);

      // Determine which TP index this corresponds to for tracking
      int tp_index = 0;  // Default to TP1
      if(tp_for_trade > 0)
      {
         if(tp_for_trade == tp_prices[1])
            tp_index = 1;
         else
            tp_index = 0;
      }

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

         // Retrieve position ticket
         ulong ticket = 0;
         ulong deal_id = trade.ResultDeal();
         if(deal_id > 0 && HistoryDealSelect(deal_id))
            ticket = (ulong)HistoryDealGetInteger(deal_id, DEAL_POSITION_ID);

         if(ticket == 0)
            ticket = trade.ResultOrder();

         if(ticket == 0)
         {
            Print("[WARNING] Unable to determine position ticket for trade ", i + 1);
            continue;
         }

         // Verify position was opened and get actual entry price
         ResetLastError();
         if(PositionSelectByTicket(ticket))
         {
            double actual_entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double actual_tp = PositionGetDouble(POSITION_TP);
            int pos_error = GetLastError();

            if(actual_entry <= 0 || pos_error != 0)
            {
               Print("[ERROR] Invalid position data for ticket ", ticket, ". Entry=", actual_entry, " Error=", pos_error);
               continue;
            }

            total_entry += actual_entry;

            // Check if TP was actually set
            if(actual_tp > 0)
            {
               // Store ticket in appropriate array based on TP
               if(tp_index == 0)
               {
                  tp1_tickets[tp1_count] = ticket;
                  tp1_count++;
               }
               else
               {
                  tp2_tickets[tp2_count] = ticket;
                  tp2_count++;
               }
            }
            else
            {
               // No TP set - add to pending BE cache
               AddToPendingBECache(ticket, actual_entry, m_selected_direction, (tp_index == 0));
               no_tp_count++;
               Print("[INFO] Trade ", i + 1, " opened without TP. Ticket: ", ticket, " added to pending BE cache.");
            }
         }
         else
         {
            int error_code = GetLastError();
            Print("[WARNING] Could not select position for ticket: ", ticket, " | Error: ", error_code);
         }

         Print("Market trade ", i + 1, " executed successfully. Ticket: ", ticket,
               " TP: ", tp_for_trade, " Lots: ", lot_size, risk_type);
      }
      else
      {
         Print("[ERROR] Market trade ", i + 1, " failed after ", max_attempts + 1, " attempts. Ret=",
               trade.ResultRetcode(), " Desc=", trade.ResultRetcodeDescription());
      }
   }

   //--- Create trade group if any trades successful with TP
   if(successful_trades > 0 && (tp1_count > 0 || tp2_count > 0))
   {
      // Use average entry price for BE calculation
      double avg_entry = total_entry / successful_trades;

      // Resize arrays to actual counts
      ArrayResize(tp1_tickets, tp1_count);
      ArrayResize(tp2_tickets, tp2_count);

      CreateTradeGroup(avg_entry, tp1_count, tp2_count, tp1_tickets, tp2_tickets);

      if(tp1_count > 0 && tp2_count > 0)
      {
         Print("[SUCCESS] Trade group created with ", tp1_count, " TP1 and ", tp2_count, " TP2 positions.");
      }
      else if(tp1_count > 0)
      {
         if(tp1_count == 1 && num_trades == 1)
            Print("[INFO] Single trade opened with TP. Breakeven will activate when TP hits.");
         else
            Print("[WARNING] Partial group created with only ", tp1_count, " TP1 position(s). BE will activate when TP1 hits.");
      }
      else
      {
         if(tp2_count == 1 && num_trades == 1)
            Print("[INFO] Single trade opened with TP. Breakeven will activate when TP hits.");
         else
            Print("[WARNING] Partial group created with only ", tp2_count, " TP2 position(s). No TP1 to trigger BE.");
      }
   }
   else if(successful_trades > 0 && tp1_count == 0 && tp2_count == 0 && no_tp_count == 0)
   {
      Print("[WARNING] No positions with TP. BE tracking disabled.");
   }

   // Inform user about pending BE positions
   if(no_tp_count > 0)
   {
      Print("[INFO] ", no_tp_count, " position(s) without TP. Breakeven will activate when TP is added.");
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

   // Note: Pending orders will be tracked automatically by OnTradeTransaction
   // when they are filled and become positions
   if(successful > 0)
   {
      Print("[INFO] ", successful, " pending order(s) placed. Trade groups will be created when orders are filled.");
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

//+------------------------------------------------------------------+
//| Normalize price to symbol requirements                           |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   return NormalizeDouble(price, symbol_digits);
}

//+------------------------------------------------------------------+
//| Create Trade Group for Breakeven Tracking                        |
//+------------------------------------------------------------------+
string CreateTradeGroup(double entry, int num_tp1, int num_tp2, ulong &tp1_tickets[], ulong &tp2_tickets[])
{
   // Generate unique group ID based on timestamp
   string group_id = "MTM_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   group_id = StringFormat("%s_%d", group_id, GetTickCount());

   // Resize array to accommodate new group
   ResetLastError();
   int resize_result = ArrayResize(active_groups, active_group_count + 1);

   if(resize_result < 0)
   {
      int error_code = GetLastError();
      Print("[ERROR] Failed to resize active_groups array. Error: ", error_code);
      return "ERROR";
   }

   // Initialize new group
   active_groups[active_group_count].group_id = group_id;
   active_groups[active_group_count].created_time = TimeCurrent();
   active_groups[active_group_count].entry_price = entry;
   active_groups[active_group_count].breakeven_moved = false;
   active_groups[active_group_count].total_trades = num_tp1 + num_tp2;

   // Copy ticket arrays
   if(num_tp1 > 0)
   {
      ArrayResize(active_groups[active_group_count].tp1_tickets, num_tp1);
      for(int i = 0; i < num_tp1; i++)
         active_groups[active_group_count].tp1_tickets[i] = tp1_tickets[i];
   }
   else
   {
      ArrayResize(active_groups[active_group_count].tp1_tickets, 0);
   }

   if(num_tp2 > 0)
   {
      ArrayResize(active_groups[active_group_count].tp2_tickets, num_tp2);
      for(int i = 0; i < num_tp2; i++)
         active_groups[active_group_count].tp2_tickets[i] = tp2_tickets[i];
   }
   else
   {
      ArrayResize(active_groups[active_group_count].tp2_tickets, 0);
   }

   active_group_count++;

   Print("Trade group created: ", group_id, " | Entry: ", entry, " | TP1 count: ", num_tp1, " | TP2 count: ", num_tp2);

   return group_id;
}

//+------------------------------------------------------------------+
//| Calculate Breakeven Price with Buffer                            |
//+------------------------------------------------------------------+
double CalculateBEWithBuffer(double entry_price, ENUM_POSITION_TYPE pos_type, double tp1_price)
{
   // Get buffer in pips from GUI
   double buffer_pips = StringToDouble(g_dialog.m_edit_be_buffer.Text());

   // Early validation
   if(buffer_pips < 0)
   {
      Print("[WARNING] BE buffer cannot be negative. Using 0.");
      buffer_pips = 0;
   }

   // Cap buffer at 50% of TP1 distance
   if(tp1_price > 0 && entry_price > 0)
   {
      double tp1_distance_pips = MathAbs(tp1_price - entry_price) / symbol_pip_size;
      double max_buffer = tp1_distance_pips * 0.5;

      if(buffer_pips > max_buffer)
      {
         Print("[WARNING] BE buffer (", buffer_pips, " pips) exceeds 50% of TP1 distance (",
               DoubleToString(max_buffer, 1), " pips). Capping at ", DoubleToString(max_buffer, 1), " pips.");
         buffer_pips = max_buffer;
      }
   }

   // Calculate BE price with buffer
   double be_price = entry_price;
   double buffer_in_price = buffer_pips * symbol_pip_size;

   if(pos_type == POSITION_TYPE_BUY)
   {
      be_price = entry_price + buffer_in_price;
   }
   else // SELL
   {
      be_price = entry_price - buffer_in_price;
   }

   // Normalize to symbol requirements
   be_price = NormalizePrice(be_price);

   return be_price;
}

//+------------------------------------------------------------------+
//| Move Group to Breakeven                                          |
//+------------------------------------------------------------------+
void MoveGroupToBreakeven(int group_index)
{
   if(group_index < 0 || group_index >= active_group_count)
      return;

   // Check if already moved
   if(active_groups[group_index].breakeven_moved)
   {
      Print("Group ", active_groups[group_index].group_id, " already moved to breakeven");
      return;
   }

   int moved_count = 0;

   // Get minimum stop level for safety check
   int stops_level = (int)SymbolInfoInteger(current_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = stops_level * symbol_point;

   // Move all open tickets in both TP1 and TP2 lists to breakeven
   int tp1_count = ArraySize(active_groups[group_index].tp1_tickets);
   int tp2_count = ArraySize(active_groups[group_index].tp2_tickets);

   // Process both arrays
   for(int arr = 0; arr < 2; arr++)
   {
      int count = (arr == 0) ? tp1_count : tp2_count;
      for(int j = 0; j < count; j++)
      {
         ulong ticket = (arr == 0) ? active_groups[group_index].tp1_tickets[j] : active_groups[group_index].tp2_tickets[j];

         // Check if position still exists
         ResetLastError();
         if(!PositionSelectByTicket(ticket))
            continue;

         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double current_tp = PositionGetDouble(POSITION_TP);
         double current_sl = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         // Validate position data
         int error_code = GetLastError();
         if(current_price <= 0 || error_code != 0)
         {
            Print("[ERROR] Invalid position data for ticket #", ticket, ": Price=", current_price, " Error=", error_code);
            continue;
         }

         // Calculate BE price with buffer for this position
         double be_price = CalculateBEWithBuffer(active_groups[group_index].entry_price, pos_type, current_tp);

         // Safety check: Verify BE price distance from current price
         double distance_from_current = MathAbs(be_price - current_price);
         if(distance_from_current < min_distance && min_distance > 0)
         {
            Print("WARNING: BE price too close to current. Distance: ", distance_from_current,
                  " | Min required: ", min_distance, " | Ticket: ", ticket);
            continue;
         }

         // Validate BE price vs position type
         bool valid_be = false;
         if(pos_type == POSITION_TYPE_BUY)
         {
            valid_be = (be_price < current_price) && (current_sl == 0 || be_price > current_sl);
         }
         else // SELL
         {
            valid_be = (be_price > current_price) && (current_sl == 0 || be_price < current_sl);
         }

         if(!valid_be)
         {
            Print("WARNING: Invalid BE placement. Type: ", EnumToString(pos_type),
                  " | Current: ", current_price, " | BE: ", be_price, " | Current SL: ", current_sl);
            continue;
         }

         // Modify SL to breakeven, keep TP unchanged. Retry once on transient failure.
         bool modified = false;
         int attempts = 0;
         int max_attempts = 2;
         while(attempts <= max_attempts)
         {
            attempts++;
            ResetLastError();
            if(trade.PositionModify(ticket, be_price, current_tp))
            {
               modified = true;
               break;
            }
            PrintFormat("[WARN] PositionModify attempt %d failed for ticket %d. Ret=%d Desc=%s",
                       attempts, ticket, trade.ResultRetcode(), trade.ResultRetcodeDescription());
            Sleep(50);
         }

         if(modified)
         {
            moved_count++;
            Print("[OK] Ticket #", ticket, " SL moved to breakeven: ", be_price);
         }
         else
         {
            int err = GetLastError();
            Print("[ERROR] Failed to move ticket #", ticket, " to BE after retries. LastError=", err,
                  " Ret=", trade.ResultRetcode(), " Desc=", trade.ResultRetcodeDescription());
         }
      }
   }

   // Mark group as moved if we actually modified at least one position
   if(moved_count > 0)
   {
      active_groups[group_index].breakeven_moved = true;
      double buffer_pips = StringToDouble(g_dialog.m_edit_be_buffer.Text());

      Print("=== BREAKEVEN ACTIVATED ===");
      Print("Group: ", active_groups[group_index].group_id);
      Print("Entry: ", active_groups[group_index].entry_price, " | Buffer: ", buffer_pips, " pips");
      Print("Moved ", moved_count, " position(s) to BE+Buffer");
      Print("===========================");
   }
   else
   {
      Print("[INFO] No positions were moved to breakeven for group: ", active_groups[group_index].group_id, ". Will retry later.");
   }
}

//+------------------------------------------------------------------+
//| Find Group by TP1 Ticket                                         |
//+------------------------------------------------------------------+
int FindGroupByTP1Ticket(ulong ticket)
{
   for(int i = 0; i < active_group_count; i++)
   {
      int tp1_count = ArraySize(active_groups[i].tp1_tickets);
      for(int j = 0; j < tp1_count; j++)
      {
         if(active_groups[i].tp1_tickets[j] == ticket)
            return i;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Find Group by Any Ticket (TP1 or TP2)                           |
//+------------------------------------------------------------------+
int FindGroupByAnyTicket(ulong ticket)
{
   for(int i = 0; i < active_group_count; i++)
   {
      // Check TP1 tickets
      int tp1_count = ArraySize(active_groups[i].tp1_tickets);
      for(int j = 0; j < tp1_count; j++)
      {
         if(active_groups[i].tp1_tickets[j] == ticket)
            return i;
      }

      // Check TP2 tickets
      int tp2_count = ArraySize(active_groups[i].tp2_tickets);
      for(int j = 0; j < tp2_count; j++)
      {
         if(active_groups[i].tp2_tickets[j] == ticket)
            return i;
      }
   }
   return -1; // Not found
}

//+------------------------------------------------------------------+
//| Remove Closed Groups                                             |
//+------------------------------------------------------------------+
void RemoveClosedGroups()
{
   for(int i = active_group_count - 1; i >= 0; i--)
   {
      bool all_closed = true;

      // Check TP1 tickets
      int tp1_count = ArraySize(active_groups[i].tp1_tickets);
      for(int j = 0; j < tp1_count; j++)
      {
         if(PositionSelectByTicket(active_groups[i].tp1_tickets[j]))
         {
            all_closed = false;
            break;
         }
      }

      // Check TP2 tickets if TP1 all closed
      if(all_closed)
      {
         int tp2_count = ArraySize(active_groups[i].tp2_tickets);
         for(int j = 0; j < tp2_count; j++)
         {
            if(PositionSelectByTicket(active_groups[i].tp2_tickets[j]))
            {
               all_closed = false;
               break;
            }
         }
      }

      // Remove group if all positions closed
      if(all_closed)
      {
         Print("[INFO] Removing closed group: ", active_groups[i].group_id);

         // Shift remaining groups down
         for(int k = i; k < active_group_count - 1; k++)
         {
            active_groups[k] = active_groups[k + 1];
         }

         active_group_count--;
         ArrayResize(active_groups, active_group_count);
      }
   }
}

//+------------------------------------------------------------------+
//| Add Ticket to Pending BE Cache                                   |
//+------------------------------------------------------------------+
void AddToPendingBECache(ulong ticket, double entry, TRADE_DIRECTION dir, bool has_tp1)
{
   // Resize cache array
   int new_size = pending_be_count + 1;
   if(ArrayResize(pending_be_cache, new_size) < 0)
   {
      Print("[ERROR] Failed to resize pending_be_cache");
      return;
   }

   // Add ticket to cache
   pending_be_cache[pending_be_count].ticket = ticket;
   pending_be_cache[pending_be_count].entry_price = entry;
   pending_be_cache[pending_be_count].direction = dir;
   pending_be_cache[pending_be_count].created_time = TimeCurrent();
   pending_be_cache[pending_be_count].has_tp1 = has_tp1;

   pending_be_count++;

   Print("[INFO] Added ticket ", ticket, " to pending BE cache. Entry: ", entry);
}

//+------------------------------------------------------------------+
//| Check if TP Added to Cached Position                             |
//+------------------------------------------------------------------+
void CheckTPAddedToCache(ulong order_ticket)
{
   for(int i = pending_be_count - 1; i >= 0; i--)
   {
      if(pending_be_cache[i].ticket == order_ticket)
      {
         // Check if TP was added
         if(PositionSelectByTicket(order_ticket))
         {
            double tp = PositionGetDouble(POSITION_TP);
            if(tp > 0)
            {
               Print("[INFO] TP added to cached ticket ", order_ticket, ". Creating trade group.");

               // Create single-trade group
               ulong tp1_array[1];
               ulong tp2_array[1];

               if(pending_be_cache[i].has_tp1)
               {
                  tp1_array[0] = order_ticket;
                  CreateTradeGroup(pending_be_cache[i].entry_price, 1, 0, tp1_array, tp2_array);
               }
               else
               {
                  tp2_array[0] = order_ticket;
                  CreateTradeGroup(pending_be_cache[i].entry_price, 0, 1, tp1_array, tp2_array);
               }

               // Remove from cache
               for(int j = i; j < pending_be_count - 1; j++)
               {
                  pending_be_cache[j] = pending_be_cache[j + 1];
               }
               pending_be_count--;
               ArrayResize(pending_be_cache, pending_be_count);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if TP was Removed from Tracked Position                    |
//+------------------------------------------------------------------+
void CheckTPRemovedFromGroup(ulong position_ticket)
{
   // Check if this position is in any trade group
   for(int i = 0; i < active_group_count; i++)
   {
      bool found_in_group = false;
      bool is_tp1 = false;

      // Check TP1 tickets
      int tp1_count = ArraySize(active_groups[i].tp1_tickets);
      for(int j = 0; j < tp1_count; j++)
      {
         if(active_groups[i].tp1_tickets[j] == position_ticket)
         {
            found_in_group = true;
            is_tp1 = true;
            break;
         }
      }

      // Check TP2 tickets if not found in TP1
      if(!found_in_group)
      {
         int tp2_count = ArraySize(active_groups[i].tp2_tickets);
         for(int j = 0; j < tp2_count; j++)
         {
            if(active_groups[i].tp2_tickets[j] == position_ticket)
            {
               found_in_group = true;
               is_tp1 = false;
               break;
            }
         }
      }

      // If found, check if TP was removed
      if(found_in_group)
      {
         if(PositionSelectByTicket(position_ticket))
         {
            double current_tp = PositionGetDouble(POSITION_TP);

            if(current_tp == 0)
            {
               // TP was removed - warn user
               Print("[WARNING] TP removed from tracked position #", position_ticket, " in group ", active_groups[i].group_id);
               Print("[WARNING] Breakeven will NOT trigger for this position if closed manually.");
               Print("[INFO] Please re-add TP to enable breakeven protection.");
            }
            else
            {
               // TP was modified but not removed - still trackable
               Print("[INFO] TP modified for position #", position_ticket, ". New TP: ", current_tp);
               Print("[INFO] Breakeven will still trigger when this TP hits.");
            }
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Pending BE Cache                                           |
//+------------------------------------------------------------------+
void CheckPendingBECache()
{
   datetime current_time = TimeCurrent();

   for(int i = pending_be_count - 1; i >= 0; i--)
   {
      ulong ticket = pending_be_cache[i].ticket;

      // Check if position still exists
      if(!PositionSelectByTicket(ticket))
      {
         Print("[INFO] Cached ticket ", ticket, " no longer exists. Removing from cache.");

         // Remove from cache
         for(int j = i; j < pending_be_count - 1; j++)
         {
            pending_be_cache[j] = pending_be_cache[j + 1];
         }
         pending_be_count--;
         ArrayResize(pending_be_cache, pending_be_count);
         continue;
      }

      // Check timeout (24 hours)
      if(current_time - pending_be_cache[i].created_time > PENDING_BE_TIMEOUT)
      {
         Print("[WARNING] Cached ticket ", ticket, " timed out after 24 hours. Removing from cache.");

         // Remove from cache
         for(int j = i; j < pending_be_count - 1; j++)
         {
            pending_be_cache[j] = pending_be_cache[j + 1];
         }
         pending_be_count--;
         ArrayResize(pending_be_cache, pending_be_count);
         continue;
      }

      // Check if TP was added
      double tp = PositionGetDouble(POSITION_TP);
      if(tp > 0)
      {
         Print("[INFO] TP detected on cached ticket ", ticket, ". Creating trade group.");

         // Create single-trade group
         ulong tp1_array[1];
         ulong tp2_array[1];

         if(pending_be_cache[i].has_tp1)
         {
            tp1_array[0] = ticket;
            CreateTradeGroup(pending_be_cache[i].entry_price, 1, 0, tp1_array, tp2_array);
         }
         else
         {
            tp2_array[0] = ticket;
            CreateTradeGroup(pending_be_cache[i].entry_price, 0, 1, tp1_array, tp2_array);
         }

         // Remove from cache
         for(int j = i; j < pending_be_count - 1; j++)
         {
            pending_be_cache[j] = pending_be_cache[j + 1];
         }
         pending_be_count--;
         ArrayResize(pending_be_cache, pending_be_count);
      }
   }
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
   GlobalVariableSet(GV_TRADES, StringToInteger(g_dialog.m_edit_trades.Text()));
   GlobalVariableSet(GV_HALF_RISK, g_dialog.m_half_risk_enabled ? 1.0 : 0.0);
   GlobalVariableSet(GV_BE_BUFFER, StringToDouble(g_dialog.m_edit_be_buffer.Text()));
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
   int trades = (int)GlobalVariableGet(GV_TRADES);
   bool half_risk = (GlobalVariableGet(GV_HALF_RISK) > 0.5);
   double be_buffer = GlobalVariableGet(GV_BE_BUFFER);
   double open_price = GlobalVariableGet(GV_OPEN_PRICE);
   double sl = GlobalVariableGet(GV_SL);
   double tp1 = GlobalVariableGet(GV_TP1);
   double tp2 = GlobalVariableGet(GV_TP2);
   int direction = (int)GlobalVariableGet(GV_DIRECTION);
   int execution = (int)GlobalVariableGet(GV_EXECUTION);

   // Apply to GUI
   g_dialog.m_edit_lot_size.Text(DoubleToString(lot_size, 2));
   g_dialog.m_edit_trades.Text(IntegerToString(trades));
   g_dialog.m_half_risk_enabled = half_risk;
   g_dialog.m_edit_be_buffer.Text(DoubleToString(be_buffer, 1));
   g_dialog.m_edit_open_price.Text(DoubleToString(open_price, symbol_digits));
   g_dialog.m_edit_sl.Text(DoubleToString(sl, 5));
   g_dialog.m_edit_tp1.Text(DoubleToString(tp1, 5));
   g_dialog.m_edit_tp2.Text(DoubleToString(tp2, 5));
   g_dialog.m_selected_direction = (TRADE_DIRECTION)direction;
   g_dialog.m_selected_execution = (EXECUTION_TYPE)execution;

   // Update displays
   g_dialog.UpdateFinalLotDisplay();
   g_dialog.UpdateLossProfitDisplay();
   g_dialog.UpdateBELevelDisplay();
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
//| Trade Transaction Event Handler - Breakeven Trigger              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Handle multiple transaction types

   // TYPE 1: Position/Order modification (SL/TP changed)
   if(trans.type == TRADE_TRANSACTION_ORDER_UPDATE)
   {
      // Check if TP was added to a position in pending BE cache
      CheckTPAddedToCache(trans.order);

      // Check if TP was removed from a tracked position in trade groups
      CheckTPRemovedFromGroup(trans.order);
   }

   // TYPE 2: Deal added (position opened or closed)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Check if it's our symbol and magic number
      if(trans.symbol != current_symbol)
         return;

      // Get deal properties
      ResetLastError();
      if(!HistoryDealSelect(trans.deal))
      {
         int error_code = GetLastError();
         if(error_code != 0)
         {
            Print("[ERROR] Failed to select deal #", trans.deal, ". Error: ", error_code);
         }
         return;
      }

      ulong deal_magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
      if(deal_magic != Magic_Number)
         return;

      string deal_comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
      if(StringFind(deal_comment, Trade_Comment) < 0)
         return;

      ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      ulong position_id = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);

      // Case A: Position ENTRY (from pending order activation or market execution)
      if(deal_entry == DEAL_ENTRY_IN)
      {
         // Check if this position has TP set
         ResetLastError();
         if(PositionSelectByTicket(position_id))
         {
            double tp = PositionGetDouble(POSITION_TP);
            double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Check if this is from a pending order fill by looking at the deal comment
            long deal_type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);

            // Only create groups for pending orders that were filled (not market orders - those are handled in ExecuteMarketTrades)
            bool is_pending_fill = (StringFind(comment, "Pending") >= 0);

            if(is_pending_fill && tp > 0)
            {
               // Pending order filled with TP - create single-trade group
               Print("[INFO] Pending order filled. Ticket: ", position_id, " Entry: ", entry_price, " TP: ", tp, " | Creating trade group");

               ulong tp1_array[1];
               ulong tp2_array[1];
               tp1_array[0] = position_id;

               // Determine if this is TP1 or TP2 based on TP value
               bool is_tp1 = (tp == StringToDouble(g_dialog.m_edit_tp1.Text()));

               if(is_tp1)
                  CreateTradeGroup(entry_price, 1, 0, tp1_array, tp2_array);
               else
                  CreateTradeGroup(entry_price, 0, 1, tp1_array, tp2_array);
            }
            else if(is_pending_fill && tp == 0)
            {
               Print("[INFO] Pending order filled without TP. Ticket: ", position_id, " | Adding to pending BE cache.");

               // Determine direction
               TRADE_DIRECTION dir = (pos_type == POSITION_TYPE_BUY) ? TRADE_BUY : TRADE_SELL;
               AddToPendingBECache(position_id, entry_price, dir, true);
            }
            else if(!is_pending_fill && tp == 0)
            {
               Print("[INFO] Position ", position_id, " opened without TP (market order). Adding to pending BE cache.");
               // Will be handled by pending BE cache system
            }
         }
      }

      // Case B: Position CLOSE (any reason)
      if(deal_entry == DEAL_ENTRY_OUT)
      {
         // Get deal details
         long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
         double deal_profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);

         // Check if this position was in any trade group (TP1 or TP2)
         int group_index = FindGroupByAnyTicket(position_id);

         if(group_index >= 0)
         {
            // Position in group closed - check if it was profitable
            if(deal_profit > 0)
            {
               // Profitable close (TP hit OR manual close in profit)
               Print("[SUCCESS] Profitable close detected! Ticket: ", position_id,
                     " | Profit: $", DoubleToString(deal_profit, 2),
                     " | Reason: ", EnumToString((ENUM_DEAL_REASON)reason));
               Print("[INFO] Moving remaining positions in group to breakeven");
               MoveGroupToBreakeven(group_index);
            }
            else if(deal_profit < 0)
            {
               // Loss - SL hit or manual close in loss
               Print("[INFO] Position ", position_id, " closed with loss: $",
                     DoubleToString(deal_profit, 2), ". Breakeven not triggered.");
            }
            else
            {
               // Breakeven close (profit = 0)
               Print("[INFO] Position ", position_id, " closed at breakeven. No action needed.");
            }
         }
      }
   }

   // Cleanup closed groups periodically
   RemoveClosedGroups();
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
      ChartRedraw();
      last_gui_update = current_time;
   }

   //--- Periodic cleanup of closed groups and pending BE cache
   static uint last_cleanup = 0;
   if(current_time - last_cleanup > 60000) // Every 60 seconds
   {
      RemoveClosedGroups();
      CheckPendingBECache();
      last_cleanup = current_time;
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   g_dialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
