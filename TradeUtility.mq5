//+------------------------------------------------------------------+
//|                                            TradeUtility.mq5       |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Trade Utility Panel - CAppDialog Framework"

// Include required libraries
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Label.mqh>
#include <Controls\ComboBox.mqh>
#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Panel Settings ==="
input int Panel_X_Position = 5;
input int Panel_Y_Position = 85;
input int Panel_Width = 350;
input int Panel_Height = 475;
input color Panel_Background = clrWhiteSmoke;
input color Panel_Border = clrDarkBlue;

input group "=== Trading Parameters ==="
input double Default_Risk_Percent = 1.0;
input ulong Magic_Number = 12345;
input string Trade_Comment = "TradeUtility";

//--- Constants
#define COUNT_UPDATE_THRESHOLD 1000
#define GUI_UPDATE_THRESHOLD 100

//--- Control IDs (start from 100 to avoid collision with CAppDialog internal IDs)
enum
{
    ID_BTN_BUY = 100,
    ID_BTN_SELL,
    ID_BTN_CANCEL_ALL,
    ID_BTN_CLOSE_ALL,
    ID_COMBO_ORDER_TYPE,
    ID_COMBO_ORDER_COUNT,
    ID_COMBO_BREAK_EVEN,
    ID_EDIT_ENTRY_PRICE,
    ID_EDIT_SL,
    ID_EDIT_TP1,
    ID_EDIT_TP2,
    ID_EDIT_TP3,
    ID_EDIT_TP4,
    ID_EDIT_RISK_PERCENT
};

//--- Enums for dropdowns
enum UTILITY_ORDER_TYPE
{
    UTILITY_ORDER_MARKET = 0,
    UTILITY_ORDER_PENDING = 1
};

enum ORDER_COUNT
{
    ORDERS_1 = 1,
    ORDERS_2 = 2,
    ORDERS_3 = 3,
    ORDERS_4 = 4
};

enum BREAK_EVEN_MODE
{
    BE_DISABLED = 0,
    BE_AFTER_TP1 = 1,
    BE_AFTER_TP2 = 2
};

enum TRADE_DIRECTION
{
    TRADE_BUY = 0,
    TRADE_SELL = 1
};

//--- Global variables
CTrade trade;
string current_symbol;
double current_bid = 0, current_ask = 0;
double symbol_point;
double symbol_tick_value;
double symbol_min_lot;
double symbol_max_lot;
double symbol_lot_step;
int symbol_digits;
uint last_gui_update = 0;

//+------------------------------------------------------------------+
//| Trade Utility Dialog Class                                       |
//+------------------------------------------------------------------+
class CTradeUtilityDialog : public CAppDialog
{
public:
    // Public members
    UTILITY_ORDER_TYPE m_selected_order_type;
    ORDER_COUNT m_selected_order_count;
    BREAK_EVEN_MODE m_selected_be_mode;
    TRADE_DIRECTION m_selected_direction;
    double m_risk_percent;

private:
    // Control members - Buttons
    CButton m_btn_buy, m_btn_sell;
    CButton m_btn_cancel_all, m_btn_close_all;

    // Control members - ComboBoxes
    CComboBox m_combo_order_type, m_combo_order_count, m_combo_breakeven;

    // Control members - Edit fields
    CEdit m_edit_entry_price, m_edit_sl, m_edit_tp1, m_edit_tp2, m_edit_tp3, m_edit_tp4, m_edit_risk_percent, m_edit_lot_size;

    // Control members - Labels (static text)
    CLabel m_label_title, m_label_symbol, m_label_symbol_value;
    CLabel m_label_min_lot, m_label_min_lot_value;
    CLabel m_label_risk_percent, m_label_order_type, m_label_entry_price;
    CLabel m_label_order_count, m_label_lot_size, m_label_sl, m_label_sl_amount;
    CLabel m_label_tp1, m_label_tp1_amount, m_label_tp2, m_label_tp2_amount;
    CLabel m_label_tp3, m_label_tp3_amount, m_label_tp4, m_label_tp4_amount;
    CLabel m_label_breakeven;

public:
    CTradeUtilityDialog(void);
    ~CTradeUtilityDialog(void);

    virtual bool Create(const long chart, const string name, const int subwin,
                       const int x1, const int y1, const int x2, const int y2);
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

    void UpdateLotSizeDisplay(void);
    void UpdateEntryPriceDisplay(void);
    void UpdateTPFieldStates(void);
    void UpdateButtonTexts(void);
    void UpdateRiskDisplay(void);

    // Public accessor methods for state persistence
    string GetEntryPriceText(void) { return m_edit_entry_price.Text(); }
    string GetSLText(void) { return m_edit_sl.Text(); }
    string GetTP1Text(void) { return m_edit_tp1.Text(); }
    string GetTP2Text(void) { return m_edit_tp2.Text(); }
    string GetTP3Text(void) { return m_edit_tp3.Text(); }
    string GetTP4Text(void) { return m_edit_tp4.Text(); }

