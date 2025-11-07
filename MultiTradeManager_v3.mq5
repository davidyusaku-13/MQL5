//+------------------------------------------------------------------+
//|                                      MultiTradeManager_v3.mq5    |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "3.00"
#property description "Multi-Trade Manager v3.0 - Advanced GUI with Enhanced Features"

#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\ComboBox.mqh>
#include <Controls\CheckBox.mqh>
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Trade Parameters ==="
input ulong Magic_Number = 12345;
input double Default_Lot_Size = 0.04;
input double Default_Risk_Amount = 100.0;
input double Default_Risk_Percent = 1.0;
input int Default_Stop_Loss_Points = 100;
input int Default_Take_Profit_Points = 150;
input double Default_Stop_Loss_Price = 0.0;
input double Default_Take_Profit_Price = 0.0;

input group "=== Display Settings ==="
input int Panel_X_Position = 5;
input int Panel_Y_Position = 85;
input color Panel_Background = clrWhiteSmoke;
input color Panel_Border = clrDarkBlue;

input group "=== Safety Settings ==="
input int Max_Total_Positions = 100;
input string Trade_Comment = "MTMv3";
input datetime Order_Expiration = D'2025.12.31 23:59:59';

//--- Constants
#define COUNT_UPDATE_THRESHOLD 1000
#define GUI_UPDATE_THRESHOLD 100

//--- Enums
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,
   LOT_RISK_AMOUNT = 1,
   LOT_RISK_BALANCE = 2,
   LOT_RISK_EQUITY = 3
};

enum ENUM_SLTP_MODE
{
   SLTP_POINTS = 0,
   SLTP_PRICE = 1
};

enum ENUM_ORDER_COUNT
{
   ORDERS_1 = 0,
   ORDERS_2 = 1,
   ORDERS_3 = 2,
   ORDERS_4 = 3
};

enum ENUM_AUTO_BE_MODE
{
   AUTO_BE_DISABLED = 0,
   AUTO_BE_AFTER_TP1 = 1,
   AUTO_BE_AFTER_TP2 = 2
};

//--- Control IDs (start from 100 to avoid collision with CAppDialog internal IDs)
enum
{
   ID_LOT_MODE = 100,
   ID_EDIT_LOT_SIZE,
   ID_EDIT_RISK_AMOUNT,
   ID_EDIT_RISK_PERCENT,
   ID_SLTP_MODE,
   ID_EDIT_SL_POINTS,
   ID_EDIT_TP_POINTS,
   ID_EDIT_SL_PRICE,
   ID_EDIT_TP_PRICE,
   ID_ORDER_COUNT,
   ID_BTN_BUY_NOW,
   ID_BTN_SELL_NOW,
   ID_EDIT_ENTRY_PRICE,
   ID_BTN_BUY_LIMIT,
   ID_BTN_SELL_LIMIT,
   ID_AUTO_BE_MODE,
   ID_CHK_BUY_ORDERS,
   ID_CHK_SELL_ORDERS,
   ID_CHK_BUY_POSITIONS,
   ID_CHK_SELL_POSITIONS,
   ID_CHK_PROFIT_POSITIONS,
   ID_CHK_LOSS_POSITIONS,
   ID_BTN_CLOSE_POSITIONS,
   ID_BTN_DELETE_ORDERS
};

//--- Global Variable Memory Keys
#define GV_LOT_MODE "MTMv3_LotMode"
#define GV_LOT_SIZE "MTMv3_LotSize"
#define GV_RISK_AMOUNT "MTMv3_RiskAmount"
#define GV_RISK_PERCENT "MTMv3_RiskPercent"
#define GV_SLTP_MODE "MTMv3_SLTPMode"
#define GV_SL_POINTS "MTMv3_SLPoints"
#define GV_TP_POINTS "MTMv3_TPPoints"
#define GV_SL_PRICE "MTMv3_SLPrice"
#define GV_TP_PRICE "MTMv3_TPPrice"
#define GV_ORDER_COUNT "MTMv3_OrderCount"
#define GV_ENTRY_PRICE "MTMv3_EntryPrice"
#define GV_AUTO_BE_MODE "MTMv3_AutoBEMode"
#define GV_CHK_BUY_ORDERS "MTMv3_ChkBuyOrders"
#define GV_CHK_SELL_ORDERS "MTMv3_ChkSellOrders"
#define GV_CHK_BUY_POSITIONS "MTMv3_ChkBuyPositions"
#define GV_CHK_SELL_POSITIONS "MTMv3_ChkSellPositions"
#define GV_CHK_PROFIT_POSITIONS "MTMv3_ChkProfitPositions"
#define GV_CHK_LOSS_POSITIONS "MTMv3_ChkLossPositions"

//--- Trade Group Structure for Auto-Breakeven
struct TradeGroup
{
   ulong ticket_tp1;
   ulong ticket_tp2;
   double entry_price;
   bool be_moved;
   datetime created_time;
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

//+------------------------------------------------------------------+
//| Multi-Trade Manager Dialog Class                                 |
//+------------------------------------------------------------------+
class CMultiTradeDialog : public CAppDialog
{
public:
   // Public members needed by external functions
   CComboBox m_combo_lot_mode, m_combo_sltp_mode, m_combo_order_count, m_combo_auto_be;
   CEdit m_edit_lot_size, m_edit_risk_amount, m_edit_risk_percent;
   CEdit m_edit_sl_points, m_edit_tp_points, m_edit_sl_price, m_edit_tp_price;
   CEdit m_edit_entry_price;
   CCheckBox m_chk_buy_orders, m_chk_sell_orders;
   CCheckBox m_chk_buy_positions, m_chk_sell_positions;
   CCheckBox m_chk_profit_positions, m_chk_loss_positions;

private:
   // Control members - Buttons
   CButton m_btn_buy_now, m_btn_sell_now;
   CButton m_btn_buy_limit, m_btn_sell_limit;
   CButton m_btn_close_positions, m_btn_delete_orders;

   // Control members - Labels
   CLabel m_label_title, m_label_symbol;
   CLabel m_label_lot_mode, m_label_sltp_mode, m_label_order_count;
   CLabel m_label_auto_be, m_label_status;
   CLabel m_label_final_lot, m_label_sl_amount, m_label_tp_amount;

public:
   CMultiTradeDialog(void);
   ~CMultiTradeDialog(void);

   virtual bool Create(const long chart, const string name, const int subwin,
                      const int x1, const int y1, const int x2, const int y2);
   virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

