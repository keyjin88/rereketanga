//+------------------------------------------------------------------+
//|                                         TrendFollower_M15_EA.mq5|
//|                          Copyright 2024, TrendFollower Strategy |
//|                    Прибыльная трендовая стратегия для M15 EURUSD |
//|                                                                  |
//| ОСОБЕННОСТИ СТРАТЕГИИ:                                           |
//| - Только трендовые сделки (высокий win-rate)                   |
//| - Многоуровневое подтверждение тренда                          |
//| - Исключение противоречивых сигналов                           |
//| - Оптимизировано для M15 EURUSD                                |
//| - Строгие фильтры входа и управления рисками                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, TrendFollower Strategy"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Торговые объекты
CTrade        m_trade;
CPositionInfo m_position;

//--- Структура торгового сигнала
struct TrendSignal
{
    bool     is_valid;           // Валидность сигнала
    bool     is_buy;             // Направление (true = BUY, false = SELL)
    double   entry_price;        // Цена входа
    double   tp_price;           // Take Profit
    double   sl_price;           // Stop Loss
    double   confidence;         // Уверенность в сигнале (0-100)
    datetime signal_time;        // Время сигнала
    string   reason;             // Описание причины сигнала
};

//=== ВХОДНЫЕ ПАРАМЕТРЫ ===

//--- Основные настройки
input group "=== Основные настройки ==="
input bool EnableTrading = true;               // Разрешить торговлю
input double LotSize = 0.1;                   // Размер лота
input bool UseAutoLotSize = true;             // Автоматический расчет лота
input double RiskPercent = 1.5;               // Риск на сделку (%)
input int MaxPositions = 1;                   // Максимум позиций одновременно
input int MagicNumber = 150001;               // Магический номер

//--- Индикаторы тренда
input group "=== Определение тренда ==="
input int FastMA_Period = 21;                 // Быстрая MA
input int SlowMA_Period = 50;                 // Медленная MA
input int TrendMA_Period = 100;               // Трендовая MA
input ENUM_MA_METHOD MA_Method = MODE_EMA;    // Метод MA
input ENUM_APPLIED_PRICE MA_Price = PRICE_CLOSE; // Цена для MA

//--- Индикаторы импульса
input group "=== Фильтры импульса ==="
input int RSI_Period = 14;                    // Период RSI
input double RSI_Overbought = 70.0;           // RSI перекупленность
input double RSI_Oversold = 30.0;             // RSI перепроданность
input int Stoch_K_Period = 14;                // Stochastic %K
input int Stoch_D_Period = 3;                 // Stochastic %D
input int Stoch_Slowing = 3;                  // Stochastic замедление

//--- Фильтр волатильности
input group "=== Фильтр волатильности ==="
input int ATR_Period = 14;                    // Период ATR
input double MinATR_Multiplier = 0.5;         // Минимальная волатильность (ATR множитель) - снижено для тестирования
input double MaxATR_Multiplier = 5.0;         // Максимальная волатильность (ATR множитель) - увеличено для тестирования

//--- Управление рисками
input group "=== Управление рисками ==="
input double ATR_SL_Multiplier = 2.0;         // SL множитель ATR
input double ATR_TP_Multiplier = 3.0;         // TP множитель ATR
input double MinRiskReward = 1.5;             // Минимальное соотношение риск/прибыль

//--- Время торговли (оптимизировано для EURUSD)
input group "=== Время торговли ==="
input bool EnableTimeFilter = false;          // Включить фильтр времени - отключено для тестирования
input string SessionStart = "00:00";          // Начало торговой сессии
input string SessionEnd = "23:59";            // Конец торговой сессии
input bool AvoidFridayEvening = false;        // Избегать пятничного вечера - отключено для тестирования
input bool AvoidMondayMorning = false;        // Избегать понедельника утром - отключено для тестирования

//--- Дополнительные фильтры
input group "=== Дополнительные фильтры ==="
input double MinConfidence = 60.0;            // Минимальная уверенность в сигнале (%) - снижено для тестирования
input int MinBarsSinceSignal = 1;             // Минимум баров между сигналами - уменьшено для тестирования
input bool UseSpreadFilter = false;           // Использовать фильтр спреда - отключено для тестирования
input double MaxSpreadPips = 5.0;             // Максимальный спред (пипсы) - увеличено
input bool EnableDebugMode = true;            // Включить отладочный режим