    void SetEntryPriceText(string text) { m_edit_entry_price.Text(text); }
    void SetSLText(string text) { m_edit_sl.Text(text); }
    void SetTP1Text(string text) { m_edit_tp1.Text(text); }
    void SetTP2Text(string text) { m_edit_tp2.Text(text); }
    void SetTP3Text(string text) { m_edit_tp3.Text(text); }
    void SetTP4Text(string text) { m_edit_tp4.Text(text); }

protected:
    bool CreateControls(void);

    void OnClickBuy(void);
    void OnClickSell(void);
    void OnClickCancelAll(void);
    void OnClickCloseAll(void);
    void OnChangeOrderType(void);
    void OnChangeOrderCount(void);
    void OnChangeEdit(void);
    void PlaceOrder(void);
};

//+------------------------------------------------------------------+
//| Update methods implementation                                    |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::UpdateLotSizeDisplay(void)
{
    double sl_price = StringToDouble(m_edit_sl.Text());
    double risk_percent = StringToDouble(m_edit_risk_percent.Text()) / 100.0;
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);

    if(sl_price > 0 && risk_percent > 0 && account_balance > 0)
    {
       // Calculate risk amount in account currency
       double risk_amount = account_balance * risk_percent;

       // Calculate pip difference for SL
       double reference_price = (m_selected_order_type == UTILITY_ORDER_MARKET) ?
          ((m_selected_direction == TRADE_BUY) ? current_ask : current_bid) :
          StringToDouble(m_edit_entry_price.Text());

       if(reference_price > 0)
       {
          double price_diff = MathAbs(reference_price - sl_price);
          double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
          double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
          double ticks_in_sl = price_diff / tick_size;

          // Calculate lot size based on risk
          double lot_size = risk_amount / (ticks_in_sl * tick_value);

          // Normalize to broker requirements
          if(symbol_lot_step > 0)
             lot_size = MathRound(lot_size / symbol_lot_step) * symbol_lot_step;
          if(lot_size < symbol_min_lot) lot_size = symbol_min_lot;
          if(lot_size > symbol_max_lot) lot_size = symbol_max_lot;

          m_edit_lot_size.Text(DoubleToString(lot_size, 2));
       }
    }
    else
    {
       m_edit_lot_size.Text("0.00");
    }
}

void CTradeUtilityDialog::UpdateEntryPriceDisplay(void)
{
    if(m_selected_order_type == UTILITY_ORDER_MARKET)
    {
       double price = (m_selected_direction == TRADE_BUY) ? current_ask : current_bid;
       m_edit_entry_price.Text(DoubleToString(price, symbol_digits));
       m_edit_entry_price.ReadOnly(true);
       m_edit_entry_price.ColorBackground(clrLightGray);
    }
    else
    {
       m_edit_entry_price.ReadOnly(false);
       m_edit_entry_price.ColorBackground(clrWhite);
       // Keep current value if user has entered something
       if(StringToDouble(m_edit_entry_price.Text()) == 0)
          m_edit_entry_price.Text("0.00000");
    }
}

void CTradeUtilityDialog::UpdateTPFieldStates(void)
{
    // TP1 is always enabled
    m_edit_tp1.ReadOnly(false);
    m_edit_tp1.ColorBackground(clrWhite);

    // TP2 enabled if order count >= 2
    if(m_selected_order_count >= ORDERS_2)
    {
       m_edit_tp2.ReadOnly(false);
       m_edit_tp2.ColorBackground(clrWhite);
    }
    else
    {
       m_edit_tp2.ReadOnly(true);
       m_edit_tp2.ColorBackground(clrLightGray);
       m_edit_tp2.Text("0.00000");
    }

    // TP3 enabled if order count >= 3
    if(m_selected_order_count >= ORDERS_3)
    {
       m_edit_tp3.ReadOnly(false);
       m_edit_tp3.ColorBackground(clrWhite);
    }
    else
    {
       m_edit_tp3.ReadOnly(true);
       m_edit_tp3.ColorBackground(clrLightGray);
       m_edit_tp3.Text("0.00000");
    }

    // TP4 enabled if order count >= 4
    if(m_selected_order_count >= ORDERS_4)
    {
       m_edit_tp4.ReadOnly(false);
       m_edit_tp4.ColorBackground(clrWhite);
    }
    else
    {
       m_edit_tp4.ReadOnly(true);
       m_edit_tp4.ColorBackground(clrLightGray);
       m_edit_tp4.Text("0.00000");
    }
}

void CTradeUtilityDialog::UpdateButtonTexts(void)
{
    if(m_selected_order_type == UTILITY_ORDER_MARKET)
    {
       m_btn_buy.Text("BUY NOW");
       m_btn_sell.Text("SELL NOW");
    }
    else
    {
       m_btn_buy.Text("BUY LIMIT");
       m_btn_sell.Text("SELL LIMIT");
    }
}