   void UpdateStatus(string status, color clr);
   void UpdateLotSizeMode();
   void UpdateSLTPMode();
   void UpdateFinalLotDisplay();
   void UpdateLossProfitDisplay();

protected:
   bool CreateControls(void);

   void OnClickBuyNow(void);
   void OnClickSellNow(void);
   void OnClickBuyLimit(void);
   void OnClickSellLimit(void);
   void OnClickClosePositions(void);
   void OnClickDeleteOrders(void);

   void OnChangeLotMode(void);
   void OnChangeSLTPMode(void);
   void OnChangeEdit(void);

   void ExecuteMarketTrade(bool is_buy);
   void ExecuteLimitOrder(bool is_buy);
   double CalculateLotSize();
   double GetStopLossPrice(bool is_buy, double entry_price);
   double GetTakeProfitPrice(bool is_buy, double entry_price, int order_index);
   void CreateTradeGroup(ulong ticket1, ulong ticket2, double avg_entry);
   void SaveSettings();
};

//--- Global dialog instance
CMultiTradeDialog g_dialog;

//--- Function declarations
void LoadSettings();

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMultiTradeDialog::CMultiTradeDialog(void)
{
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
   UpdateLotSizeMode();
   UpdateSLTPMode();
   UpdateFinalLotDisplay();
   UpdateLossProfitDisplay();

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
   int edit_width = 80, edit_height = 22;
   int combo_width = 120, button_width = 90, button_height = 22;

   // Title
   if(!m_label_title.Create(m_chart_id, "label_title", m_subwin, x_base, y_pos, x_base + 380, y_pos + 18))
      return false;
   m_label_title.Text("Multi-Trade Manager v3.0");
   m_label_title.Color(clrDarkBlue);
   if(!Add(m_label_title))
      return false;
   y_pos += 22;

   // Symbol
   if(!m_label_symbol.Create(m_chart_id, "label_symbol", m_subwin, x_base, y_pos, x_base + 380, y_pos + 18))
      return false;
   m_label_symbol.Text("Symbol: " + current_symbol);
   m_label_symbol.Color(clrBlack);
   if(!Add(m_label_symbol))
      return false;
   y_pos += 28;

   // Lot Size Mode
   if(!m_label_lot_mode.Create(m_chart_id, "label_lot_mode", m_subwin, x_base, y_pos, x_base + 80, y_pos + 18))
      return false;
   m_label_lot_mode.Text("Lot Mode:");
   if(!Add(m_label_lot_mode))
      return false;

   if(!m_combo_lot_mode.Create(m_chart_id, "combo_lot_mode", m_subwin, x_base + 85, y_pos, x_base + 85 + combo_width, y_pos + edit_height))
      return false;
   m_combo_lot_mode.AddItem("Fixed Lot", LOT_FIXED);
   m_combo_lot_mode.AddItem("Risk Amount($)", LOT_RISK_AMOUNT);
   m_combo_lot_mode.AddItem("Risk % of Balance", LOT_RISK_BALANCE);
   m_combo_lot_mode.AddItem("Risk % of Equity", LOT_RISK_EQUITY);
   m_combo_lot_mode.Select(LOT_RISK_AMOUNT); // Default choice
   m_combo_lot_mode.Id(ID_LOT_MODE);
   if(!Add(m_combo_lot_mode))
      return false;
   y_pos += 26;

   // Lot Size Input Fields
   if(!m_edit_lot_size.Create(m_chart_id, "edit_lot_size", m_subwin, x_base, y_pos, x_base + edit_width, y_pos + edit_height))
      return false;
   m_edit_lot_size.Text(DoubleToString(Default_Lot_Size, 2));
   if(!Add(m_edit_lot_size))
      return false;

   if(!m_edit_risk_amount.Create(m_chart_id, "edit_risk_amount", m_subwin, x_base + 90, y_pos, x_base + 90 + edit_width, y_pos + edit_height))
      return false;
   m_edit_risk_amount.Text(DoubleToString(Default_Risk_Amount, 2));
   if(!Add(m_edit_risk_amount))
      return false;

   if(!m_edit_risk_percent.Create(m_chart_id, "edit_risk_percent", m_subwin, x_base + 180, y_pos, x_base + 180 + edit_width, y_pos + edit_height))
      return false;
   m_edit_risk_percent.Text(DoubleToString(Default_Risk_Percent, 1));
   if(!Add(m_edit_risk_percent))
      return false;
   y_pos += 26;

   // Final Lot Display
   if(!m_label_final_lot.Create(m_chart_id, "label_final_lot", m_subwin, x_base, y_pos, x_base + 200, y_pos + 18))
      return false;
   m_label_final_lot.Text("Final Lot: 0.00");
   m_label_final_lot.Color(clrBlue);
   if(!Add(m_label_final_lot))
      return false;
   y_pos += 26;

   // SL/TP Mode
   if(!m_label_sltp_mode.Create(m_chart_id, "label_sltp_mode", m_subwin, x_base, y_pos, x_base + 80, y_pos + 18))
      return false;
   m_label_sltp_mode.Text("SLTP Mode:");
   if(!Add(m_label_sltp_mode))
      return false;

   if(!m_combo_sltp_mode.Create(m_chart_id, "combo_sltp_mode", m_subwin, x_base + 85, y_pos, x_base + 85 + combo_width, y_pos + edit_height))
      return false;
   m_combo_sltp_mode.AddItem("Points", SLTP_POINTS);
   m_combo_sltp_mode.AddItem("Price", SLTP_PRICE);
   m_combo_sltp_mode.Select(SLTP_POINTS); // Default choice
   m_combo_sltp_mode.Id(ID_SLTP_MODE);
   if(!Add(m_combo_sltp_mode))
      return false;
   y_pos += 26;

   // SL/TP Input Fields - Points
   if(!m_edit_sl_points.Create(m_chart_id, "edit_sl_points", m_subwin, x_base, y_pos, x_base + edit_width, y_pos + edit_height))
      return false;
   m_edit_sl_points.Text(IntegerToString(Default_Stop_Loss_Points));
   if(!Add(m_edit_sl_points))
      return false;

   if(!m_edit_tp_points.Create(m_chart_id, "edit_tp_points", m_subwin, x_base + 90, y_pos, x_base + 90 + edit_width, y_pos + edit_height))
      return false;
   m_edit_tp_points.Text(IntegerToString(Default_Take_Profit_Points));
   if(!Add(m_edit_tp_points))
      return false;

   // SL/TP Input Fields - Price
   if(!m_edit_sl_price.Create(m_chart_id, "edit_sl_price", m_subwin, x_base + 180, y_pos, x_base + 180 + edit_width, y_pos + edit_height))
      return false;
   m_edit_sl_price.Text(DoubleToString(Default_Stop_Loss_Price, symbol_digits));
   if(!Add(m_edit_sl_price))
      return false;

   if(!m_edit_tp_price.Create(m_chart_id, "edit_tp_price", m_subwin, x_base + 270, y_pos, x_base + 270 + edit_width, y_pos + edit_height))
      return false;
   m_edit_tp_price.Text(DoubleToString(Default_Take_Profit_Price, symbol_digits));
   if(!Add(m_edit_tp_price))
      return false;
   y_pos += 26;

   // SL/TP Amount Display
   if(!m_label_sl_amount.Create(m_chart_id, "label_sl_amount", m_subwin, x_base, y_pos, x_base + 150, y_pos + 18))
      return false;
   m_label_sl_amount.Text("SL: $0.00");
   m_label_sl_amount.Color(clrRed);
   if(!Add(m_label_sl_amount))
      return false;

   if(!m_label_tp_amount.Create(m_chart_id, "label_tp_amount", m_subwin, x_base + 160, y_pos, x_base + 310, y_pos + 18))
      return false;
   m_label_tp_amount.Text("TP: $0.00");
   m_label_tp_amount.Color(clrGreen);
   if(!Add(m_label_tp_amount))
      return false;
   y_pos += 26;

   // Order Count
   if(!m_label_order_count.Create(m_chart_id, "label_order_count", m_subwin, x_base, y_pos, x_base + 80, y_pos + 18))
      return false;
   m_label_order_count.Text("Order Count:");
   if(!Add(m_label_order_count))
      return false;

   if(!m_combo_order_count.Create(m_chart_id, "combo_order_count", m_subwin, x_base + 85, y_pos, x_base + 85 + combo_width, y_pos + edit_height))
      return false;
   m_combo_order_count.AddItem("1 Order", ORDERS_1);
   m_combo_order_count.AddItem("2 Orders", ORDERS_2);
   m_combo_order_count.AddItem("3 Orders", ORDERS_3);
   m_combo_order_count.AddItem("4 Orders", ORDERS_4);
   m_combo_order_count.Select(ORDERS_2); // Default choice
   m_combo_order_count.Id(ID_ORDER_COUNT);
   if(!Add(m_combo_order_count))
      return false;
   y_pos += 28;

   // Buy Now / Sell Now Buttons
   if(!m_btn_buy_now.Create(m_chart_id, "btn_buy_now", m_subwin, x_base, y_pos, x_base + button_width, y_pos + button_height))
      return false;
   m_btn_buy_now.Text("BUY NOW");
   m_btn_buy_now.Color(clrWhite);
   m_btn_buy_now.ColorBackground(clrLimeGreen);
   m_btn_buy_now.Id(ID_BTN_BUY_NOW);
   if(!Add(m_btn_buy_now))
      return false;

   if(!m_btn_sell_now.Create(m_chart_id, "btn_sell_now", m_subwin, x_base + button_width + 10, y_pos, x_base + button_width * 2 + 10, y_pos + button_height))
      return false;
   m_btn_sell_now.Text("SELL NOW");
   m_btn_sell_now.Color(clrWhite);
   m_btn_sell_now.ColorBackground(clrCrimson);
   m_btn_sell_now.Id(ID_BTN_SELL_NOW);
   if(!Add(m_btn_sell_now))
      return false;
   y_pos += 32;

   // Entry Price
   if(!m_edit_entry_price.Create(m_chart_id, "edit_entry_price", m_subwin, x_base, y_pos, x_base + edit_width * 2 + 10, y_pos + edit_height))
      return false;
   m_edit_entry_price.Text("0.00000");
   if(!Add(m_edit_entry_price))
      return false;
   y_pos += 26;

   // Buy Limit / Sell Limit Buttons
   if(!m_btn_buy_limit.Create(m_chart_id, "btn_buy_limit", m_subwin, x_base, y_pos, x_base + button_width, y_pos + button_height))
      return false;
   m_btn_buy_limit.Text("BUY LIMIT");
   m_btn_buy_limit.Color(clrWhite);
   m_btn_buy_limit.ColorBackground(clrDodgerBlue);
   m_btn_buy_limit.Id(ID_BTN_BUY_LIMIT);
   if(!Add(m_btn_buy_limit))
      return false;

   if(!m_btn_sell_limit.Create(m_chart_id, "btn_sell_limit", m_subwin, x_base + button_width + 10, y_pos, x_base + button_width * 2 + 10, y_pos + button_height))
      return false;
   m_btn_sell_limit.Text("SELL LIMIT");
   m_btn_sell_limit.Color(clrWhite);
   m_btn_sell_limit.ColorBackground(clrOrange);
   m_btn_sell_limit.Id(ID_BTN_SELL_LIMIT);
   if(!Add(m_btn_sell_limit))
      return false;
   y_pos += 32;

   // Auto Breakeven
   if(!m_label_auto_be.Create(m_chart_id, "label_auto_be", m_subwin, x_base, y_pos, x_base + 80, y_pos + 18))
      return false;
   m_label_auto_be.Text("Auto BE:");
   if(!Add(m_label_auto_be))
      return false;

   if(!m_combo_auto_be.Create(m_chart_id, "combo_auto_be", m_subwin, x_base + 85, y_pos, x_base + 85 + combo_width, y_pos + edit_height))
      return false;
   m_combo_auto_be.AddItem("Disabled", AUTO_BE_DISABLED);
   m_combo_auto_be.AddItem("After TP1", AUTO_BE_AFTER_TP1);
   m_combo_auto_be.AddItem("After TP2", AUTO_BE_AFTER_TP2);
   m_combo_auto_be.Select(AUTO_BE_DISABLED); // Default choice
   m_combo_auto_be.Id(ID_AUTO_BE_MODE);
   if(!Add(m_combo_auto_be))
      return false;
   y_pos += 28;

   // Close/Delete Filter Header
   if(!m_label_title.Create(m_chart_id, "label_filter_title", m_subwin, x_base, y_pos, x_base + 380, y_pos + 18))
      return false;
   m_label_title.Text("Close/Delete Filter:");
   m_label_title.Color(clrDarkBlue);
   if(!Add(m_label_title))
      return false;
   y_pos += 22;

   // Checkboxes - Row 1: Orders
   if(!m_chk_buy_orders.Create(m_chart_id, "chk_buy_orders", m_subwin, x_base, y_pos, x_base + 80, y_pos + 20))
      return false;
   m_chk_buy_orders.Text("Buy Orders");
   m_chk_buy_orders.Id(ID_CHK_BUY_ORDERS);
   if(!Add(m_chk_buy_orders))
      return false;

   if(!m_chk_sell_orders.Create(m_chart_id, "chk_sell_orders", m_subwin, x_base + 90, y_pos, x_base + 170, y_pos + 20))
      return false;
   m_chk_sell_orders.Text("Sell Orders");
   m_chk_sell_orders.Id(ID_CHK_SELL_ORDERS);
   if(!Add(m_chk_sell_orders))
      return false;
   y_pos += 24;

   // Checkboxes - Row 2: Positions
   if(!m_chk_buy_positions.Create(m_chart_id, "chk_buy_positions", m_subwin, x_base, y_pos, x_base + 90, y_pos + 20))
      return false;
   m_chk_buy_positions.Text("Buy Positions");
   m_chk_buy_positions.Id(ID_CHK_BUY_POSITIONS);
   if(!Add(m_chk_buy_positions))
      return false;

   if(!m_chk_sell_positions.Create(m_chart_id, "chk_sell_positions", m_subwin, x_base + 100, y_pos, x_base + 200, y_pos + 20))
      return false;
   m_chk_sell_positions.Text("Sell Positions");
   m_chk_sell_positions.Id(ID_CHK_SELL_POSITIONS);
   if(!Add(m_chk_sell_positions))
      return false;
   y_pos += 24;

   // Checkboxes - Row 3: Profit/Loss
   if(!m_chk_profit_positions.Create(m_chart_id, "chk_profit_positions", m_subwin, x_base, y_pos, x_base + 80, y_pos + 20))
      return false;
   m_chk_profit_positions.Text("Profit");
   m_chk_profit_positions.Id(ID_CHK_PROFIT_POSITIONS);
   if(!Add(m_chk_profit_positions))
      return false;

   if(!m_chk_loss_positions.Create(m_chart_id, "chk_loss_positions", m_subwin, x_base + 90, y_pos, x_base + 160, y_pos + 20))
      return false;
   m_chk_loss_positions.Text("Loss");
   m_chk_loss_positions.Id(ID_CHK_LOSS_POSITIONS);
   if(!Add(m_chk_loss_positions))
      return false;
   y_pos += 28;

   // Action Buttons - Row 1
   if(!m_btn_close_positions.Create(m_chart_id, "btn_close_positions", m_subwin, x_base, y_pos, x_base + button_width + 20, y_pos + button_height))
      return false;
   m_btn_close_positions.Text("Close Positions");
   m_btn_close_positions.Color(clrWhite);
   m_btn_close_positions.ColorBackground(clrRed);
   m_btn_close_positions.Id(ID_BTN_CLOSE_POSITIONS);
   if(!Add(m_btn_close_positions))
      return false;

   if(!m_btn_delete_orders.Create(m_chart_id, "btn_delete_orders", m_subwin, x_base + button_width + 30, y_pos, x_base + button_width * 2 + 30, y_pos + button_height))
      return false;
   m_btn_delete_orders.Text("Delete Orders");
   m_btn_delete_orders.Color(clrWhite);
   m_btn_delete_orders.ColorBackground(clrOrangeRed);
   m_btn_delete_orders.Id(ID_BTN_DELETE_ORDERS);
   if(!Add(m_btn_delete_orders))
      return false;
   y_pos += 28;

   // Status
   if(!m_label_status.Create(m_chart_id, "label_status", m_subwin, x_base, y_pos, x_base + 380, y_pos + 18))
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
   // Handle combo box changes
   if(id == CHARTEVENT_CUSTOM)
   {
      if(lparam == ID_LOT_MODE)
      {
         OnChangeLotMode();
         return true;
      }
      if(lparam == ID_SLTP_MODE)
      {
         OnChangeSLTPMode();
         return true;
      }
      if(lparam == ID_ORDER_COUNT)
      {
         UpdateLossProfitDisplay();
         return true;
      }
      if(lparam == ID_AUTO_BE_MODE)
      {
         return true;
      }

      // Handle button clicks
      if(lparam == ID_BTN_BUY_NOW)
      {
         OnClickBuyNow();
         return true;
      }
      if(lparam == ID_BTN_SELL_NOW)
      {
         OnClickSellNow();
         return true;
      }
      if(lparam == ID_BTN_BUY_LIMIT)
      {
         OnClickBuyLimit();
         return true;
      }
      if(lparam == ID_BTN_SELL_LIMIT)
      {
         OnClickSellLimit();
         return true;
      }
      if(lparam == ID_BTN_CLOSE_POSITIONS)
      {
         OnClickClosePositions();
         return true;
      }
      if(lparam == ID_BTN_DELETE_ORDERS)
      {
         OnClickDeleteOrders();
         return true;
      }

      // Handle checkbox clicks
      if(lparam == ID_CHK_BUY_ORDERS || lparam == ID_CHK_SELL_ORDERS ||
         lparam == ID_CHK_BUY_POSITIONS || lparam == ID_CHK_SELL_POSITIONS ||
         lparam == ID_CHK_PROFIT_POSITIONS || lparam == ID_CHK_LOSS_POSITIONS)
      {
         return true;
      }
   }

   // Handle edit field changes
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      OnChangeEdit();
      // Don't return yet - let base class handle it too for proper state management
   }