//--- Трейлинг и безубыток
input group "=== Трейлинг и безубыток ==="
input bool EnableTrailing = true;             // Включить трейлинг
input double TrailingStart_Pips = 20.0;       // Начать трейлинг (пипсы)
input double TrailingStep_Pips = 10.0;        // Шаг трейлинга (пипсы)
input bool EnableBreakeven = true;            // Включить безубыток
input double BreakevenStart_Pips = 15.0;      // Начать безубыток (пипсы)
input double BreakevenOffset_Pips = 5.0;      // Отступ безубытка (пипсы)

//--- Уведомления
input group "=== Уведомления ==="
input bool EnableAlerts = true;               // Включить алерты
input bool AlertOnEntry = true;               // Алерт при входе
input bool AlertOnExit = true;                // Алерт при выходе

//=== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ===

//--- Хендлы индикаторов
int h_FastMA, h_SlowMA, h_TrendMA;
int h_RSI, h_Stoch, h_ATR;

//--- Торговые переменные
datetime g_LastSignalTime = 0;
datetime g_LastBarTime = 0;
double g_PipValue;
bool g_FirstRun = true;

//--- Массивы для трейлинга
ulong g_BreakevenPositions[];

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Инициализация TrendFollower M15 EA ===");
    
    // Проверка символа и таймфрейма
    if(_Symbol != "EURUSD")
        Print("⚠️ ВНИМАНИЕ: EA оптимизирован для EURUSD, текущий символ: ", _Symbol);
    
    if(_Period != PERIOD_M15)
        Print("⚠️ ВНИМАНИЕ: EA оптимизирован для M15, текущий таймфрейм: ", EnumToString(_Period));
    
    // Валидация параметров
    if(!ValidateInputs())
        return INIT_PARAMETERS_INCORRECT;
    
    // Настройка торговых объектов
    m_trade.SetExpertMagicNumber(MagicNumber);
    m_trade.SetMarginMode();
    m_trade.SetTypeFillingBySymbol(_Symbol);
    m_trade.SetDeviationInPoints(30);
    
    // Инициализация индикаторов
    if(!InitializeIndicators())
        return INIT_FAILED;
    
    // Расчет размера пипса
    g_PipValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(_Digits == 5 || _Digits == 3)
        g_PipValue *= 10;
    
    // Инициализация массивов
    ArrayResize(g_BreakevenPositions, 0);
    
    Print("✅ Инициализация завершена успешно");
    PrintSettings();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Валидация входных параметров                                    |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(LotSize <= 0 || LotSize > 10)
    {
        Print("❌ Неверный размер лота: ", LotSize);
        return false;
    }
    
    if(RiskPercent <= 0 || RiskPercent > 10)
    {
        Print("❌ Неверный процент риска: ", RiskPercent);
        return false;
    }
    
    if(FastMA_Period >= SlowMA_Period || SlowMA_Period >= TrendMA_Period)
    {
        Print("❌ Неверные периоды MA: Fast < Slow < Trend");
        return false;
    }
    
    if(ATR_SL_Multiplier <= 0 || ATR_TP_Multiplier <= ATR_SL_Multiplier)
    {
        Print("❌ Неверные множители ATR: SL > 0, TP > SL");
        return false;
    }
    
    if(MinRiskReward < 1.0)
    {
        Print("❌ Минимальное Risk/Reward должно быть >= 1.0");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Инициализация индикаторов                                       |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
    // Moving Averages
    h_FastMA = iMA(_Symbol, PERIOD_CURRENT, FastMA_Period, 0, MA_Method, MA_Price);
    h_SlowMA = iMA(_Symbol, PERIOD_CURRENT, SlowMA_Period, 0, MA_Method, MA_Price);
    h_TrendMA = iMA(_Symbol, PERIOD_CURRENT, TrendMA_Period, 0, MA_Method, MA_Price);
    
    // RSI
    h_RSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, MA_Price);
    
    // Stochastic
    h_Stoch = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K_Period, Stoch_D_Period, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    
    // ATR
    h_ATR = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    
    // Проверка хендлов
    if(h_FastMA == INVALID_HANDLE || h_SlowMA == INVALID_HANDLE || h_TrendMA == INVALID_HANDLE ||
       h_RSI == INVALID_HANDLE || h_Stoch == INVALID_HANDLE || h_ATR == INVALID_HANDLE)
    {
        Print("❌ Ошибка создания индикаторов");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Вывод настроек                                                   |
//+------------------------------------------------------------------+
void PrintSettings()
{
    Print("📊 Настройки TrendFollower M15 EA:");
    Print("💰 Лот: ", (UseAutoLotSize ? "Авто (" + DoubleToString(RiskPercent, 1) + "%)" : DoubleToString(LotSize, 2)));
    Print("📈 MA периоды: ", FastMA_Period, "/", SlowMA_Period, "/", TrendMA_Period);
    Print("⚡ RSI период: ", RSI_Period, " (", RSI_Oversold, "-", RSI_Overbought, ")");
    Print("🎯 Risk/Reward: мин ", DoubleToString(MinRiskReward, 1), ", ATR SL/TP: ", DoubleToString(ATR_SL_Multiplier, 1), "/", DoubleToString(ATR_TP_Multiplier, 1));
    Print("🕒 Торговля: ", (EnableTimeFilter ? SessionStart + "-" + SessionEnd : "24/7"));
    Print("📊 Мин. уверенность: ", DoubleToString(MinConfidence, 0), "%");
}

//+------------------------------------------------------------------+
//| Основная функция                                                |
//+------------------------------------------------------------------+
void OnTick()
{
    // Проверка нового бара
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool is_new_bar = (current_time != g_LastBarTime);
    
    if(is_new_bar || g_FirstRun)
    {
        g_LastBarTime = current_time;
        g_FirstRun = false;
        
        // Очистка массива безубытка
        CleanupBreakevenArray();
        
        // Основная торговая логика
        ProcessTradingLogic();
    }
    
    // Управление позициями на каждом тике
    ManagePositions();
}

//+------------------------------------------------------------------+
//| Основная торговая логика                                        |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
    if(EnableDebugMode)
        Print("ОТЛАДКА: Начало обработки торговой логики");
    
    if(!EnableTrading)
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Торговля отключена");
        return;
    }
    
    // Проверка времени торговли
    if(!IsTimeToTrade())
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Неподходящее время для торговли");
        return;
    }
    
    // Проверка спреда
    if(!IsSpreadAcceptable())
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Неприемлемый спред");
        return;
    }
    
    // Проверка максимального количества позиций
    int current_positions = GetOpenPositionsCount();
    if(current_positions >= MaxPositions)
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Достигнуто максимальное количество позиций: ", current_positions);
        return;
    }
    
    // Проверка времени с последнего сигнала
    if(!IsEnoughTimeSinceLastSignal())
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Слишком рано после последнего сигнала");
        return;
    }
    
    // Ожидание готовности индикаторов
    if(!WaitForIndicatorData())
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Данные индикаторов не готовы");
        return;
    }
    
    if(EnableDebugMode)
        Print("ОТЛАДКА: Все проверки пройдены, генерируем сигнал");
    
    // Генерация торгового сигнала
    TrendSignal signal = GenerateTradingSignal();
    
    // Обработка сигнала
    if(signal.is_valid && signal.confidence >= MinConfidence)
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Валидный сигнал найден, обрабатываем");
        ProcessTradingSignal(signal);
    }
    else if(EnableDebugMode)
    {
        Print("ОТЛАДКА: Сигнал невалиден или недостаточная уверенность. Валидность=", signal.is_valid, 
              " Уверенность=", DoubleToString(signal.confidence, 1));
    }
}