void CTradeUtilityDialog::UpdateRiskDisplay(void)
{
    double lot_size = StringToDouble(m_edit_lot_size.Text());
    double sl_price = StringToDouble(m_edit_sl.Text());
    double reference_price = (m_selected_order_type == UTILITY_ORDER_MARKET) ?
       ((m_selected_direction == TRADE_BUY) ? current_ask : current_bid) :
       StringToDouble(m_edit_entry_price.Text());

    // Update SL amount display
    if(sl_price > 0 && reference_price > 0 && lot_size > 0)
    {
       double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
       double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
       double ticks = MathAbs(reference_price - sl_price) / tick_size;
       double loss = lot_size * ticks * tick_value;
       m_label_sl_amount.Text("($" + DoubleToString(loss, 2) + ")");
    }
    else
    {
       m_label_sl_amount.Text("($0.00)");
    }

    // Update TP amounts
    double tp_prices[4];
    tp_prices[0] = StringToDouble(m_edit_tp1.Text());
    tp_prices[1] = StringToDouble(m_edit_tp2.Text());
    tp_prices[2] = StringToDouble(m_edit_tp3.Text());
    tp_prices[3] = StringToDouble(m_edit_tp4.Text());

    for(int i = 0; i < 4; i++)
    {
       if(tp_prices[i] > 0 && reference_price > 0 && lot_size > 0)
       {
          double tick_size = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_SIZE);
          double tick_value = SymbolInfoDouble(current_symbol, SYMBOL_TRADE_TICK_VALUE);
          double ticks = MathAbs(tp_prices[i] - reference_price) / tick_size;
          double profit = lot_size * ticks * tick_value;

          if(i == 0) m_label_tp1_amount.Text("($" + DoubleToString(profit, 2) + ")");
          else if(i == 1) m_label_tp2_amount.Text("($" + DoubleToString(profit, 2) + ")");
          else if(i == 2) m_label_tp3_amount.Text("($" + DoubleToString(profit, 2) + ")");
          else if(i == 3) m_label_tp4_amount.Text("($" + DoubleToString(profit, 2) + ")");
       }
       else
       {
          if(i == 0) m_label_tp1_amount.Text("($0.00)");
          else if(i == 1) m_label_tp2_amount.Text("($0.00)");
          else if(i == 2) m_label_tp3_amount.Text("($0.00)");
          else if(i == 3) m_label_tp4_amount.Text("($0.00)");
       }
    }
}

//+------------------------------------------------------------------+
//| Event handlers implementation                                    |
//+------------------------------------------------------------------+
void CTradeUtilityDialog::OnClickBuy(void)
{
    m_selected_direction = TRADE_BUY;
    PlaceOrder();
}

void CTradeUtilityDialog::OnClickSell(void)
{
    m_selected_direction = TRADE_SELL;
    PlaceOrder();
}

void CTradeUtilityDialog::OnClickCancelAll(void)
{
    // Cancel all pending orders
    int canceled_count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
       if(OrderGetTicket(i))
       {
          if(OrderGetString(ORDER_SYMBOL) == current_symbol)
          {
             ulong magic = OrderGetInteger(ORDER_MAGIC);
             if(magic == Magic_Number)
             {
                ulong ticket = OrderGetInteger(ORDER_TICKET);
                if(trade.OrderDelete(ticket))
                   canceled_count++;
             }
          }
       }
    }

    if(canceled_count > 0)
       Print("Canceled ", canceled_count, " orders");
    else
       Print("No orders found to cancel");
}

void CTradeUtilityDialog::OnClickCloseAll(void)
{
    // Close all positions
    int closed_count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
       if(PositionGetSymbol(i) == current_symbol)
       {
          ulong magic = PositionGetInteger(POSITION_MAGIC);
          if(magic == Magic_Number)
          {
             ulong ticket = PositionGetInteger(POSITION_TICKET);
             if(trade.PositionClose(ticket))
                closed_count++;
          }
       }
    }

    if(closed_count > 0)
       Print("Closed ", closed_count, " positions");
    else
       Print("No positions found to close");
}

void CTradeUtilityDialog::OnChangeOrderType(void)
{
    m_selected_order_type = (UTILITY_ORDER_TYPE)m_combo_order_type.Value();
    UpdateEntryPriceDisplay();
    UpdateButtonTexts();
    UpdateLotSizeDisplay();
    UpdateRiskDisplay();
}

void CTradeUtilityDialog::OnChangeOrderCount(void)
{
    m_selected_order_count = (ORDER_COUNT)m_combo_order_count.Value();
    UpdateTPFieldStates();
    UpdateRiskDisplay();
}

void CTradeUtilityDialog::OnChangeEdit(void)
{
    UpdateLotSizeDisplay();
    UpdateRiskDisplay();
}