   // Call base class to handle minimize/maximize/close and other internal events
   return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Button click handlers                                            |
//+------------------------------------------------------------------+
void CMultiTradeDialog::OnClickBuyNow(void)
{
   ExecuteMarketTrade(true);
}

void CMultiTradeDialog::OnClickSellNow(void)
{
   ExecuteMarketTrade(false);
}

void CMultiTradeDialog::OnClickBuyLimit(void)
{
   ExecuteLimitOrder(true);
}

void CMultiTradeDialog::OnClickSellLimit(void)
{
   ExecuteLimitOrder(false);
}

void CMultiTradeDialog::OnClickClosePositions(void)
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
            // Check filter conditions
            bool should_close = false;
            ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double profit = PositionGetDouble(POSITION_PROFIT);

            // Check position type filter
            if((m_chk_buy_positions.Checked() && pos_type == POSITION_TYPE_BUY) ||
               (m_chk_sell_positions.Checked() && pos_type == POSITION_TYPE_SELL))
            {
               // Check profit/loss filter
               if((m_chk_profit_positions.Checked() && profit > 0) ||
                  (m_chk_loss_positions.Checked() && profit <= 0) ||
                  (!m_chk_profit_positions.Checked() && !m_chk_loss_positions.Checked()))
               {
                  should_close = true;
               }
            }