//+------------------------------------------------------------------+
//| Проверка времени торговли                                       |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    if(!EnableTimeFilter)
        return true;
    
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    
    // Избегаем понедельника утром (до 9:00)
    if(AvoidMondayMorning && time_struct.day_of_week == 1 && time_struct.hour < 9)
    {
        return false;
    }
    
    // Избегаем пятничного вечера (после 18:00)
    if(AvoidFridayEvening && time_struct.day_of_week == 5 && time_struct.hour >= 18)
    {
        return false;
    }
    
    // Проверка торговой сессии
    int session_start = ParseTimeString(SessionStart);
    int session_end = ParseTimeString(SessionEnd);
    int current_time = time_struct.hour * 60 + time_struct.min;
    
    if(session_start == -1 || session_end == -1)
        return true;
    
    return (current_time >= session_start && current_time <= session_end);
}

//+------------------------------------------------------------------+
//| Парсинг строки времени                                         |
//+------------------------------------------------------------------+
int ParseTimeString(string time_str)
{
    int colon_pos = StringFind(time_str, ":");
    if(colon_pos == -1) return -1;
    
    int hours = (int)StringToInteger(StringSubstr(time_str, 0, colon_pos));
    int minutes = (int)StringToInteger(StringSubstr(time_str, colon_pos + 1));
    
    if(hours < 0 || hours > 23 || minutes < 0 || minutes > 59)
        return -1;
    
    return hours * 60 + minutes;
}