void CTradeUtilityDialog::PlaceOrder(void)
{
    double lot_size = StringToDouble(m_edit_lot_size.Text());
    double entry_price = StringToDouble(m_edit_entry_price.Text());
    double sl_price = StringToDouble(m_edit_sl.Text());
    double tp_prices[4];
    tp_prices[0] = StringToDouble(m_edit_tp1.Text());
    tp_prices[1] = StringToDouble(m_edit_tp2.Text());
    tp_prices[2] = StringToDouble(m_edit_tp3.Text());
    tp_prices[3] = StringToDouble(m_edit_tp4.Text());
    
    // Convert Trade_Comment to string explicitly
    string trade_comment = Trade_Comment;

    if(lot_size <= 0)
    {
        Print("Error: Invalid lot size");
        return;
    }

    if(m_selected_order_type == UTILITY_ORDER_MARKET)
    {
        // Market order
        if(m_selected_direction == TRADE_BUY)
        {
            if(!trade.Buy(lot_size, current_symbol, current_ask, sl_price, tp_prices[0], trade_comment))
                Print("Market Buy failed: ", trade.ResultRetcodeDescription());
            else
                Print("Market Buy placed successfully");
        }
        else if(m_selected_direction == TRADE_SELL)
        {
            if(!trade.Sell(lot_size, current_symbol, current_bid, sl_price, tp_prices[0], trade_comment))
                Print("Market Sell failed: ", trade.ResultRetcodeDescription());
            else
                Print("Market Sell placed successfully");
        }
    }
    else if(m_selected_order_type == UTILITY_ORDER_PENDING)
    {
        // Pending order

        if(entry_price <= 0)
        {
            Print("Error: Invalid entry price for pending order - please set entry price in the panel");
            return;
        }

        ENUM_ORDER_TYPE order_type = (m_selected_direction == TRADE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;

        if(!trade.OrderOpen(current_symbol, order_type, lot_size, entry_price, sl_price, tp_prices[0], 0.0, ORDER_TIME_GTC, 0, trade_comment))
            Print("Pending order failed: ", trade.ResultRetcodeDescription());
        else
            Print("Pending order placed successfully");
    }

    // Handle multiple TPs if order count > 1
    if(m_selected_order_count > ORDERS_1)
    {
        double total_lot = lot_size;
        double lot_per_order = total_lot / (double)m_selected_order_count;

        // Normalize lot size to broker requirements
        if(symbol_lot_step > 0)
            lot_per_order = MathRound(lot_per_order / symbol_lot_step) * symbol_lot_step;

        // Ensure minimum lot size
        if(lot_per_order < symbol_min_lot)
            lot_per_order = symbol_min_lot;

        // If normalized lot * order_count exceeds max lot, adjust
        if(lot_per_order * m_selected_order_count > symbol_max_lot)
            lot_per_order = symbol_max_lot / m_selected_order_count;

        // Re-normalize after adjustment
        if(symbol_lot_step > 0)
            lot_per_order = MathRound(lot_per_order / symbol_lot_step) * symbol_lot_step;

        for(int i = 1; i < m_selected_order_count; i++)
        {
            if(tp_prices[i] > 0 && lot_per_order >= symbol_min_lot)
            {
                if(m_selected_order_type == UTILITY_ORDER_MARKET)
                {
                    // Place additional market positions with different TPs
                    if(m_selected_direction == TRADE_BUY)
                    {
                        if(!trade.Buy(lot_per_order, current_symbol, current_ask, sl_price, tp_prices[i], trade_comment))
                            Print("Additional Market Buy failed: ", trade.ResultRetcodeDescription());
                        else
                            Print("Additional Market Buy placed successfully at TP", i+1);
                    }
                    else if(m_selected_direction == TRADE_SELL)
                    {
                        if(!trade.Sell(lot_per_order, current_symbol, current_bid, sl_price, tp_prices[i], trade_comment))
                            Print("Additional Market Sell failed: ", trade.ResultRetcodeDescription());
                        else
                            Print("Additional Market Sell placed successfully at TP", i+1);
                    }
                }
                else if(m_selected_order_type == UTILITY_ORDER_PENDING)
                {
                    // Place additional pending orders with different TPs
                    if(entry_price > 0)
                    {
                        ENUM_ORDER_TYPE order_type = (m_selected_direction == TRADE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;

                        if(!trade.OrderOpen(current_symbol, order_type, lot_per_order, entry_price, sl_price, tp_prices[i], 0.0, ORDER_TIME_GTC, 0, trade_comment))
                            Print("Additional Pending order failed: ", trade.ResultRetcodeDescription());
                        else
                            Print("Additional Pending order placed successfully at TP", i+1);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| State persistence functions                                      |
//+------------------------------------------------------------------+
void SaveState()
{
    // Save enum values as integers
    GlobalVariableSet("TradeUtility_OrderType", (double)g_dialog.m_selected_order_type);
    GlobalVariableSet("TradeUtility_OrderCount", (double)g_dialog.m_selected_order_count);
    GlobalVariableSet("TradeUtility_BEMode", (double)g_dialog.m_selected_be_mode);
    GlobalVariableSet("TradeUtility_Direction", (double)g_dialog.m_selected_direction);

    // Save numeric values
    GlobalVariableSet("TradeUtility_RiskPercent", g_dialog.m_risk_percent);

    // Save price values from edit fields
    GlobalVariableSet("TradeUtility_EntryPrice", StringToDouble(g_dialog.GetEntryPriceText()));
    GlobalVariableSet("TradeUtility_SL", StringToDouble(g_dialog.GetSLText()));
    GlobalVariableSet("TradeUtility_TP1", StringToDouble(g_dialog.GetTP1Text()));
    GlobalVariableSet("TradeUtility_TP2", StringToDouble(g_dialog.GetTP2Text()));
    GlobalVariableSet("TradeUtility_TP3", StringToDouble(g_dialog.GetTP3Text()));
    GlobalVariableSet("TradeUtility_TP4", StringToDouble(g_dialog.GetTP4Text()));

    Print("Trade Utility state saved to global variables");
}

void LoadState()
{
    // Load enum values (with defaults if not found)
    if(GlobalVariableCheck("TradeUtility_OrderType"))
        g_dialog.m_selected_order_type = (UTILITY_ORDER_TYPE)(int)GlobalVariableGet("TradeUtility_OrderType");
    else
        g_dialog.m_selected_order_type = UTILITY_ORDER_MARKET;

    if(GlobalVariableCheck("TradeUtility_OrderCount"))
        g_dialog.m_selected_order_count = (ORDER_COUNT)(int)GlobalVariableGet("TradeUtility_OrderCount");
    else
        g_dialog.m_selected_order_count = ORDERS_1;

    if(GlobalVariableCheck("TradeUtility_BEMode"))
        g_dialog.m_selected_be_mode = (BREAK_EVEN_MODE)(int)GlobalVariableGet("TradeUtility_BEMode");
    else
        g_dialog.m_selected_be_mode = BE_DISABLED;

    if(GlobalVariableCheck("TradeUtility_Direction"))
        g_dialog.m_selected_direction = (TRADE_DIRECTION)(int)GlobalVariableGet("TradeUtility_Direction");
    else
        g_dialog.m_selected_direction = TRADE_BUY;

    // Load numeric values
    if(GlobalVariableCheck("TradeUtility_RiskPercent"))
        g_dialog.m_risk_percent = GlobalVariableGet("TradeUtility_RiskPercent");
    else
        g_dialog.m_risk_percent = Default_Risk_Percent;

    // Load price values into edit fields
    if(GlobalVariableCheck("TradeUtility_EntryPrice"))
    {
        double entry_price = GlobalVariableGet("TradeUtility_EntryPrice");
        if(entry_price > 0)
            g_dialog.SetEntryPriceText(DoubleToString(entry_price, symbol_digits));
    }

    if(GlobalVariableCheck("TradeUtility_SL"))
    {
        double sl_price = GlobalVariableGet("TradeUtility_SL");
        if(sl_price > 0)
            g_dialog.SetSLText(DoubleToString(sl_price, symbol_digits));
    }

    if(GlobalVariableCheck("TradeUtility_TP1"))
    {
        double tp1_price = GlobalVariableGet("TradeUtility_TP1");
        if(tp1_price > 0)
            g_dialog.SetTP1Text(DoubleToString(tp1_price, symbol_digits));
    }

    if(GlobalVariableCheck("TradeUtility_TP2"))
    {
        double tp2_price = GlobalVariableGet("TradeUtility_TP2");
        if(tp2_price > 0)
            g_dialog.SetTP2Text(DoubleToString(tp2_price, symbol_digits));
    }

    if(GlobalVariableCheck("TradeUtility_TP3"))
    {
        double tp3_price = GlobalVariableGet("TradeUtility_TP3");
        if(tp3_price > 0)
            g_dialog.SetTP3Text(DoubleToString(tp3_price, symbol_digits));
    }

    if(GlobalVariableCheck("TradeUtility_TP4"))
    {
        double tp4_price = GlobalVariableGet("TradeUtility_TP4");
        if(tp4_price > 0)
            g_dialog.SetTP4Text(DoubleToString(tp4_price, symbol_digits));
    }

    Print("Trade Utility state loaded from global variables");
}

//--- Global dialog instance
CTradeUtilityDialog g_dialog;

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeUtilityDialog::CTradeUtilityDialog(void)
{
    m_selected_order_type = UTILITY_ORDER_MARKET;
    m_selected_order_count = ORDERS_1;
    m_selected_be_mode = BE_DISABLED;
    m_selected_direction = TRADE_BUY;
    m_risk_percent = Default_Risk_Percent;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeUtilityDialog::~CTradeUtilityDialog(void)
{
    // CAppDialog base class will handle most cleanup
}

//+------------------------------------------------------------------+
//| Create Dialog                                                     |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::Create(const long chart, const string name, const int subwin,
                                const int x1, const int y1, const int x2, const int y2)
{
    if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
       return false;

    if(!CreateControls())
       return false;

    // Set dialog to start in maximized/expanded state
    Maximize();

    // Initialize displays
    UpdateLotSizeDisplay();
    UpdateEntryPriceDisplay();
    UpdateTPFieldStates();
    UpdateButtonTexts();
    UpdateRiskDisplay();

    return true;
}

//+------------------------------------------------------------------+
//| Create all controls                                              |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::CreateControls(void)
{
    int x_base = 10, y_pos = 10;
    int edit_width = 100, edit_height = 22;
    int combo_width = 100, combo_height = 22;
    int button_width = 120, button_height = 22;
    int label_width = 120;

    // Title
    if(!m_label_title.Create(m_chart_id, "label_title", m_subwin, x_base, y_pos, x_base + 320, y_pos + 18))
       return false;
    m_label_title.Text("Trade Utility Panel");
    m_label_title.Color(clrDarkBlue);
    if(!Add(m_label_title))
       return false;
    y_pos += 25;

    // Symbol
    if(!m_label_symbol.Create(m_chart_id, "label_symbol", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_symbol.Text("Symbol:");
    if(!Add(m_label_symbol))
       return false;

    if(!m_label_symbol_value.Create(m_chart_id, "label_symbol_value", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 100, y_pos + 18))
       return false;
    m_label_symbol_value.Text(current_symbol);
    m_label_symbol_value.Color(clrBlue);
    if(!Add(m_label_symbol_value))
       return false;
    y_pos += 26;

    // Min. Allowed Lot
    if(!m_label_min_lot.Create(m_chart_id, "label_min_lot", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_min_lot.Text("Min. Allowed Lot:");
    if(!Add(m_label_min_lot))
       return false;

    if(!m_label_min_lot_value.Create(m_chart_id, "label_min_lot_value", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 100, y_pos + 18))
       return false;
    m_label_min_lot_value.Text(DoubleToString(symbol_min_lot, 2));
    m_label_min_lot_value.Color(clrBlue);
    if(!Add(m_label_min_lot_value))
       return false;
    y_pos += 26;

    // Risk % of Balance
    if(!m_label_risk_percent.Create(m_chart_id, "label_risk_percent", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_risk_percent.Text("Risk % of Balance:");
    if(!Add(m_label_risk_percent))
       return false;

    if(!m_edit_risk_percent.Create(m_chart_id, "edit_risk_percent", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + edit_width, y_pos + edit_height))
       return false;
    m_edit_risk_percent.Text(DoubleToString(m_risk_percent, 2));
    if(!Add(m_edit_risk_percent))
       return false;
    y_pos += 26;

    // Order Type
    if(!m_label_order_type.Create(m_chart_id, "label_order_type", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_order_type.Text("Order Type:");
    if(!Add(m_label_order_type))
       return false;

    if(!m_combo_order_type.Create(m_chart_id, "combo_order_type", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + combo_width, y_pos + combo_height))
       return false;
    m_combo_order_type.AddItem("MARKET", UTILITY_ORDER_MARKET);
    m_combo_order_type.AddItem("PENDING", UTILITY_ORDER_PENDING);
    m_combo_order_type.SelectByValue((int)m_selected_order_type);
    m_combo_order_type.Id(ID_COMBO_ORDER_TYPE);
    if(!Add(m_combo_order_type))
       return false;
    y_pos += 26;

    // Entry Price
    if(!m_label_entry_price.Create(m_chart_id, "label_entry_price", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_entry_price.Text("Entry Price:");
    if(!Add(m_label_entry_price))
       return false;

    if(!m_edit_entry_price.Create(m_chart_id, "edit_entry_price", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + edit_width, y_pos + edit_height))
       return false;
    m_edit_entry_price.Text("0.00000");
    if(!Add(m_edit_entry_price))
       return false;
    y_pos += 26;

    // Order Count
    if(!m_label_order_count.Create(m_chart_id, "label_order_count", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_order_count.Text("Order Count:");
    if(!Add(m_label_order_count))
       return false;

    if(!m_combo_order_count.Create(m_chart_id, "combo_order_count", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + combo_width, y_pos + combo_height))
       return false;
    m_combo_order_count.AddItem("1", ORDERS_1);
    m_combo_order_count.AddItem("2", ORDERS_2);
    m_combo_order_count.AddItem("3", ORDERS_3);
    m_combo_order_count.AddItem("4", ORDERS_4);
    m_combo_order_count.SelectByValue((int)m_selected_order_count);
    m_combo_order_count.Id(ID_COMBO_ORDER_COUNT);
    if(!Add(m_combo_order_count))
       return false;
    y_pos += 26;

    // Lot Size
    if(!m_label_lot_size.Create(m_chart_id, "label_lot_size", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_lot_size.Text("Lot Size:");
    if(!Add(m_label_lot_size))
       return false;

    if(!m_edit_lot_size.Create(m_chart_id, "edit_lot_size", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + edit_width, y_pos + edit_height))
       return false;
    m_edit_lot_size.Text("0.00");
    m_edit_lot_size.ReadOnly(true);
    m_edit_lot_size.ColorBackground(clrLightGray);
    if(!Add(m_edit_lot_size))
       return false;
    y_pos += 26;

    // Stop Loss
    if(!m_label_sl.Create(m_chart_id, "label_sl", m_subwin, x_base, y_pos, x_base + 25, y_pos + 18))
       return false;
    m_label_sl.Text("SL:");
    if(!Add(m_label_sl))
       return false;

    if(!m_edit_sl.Create(m_chart_id, "edit_sl", m_subwin, x_base + 28, y_pos, x_base + 28 + edit_width, y_pos + edit_height))
       return false;
    m_edit_sl.Text("0.00000");
    if(!Add(m_edit_sl))
       return false;

    if(!m_label_sl_amount.Create(m_chart_id, "label_sl_amount", m_subwin, x_base + 135, y_pos, x_base + 230, y_pos + 18))
       return false;
    m_label_sl_amount.Text("($0.00)");
    m_label_sl_amount.Color(clrRed);
    if(!Add(m_label_sl_amount))
       return false;
    y_pos += 26;

    // TP1
    if(!m_label_tp1.Create(m_chart_id, "label_tp1", m_subwin, x_base, y_pos, x_base + 35, y_pos + 18))
       return false;
    m_label_tp1.Text("TP1:");
    if(!Add(m_label_tp1))
       return false;

    if(!m_edit_tp1.Create(m_chart_id, "edit_tp1", m_subwin, x_base + 38, y_pos, x_base + 38 + edit_width, y_pos + edit_height))
       return false;
    m_edit_tp1.Text("0.00000");
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

    if(!m_edit_tp2.Create(m_chart_id, "edit_tp2", m_subwin, x_base + 38, y_pos, x_base + 38 + edit_width, y_pos + edit_height))
       return false;
    m_edit_tp2.Text("0.00000");
    if(!Add(m_edit_tp2))
       return false;

    if(!m_label_tp2_amount.Create(m_chart_id, "label_tp2_amount", m_subwin, x_base + 145, y_pos, x_base + 240, y_pos + 18))
       return false;
    m_label_tp2_amount.Text("($0.00)");
    m_label_tp2_amount.Color(clrGreen);
    if(!Add(m_label_tp2_amount))
       return false;
    y_pos += 26;

    // TP3
    if(!m_label_tp3.Create(m_chart_id, "label_tp3", m_subwin, x_base, y_pos, x_base + 35, y_pos + 18))
       return false;
    m_label_tp3.Text("TP3:");
    if(!Add(m_label_tp3))
       return false;

    if(!m_edit_tp3.Create(m_chart_id, "edit_tp3", m_subwin, x_base + 38, y_pos, x_base + 38 + edit_width, y_pos + edit_height))
       return false;
    m_edit_tp3.Text("0.00000");
    if(!Add(m_edit_tp3))
       return false;

    if(!m_label_tp3_amount.Create(m_chart_id, "label_tp3_amount", m_subwin, x_base + 145, y_pos, x_base + 240, y_pos + 18))
       return false;
    m_label_tp3_amount.Text("($0.00)");
    m_label_tp3_amount.Color(clrGreen);
    if(!Add(m_label_tp3_amount))
       return false;
    y_pos += 26;

    // TP4
    if(!m_label_tp4.Create(m_chart_id, "label_tp4", m_subwin, x_base, y_pos, x_base + 35, y_pos + 18))
       return false;
    m_label_tp4.Text("TP4:");
    if(!Add(m_label_tp4))
       return false;

    if(!m_edit_tp4.Create(m_chart_id, "edit_tp4", m_subwin, x_base + 38, y_pos, x_base + 38 + edit_width, y_pos + edit_height))
       return false;
    m_edit_tp4.Text("0.00000");
    if(!Add(m_edit_tp4))
       return false;

    if(!m_label_tp4_amount.Create(m_chart_id, "label_tp4_amount", m_subwin, x_base + 145, y_pos, x_base + 240, y_pos + 18))
       return false;
    m_label_tp4_amount.Text("($0.00)");
    m_label_tp4_amount.Color(clrGreen);
    if(!Add(m_label_tp4_amount))
       return false;
    y_pos += 26;

    // Breakeven
    if(!m_label_breakeven.Create(m_chart_id, "label_breakeven", m_subwin, x_base, y_pos, x_base + label_width, y_pos + 18))
       return false;
    m_label_breakeven.Text("Breakeven:");
    if(!Add(m_label_breakeven))
       return false;

    if(!m_combo_breakeven.Create(m_chart_id, "combo_breakeven", m_subwin, x_base + label_width + 5, y_pos, x_base + label_width + 5 + combo_width, y_pos + combo_height))
       return false;
    m_combo_breakeven.AddItem("Disabled", BE_DISABLED);
    m_combo_breakeven.AddItem("After TP1", BE_AFTER_TP1);
    m_combo_breakeven.AddItem("After TP2", BE_AFTER_TP2);
    m_combo_breakeven.SelectByValue((int)m_selected_be_mode);
    m_combo_breakeven.Id(ID_COMBO_BREAK_EVEN);
    if(!Add(m_combo_breakeven))
       return false;
    y_pos += 32;

    // Action buttons - Row 1: BUY and SELL
    if(!m_btn_buy.Create(m_chart_id, "btn_buy", m_subwin, x_base + 5, y_pos, x_base + 5 + button_width, y_pos + button_height))
       return false;
    m_btn_buy.Text("BUY NOW");
    m_btn_buy.Color(clrWhite);
    m_btn_buy.ColorBackground(clrBlue);
    m_btn_buy.Id(ID_BTN_BUY);
    if(!Add(m_btn_buy))
       return false;

    if(!m_btn_sell.Create(m_chart_id, "btn_sell", m_subwin, x_base + 5 + button_width + 10, y_pos, x_base + 5 + button_width * 2 + 10, y_pos + button_height))
       return false;
    m_btn_sell.Text("SELL NOW");
    m_btn_sell.Color(clrWhite);
    m_btn_sell.ColorBackground(clrRed);
    m_btn_sell.Id(ID_BTN_SELL);
    if(!Add(m_btn_sell))
       return false;
    y_pos += 26;

    // Action buttons - Row 2: CANCEL ALL and CLOSE ALL
    if(!m_btn_cancel_all.Create(m_chart_id, "btn_cancel_all", m_subwin, x_base + 5, y_pos, x_base + 5 + button_width, y_pos + button_height))
       return false;
    m_btn_cancel_all.Text("Cancel All Order");
    m_btn_cancel_all.Color(clrWhite);
    m_btn_cancel_all.ColorBackground(clrOrange);
    m_btn_cancel_all.Id(ID_BTN_CANCEL_ALL);
    if(!Add(m_btn_cancel_all))
       return false;

    if(!m_btn_close_all.Create(m_chart_id, "btn_close_all", m_subwin, x_base + 5 + button_width + 10, y_pos, x_base + 5 + button_width * 2 + 10, y_pos + button_height))
       return false;
    m_btn_close_all.Text("Close All Position");
    m_btn_close_all.Color(clrWhite);
    m_btn_close_all.ColorBackground(clrRed);
    m_btn_close_all.Id(ID_BTN_CLOSE_ALL);
    if(!Add(m_btn_close_all))
       return false;

    return true;
}

//+------------------------------------------------------------------+
//| Event handler                                                     |
//+------------------------------------------------------------------+
bool CTradeUtilityDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{

    // Handle edit field changes - use a different approach since lparam is 0
    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        // For edit fields, we can't identify which one from lparam, so call OnChangeEdit for any ENDEDIT
        // This will be called for both edit fields and potentially other controls
        OnChangeEdit();
        // Don't return yet - let base class handle it too for proper state management
    }

    // Handle ComboBox changes (id=1004 is CHARTEVENT_OBJECT_ENDEDIT for ComboBox selection)
    if(id == 1004)
    {
        if(lparam == m_combo_order_type.Id())
        {
           OnChangeOrderType();
           return true;
        }
        if(lparam == m_combo_order_count.Id())
        {
           OnChangeOrderCount();
           return true;
        }
        if(lparam == m_combo_breakeven.Id())
        {
           m_selected_be_mode = (BREAK_EVEN_MODE)m_combo_breakeven.Value();
           return true;
        }
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
        if(lparam == m_btn_cancel_all.Id())
        {
           OnClickCancelAll();
           return true;
        }
        if(lparam == m_btn_close_all.Id())
        {
           OnClickCloseAll();
           return true;
        }
    }

    // Call base class to handle minimize/maximize/close and other internal events
    return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Initialize symbol data                                           |
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

    current_bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
    current_ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    InitializeSymbolData();

    trade.SetExpertMagicNumber(Magic_Number);

    if(!g_dialog.Create(0, "TradeUtility", 0, Panel_X_Position, Panel_Y_Position,
                        Panel_X_Position + Panel_Width, Panel_Y_Position + Panel_Height))
    {
       Print("Failed to create dialog");
       return INIT_FAILED;
    }

    // Load previous state from global variables
    LoadState();

    if(!g_dialog.Run())
    {
       Print("Failed to run dialog");
       return INIT_FAILED;
    }

    Print("=== Trade Utility Panel Initialized ===");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("Starting deinitialization (reason: ", reason, ")");

    // Save current state before cleanup
    SaveState();

    // Clean up dialog properly
    Print("Destroying dialog...");
    g_dialog.Destroy(reason);

    // Delete all chart objects with our prefix to ensure complete cleanup
    int obj_total = ObjectsTotal(0, 0, -1);
    Print("Total objects before cleanup: ", obj_total);

    for(int i = obj_total - 1; i >= 0; i--)
    {
       string obj_name = ObjectName(0, i, 0, -1);
       // Delete objects that start with our dialog name
       if(StringFind(obj_name, "TradeUtility") >= 0)
       {
          Print("Deleting object: ", obj_name);
          ObjectDelete(0, obj_name);
       }
    }

    // Force chart redraw
    ChartRedraw();
    Sleep(100); // Give time for objects to be deleted

    Print("Trade Utility Panel deinitialized successfully");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    uint current_time = GetTickCount();

    current_bid = SymbolInfoDouble(current_symbol, SYMBOL_BID);
    current_ask = SymbolInfoDouble(current_symbol, SYMBOL_ASK);

    if(current_time - last_gui_update > GUI_UPDATE_THRESHOLD)
    {
        // Update real-time price for MARKET mode
        if(g_dialog.m_selected_order_type == UTILITY_ORDER_MARKET)
        {
            g_dialog.UpdateEntryPriceDisplay();
            g_dialog.UpdateLotSizeDisplay();
            g_dialog.UpdateRiskDisplay();
        }

        ChartRedraw();
        last_gui_update = current_time;
    }
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Filter out events that should NOT minimize dialog
    if(id == CHARTEVENT_CHART_CHANGE)
    {
       // Symbol or timeframe changed - skip dialog event processing to prevent auto-minimize
       return;
    }

    // Use ChartEvent for proper state management, but filter problematic events
    g_dialog.ChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+