            if(should_close)
            {
               ulong ticket = PositionGetInteger(POSITION_TICKET);
               if(trade.PositionClose(ticket))
                  closed_count++;
            }
         }
      }
   }

   if(closed_count > 0)
      UpdateStatus("Closed " + IntegerToString(closed_count) + " positions", clrGreen);
   else
      UpdateStatus("No positions match filter", clrOrange);
}

void CMultiTradeDialog::OnClickDeleteOrders(void)
{
   UpdateStatus("Deleting orders...", clrBlue);

   int deleted_count = 0;
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
               // Check filter conditions
               bool should_delete = false;
               ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

               if((m_chk_buy_orders.Checked() && (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP)) ||
                  (m_chk_sell_orders.Checked() && (order_type == ORDER_TYPE_SELL_LIMIT || order_type == ORDER_TYPE_SELL_STOP)))
               {
                  should_delete = true;
               }

               if(should_delete)
               {
                  ulong ticket = OrderGetInteger(ORDER_TICKET);
                  if(trade.OrderDelete(ticket))
                     deleted_count++;
               }
            }
         }
      }
   }

   if(deleted_count > 0)
      UpdateStatus("Deleted " + IntegerToString(deleted_count) + " orders", clrGreen);
   else
      UpdateStatus("No orders match filter", clrOrange);
}