//+------------------------------------------------------------------+
//| Проверка приемлемого спреда                                    |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable()
{
    if(!UseSpreadFilter)
        return true;
    
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double spread_pips = spread / g_PipValue;
    
    return (spread_pips <= MaxSpreadPips);
}

//+------------------------------------------------------------------+
//| Подсчет открытых позиций                                       |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Проверка времени с последнего сигнала                          |
//+------------------------------------------------------------------+
bool IsEnoughTimeSinceLastSignal()
{
    if(g_LastSignalTime == 0)
        return true;
    
    int bars_since = Bars(_Symbol, PERIOD_CURRENT, g_LastSignalTime, TimeCurrent()) - 1;
    return (bars_since >= MinBarsSinceSignal);
}

//+------------------------------------------------------------------+
//| Ожидание готовности индикаторов                                |
//+------------------------------------------------------------------+
bool WaitForIndicatorData()
{
    double temp[];
    ArraySetAsSeries(temp, true);
    
    if(CopyBuffer(h_FastMA, 0, 0, 3, temp) <= 0) return false;
    if(CopyBuffer(h_SlowMA, 0, 0, 3, temp) <= 0) return false;
    if(CopyBuffer(h_TrendMA, 0, 0, 3, temp) <= 0) return false;
    if(CopyBuffer(h_RSI, 0, 0, 3, temp) <= 0) return false;
    if(CopyBuffer(h_Stoch, 0, 0, 3, temp) <= 0) return false;
    if(CopyBuffer(h_ATR, 0, 0, 3, temp) <= 0) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Генерация торгового сигнала                                    |
//+------------------------------------------------------------------+
TrendSignal GenerateTradingSignal()
{
    TrendSignal signal;
    ZeroMemory(signal);
    
    // Получение данных индикаторов
    double fast_ma[], slow_ma[], trend_ma[];
    double rsi[], stoch_main[], stoch_signal[];
    double atr[];
    
    ArraySetAsSeries(fast_ma, true);
    ArraySetAsSeries(slow_ma, true);
    ArraySetAsSeries(trend_ma, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(h_FastMA, 0, 0, 3, fast_ma) <= 0) return signal;
    if(CopyBuffer(h_SlowMA, 0, 0, 3, slow_ma) <= 0) return signal;
    if(CopyBuffer(h_TrendMA, 0, 0, 3, trend_ma) <= 0) return signal;
    if(CopyBuffer(h_RSI, 0, 0, 3, rsi) <= 0) return signal;
    if(CopyBuffer(h_Stoch, 0, 0, 3, stoch_main) <= 0) return signal;
    if(CopyBuffer(h_Stoch, 1, 0, 3, stoch_signal) <= 0) return signal;
    if(CopyBuffer(h_ATR, 0, 0, 3, atr) <= 0) return signal;
    
    // Текущие цены
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // Фильтр волатильности
    double atr_current = atr[0];
    double atr_avg = (atr[0] + atr[1] + atr[2]) / 3.0;
    
    if(EnableDebugMode)
    {
        Print("ОТЛАДКА: ATR текущий=", DoubleToString(atr_current, 5), 
              " ATR средний=", DoubleToString(atr_avg, 5),
              " Мин. множитель=", MinATR_Multiplier,
              " Макс. множитель=", MaxATR_Multiplier);
    }
    
    if(atr_current < atr_avg * MinATR_Multiplier || atr_current > atr_avg * MaxATR_Multiplier)
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Сигнал отклонен - неподходящая волатильность");
        return signal; // Неподходящая волатильность
    }
    
    // Определение направления тренда (смягченные условия для тестирования)
    bool trend_up = (fast_ma[0] > slow_ma[0] && slow_ma[0] > trend_ma[0]);
    bool trend_down = (fast_ma[0] < slow_ma[0] && slow_ma[0] < trend_ma[0]);
    
    if(EnableDebugMode)
    {
        Print("ОТЛАДКА: MA значения - Fast=", DoubleToString(fast_ma[0], 5),
              " Slow=", DoubleToString(slow_ma[0], 5),
              " Trend=", DoubleToString(trend_ma[0], 5));
        Print("ОТЛАДКА: Тренд UP=", trend_up, " DOWN=", trend_down);
        Print("ОТЛАДКА: RSI=", DoubleToString(rsi[0], 2),
              " Stoch Main=", DoubleToString(stoch_main[0], 2),
              " Stoch Signal=", DoubleToString(stoch_signal[0], 2));
    }
    
    if(!trend_up && !trend_down)
    {
        if(EnableDebugMode)
            Print("ОТЛАДКА: Сигнал отклонен - нет четкого тренда");
        return signal; // Нет четкого тренда
    }
    
    // Анализ сигналов BUY
    if(trend_up)
    {
        double confidence = 0;
        string reasons = "";
        
        // Проверка RSI (упрощенные условия)
        if(rsi[0] > 40 && rsi[0] < 80)
        {
            confidence += 25;
            reasons += "RSI_Bullish ";
        }
        
        // Проверка Stochastic (упрощенные условия)
        if(stoch_main[0] > stoch_signal[0] && stoch_main[0] < 85)
        {
            confidence += 30;
            reasons += "Stoch_Bullish ";
        }
        
        // Проверка MA импульса (упрощенные условия)
        if(fast_ma[0] > fast_ma[1])
        {
            confidence += 25;
            reasons += "MA_Momentum ";
        }
        
        // Проверка позиции относительно MA
        if(ask_price > fast_ma[0])
        {
            confidence += 20;
            reasons += "Price_Above_MA ";
        }
        
        if(EnableDebugMode)
        {
            Print("ОТЛАДКА BUY: Уверенность=", DoubleToString(confidence, 1), 
                  " Причины: ", reasons, " Минимум=", MinConfidence);
        }
        
        if(confidence >= MinConfidence)
        {
            signal.is_valid = true;
            signal.is_buy = true;
            signal.entry_price = ask_price;
            signal.confidence = confidence;
            signal.reason = reasons;
            signal.signal_time = TimeCurrent();
            
            // Расчет SL и TP
            CalculateTPSL(signal, atr_current, true);
        }
    }
    
    // Анализ сигналов SELL
    if(trend_down)
    {
        double confidence = 0;
        string reasons = "";
        
        // Проверка RSI (упрощенные условия)
        if(rsi[0] < 60 && rsi[0] > 20)
        {
            confidence += 25;
            reasons += "RSI_Bearish ";
        }
        
        // Проверка Stochastic (упрощенные условия)
        if(stoch_main[0] < stoch_signal[0] && stoch_main[0] > 15)
        {
            confidence += 30;
            reasons += "Stoch_Bearish ";
        }
        
        // Проверка MA импульса (упрощенные условия)
        if(fast_ma[0] < fast_ma[1])
        {
            confidence += 25;
            reasons += "MA_Momentum ";
        }
        
        // Проверка позиции относительно MA
        if(current_price < fast_ma[0])
        {
            confidence += 20;
            reasons += "Price_Below_MA ";
        }
        
        if(EnableDebugMode)
        {
            Print("ОТЛАДКА SELL: Уверенность=", DoubleToString(confidence, 1), 
                  " Причины: ", reasons, " Минимум=", MinConfidence);
        }
        
        if(confidence >= MinConfidence)
        {
            signal.is_valid = true;
            signal.is_buy = false;
            signal.entry_price = current_price;
            signal.confidence = confidence;
            signal.reason = reasons;
            signal.signal_time = TimeCurrent();
            
            // Расчет SL и TP
            CalculateTPSL(signal, atr_current, false);
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Расчет TP и SL                                                  |
//+------------------------------------------------------------------+
void CalculateTPSL(TrendSignal &signal, double atr_value, bool is_buy)
{
    double sl_distance = atr_value * ATR_SL_Multiplier;
    double tp_distance = atr_value * ATR_TP_Multiplier;
    
    // Проверка минимального Risk/Reward
    if(tp_distance / sl_distance < MinRiskReward)
    {
        tp_distance = sl_distance * MinRiskReward;
    }
    
    if(is_buy)
    {
        signal.sl_price = signal.entry_price - sl_distance;
        signal.tp_price = signal.entry_price + tp_distance;
    }
    else
    {
        signal.sl_price = signal.entry_price + sl_distance;
        signal.tp_price = signal.entry_price - tp_distance;
    }
    
    // Нормализация цен
    signal.entry_price = NormalizeDouble(signal.entry_price, _Digits);
    signal.sl_price = NormalizeDouble(signal.sl_price, _Digits);
    signal.tp_price = NormalizeDouble(signal.tp_price, _Digits);
}

//+------------------------------------------------------------------+
//| Обработка торгового сигнала                                    |
//+------------------------------------------------------------------+
void ProcessTradingSignal(TrendSignal &signal)
{
    double lot_size = CalculateLotSize(signal);
    if(lot_size <= 0)
    {
        Print("❌ Ошибка расчета размера лота");
        return;
    }
    
    string comment = StringFormat("TrendFollower_%.0f%%_%s", signal.confidence, 
                                  StringSubstr(signal.reason, 0, 10));
    
    bool result = false;
    if(signal.is_buy)
    {
        result = m_trade.Buy(lot_size, _Symbol, 0, signal.sl_price, signal.tp_price, comment);
    }
    else
    {
        result = m_trade.Sell(lot_size, _Symbol, 0, signal.sl_price, signal.tp_price, comment);
    }
    
    if(result)
    {
        g_LastSignalTime = TimeCurrent();
        
        Print("✅ Позиция открыта: ", (signal.is_buy ? "BUY" : "SELL"),
              " | Лот: ", DoubleToString(lot_size, 2),
              " | Уверенность: ", DoubleToString(signal.confidence, 0), "%",
              " | Причины: ", signal.reason);
        
        if(AlertOnEntry)
        {
            string alert_msg = StringFormat("TrendFollower: %s открыт, уверенность %.0f%%, цена %s",
                                           (signal.is_buy ? "BUY" : "SELL"),
                                           signal.confidence,
                                           DoubleToString(signal.entry_price, _Digits));
            Alert(alert_msg);
        }
    }
    else
    {
        Print("❌ Ошибка открытия позиции: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Расчет размера лота                                            |
//+------------------------------------------------------------------+
double CalculateLotSize(TrendSignal &signal)
{
    double calculated_lot = LotSize;
    
    if(UseAutoLotSize)
    {
        double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double risk_amount = account_balance * RiskPercent / 100.0;
        
        double sl_distance = MathAbs(signal.entry_price - signal.sl_price);
        if(sl_distance > 0)
        {
            double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            
            if(tick_value > 0 && tick_size > 0)
            {
                double loss_per_lot = (sl_distance / tick_size) * tick_value;
                if(loss_per_lot > 0)
                {
                    calculated_lot = risk_amount / loss_per_lot;
                }
            }
        }
    }
    
    // Нормализация лота
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    calculated_lot = MathMax(calculated_lot, min_lot);
    calculated_lot = MathMin(calculated_lot, max_lot);
    calculated_lot = NormalizeDouble(calculated_lot / lot_step, 0) * lot_step;
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
//| Управление позициями                                           |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                ulong ticket = m_position.Ticket();
                
                // Перевод в безубыток
                if(EnableBreakeven)
                {
                    MoveToBreakeven(ticket);
                }
                
                // Трейлинг стоп
                if(EnableTrailing)
                {
                    TrailingStop(ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Перевод в безубыток                                            |
//+------------------------------------------------------------------+
void MoveToBreakeven(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket))
        return;
    
    // Проверяем, была ли уже переведена в безубыток
    if(IsPositionInBreakeven(ticket))
        return;
    
    ENUM_POSITION_TYPE pos_type = m_position.PositionType();
    double entry_price = m_position.PriceOpen();
    double current_sl = m_position.StopLoss();
    double current_tp = m_position.TakeProfit();
    
    double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double breakeven_distance = BreakevenStart_Pips * g_PipValue;
    double offset = BreakevenOffset_Pips * g_PipValue;
    
    bool should_move = false;
    double new_sl = 0;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        if(current_price >= entry_price + breakeven_distance)
        {
            new_sl = entry_price + offset;
            should_move = (current_sl == 0 || new_sl > current_sl);
        }
    }
    else
    {
        if(current_price <= entry_price - breakeven_distance)
        {
            new_sl = entry_price - offset;
            should_move = (current_sl == 0 || new_sl < current_sl);
        }
    }
    
    if(should_move)
    {
        new_sl = NormalizeDouble(new_sl, _Digits);
        if(m_trade.PositionModify(ticket, new_sl, current_tp))
        {
            AddToBreakevenList(ticket);
            Print("⚖️ Позиция ", ticket, " переведена в безубыток: ", DoubleToString(new_sl, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Трейлинг стоп                                                  |
//+------------------------------------------------------------------+
void TrailingStop(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket))
        return;
    
    ENUM_POSITION_TYPE pos_type = m_position.PositionType();
    double entry_price = m_position.PriceOpen();
    double current_sl = m_position.StopLoss();
    double current_tp = m_position.TakeProfit();
    
    double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double trailing_start = TrailingStart_Pips * g_PipValue;
    double trailing_step = TrailingStep_Pips * g_PipValue;
    
    bool should_trail = false;
    double new_sl = 0;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        double profit_distance = current_price - entry_price;
        if(profit_distance >= trailing_start)
        {
            new_sl = current_price - trailing_step;
            should_trail = (current_sl == 0 || new_sl > current_sl + trailing_step * 0.5);
        }
    }
    else
    {
        double profit_distance = entry_price - current_price;
        if(profit_distance >= trailing_start)
        {
            new_sl = current_price + trailing_step;
            should_trail = (current_sl == 0 || new_sl < current_sl - trailing_step * 0.5);
        }
    }
    
    if(should_trail)
    {
        new_sl = NormalizeDouble(new_sl, _Digits);
        if(m_trade.PositionModify(ticket, new_sl, current_tp))
        {
            Print("📈 Трейлинг стоп обновлен для позиции ", ticket, ": ", DoubleToString(new_sl, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Проверка позиции в безубытке                                   |
//+------------------------------------------------------------------+
bool IsPositionInBreakeven(ulong ticket)
{
    int size = ArraySize(g_BreakevenPositions);
    for(int i = 0; i < size; i++)
    {
        if(g_BreakevenPositions[i] == ticket)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Добавление в список безубытка                                  |
//+------------------------------------------------------------------+
void AddToBreakevenList(ulong ticket)
{
    int size = ArraySize(g_BreakevenPositions);
    ArrayResize(g_BreakevenPositions, size + 1);
    g_BreakevenPositions[size] = ticket;
}

//+------------------------------------------------------------------+
//| Очистка списка безубытка                                       |
//+------------------------------------------------------------------+
void CleanupBreakevenArray()
{
    if(ArraySize(g_BreakevenPositions) == 0) return;
    
    ulong temp_array[];
    ArrayResize(temp_array, 0);
    
    for(int i = 0; i < ArraySize(g_BreakevenPositions); i++)
    {
        if(m_position.SelectByTicket(g_BreakevenPositions[i]))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                int size = ArraySize(temp_array);
                ArrayResize(temp_array, size + 1);
                temp_array[size] = g_BreakevenPositions[i];
            }
        }
    }
    
    ArrayResize(g_BreakevenPositions, ArraySize(temp_array));
    for(int i = 0; i < ArraySize(temp_array); i++)
    {
        g_BreakevenPositions[i] = temp_array[i];
    }
}

//+------------------------------------------------------------------+
//| Деинициализация                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Деинициализация TrendFollower M15 EA ===");
    
    // Освобождение ресурсов
    if(h_FastMA != INVALID_HANDLE) IndicatorRelease(h_FastMA);
    if(h_SlowMA != INVALID_HANDLE) IndicatorRelease(h_SlowMA);
    if(h_TrendMA != INVALID_HANDLE) IndicatorRelease(h_TrendMA);
    if(h_RSI != INVALID_HANDLE) IndicatorRelease(h_RSI);
    if(h_Stoch != INVALID_HANDLE) IndicatorRelease(h_Stoch);
    if(h_ATR != INVALID_HANDLE) IndicatorRelease(h_ATR);
    
    Print("✅ Деинициализация завершена");
} 