//+------------------------------------------------------------------+
//| Change handlers                                                  |
//+------------------------------------------------------------------+
void CMultiTradeDialog::OnChangeLotMode(void)
{
   UpdateLotSizeMode();
   UpdateFinalLotDisplay();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnChangeSLTPMode(void)
{
   UpdateSLTPMode();
   UpdateLossProfitDisplay();
   SaveSettings();
}

void CMultiTradeDialog::OnChangeEdit(void)
{
   UpdateFinalLotDisplay();
   UpdateLossProfitDisplay();
   SaveSettings();
}

//+------------------------------------------------------------------+
//| Update functions                                                 |
//+------------------------------------------------------------------+
void CMultiTradeDialog::UpdateStatus(string status, color clr)
{
   m_label_status.Text(status);
   m_label_status.Color(clr);
}

void CMultiTradeDialog::UpdateLotSizeMode()
{
   ENUM_LOT_MODE mode = (ENUM_LOT_MODE)(int)m_combo_lot_mode.Value();

   switch(mode)
   {
      case LOT_FIXED:
         m_edit_lot_size.ReadOnly(false);
         m_edit_risk_amount.ReadOnly(true);
         m_edit_risk_percent.ReadOnly(true);
         m_edit_lot_size.ColorBackground(clrWhite);
         m_edit_risk_amount.ColorBackground(clrLightGray);
         m_edit_risk_percent.ColorBackground(clrLightGray);
         break;

      case LOT_RISK_AMOUNT:
         m_edit_lot_size.ReadOnly(true);
         m_edit_risk_amount.ReadOnly(false);
         m_edit_risk_percent.ReadOnly(true);
         m_edit_lot_size.ColorBackground(clrLightGray);
         m_edit_risk_amount.ColorBackground(clrWhite);
         m_edit_risk_percent.ColorBackground(clrLightGray);
         break;

      case LOT_RISK_BALANCE:
      case LOT_RISK_EQUITY:
         m_edit_lot_size.ReadOnly(true);
         m_edit_risk_amount.ReadOnly(true);
         m_edit_risk_percent.ReadOnly(false);
         m_edit_lot_size.ColorBackground(clrLightGray);
         m_edit_risk_amount.ColorBackground(clrLightGray);
         m_edit_risk_percent.ColorBackground(clrWhite);
         break;
   }
}

void CMultiTradeDialog::UpdateSLTPMode()
{
   ENUM_SLTP_MODE mode = (ENUM_SLTP_MODE)(int)m_combo_sltp_mode.Value();

   switch(mode)
   {
      case SLTP_POINTS:
         m_edit_sl_points.ReadOnly(false);
         m_edit_tp_points.ReadOnly(false);
         m_edit_sl_price.ReadOnly(true);
         m_edit_tp_price.ReadOnly(true);
         m_edit_sl_points.ColorBackground(clrWhite);
         m_edit_tp_points.ColorBackground(clrWhite);
         m_edit_sl_price.ColorBackground(clrLightGray);
         m_edit_tp_price.ColorBackground(clrLightGray);
         break;

      case SLTP_PRICE:
         m_edit_sl_points.ReadOnly(true);
         m_edit_tp_points.ReadOnly(true);
         m_edit_sl_price.ReadOnly(false);
         m_edit_tp_price.ReadOnly(false);
         m_edit_sl_points.ColorBackground(clrLightGray);
         m_edit_tp_points.ColorBackground(clrLightGray);
         m_edit_sl_price.ColorBackground(clrWhite);
         m_edit_tp_price.ColorBackground(clrWhite);
         break;
   }
}

void CMultiTradeDialog::UpdateFinalLotDisplay()
{
   double lot_size = CalculateLotSize();
   m_label_final_lot.Text("Final Lot: " + DoubleToString(lot_size, 2));
}

void CMultiTradeDialog::UpdateLossProfitDisplay()
{
   if(current_bid <= 0 || current_ask <= 0) return;

   double lot_size = CalculateLotSize();
   double reference_price = current_ask; // Default to ask for display purposes

   ENUM_SLTP_MODE sltp_mode = (ENUM_SLTP_MODE)(int)m_combo_sltp_mode.Value();
   double sl_price = 0, tp_price = 0;

   if(sltp_mode == SLTP_POINTS)
   {
      int sl_points = (int)StringToInteger(m_edit_sl_points.Text());
      int tp_points = (int)StringToInteger(m_edit_tp_points.Text());

      if(sl_points > 0)
         sl_price = reference_price - sl_points * symbol_point;
      if(tp_points > 0)
         tp_price = reference_price + tp_points * symbol_point;
   }
   else
   {
      sl_price = StringToDouble(m_edit_sl_price.Text());
      tp_price = StringToDouble(m_edit_tp_price.Text());
   }

   // Calculate SL amount
   if(sl_price > 0)
   {
      double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
      double ticks = MathAbs(reference_price - sl_price) / tick_size;
      double loss = lot_size * ticks * tick_value;
      m_label_sl_amount.Text("SL: $" + DoubleToString(loss, 2));
   }
   else
   {
      m_label_sl_amount.Text("SL: $0.00");
   }

   // Calculate TP amount
   if(tp_price > 0)
   {
      double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
      double ticks = MathAbs(tp_price - reference_price) / tick_size;
      double profit = lot_size * ticks * tick_value;
      m_label_tp_amount.Text("TP: $" + DoubleToString(profit, 2));
   }
   else
   {
      m_label_tp_amount.Text("TP: $0.00");
   }
}

//+------------------------------------------------------------------+
//| Trade execution functions                                       |
//+------------------------------------------------------------------+
void CMultiTradeDialog::ExecuteMarketTrade(bool is_buy)
{
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
   {
      UpdateStatus("Trading disabled in terminal", clrRed);
      return;
   }

   double lot_size = CalculateLotSize();

   if(lot_size < symbol_min_lot || lot_size > symbol_max_lot)
   {
      UpdateStatus("Invalid lot size", clrRed);
      return;
   }

   ENUM_ORDER_COUNT order_count = (ENUM_ORDER_COUNT)(int)m_combo_order_count.Value();
   int num_orders = order_count + 1;

   UpdateStatus("Executing " + IntegerToString(num_orders) + " " + (is_buy ? "BUY" : "SELL") + " trades...", clrBlue);

   int successful_trades = 0;
   ulong tickets[4];
   double entries[4];

   for(int i = 0; i < num_orders; i++)
   {
      double sl_price = GetStopLossPrice(is_buy, 0); // Market order uses 0 as entry
      double tp_price = GetTakeProfitPrice(is_buy, 0, i);

      bool result = false;
      string comment = Trade_Comment + " " + (is_buy ? "Buy" : "Sell") + " #" + IntegerToString(i + 1);

      for(int attempt = 0; attempt <= 2; attempt++)
      {
         if(is_buy)
            result = trade.Buy(lot_size, current_symbol, 0, sl_price, tp_price, comment);
         else
            result = trade.Sell(lot_size, current_symbol, 0, sl_price, tp_price, comment);

         if(result) break;
         Sleep(50);
      }

      if(result)
      {
         successful_trades++;
         ulong ticket = trade.ResultOrder();
         tickets[i] = ticket;

         if(PositionSelectByTicket(ticket))
         {
            entries[i] = PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }

   // Create BE group if we have 2 or more successful trades
   if(successful_trades >= 2)
   {
      double avg_entry = 0;
      for(int i = 0; i < successful_trades; i++)
         avg_entry += entries[i];
      avg_entry /= successful_trades;

      CreateTradeGroup(tickets[0], tickets[1], avg_entry);
   }

   if(successful_trades == num_orders)
      UpdateStatus(IntegerToString(successful_trades) + " trades opened", clrGreen);
   else if(successful_trades > 0)
      UpdateStatus(IntegerToString(successful_trades) + "/" + IntegerToString(num_orders) + " trades opened", clrOrange);
   else
      UpdateStatus("All trades failed", clrRed);
}

void CMultiTradeDialog::ExecuteLimitOrder(bool is_buy)
{
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 0)
   {
      UpdateStatus("Trading disabled in terminal", clrRed);
      return;
   }

   double lot_size = CalculateLotSize();
   double entry_price = StringToDouble(m_edit_entry_price.Text());

   if(lot_size < symbol_min_lot || lot_size > symbol_max_lot)
   {
      UpdateStatus("Invalid lot size", clrRed);
      return;
   }

   if(entry_price <= 0)
   {
      UpdateStatus("Invalid entry price", clrRed);
      return;
   }

   ENUM_ORDER_COUNT order_count = (ENUM_ORDER_COUNT)(int)m_combo_order_count.Value();
   int num_orders = order_count + 1;

   UpdateStatus("Placing " + IntegerToString(num_orders) + " " + (is_buy ? "BUY LIMIT" : "SELL LIMIT") + " orders...", clrBlue);

   int successful_orders = 0;

   for(int i = 0; i < num_orders; i++)
   {
      double sl_price = GetStopLossPrice(is_buy, entry_price);
      double tp_price = GetTakeProfitPrice(is_buy, entry_price, i);

      ENUM_ORDER_TYPE order_type = is_buy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
      string comment = Trade_Comment + " " + (is_buy ? "BuyLimit" : "SellLimit") + " #" + IntegerToString(i + 1);

      bool result = false;
      for(int attempt = 0; attempt <= 2; attempt++)
      {
         result = trade.OrderOpen(current_symbol, order_type, lot_size, 0, entry_price, sl_price, tp_price,
                                 ORDER_TIME_SPECIFIED, Order_Expiration, comment);
         if(result) break;
         Sleep(50);
      }

      if(result)
         successful_orders++;
   }

   if(successful_orders == num_orders)
      UpdateStatus(IntegerToString(successful_orders) + " orders placed", clrGreen);
   else if(successful_orders > 0)
      UpdateStatus(IntegerToString(successful_orders) + "/" + IntegerToString(num_orders) + " orders placed", clrOrange);
   else
      UpdateStatus("All orders failed", clrRed);
}

//+------------------------------------------------------------------+
//| Calculation functions                                           |
//+------------------------------------------------------------------+
double CMultiTradeDialog::CalculateLotSize()
{
   ENUM_LOT_MODE mode = (ENUM_LOT_MODE)(int)m_combo_lot_mode.Value();
   double lot_size = 0;

   switch(mode)
   {
      case LOT_FIXED:
         lot_size = StringToDouble(m_edit_lot_size.Text());
         break;

      case LOT_RISK_AMOUNT:
      {
         double risk_amount = StringToDouble(m_edit_risk_amount.Text());
         ENUM_SLTP_MODE sltp_mode = (ENUM_SLTP_MODE)(int)m_combo_sltp_mode.Value();
         double sl_points = 0;

         if(sltp_mode == SLTP_POINTS)
         {
            sl_points = (int)StringToInteger(m_edit_sl_points.Text());
         }
         else
         {
            double sl_price = StringToDouble(m_edit_sl_price.Text());
            if(sl_price > 0 && current_ask > 0)
               sl_points = MathAbs(current_ask - sl_price) / symbol_point;
         }

         if(sl_points > 0)
         {
            double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
            lot_size = risk_amount / (sl_points * tick_value);
         }
         break;
      }

      case LOT_RISK_BALANCE:
      {
         double risk_percent = StringToDouble(m_edit_risk_percent.Text()) / 100.0;
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double risk_amount = balance * risk_percent;

         ENUM_SLTP_MODE sltp_mode = (ENUM_SLTP_MODE)(int)m_combo_sltp_mode.Value();
         double sl_points = 0;

         if(sltp_mode == SLTP_POINTS)
         {
            sl_points = (int)StringToInteger(m_edit_sl_points.Text());
         }
         else
         {
            double sl_price = StringToDouble(m_edit_sl_price.Text());
            if(sl_price > 0 && current_ask > 0)
               sl_points = MathAbs(current_ask - sl_price) / symbol_point;
         }

         if(sl_points > 0)
         {
            double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
            lot_size = risk_amount / (sl_points * tick_value);
         }
         break;
      }

      case LOT_RISK_EQUITY:
      {
         double risk_percent = StringToDouble(m_edit_risk_percent.Text()) / 100.0;
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double risk_amount = equity * risk_percent;

         ENUM_SLTP_MODE sltp_mode = (ENUM_SLTP_MODE)(int)m_combo_sltp_mode.Value();
         double sl_points = 0;

         if(sltp_mode == SLTP_POINTS)
         {
            sl_points = (int)StringToInteger(m_edit_sl_points.Text());
         }
         else
         {
            double sl_price = StringToDouble(m_edit_sl_price.Text());
            if(sl_price > 0 && current_ask > 0)
               sl_points = MathAbs(current_ask - sl_price) / symbol_point;
         }

         if(sl_points > 0)
         {
            double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
            lot_size = risk_amount / (sl_points * tick_value);
         }
         break;
      }
   }

   // Normalize lot size to broker requirements
   if(symbol_lot_step > 0)
      lot_size = MathRound(lot_size / symbol_lot_step) * symbol_lot_step;
   if(lot_size < symbol_min_lot) lot_size = symbol_min_lot;
   if(lot_size > symbol_max_lot) lot_size = symbol_max_lot;

   return lot_size;
}

double CMultiTradeDialog::GetStopLossPrice(bool is_buy, double entry_price)
{
   ENUM_SLTP_MODE mode = (ENUM_SLTP_MODE)m_combo_sltp_mode.Value();

   if(mode == SLTP_POINTS)
   {
      int sl_points = (int)StringToInteger(m_edit_sl_points.Text());
      if(entry_price == 0)
         entry_price = is_buy ? current_ask : current_bid;

      return is_buy ? entry_price - sl_points * symbol_point : entry_price + sl_points * symbol_point;
   }
   else
   {
      return StringToDouble(m_edit_sl_price.Text());
   }
}

double CMultiTradeDialog::GetTakeProfitPrice(bool is_buy, double entry_price, int order_index)
{
   ENUM_SLTP_MODE mode = (ENUM_SLTP_MODE)m_combo_sltp_mode.Value();
   ENUM_ORDER_COUNT order_count = (ENUM_ORDER_COUNT)(int)m_combo_order_count.Value();
   int num_orders = order_count + 1;

   if(mode == SLTP_POINTS)
   {
      int tp_points = (int)StringToInteger(m_edit_tp_points.Text());
      if(entry_price == 0)
         entry_price = is_buy ? current_ask : current_bid;

      // Add additional TP for orders 2, 3, and 4
      int additional_points = 0;
      if(order_index == 1) additional_points = 500;  // +50 pips for TP2
      if(order_index == 2) additional_points = 1000; // +100 pips for TP3
      if(order_index == 3) additional_points = 1500; // +150 pips for TP4 (runner)

      return is_buy ? entry_price + (tp_points + additional_points) * symbol_point
                    : entry_price - (tp_points + additional_points) * symbol_point;
   }
   else
   {
      double base_tp = StringToDouble(m_edit_tp_price.Text());
      if(base_tp == 0) return 0;

      // Add additional TP for orders 2, 3, and 4 (50 pips = 500 points for 5-digit brokers)
      if(order_index == 1) return is_buy ? base_tp + 500 * symbol_point : base_tp - 500 * symbol_point;
      if(order_index == 2) return is_buy ? base_tp + 1000 * symbol_point : base_tp - 1000 * symbol_point;
      if(order_index == 3) return 0; // No TP4 for runner

      return base_tp;
   }
}

//+------------------------------------------------------------------+
//| Auto-Breakeven Helper Functions                                  |
//+------------------------------------------------------------------+
void CMultiTradeDialog::CreateTradeGroup(ulong ticket1, ulong ticket2, double avg_entry)
{
   int new_size = active_group_count + 1;
   if(ArrayResize(active_groups, new_size) < 0)
   {
      Print("[ERROR] Failed to resize active_groups array");
      return;
   }

   active_groups[active_group_count].ticket_tp1 = ticket1;
   active_groups[active_group_count].ticket_tp2 = ticket2;
   active_groups[active_group_count].entry_price = avg_entry;
   active_groups[active_group_count].be_moved = false;
   active_groups[active_group_count].created_time = TimeCurrent();

   active_group_count++;

   Print("[BE] Trade group created | TP1: ", ticket1, " | TP2: ", ticket2, " | Entry: ", avg_entry);
}

//+------------------------------------------------------------------+
//| Save Settings Method                                             |
//+------------------------------------------------------------------+
void CMultiTradeDialog::SaveSettings()
{
   GlobalVariableSet(GV_LOT_MODE, (double)(int)m_combo_lot_mode.Value());
   GlobalVariableSet(GV_LOT_SIZE, StringToDouble(m_edit_lot_size.Text()));
   GlobalVariableSet(GV_RISK_AMOUNT, StringToDouble(m_edit_risk_amount.Text()));
   GlobalVariableSet(GV_RISK_PERCENT, StringToDouble(m_edit_risk_percent.Text()));
   GlobalVariableSet(GV_SLTP_MODE, (double)(int)m_combo_sltp_mode.Value());
   GlobalVariableSet(GV_SL_POINTS, (double)(int)StringToInteger(m_edit_sl_points.Text()));
   GlobalVariableSet(GV_TP_POINTS, (double)(int)StringToInteger(m_edit_tp_points.Text()));
   GlobalVariableSet(GV_SL_PRICE, StringToDouble(m_edit_sl_price.Text()));
   GlobalVariableSet(GV_TP_PRICE, StringToDouble(m_edit_tp_price.Text()));
   GlobalVariableSet(GV_ORDER_COUNT, (double)(int)m_combo_order_count.Value());
   GlobalVariableSet(GV_ENTRY_PRICE, StringToDouble(m_edit_entry_price.Text()));
   GlobalVariableSet(GV_AUTO_BE_MODE, (double)(int)m_combo_auto_be.Value());
   GlobalVariableSet(GV_CHK_BUY_ORDERS, m_chk_buy_orders.Checked() ? 1.0 : 0.0);
   GlobalVariableSet(GV_CHK_SELL_ORDERS, m_chk_sell_orders.Checked() ? 1.0 : 0.0);
   GlobalVariableSet(GV_CHK_BUY_POSITIONS, m_chk_buy_positions.Checked() ? 1.0 : 0.0);
   GlobalVariableSet(GV_CHK_SELL_POSITIONS, m_chk_sell_positions.Checked() ? 1.0 : 0.0);
   GlobalVariableSet(GV_CHK_PROFIT_POSITIONS, m_chk_profit_positions.Checked() ? 1.0 : 0.0);
   GlobalVariableSet(GV_CHK_LOSS_POSITIONS, m_chk_loss_positions.Checked() ? 1.0 : 0.0);
}

void LoadSettings()
{
   if(!GlobalVariableCheck(GV_LOT_MODE))
   {
      Print("[MEMORY] No saved settings found. Using input parameters.");
      return;
   }

   g_dialog.m_combo_lot_mode.Select((int)GlobalVariableGet(GV_LOT_MODE));
   g_dialog.m_edit_lot_size.Text(DoubleToString(GlobalVariableGet(GV_LOT_SIZE), 2));
   g_dialog.m_edit_risk_amount.Text(DoubleToString(GlobalVariableGet(GV_RISK_AMOUNT), 2));
   g_dialog.m_edit_risk_percent.Text(DoubleToString(GlobalVariableGet(GV_RISK_PERCENT), 1));
   g_dialog.m_combo_sltp_mode.Select((int)GlobalVariableGet(GV_SLTP_MODE));
   g_dialog.m_edit_sl_points.Text(IntegerToString((int)GlobalVariableGet(GV_SL_POINTS)));
   g_dialog.m_edit_tp_points.Text(IntegerToString((int)GlobalVariableGet(GV_TP_POINTS)));
   g_dialog.m_edit_sl_price.Text(DoubleToString(GlobalVariableGet(GV_SL_PRICE), symbol_digits));
   g_dialog.m_edit_tp_price.Text(DoubleToString(GlobalVariableGet(GV_TP_PRICE), symbol_digits));
   g_dialog.m_combo_order_count.Select((int)GlobalVariableGet(GV_ORDER_COUNT));
   g_dialog.m_edit_entry_price.Text(DoubleToString(GlobalVariableGet(GV_ENTRY_PRICE), symbol_digits));
   g_dialog.m_combo_auto_be.Select((int)GlobalVariableGet(GV_AUTO_BE_MODE));
   g_dialog.m_chk_buy_orders.Checked(GlobalVariableGet(GV_CHK_BUY_ORDERS) > 0.5);
   g_dialog.m_chk_sell_orders.Checked(GlobalVariableGet(GV_CHK_SELL_ORDERS) > 0.5);
   g_dialog.m_chk_buy_positions.Checked(GlobalVariableGet(GV_CHK_BUY_POSITIONS) > 0.5);
   g_dialog.m_chk_sell_positions.Checked(GlobalVariableGet(GV_CHK_SELL_POSITIONS) > 0.5);
   g_dialog.m_chk_profit_positions.Checked(GlobalVariableGet(GV_CHK_PROFIT_POSITIONS) > 0.5);
   g_dialog.m_chk_loss_positions.Checked(GlobalVariableGet(GV_CHK_LOSS_POSITIONS) > 0.5);

   g_dialog.UpdateLotSizeMode();
   g_dialog.UpdateSLTPMode();
   g_dialog.UpdateFinalLotDisplay();
   g_dialog.UpdateLossProfitDisplay();
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   InitializeSymbolData();

   trade.SetExpertMagicNumber(Magic_Number);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(current_symbol);

   if(!g_dialog.Create(0, "MultiTradeManager", 0, Panel_X_Position, Panel_Y_Position,
                        Panel_X_Position + 400, Panel_Y_Position + 600))
   {
      Print("Failed to create dialog");
      return INIT_FAILED;
   }

   if(!g_dialog.Run())
   {
      Print("Failed to run dialog");
      return INIT_FAILED;
   }

   LoadSettings();

   Print("=== MultiTradeManager EA v3.0 Initialized ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Starting deinitialization (reason: ", reason, ")");

   g_dialog.Destroy(reason);

   // Clean up global variables
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
   {
      GlobalVariableDel(GV_LOT_MODE);
      GlobalVariableDel(GV_LOT_SIZE);
      GlobalVariableDel(GV_RISK_AMOUNT);
      GlobalVariableDel(GV_RISK_PERCENT);
      GlobalVariableDel(GV_SLTP_MODE);
      GlobalVariableDel(GV_SL_POINTS);
      GlobalVariableDel(GV_TP_POINTS);
      GlobalVariableDel(GV_SL_PRICE);
      GlobalVariableDel(GV_TP_PRICE);
      GlobalVariableDel(GV_ORDER_COUNT);
      GlobalVariableDel(GV_ENTRY_PRICE);
      GlobalVariableDel(GV_AUTO_BE_MODE);
      GlobalVariableDel(GV_CHK_BUY_ORDERS);
      GlobalVariableDel(GV_CHK_SELL_ORDERS);
      GlobalVariableDel(GV_CHK_BUY_POSITIONS);
      GlobalVariableDel(GV_CHK_SELL_POSITIONS);
      GlobalVariableDel(GV_CHK_PROFIT_POSITIONS);
      GlobalVariableDel(GV_CHK_LOSS_POSITIONS);
   }

   ChartRedraw();
   Sleep(100);

   Print("MultiTradeManager EA v3.0 deinitialized successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   uint current_time = GetTickCount();

   current_bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
   current_ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);

   if(current_time - last_gui_update > GUI_UPDATE_THRESHOLD)
   {
      g_dialog.UpdateLossProfitDisplay();
      ChartRedraw();
      last_gui_update = current_time;
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      return;
   }

   g_dialog.ChartEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+