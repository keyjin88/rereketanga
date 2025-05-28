//+------------------------------------------------------------------+
//|                                      DivergenceTrader_EA.mq5    |
//|                          Copyright 2024, Expert Advisor Version |
//|                             Автоматическая торговля дивергенций |
//|                                    Оптимизировано для M15 EURUSD |
//|                                                                  |
//| РЕКОМЕНДАЦИИ ДЛЯ M15 EURUSD:                                    |
//| - Лучшее время торговли: 07:00-20:00 GMT (европейская + US)    |
//| - Рекомендуемый риск: 1-2% на сделку                           |
//| - Спред должен быть менее 3 пипсов                             |
//| - Тестировать на исторических данных минимум 3 месяца          |
//| - Избегать торговли во время важных новостей EUR/USD           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Expert Advisor Version"
#property link      ""
#property version   "1.01"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Объекты для торговли
CTrade        m_trade;
CPositionInfo m_position;
COrderInfo    m_order;

//+------------------------------------------------------------------+
//| Структуры для хранения пиков и дивергенций                      |
//+------------------------------------------------------------------+
struct Peak
{
   int      index;
   double   value;
   double   price;
   datetime time;
};

struct TradeSignal
{
    string   type;           // Тип сигнала (StochBearish, StochBullish, MACDBearish, MACDBullish)
    bool     is_bearish;     // Направление сигнала
    double   entry_price;    // Цена входа
    double   tp_price;       // Take Profit
    double   sl_price;       // Stop Loss
    double   strength;       // Сила сигнала
    datetime signal_time;    // Время сигнала
    int      signal_bar;     // Бар сигнала
};

//--- Входные параметры для Stochastic (оптимизировано для M15)
input group "=== Настройки Stochastic ==="
input int StochKPeriod = 14;                // Период %K (оптимизировано для M15)
input int StochDPeriod = 3;                 // Период %D
input int StochSlowing = 3;                 // Замедление (уменьшено для быстрой реакции)

//--- Входные параметры для MACD (стандартные настройки подходят для M15)
input group "=== Настройки MACD ==="
input int MACDFastEMA = 12;                 // Быстрый EMA
input int MACDSlowEMA = 26;                 // Медленный EMA
input int MACDSignalPeriod = 9;             // Период сигнальной линии

//--- Настройки поиска дивергенций (оптимизировано для M15)
input group "=== Настройки дивергенций ==="
input bool StochBearish = true;             // Торговать медвежьи дивергенции Stochastic
input bool StochBullish = true;             // Торговать бычьи дивергенции Stochastic
input bool MACDBearish = true;              // Торговать медвежьи дивергенции MACD
input bool MACDBullish = true;              // Торговать бычьи дивергенции MACD
input bool OnlyDoubleDivergences = false;   // Торговать только двойные дивергенции
input double MACDPickDif = 0.8;             // Минимальная разница для пиков MACD (оптимизировано для EURUSD)
input int MinBarsBetweenPeaks = 8;          // Минимальное расстояние между пиками (оптимизировано для M15)
input int MaxBarsToAnalyze = 80;            // Максимальное количество баров для анализа (увеличено для M15)
input int NrLoad = 120;                     // Количество баров для анализа (увеличено для M15)

//--- Настройки торговли
input group "=== Настройки торговли ==="
input bool EnableTrading = true;            // Разрешить торговлю
input bool BacktestMode = false;            // Режим тестирования (анализ исторических данных)
input double LotSize = 0.1;                 // Размер лота
input bool UseAutoLotSize = true;           // Автоматический расчет лота (включен по умолчанию)
input double RiskPercent = 1.5;             // Риск на сделку (% от депозита, уменьшен для M15)
input int MaxPositions = 2;                 // Максимальное количество позиций (увеличено для M15)
input bool AllowOpposite = true;            // Разрешить противоположные позиции (включено для M15)
input int MagicNumber = 151234;             // Магический номер (изменен для M15 версии)

//--- Настройки TP/SL (оптимизировано для M15 EURUSD)
input group "=== Настройки TP/SL ==="
input int ATRPeriod = 14;                   // Период ATR (стандартный для M15)
input double ATRMultiplierTP = 2.0;         // Множитель ATR для TP (уменьшено для M15)
input double ATRMultiplierSL = 1.5;         // Множитель ATR для SL (оптимизировано для M15)
input bool UseFixedTPSL = false;            // Использовать фиксированные TP/SL
input int FixedTPPoints = 300;              // Фиксированный TP в пунктах (оптимизировано для EURUSD M15)
input int FixedSLPoints = 150;              // Фиксированный SL в пунктах (оптимизировано для EURUSD M15)
input double MinStopDistanceMultiplier = 1.5; // Множитель минимальной дистанции стопов (уменьшено)

//--- Настройки трейлинга (оптимизировано для M15)
input group "=== Настройки трейлинга ==="
input bool EnableTrailing = true;           // Включить трейлинг стоп
input double TrailingStart = 150;           // Начать трейлинг после (пунктов, уменьшено для M15)
input double TrailingStop = 80;             // Шаг трейлинга (пунктов, оптимизировано для M15)
input double TrailingStep = 30;             // Минимальный шаг (пунктов, уменьшено для M15)

//--- Настройки безубытка (оптимизировано для M15)
input group "=== Настройки безубытка ==="
input bool EnableBreakeven = true;          // Включить перевод в безубыток
input double BreakevenTrigger = 40.0;       // При достижении % от TP переводить в безубыток (увеличено для M15)
input double BreakevenOffset = 8.0;         // Отступ от цены входа (пунктов, оптимизировано для EURUSD)
input bool BreakevenOnce = true;            // Переводить в безубыток только один раз

//--- Настройки времени торговли (оптимизировано для EURUSD)
input group "=== Фильтр времени торговли ==="
input bool EnableTimeFilter = true;         // Включить фильтр времени для открытия позиций
input bool CloseAtSessionEnd = false;       // Закрывать позиции в конце торговой сессии
input string SessionStartTime = "07:00";    // Время начала торговой сессии (европейская сессия)
input string SessionEndTime = "20:00";      // Время окончания торговой сессии (американская сессия)
input bool TradeMonday = true;              // Торговать в понедельник
input bool TradeTuesday = true;             // Торговать во вторник
input bool TradeWednesday = true;           // Торговать в среду
input bool TradeThursday = true;            // Торговать в четверг
input bool TradeFriday = true;              // Торговать в пятницу

//--- Настройки силы сигнала (оптимизировано для M15)
input group "=== Фильтры силы сигнала ==="
input bool EnableStrengthFilter = true;     // Включить фильтр силы сигнала
input double MinSignalStrength = 8.0;       // Минимальная сила сигнала (уменьшено для M15)
input bool RequireStochInZone = true;       // Требовать Stochastic в зоне
input double StochOverboughtLevel = 75.0;   // Уровень перекупленности (увеличено для M15)
input double StochOversoldLevel = 25.0;     // Уровень перепроданности (уменьшено для M15)

//--- Фильтр тренда (оптимизировано для M15)
input group "=== Фильтр тренда ==="
input bool UseTrendFilter = true;           // Использовать фильтр тренда
input int TrendMA_Period = 34;              // Период MA для определения тренда (оптимизировано для M15)
input bool OnlyCounterTrend = false;        // Торговать по тренду (изменено для M15)
input int MinMinutesBetweenSignals = 30;    // Минимум минут между сигналами (уменьшено для M15)

//--- Настройки уведомлений
input group "=== Настройки уведомлений ==="
input bool EnableAlerts = true;             // Включить алерты
input bool EnableEmailAlerts = false;       // Включить email-уведомления
input bool EnablePushAlerts = false;        // Включить push-уведомления
input bool AlertOnEntry = true;             // Уведомлять о входах
input bool AlertOnClose = true;             // Уведомлять о закрытиях

//--- Настройки интеллектуального закрытия позиций
input group "=== Интеллектуальное закрытие позиций ==="
input bool EnableSmartExit = true;          // Включить умное закрытие позиций
input bool CloseOnOppositeSignal = true;    // Закрывать при противоположном сигнале
input double OppositeSignalMinStrength = 12.0; // Минимальная сила противоположного сигнала для закрытия
input bool CloseOnWeakening = true;         // Закрывать при ослаблении движения
input bool UseRSIForWeakening = true;       // Использовать RSI для определения ослабления
input int RSIPeriod = 14;                   // Период RSI
input double RSIWeakeningLevel = 70.0;      // Уровень RSI для определения ослабления (для BUY)
input bool UsePartialClose = true;          // Частичное закрытие позиций
input double PartialClosePercent = 50.0;    // Процент закрытия при ослаблении
input int MinProfitPointsForSmartExit = 100; // Минимум пунктов прибыли для умного закрытия

//--- Глобальные переменные
int g_stoch_handle;                         // Хендл индикатора Stochastic
int g_macd_handle;                          // Хендл индикатора MACD
int g_atr_handle;                           // Хендл индикатора ATR
int g_trend_ma_handle;                      // Хендл индикатора MA для тренда
int g_rsi_handle;                           // Хендл индикатора RSI для умного закрытия
double g_point;                             // Размер пункта
datetime g_last_signal_time;                // Время последнего сигнала
datetime g_last_bar_time;                   // Время последнего бара
bool g_first_run;                           // Флаг первого запуска

//--- Массивы для хранения пиков
Peak g_stoch_max_peaks[];
Peak g_stoch_min_peaks[];
Peak g_macd_max_peaks[];
Peak g_macd_min_peaks[];

//--- Массив для отслеживания позиций в безубытке
ulong g_breakeven_positions[];              // Тикеты позиций, переведенных в безубыток

//--- Статистика
struct TradingStats
{
    int total_signals;
    int total_trades;
    int winning_trades;
    int losing_trades;
    double total_profit;
    double max_drawdown;
    datetime last_trade_time;
};

TradingStats g_stats;

//+------------------------------------------------------------------+
//| Инициализация эксперта                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Инициализация DivergenceTrader EA для M15 EURUSD ===");
    
    // Проверка символа и таймфрейма
    if(_Symbol != "EURUSD")
        Print("⚠️ ВНИМАНИЕ: Советник оптимизирован для EURUSD, текущий символ: ", _Symbol);
    
    if(_Period != PERIOD_M15)
        Print("⚠️ ВНИМАНИЕ: Советник оптимизирован для M15, текущий таймфрейм: ", EnumToString(_Period));
    
    // Валидация параметров
    if(!ValidateInputs())
        return INIT_PARAMETERS_INCORRECT;
    
    // Инициализация торговых объектов
    m_trade.SetExpertMagicNumber(MagicNumber);
    m_trade.SetMarginMode();
    m_trade.SetTypeFillingBySymbol(_Symbol);
    m_trade.SetDeviationInPoints(10);
    
    // Инициализация индикаторов
    g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, STO_LOWHIGH);
    if(g_stoch_handle == INVALID_HANDLE)
    {
        Print("❌ Ошибка создания индикатора Stochastic: ", GetLastError());
        return INIT_FAILED;
    }
    
    g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACDFastEMA, MACDSlowEMA, MACDSignalPeriod, PRICE_CLOSE);
    if(g_macd_handle == INVALID_HANDLE)
    {
        Print("❌ Ошибка создания индикатора MACD: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        return INIT_FAILED;
    }
    
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("❌ Ошибка создания индикатора ATR: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        IndicatorRelease(g_macd_handle);
        return INIT_FAILED;
    }
    
    g_trend_ma_handle = iMA(_Symbol, PERIOD_CURRENT, TrendMA_Period, 0, MODE_SMA, PRICE_CLOSE);
    if(g_trend_ma_handle == INVALID_HANDLE)
    {
        Print("❌ Ошибка создания индикатора MA для тренда: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        IndicatorRelease(g_macd_handle);
        IndicatorRelease(g_atr_handle);
        return INIT_FAILED;
    }
    
    // Инициализация RSI для умного закрытия
    if(EnableSmartExit && UseRSIForWeakening)
    {
        g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
        if(g_rsi_handle == INVALID_HANDLE)
        {
            Print("❌ Ошибка создания индикатора RSI: ", GetLastError());
            IndicatorRelease(g_stoch_handle);
            IndicatorRelease(g_macd_handle);
            IndicatorRelease(g_atr_handle);
            IndicatorRelease(g_trend_ma_handle);
            return INIT_FAILED;
        }
    }
    
    // Инициализация переменных
    g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    g_last_signal_time = 0;
    g_last_bar_time = 0;
    g_first_run = true;
    
    // Инициализация статистики
    ZeroMemory(g_stats);
    
    // Изменение размера массивов
    ArrayResize(g_stoch_max_peaks, 0);
    ArrayResize(g_stoch_min_peaks, 0);
    ArrayResize(g_macd_max_peaks, 0);
    ArrayResize(g_macd_min_peaks, 0);
    ArrayResize(g_breakeven_positions, 0);
    
    Print("✅ Инициализация завершена успешно");
    Print("📊 Торговля: ", (EnableTrading ? "ВКЛЮЧЕНА" : "ОТКЛЮЧЕНА"));
    Print("💰 Размер лота: ", (UseAutoLotSize ? "Авто (" + DoubleToString(RiskPercent, 1) + "%)" : DoubleToString(LotSize, 2)));
    Print("🎯 Максимум позиций: ", MaxPositions);
    Print("🔄 Противоположные позиции: ", (AllowOpposite ? "РАЗРЕШЕНЫ" : "ЗАПРЕЩЕНЫ"));
    Print("🕒 Фильтр времени открытия: ", (EnableTimeFilter ? SessionStartTime + " - " + SessionEndTime + " (EURUSD сессии)" : "ОТКЛЮЧЕН"));
    Print("🔒 Закрытие в конце сессии: ", (CloseAtSessionEnd ? "ВКЛЮЧЕНО" : "ОТКЛЮЧЕНО"));
    Print("🎯 Трейлинг стоп: ", (EnableTrailing ? "ВКЛЮЧЕН (начало: " + DoubleToString(TrailingStart, 0) + " пп)" : "ОТКЛЮЧЕН"));
    Print("⚖️ Безубыток: ", (EnableBreakeven ? "ВКЛЮЧЕН при " + DoubleToString(BreakevenTrigger, 1) + "%" : "ОТКЛЮЧЕН"));
    Print("📈 Фильтр тренда: ", (UseTrendFilter ? "ВКЛЮЧЕН (MA" + IntegerToString(TrendMA_Period) + ", торговля: " + (OnlyCounterTrend ? "ПРОТИВ тренда)" : "ПО тренду)") : "ОТКЛЮЧЕН"));
    Print("📊 Stochastic: K" + IntegerToString(StochKPeriod) + ", D" + IntegerToString(StochDPeriod) + ", зоны: " + DoubleToString(StochOversoldLevel, 0) + "-" + DoubleToString(StochOverboughtLevel, 0));
    Print("📈 MACD: " + IntegerToString(MACDFastEMA) + "," + IntegerToString(MACDSlowEMA) + "," + IntegerToString(MACDSignalPeriod) + ", мин.разность: " + DoubleToString(MACDPickDif, 1));
    Print("⏱️ M15 оптимизация: Пики через " + IntegerToString(MinBarsBetweenPeaks) + " баров, анализ " + IntegerToString(MaxBarsToAnalyze) + " баров");
    
    // Информация об интеллектуальном закрытии
    if(EnableSmartExit)
    {
        Print("🧠 Умное закрытие: ВКЛЮЧЕНО");
        if(CloseOnOppositeSignal)
            Print("🔄 Закрытие по противоположному сигналу: мин.сила " + DoubleToString(OppositeSignalMinStrength, 1));
        if(CloseOnWeakening)
        {
            Print("📉 Закрытие при ослаблении: ВКЛЮЧЕНО");
            if(UseRSIForWeakening)
                Print("📊 RSI фильтр: период " + IntegerToString(RSIPeriod) + ", уровень " + DoubleToString(RSIWeakeningLevel, 1));
            if(UsePartialClose)
                Print("🔸 Частичное закрытие: " + DoubleToString(PartialClosePercent, 1) + "%");
        }
        Print("💰 Мин.прибыль для умного закрытия: " + IntegerToString(MinProfitPointsForSmartExit) + " пунктов");
    }
    else
    {
        Print("🧠 Умное закрытие: ОТКЛЮЧЕНО");
    }
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Валидация входных параметров                                    |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(LotSize <= 0 || LotSize > 100)
    {
        Print("❌ Неверный размер лота: ", LotSize);
        return false;
    }
    
    if(RiskPercent <= 0 || RiskPercent > 20)
    {
        Print("❌ Риск должен быть от 0.1% до 20%: ", RiskPercent);
        return false;
    }
    
    if(MaxPositions <= 0 || MaxPositions > 10)
    {
        Print("❌ Максимальное количество позиций должно быть от 1 до 10: ", MaxPositions);
        return false;
    }
    
    if(StochKPeriod < 1 || StochKPeriod > 100)
    {
        Print("❌ Неверный период %K для Stochastic: ", StochKPeriod);
        return false;
    }
    
    if(MACDFastEMA >= MACDSlowEMA)
    {
        Print("❌ Быстрый EMA должен быть меньше медленного EMA");
        return false;
    }
    
    if(EnableTimeFilter)
    {
        if(ParseTimeString(SessionStartTime) == -1)
        {
            Print("❌ Неверный формат времени начала: ", SessionStartTime);
            return false;
        }
        
        if(ParseTimeString(SessionEndTime) == -1)
        {
            Print("❌ Неверный формат времени окончания: ", SessionEndTime);
            return false;
        }
    }
    
    // Проверяем настройки времени для автозакрытия позиций
    if(CloseAtSessionEnd)
    {
        if(ParseTimeString(SessionStartTime) == -1)
        {
            Print("❌ Неверный формат времени начала (требуется для автозакрытия): ", SessionStartTime);
            return false;
        }
        
        if(ParseTimeString(SessionEndTime) == -1)
        {
            Print("❌ Неверный формат времени окончания (требуется для автозакрытия): ", SessionEndTime);
            return false;
        }
    }
    
    // Проверяем минимальные требования для торговли
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(LotSize < min_lot)
    {
        Print("❌ Размер лота меньше минимального: ", LotSize, " < ", min_lot);
        return false;
    }
    
    if(LotSize > max_lot)
    {
        Print("❌ Размер лота больше максимального: ", LotSize, " > ", max_lot);
        return false;
    }
    
    // Валидация параметров безубытка
    if(EnableBreakeven)
    {
        if(BreakevenTrigger <= 0 || BreakevenTrigger >= 100)
        {
            Print("❌ Триггер безубытка должен быть от 1% до 99%: ", BreakevenTrigger);
            return false;
        }
        
        if(BreakevenOffset < 0 || BreakevenOffset > 1000)
        {
            Print("❌ Отступ безубытка должен быть от 0 до 1000 пунктов: ", BreakevenOffset);
            return false;
        }
    }
    
    // Дополнительные проверки для EURUSD M15
    if(_Symbol == "EURUSD")
    {
        double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(spread > 3.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT))
        {
            Print("⚠️ ВНИМАНИЕ: Большой спред для EURUSD: ", DoubleToString(spread, 5), 
                  " - рекомендуется торговать при спреде менее 3 пипсов");
        }
        
        if(UseAutoLotSize && RiskPercent > 2.0)
        {
            Print("⚠️ ВНИМАНИЕ: Для M15 EURUSD рекомендуется риск не более 2% на сделку");
        }
    }
    
    // Валидация параметров интеллектуального закрытия
    if(EnableSmartExit)
    {
        if(OppositeSignalMinStrength <= 0 || OppositeSignalMinStrength > 100)
        {
            Print("❌ Минимальная сила противоположного сигнала должна быть от 1 до 100: ", OppositeSignalMinStrength);
            return false;
        }
        
        if(UseRSIForWeakening)
        {
            if(RSIPeriod < 2 || RSIPeriod > 100)
            {
                Print("❌ Период RSI должен быть от 2 до 100: ", RSIPeriod);
                return false;
            }
            
            if(RSIWeakeningLevel <= 50 || RSIWeakeningLevel >= 100)
            {
                Print("❌ Уровень ослабления RSI должен быть от 50 до 100: ", RSIWeakeningLevel);
                return false;
            }
        }
        
        if(UsePartialClose)
        {
            if(PartialClosePercent <= 0 || PartialClosePercent >= 100)
            {
                Print("❌ Процент частичного закрытия должен быть от 1% до 99%: ", PartialClosePercent);
                return false;
            }
        }
        
        if(MinProfitPointsForSmartExit < 0 || MinProfitPointsForSmartExit > 10000)
        {
            Print("❌ Минимум пунктов прибыли для умного закрытия должен быть от 0 до 10000: ", MinProfitPointsForSmartExit);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Основная функция эксперта                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    // Проверяем новый бар
    datetime current_time = iTime(_Symbol, PERIOD_CURRENT, 0);
    bool is_new_bar = (current_time != g_last_bar_time);
    
    if(is_new_bar || g_first_run)
    {
        g_last_bar_time = current_time;
        g_first_run = false;
        
        // Очистка массива безубытка от закрытых позиций
        CleanupBreakevenArray();
        
        // Основная логика торговли
        ProcessTradingLogic();
    }
    
    // Управление открытыми позициями
    ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Основная торговая логика                                        |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
    // Проверяем готовность данных
    if(!WaitForIndicatorData())
        return;
    
    // Фильтр времени торговли
    if(EnableTimeFilter && !IsTimeToTrade())
        return;
    
    // Поиск пиков
    FindPeaks(g_stoch_handle, 0, g_stoch_max_peaks, g_stoch_min_peaks, true);
    FindPeaks(g_macd_handle, 0, g_macd_max_peaks, g_macd_min_peaks, false);
    
    // Поиск торговых сигналов
    TradeSignal signals[];
    ArrayResize(signals, 0);
    
    if(StochBearish) FindTradingSignals(g_stoch_max_peaks, "StochBearish", true, false, signals);
    if(StochBullish) FindTradingSignals(g_stoch_min_peaks, "StochBullish", false, false, signals);
    if(MACDBearish) FindTradingSignals(g_macd_max_peaks, "MACDBearish", true, true, signals);
    if(MACDBullish) FindTradingSignals(g_macd_min_peaks, "MACDBullish", false, true, signals);
    
    // Обработка найденных сигналов
    ProcessTradingSignals(signals);
}

//+------------------------------------------------------------------+
//| Ожидание готовности данных индикаторов                         |
//+------------------------------------------------------------------+
bool WaitForIndicatorData()
{
    double temp_buffer[];
    
    if(CopyBuffer(g_stoch_handle, 0, 0, 1, temp_buffer) <= 0) return false;
    if(CopyBuffer(g_macd_handle, 0, 0, 1, temp_buffer) <= 0) return false;
    if(CopyBuffer(g_atr_handle, 0, 0, 1, temp_buffer) <= 0) return false;
    
    // Проверяем RSI только если он используется
    if(EnableSmartExit && UseRSIForWeakening && g_rsi_handle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_rsi_handle, 0, 0, 1, temp_buffer) <= 0) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Поиск пиков (копия из индикатора с упрощениями)                |
//+------------------------------------------------------------------+
void FindPeaks(int indicator_handle, int buffer_index, Peak &max_peaks[], Peak &min_peaks[], bool is_stochastic)
{
    double values[];
    ArraySetAsSeries(values, true);
    
    int copied = CopyBuffer(indicator_handle, buffer_index, 0, NrLoad, values);
    if(copied <= 0) return;
    
    ArrayResize(max_peaks, 0);
    ArrayResize(min_peaks, 0);
    
    Peak temp_max_peaks[], temp_min_peaks[];
    ArrayResize(temp_max_peaks, 0);
    ArrayResize(temp_min_peaks, 0);
    
    int lookback = 2;
    
    // Определяем диапазон поиска в зависимости от режима
    int start_bar, end_bar;
    if(BacktestMode)
    {
        // В режиме тестирования анализируем исторические бары
        start_bar = lookback;
        end_bar = MathMin(copied - lookback, MaxBarsToAnalyze);
        Print("ОТЛАДКА: Режим тестирования - анализ баров от ", start_bar, " до ", end_bar);
    }
    else
    {
        // В реальной торговле - только текущий бар и ближайшие
        start_bar = 0;
        end_bar = lookback + 1;
    }
    
    for(int i = start_bar; i < end_bar; i++)
    {
        if(i >= copied) continue;
        
        double curr_val = values[i];
        datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);
        
        bool is_max = true;
        bool is_min = true;
        
        // Проверяем окружающие бары
        if(i == 0 && !BacktestMode)
        {
            // Для текущего бара в реальном времени сравниваем с предыдущими
            for(int k = 1; k <= lookback && k < copied; k++)
            {
                if(curr_val <= values[k]) is_max = false;
                if(curr_val >= values[k]) is_min = false;
            }
        }
        else
        {
            // Для исторических баров или режима тестирования - обычная проверка с обеих сторон
            for(int k = 1; k <= lookback; k++)
            {
                if((i - k >= 0 && curr_val <= values[i - k]) || 
                   (i + k < copied && curr_val <= values[i + k]))
                    is_max = false;
                if((i - k >= 0 && curr_val >= values[i - k]) || 
                   (i + k < copied && curr_val >= values[i + k]))
                    is_min = false;
            }
        }
        
        // Фильтрация для Stochastic
        if(is_stochastic)
        {
            if(is_max && curr_val < StochOverboughtLevel) is_max = false;
            if(is_min && curr_val > StochOversoldLevel) is_min = false;
        }
        
        if(is_max)
        {
            double price = iHigh(_Symbol, PERIOD_CURRENT, i);
            Peak peak;
            peak.index = i;
            peak.value = curr_val;
            peak.price = price;
            peak.time = bar_time;
            ArrayResize(temp_max_peaks, ArraySize(temp_max_peaks) + 1);
            temp_max_peaks[ArraySize(temp_max_peaks) - 1] = peak;
            
            if(BacktestMode)
                Print("ОТЛАДКА: Найден пик MAX на баре ", i, ", значение: ", curr_val, ", цена: ", price);
        }
        
        if(is_min)
        {
            double price = iLow(_Symbol, PERIOD_CURRENT, i);
            Peak peak;
            peak.index = i;
            peak.value = curr_val;
            peak.price = price;
            peak.time = bar_time;
            ArrayResize(temp_min_peaks, ArraySize(temp_min_peaks) + 1);
            temp_min_peaks[ArraySize(temp_min_peaks) - 1] = peak;
            
            if(BacktestMode)
                Print("ОТЛАДКА: Найден пик MIN на баре ", i, ", значение: ", curr_val, ", цена: ", price);
        }
    }
    
    // Фильтрация по расстоянию
    FilterPeaksByDistance(temp_max_peaks, max_peaks);
    FilterPeaksByDistance(temp_min_peaks, min_peaks);
    
    if(BacktestMode)
    {
        Print("ОТЛАДКА: После фильтрации - MAX пиков: ", ArraySize(max_peaks), ", MIN пиков: ", ArraySize(min_peaks));
    }
}

//+------------------------------------------------------------------+
//| Фильтрация пиков по расстоянию                                  |
//+------------------------------------------------------------------+
void FilterPeaksByDistance(Peak &source_peaks[], Peak &filtered_peaks[])
{
    int source_count = ArraySize(source_peaks);
    if(source_count == 0) return;
    
    ArrayResize(filtered_peaks, 0);
    
    for(int i = 0; i < source_count; i++)
    {
        bool add_peak = true;
        
        for(int j = 0; j < ArraySize(filtered_peaks); j++)
        {
            if(MathAbs(source_peaks[i].index - filtered_peaks[j].index) < MinBarsBetweenPeaks)
            {
                if(MathAbs(source_peaks[i].value) > MathAbs(filtered_peaks[j].value))
                {
                    filtered_peaks[j] = source_peaks[i];
                }
                add_peak = false;
                break;
            }
        }
        
        if(add_peak)
        {
            ArrayResize(filtered_peaks, ArraySize(filtered_peaks) + 1);
            filtered_peaks[ArraySize(filtered_peaks) - 1] = source_peaks[i];
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск торговых сигналов                                        |
//+------------------------------------------------------------------+
void FindTradingSignals(Peak &peaks[], string type, bool is_bearish, bool is_macd, TradeSignal &signals[])
{
    int peaks_count = ArraySize(peaks);
    if(peaks_count < 2) 
    {
        if(BacktestMode)
            Print("ОТЛАДКА: Недостаточно пиков для ", type, " - найдено: ", peaks_count);
        return;
    }
    
    if(BacktestMode)
    {
        // В режиме тестирования анализируем ВСЕ комбинации пиков
        FindSignalsBacktest(peaks, type, is_bearish, is_macd, signals);
    }
    else
    {
        // В реальном времени - только с участием текущего бара
        FindSignalsRealtime(peaks, type, is_bearish, is_macd, signals);
    }
}

//+------------------------------------------------------------------+
//| Поиск сигналов в режиме реального времени                      |
//+------------------------------------------------------------------+
void FindSignalsRealtime(Peak &peaks[], string type, bool is_bearish, bool is_macd, TradeSignal &signals[])
{
    int peaks_count = ArraySize(peaks);
    
    // Проверяем, есть ли пик на текущем баре
    int current_bar_peak_idx = -1;
    for(int i = 0; i < peaks_count; i++)
    {
        if(peaks[i].index == 0)
        {
            current_bar_peak_idx = i;
            break;
        }
    }
    
    if(current_bar_peak_idx == -1) return;
    
    Peak current_peak = peaks[current_bar_peak_idx];
    
    // Ищем дивергенции с историческими пиками
    for(int i = 0; i < peaks_count; i++)
    {
        if(i == current_bar_peak_idx) continue;
        
        Peak historical_peak = peaks[i];
        
        // Проверки расстояния и времени
        if(historical_peak.index - current_peak.index < MinBarsBetweenPeaks) continue;
        if(historical_peak.index > MaxBarsToAnalyze) continue;
        
        // Проверка дивергенции и создание сигнала
        if(CheckDivergenceAndCreateSignal(current_peak, historical_peak, type, is_bearish, is_macd, signals))
            break; // Берем только первую найденную дивергенцию
    }
}

//+------------------------------------------------------------------+
//| Поиск сигналов в режиме тестирования                           |
//+------------------------------------------------------------------+
void FindSignalsBacktest(Peak &peaks[], string type, bool is_bearish, bool is_macd, TradeSignal &signals[])
{
    int peaks_count = ArraySize(peaks);
    
    // В режиме тестирования анализируем все возможные пары пиков
    for(int i = 0; i < peaks_count - 1; i++)
    {
        for(int j = i + 1; j < peaks_count; j++)
        {
            Peak recent_peak = peaks[i];    // Более свежий пик (меньший индекс)
            Peak older_peak = peaks[j];     // Более старый пик (больший индекс)
            
            // Проверки расстояния и времени
            if(older_peak.index - recent_peak.index < MinBarsBetweenPeaks) continue;
            if(older_peak.index > MaxBarsToAnalyze) continue;
            
            // Проверка дивергенции и создание сигнала
            CheckDivergenceAndCreateSignal(recent_peak, older_peak, type, is_bearish, is_macd, signals);
        }
    }
    
    if(BacktestMode && ArraySize(signals) > 0)
    {
        Print("ОТЛАДКА: Найдено сигналов ", type, ": ", ArraySize(signals));
    }
}

//+------------------------------------------------------------------+
//| Проверка дивергенции и создание сигнала                        |
//+------------------------------------------------------------------+
bool CheckDivergenceAndCreateSignal(const Peak &recent_peak, const Peak &older_peak, string type, bool is_bearish, bool is_macd, TradeSignal &signals[])
{
    // Проверка условий дивергенции
    bool divergence_found = false;
    double strength = 0.0;
    
    if(is_bearish)
    {
        bool price_grows = older_peak.price < recent_peak.price;
        bool indicator_falls = older_peak.value > recent_peak.value;
        
        if(price_grows && indicator_falls)
        {
            if(is_macd)
            {
                double macd_diff = MathAbs(older_peak.value - recent_peak.value);
                if(macd_diff >= MACDPickDif * g_point)
                {
                    divergence_found = true;
                    strength = macd_diff + (recent_peak.price - older_peak.price) / g_point;
                }
            }
            else
            {
                divergence_found = true;
                strength = (older_peak.value - recent_peak.value) + (recent_peak.price - older_peak.price) / g_point;
            }
        }
    }
    else
    {
        bool price_falls = older_peak.price > recent_peak.price;
        bool indicator_grows = older_peak.value < recent_peak.value;
        
        if(price_falls && indicator_grows)
        {
            if(is_macd)
            {
                double macd_diff = MathAbs(older_peak.value - recent_peak.value);
                if(macd_diff >= MACDPickDif * g_point)
                {
                    divergence_found = true;
                    strength = macd_diff + (older_peak.price - recent_peak.price) / g_point;
                }
            }
            else
            {
                divergence_found = true;
                strength = (recent_peak.value - older_peak.value) + (older_peak.price - recent_peak.price) / g_point;
            }
        }
    }
    
    // Если дивергенция найдена, создаем торговый сигнал
    if(divergence_found)
    {
        // Фильтр силы сигнала
        if(EnableStrengthFilter && strength < MinSignalStrength)
        {
            if(BacktestMode)
                Print("ОТЛАДКА: Сигнал отклонен - слабая сила: ", strength, " < ", MinSignalStrength);
            return false;
        }
        
        // Фильтр тренда
        if(!IsTrendFilterPassed(is_bearish))
        {
            if(BacktestMode)
                Print("ОТЛАДКА: Сигнал отклонен фильтром тренда: ", type);
            return false;
        }
        
        // Фильтр времени между сигналами
        if(!IsTimeBetweenSignalsPassed())
        {
            if(BacktestMode)
                Print("ОТЛАДКА: Сигнал отклонен - слишком рано после предыдущего");
            return false;
        }
        
        TradeSignal signal;
        signal.type = type;
        signal.is_bearish = is_bearish;
        signal.entry_price = recent_peak.price;  // Используем цену более свежего пика
        signal.strength = strength;
        signal.signal_time = recent_peak.time;
        signal.signal_bar = recent_peak.index;
        
        // Расчет TP/SL
        CalculateTPSL(signal);
        
        // Обновляем время последнего сигнала
        g_last_signal_time = TimeCurrent();
        
        // Добавляем сигнал в массив
        int idx = ArraySize(signals);
        ArrayResize(signals, idx + 1);
        signals[idx] = signal;
        
        g_stats.total_signals++;
        
        Print("📈 ТОРГОВЫЙ СИГНАЛ: ", type, " | Сила: ", DoubleToString(strength, 2), 
              " | Цена: ", DoubleToString(signal.entry_price, _Digits),
              " | Бар: ", signal.signal_bar);
        
        if(BacktestMode)
        {
            Print("ОТЛАДКА: Создан сигнал - старый пик (бар ", older_peak.index, ", цена ", older_peak.price, ", значение ", older_peak.value, 
                  ") vs новый пик (бар ", recent_peak.index, ", цена ", recent_peak.price, ", значение ", recent_peak.value, ")");
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Расчет TP и SL уровней                                          |
//+------------------------------------------------------------------+
void CalculateTPSL(TradeSignal &signal)
{
    // Получаем текущие цены (НЕ цену пика!)
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_price = signal.is_bearish ? current_bid : current_ask;
    
    // Получаем минимальные дистанции
    int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_distance = stops_level * g_point;
    
    if(min_distance <= 0)
        min_distance = 50 * g_point;
    
    // Используем множитель для безопасности
    min_distance = min_distance * MinStopDistanceMultiplier;
    
    double tp_distance, sl_distance;
    
    if(UseFixedTPSL)
    {
        // Фиксированные TP/SL в пунктах
        tp_distance = FixedTPPoints * g_point;
        sl_distance = FixedSLPoints * g_point;
    }
    else
    {
        // TP/SL на основе ATR
        double atr[];
        ArraySetAsSeries(atr, true);
        
        if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) > 0)
        {
            double atr_value = atr[0];
            tp_distance = ATRMultiplierTP * atr_value;
            sl_distance = ATRMultiplierSL * atr_value;
        }
        else
        {
            // Резервные значения
            tp_distance = 500 * g_point; // 50 пунктов
            sl_distance = 250 * g_point; // 25 пунктов
        }
    }
    
    // Проверяем минимальные дистанции
    tp_distance = MathMax(tp_distance, min_distance);
    sl_distance = MathMax(sl_distance, min_distance);
    
    // Рассчитываем TP/SL от ТЕКУЩЕЙ цены
    if(signal.is_bearish)
    {
        signal.tp_price = current_price - tp_distance;
        signal.sl_price = current_price + sl_distance;
        signal.entry_price = current_price; // Обновляем цену входа
    }
    else
    {
        signal.tp_price = current_price + tp_distance;
        signal.sl_price = current_price - sl_distance;
        signal.entry_price = current_price; // Обновляем цену входа
    }
    
    // Нормализуем цены
    signal.entry_price = NormalizeDouble(signal.entry_price, _Digits);
    signal.tp_price = NormalizeDouble(signal.tp_price, _Digits);
    signal.sl_price = NormalizeDouble(signal.sl_price, _Digits);
    
    if(BacktestMode)
    {
        Print("ОТЛАДКА TP/SL: Текущая цена: ", DoubleToString(current_price, _Digits),
              " | TP: ", DoubleToString(signal.tp_price, _Digits),
              " | SL: ", DoubleToString(signal.sl_price, _Digits),
              " | Мин.дистанция: ", DoubleToString(min_distance, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Валидация уровней TP/SL                                        |
//+------------------------------------------------------------------+
bool ValidateTPSL(double price, double tp, double sl, bool is_buy)
{
    // Получаем минимальные дистанции
    int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_distance = stops_level * g_point;
    
    if(min_distance <= 0)
        min_distance = 50 * g_point;
    
    // Проверяем направление уровней
    if(is_buy)
    {
        // Для BUY: SL должен быть ниже цены, TP - выше
        if(sl > 0 && sl >= price)
        {
            Print("❌ Ошибка SL для BUY: ", sl, " >= ", price);
            return false;
        }
        if(tp > 0 && tp <= price)
        {
            Print("❌ Ошибка TP для BUY: ", tp, " <= ", price);
            return false;
        }
        
        // Проверяем минимальные дистанции
        if(sl > 0 && (price - sl) < min_distance)
        {
            Print("❌ SL слишком близко для BUY: ", (price - sl), " < ", min_distance);
            return false;
        }
        if(tp > 0 && (tp - price) < min_distance)
        {
            Print("❌ TP слишком близко для BUY: ", (tp - price), " < ", min_distance);
            return false;
        }
    }
    else
    {
        // Для SELL: SL должен быть выше цены, TP - ниже
        if(sl > 0 && sl <= price)
        {
            Print("❌ Ошибка SL для SELL: ", sl, " <= ", price);
            return false;
        }
        if(tp > 0 && tp >= price)
        {
            Print("❌ Ошибка TP для SELL: ", tp, " >= ", price);
            return false;
        }
        
        // Проверяем минимальные дистанции
        if(sl > 0 && (sl - price) < min_distance)
        {
            Print("❌ SL слишком близко для SELL: ", (sl - price), " < ", min_distance);
            return false;
        }
        if(tp > 0 && (price - tp) < min_distance)
        {
            Print("❌ TP слишком близко для SELL: ", (price - tp), " < ", min_distance);
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Обработка торговых сигналов                                    |
//+------------------------------------------------------------------+
void ProcessTradingSignals(TradeSignal &signals[])
{
    if(!EnableTrading)
    {
        // Только уведомления, без торговли
        for(int i = 0; i < ArraySize(signals); i++)
        {
            SendTradingAlert("СИГНАЛ (ТОРГОВЛЯ ОТКЛЮЧЕНА)", signals[i]);
        }
        return;
    }
    
    // Проверяем количество открытых позиций
    int current_positions = CountPositions();
    if(current_positions >= MaxPositions)
    {
        Print("⚠️ Достигнуто максимальное количество позиций: ", current_positions);
        return;
    }
    
    // Обрабатываем сигналы по силе (от сильных к слабым)
    SortSignalsByStrength(signals);
    
    for(int i = 0; i < ArraySize(signals); i++)
    {
        TradeSignal signal = signals[i];
        
        // Проверяем, можно ли открыть позицию в этом направлении
        if(!AllowOpposite && HasOppositePosition(signal.is_bearish))
        {
            Print("⚠️ Пропуск сигнала - есть противоположная позиция");
            continue;
        }
        
        // Рассчитываем размер лота
        double lot_size = CalculateLotSize(signal);
        if(lot_size <= 0)
        {
            Print("❌ Ошибка расчета размера лота");
            continue;
        }
        
        // Открываем позицию
        if(OpenPosition(signal, lot_size))
        {
            g_stats.total_trades++;
            g_stats.last_trade_time = TimeCurrent();
            
            Print("✅ Позиция открыта: ", (signal.is_bearish ? "SELL" : "BUY"), 
                  " | Лот: ", DoubleToString(lot_size, 2),
                  " | Цена: ", DoubleToString(signal.entry_price, _Digits));
            
            if(AlertOnEntry)
                SendTradingAlert("ВХОД В ПОЗИЦИЮ", signal);
            
            // Открываем только одну позицию за раз
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Подсчет текущих позиций                                        |
//+------------------------------------------------------------------+
int CountPositions()
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
//| Проверка наличия противоположной позиции                       |
//+------------------------------------------------------------------+
bool HasOppositePosition(bool is_bearish_signal)
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                ENUM_POSITION_TYPE pos_type = m_position.PositionType();
                
                if(is_bearish_signal && pos_type == POSITION_TYPE_BUY)
                    return true;
                if(!is_bearish_signal && pos_type == POSITION_TYPE_SELL)
                    return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Расчет размера лота                                            |
//+------------------------------------------------------------------+
double CalculateLotSize(const TradeSignal &signal)
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
//| Открытие позиции                                               |
//+------------------------------------------------------------------+
bool OpenPosition(const TradeSignal &signal, double lot_size)
{
    // Получаем текущие цены
    double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double current_price = signal.is_bearish ? current_bid : current_ask;
    
    // Пересчитываем TP/SL от текущей цены (на случай изменения)
    TradeSignal updated_signal = signal;
    CalculateTPSL(updated_signal);
    
    // Валидируем уровни
    if(!ValidateTPSL(updated_signal.entry_price, updated_signal.tp_price, updated_signal.sl_price, !signal.is_bearish))
    {
        Print("❌ Невалидные уровни TP/SL для сигнала ", signal.type);
        return false;
    }
    
    string comment = StringFormat("DivEA_%s_%.1f", signal.type, signal.strength);
    
    Print("🔄 Открытие позиции: ", (signal.is_bearish ? "SELL" : "BUY"),
          " | Цена: ", DoubleToString(updated_signal.entry_price, _Digits),
          " | SL: ", DoubleToString(updated_signal.sl_price, _Digits),
          " | TP: ", DoubleToString(updated_signal.tp_price, _Digits));
    
    bool result = false;
    if(signal.is_bearish)
    {
        result = m_trade.Sell(lot_size, _Symbol, 0, updated_signal.sl_price, updated_signal.tp_price, comment);
    }
    else
    {
        result = m_trade.Buy(lot_size, _Symbol, 0, updated_signal.sl_price, updated_signal.tp_price, comment);
    }
    
    if(!result)
    {
        Print("❌ Ошибка открытия позиции: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
        
        // Дополнительная диагностика
        Print("🔍 Диагностика: Bid=", DoubleToString(current_bid, _Digits), 
              " Ask=", DoubleToString(current_ask, _Digits),
              " Спред=", DoubleToString(current_ask - current_bid, _Digits));
        
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Управление открытыми позициями                                 |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    // Интеллектуальное управление закрытием позиций
    SmartExitManagement();
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                // Перевод в безубыток
                if(EnableBreakeven)
                {
                    BreakevenStop(m_position.Ticket());
                }
                
                // Трейлинг стоп
                if(EnableTrailing)
                {
                    TrailingStop(m_position.Ticket());
                }
                
                // Принудительное закрытие позиций в конце торговой сессии
                if(CloseAtSessionEnd && !IsTimeToTrade())
                {
                    ClosePosition(m_position.Ticket(), "Принудительное закрытие - конец сессии");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Перевод позиции в безубыток                                    |
//+------------------------------------------------------------------+
void BreakevenStop(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket))
        return;
    
    // Проверяем, была ли уже переведена в безубыток
    if(BreakevenOnce && IsPositionInBreakeven(ticket))
        return;
    
    ENUM_POSITION_TYPE pos_type = m_position.PositionType();
    double entry_price = m_position.PriceOpen();
    double take_profit = m_position.TakeProfit();
    double stop_loss = m_position.StopLoss();
    
    // Проверяем, есть ли TP (без него нельзя рассчитать процент)
    if(take_profit == 0)
        return;
    
    double current_price;
    double profit_distance, target_distance;
    bool should_breakeven = false;
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        profit_distance = take_profit - entry_price;
        target_distance = profit_distance * BreakevenTrigger / 100.0;
        
        // Проверяем, достигнут ли триггер
        if(current_price >= entry_price + target_distance)
        {
            should_breakeven = true;
        }
    }
    else if(pos_type == POSITION_TYPE_SELL)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        profit_distance = entry_price - take_profit;
        target_distance = profit_distance * BreakevenTrigger / 100.0;
        
        // Проверяем, достигнут ли триггер
        if(current_price <= entry_price - target_distance)
        {
            should_breakeven = true;
        }
    }
    
    if(should_breakeven)
    {
        // Рассчитываем новый SL с отступом
        double offset = BreakevenOffset * g_point;
        double new_sl;
        
        if(pos_type == POSITION_TYPE_BUY)
        {
            new_sl = entry_price + offset;
            
            // Проверяем, что новый SL лучше текущего
            if(stop_loss == 0 || new_sl > stop_loss)
            {
                new_sl = NormalizeDouble(new_sl, _Digits);
                
                if(m_trade.PositionModify(ticket, new_sl, take_profit))
                {
                    Print("⚖️ BUY переведен в безубыток: ", DoubleToString(new_sl, _Digits),
                          " (триггер: ", DoubleToString(BreakevenTrigger, 1), "%)");
                    
                    AddPositionToBreakeven(ticket);
                    
                    if(EnableAlerts)
                        Alert("⚖️ Позиция ", ticket, " переведена в безубыток");
                }
            }
        }
        else
        {
            new_sl = entry_price - offset;
            
            // Проверяем, что новый SL лучше текущего
            if(stop_loss == 0 || new_sl < stop_loss)
            {
                new_sl = NormalizeDouble(new_sl, _Digits);
                
                if(m_trade.PositionModify(ticket, new_sl, take_profit))
                {
                    Print("⚖️ SELL переведен в безубыток: ", DoubleToString(new_sl, _Digits),
                          " (триггер: ", DoubleToString(BreakevenTrigger, 1), "%)");
                    
                    AddPositionToBreakeven(ticket);
                    
                    if(EnableAlerts)
                        Alert("⚖️ Позиция ", ticket, " переведена в безубыток");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Проверка, переведена ли позиция в безубыток                    |
//+------------------------------------------------------------------+
bool IsPositionInBreakeven(ulong ticket)
{
    int size = ArraySize(g_breakeven_positions);
    for(int i = 0; i < size; i++)
    {
        if(g_breakeven_positions[i] == ticket)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Добавление позиции в список безубытка                          |
//+------------------------------------------------------------------+
void AddPositionToBreakeven(ulong ticket)
{
    // Проверяем, что позиция еще не в списке
    if(IsPositionInBreakeven(ticket))
        return;
    
    int size = ArraySize(g_breakeven_positions);
    ArrayResize(g_breakeven_positions, size + 1);
    g_breakeven_positions[size] = ticket;
}

//+------------------------------------------------------------------+
//| Очистка закрытых позиций из массива безубытка                  |
//+------------------------------------------------------------------+
void CleanupBreakevenArray()
{
    if(ArraySize(g_breakeven_positions) == 0) return;
    
    ulong temp_array[];
    ArrayResize(temp_array, 0);
    
    for(int i = 0; i < ArraySize(g_breakeven_positions); i++)
    {
        // Проверяем, существует ли еще позиция
        if(m_position.SelectByTicket(g_breakeven_positions[i]))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                int size = ArraySize(temp_array);
                ArrayResize(temp_array, size + 1);
                temp_array[size] = g_breakeven_positions[i];
            }
        }
    }
    
    // Копируем обратно
    ArrayResize(g_breakeven_positions, ArraySize(temp_array));
    for(int i = 0; i < ArraySize(temp_array); i++)
    {
        g_breakeven_positions[i] = temp_array[i];
    }
}

//+------------------------------------------------------------------+
//| Трейлинг стоп                                                  |
//+------------------------------------------------------------------+
void TrailingStop(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket))
        return;
    
    double current_price, stop_loss, new_sl;
    ENUM_POSITION_TYPE pos_type = m_position.PositionType();
    
    if(pos_type == POSITION_TYPE_BUY)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        stop_loss = m_position.StopLoss();
        
        double profit_points = (current_price - m_position.PriceOpen()) / g_point / 10;
        
        if(profit_points >= TrailingStart)
        {
            new_sl = current_price - TrailingStop * g_point * 10;
            
            if(new_sl > stop_loss + TrailingStep * g_point * 10)
            {
                new_sl = NormalizeDouble(new_sl, _Digits);
                m_trade.PositionModify(ticket, new_sl, m_position.TakeProfit());
                Print("📈 Трейлинг BUY: ", DoubleToString(new_sl, _Digits));
            }
        }
    }
    else if(pos_type == POSITION_TYPE_SELL)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        stop_loss = m_position.StopLoss();
        
        double profit_points = (m_position.PriceOpen() - current_price) / g_point / 10;
        
        if(profit_points >= TrailingStart)
        {
            new_sl = current_price + TrailingStop * g_point * 10;
            
            if(new_sl < stop_loss - TrailingStep * g_point * 10 || stop_loss == 0)
            {
                new_sl = NormalizeDouble(new_sl, _Digits);
                m_trade.PositionModify(ticket, new_sl, m_position.TakeProfit());
                Print("📉 Трейлинг SELL: ", DoubleToString(new_sl, _Digits));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Закрытие позиции                                               |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket, string reason)
{
    if(m_position.SelectByTicket(ticket))
    {
        double profit = m_position.Profit();
        bool result = m_trade.PositionClose(ticket);
        
        if(result)
        {
            Print("✅ Позиция закрыта: ", reason, " | Прибыль: ", DoubleToString(profit, 2));
            
            // Обновляем статистику
            if(profit > 0)
                g_stats.winning_trades++;
            else
                g_stats.losing_trades++;
            
            g_stats.total_profit += profit;
            
            if(AlertOnClose)
            {
                string alert_msg = StringFormat("ПОЗИЦИЯ ЗАКРЫТА: %s | Прибыль: %.2f", reason, profit);
                SendAlert(alert_msg);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Сортировка сигналов по силе                                    |
//+------------------------------------------------------------------+
void SortSignalsByStrength(TradeSignal &signals[])
{
    int size = ArraySize(signals);
    if(size < 2) return;
    
    for(int i = 0; i < size - 1; i++)
    {
        for(int j = 0; j < size - 1 - i; j++)
        {
            if(signals[j].strength < signals[j + 1].strength)
            {
                TradeSignal temp = signals[j];
                signals[j] = signals[j + 1];
                signals[j + 1] = temp;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Проверка фильтра тренда                                        |
//+------------------------------------------------------------------+
bool IsTrendFilterPassed(bool is_bearish_signal)
{
    if(!UseTrendFilter) return true;
    
    double ma[];
    ArraySetAsSeries(ma, true);
    
    if(CopyBuffer(g_trend_ma_handle, 0, 0, 1, ma) <= 0) 
    {
        Print("⚠️ Ошибка получения данных MA для фильтра тренда");
        return true; // В случае ошибки разрешаем торговлю
    }
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ma_value = ma[0];
    
    if(OnlyCounterTrend)
    {
        // BUY сигналы только когда цена ниже MA (разворот вверх от перепроданности)
        if(!is_bearish_signal && current_price < ma_value) 
        {
            Print("✅ Фильтр тренда пройден: BUY сигнал (цена ", DoubleToString(current_price, _Digits), 
                  " ниже MA ", DoubleToString(ma_value, _Digits), ")");
            return true;
        }
        
        // SELL сигналы только когда цена выше MA (разворот вниз от перекупленности)
        if(is_bearish_signal && current_price > ma_value) 
        {
            Print("✅ Фильтр тренда пройден: SELL сигнал (цена ", DoubleToString(current_price, _Digits), 
                  " выше MA ", DoubleToString(ma_value, _Digits), ")");
            return true;
        }
        
        Print("❌ Фильтр тренда не пройден: ", (is_bearish_signal ? "SELL" : "BUY"), 
              " сигнал не против тренда (цена: ", DoubleToString(current_price, _Digits), 
              ", MA: ", DoubleToString(ma_value, _Digits), ")");
        return false;
    }
    else
    {
        // Торговля по тренду для M15 EURUSD
        // BUY сигналы когда цена выше MA (восходящий тренд)
        if(!is_bearish_signal && current_price > ma_value) 
        {
            Print("✅ Фильтр тренда пройден: BUY сигнал по тренду (цена ", DoubleToString(current_price, _Digits), 
                  " выше MA ", DoubleToString(ma_value, _Digits), ")");
            return true;
        }
        
        // SELL сигналы когда цена ниже MA (нисходящий тренд)
        if(is_bearish_signal && current_price < ma_value) 
        {
            Print("✅ Фильтр тренда пройден: SELL сигнал по тренду (цена ", DoubleToString(current_price, _Digits), 
                  " ниже MA ", DoubleToString(ma_value, _Digits), ")");
            return true;
        }
        
        Print("❌ Фильтр тренда не пройден: ", (is_bearish_signal ? "SELL" : "BUY"), 
              " сигнал против тренда (цена: ", DoubleToString(current_price, _Digits), 
              ", MA: ", DoubleToString(ma_value, _Digits), ")");
        return false;
    }
}

//+------------------------------------------------------------------+
//| Проверка времени между сигналами                               |
//+------------------------------------------------------------------+
bool IsTimeBetweenSignalsPassed()
{
    if(MinMinutesBetweenSignals <= 0) return true;
    
    datetime current_time = TimeCurrent();
    int minutes_passed = (int)((current_time - g_last_signal_time) / 60);
    
    if(minutes_passed >= MinMinutesBetweenSignals)
    {
        return true;
    }
    
    Print("⏱️ Фильтр времени: прошло ", minutes_passed, " мин, требуется ", MinMinutesBetweenSignals, " мин");
    return false;
}

//+------------------------------------------------------------------+
//| Проверка времени торговли                                      |
//+------------------------------------------------------------------+
bool IsTimeToTrade()
{
    if(!EnableTimeFilter) return true;
    
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    
    // Проверка дня недели
    switch(time_struct.day_of_week)
    {
        case 1: if(!TradeMonday) return false; break;
        case 2: if(!TradeTuesday) return false; break;
        case 3: if(!TradeWednesday) return false; break;
        case 4: if(!TradeThursday) return false; break;
        case 5: if(!TradeFriday) return false; break;
        default: return false; // Выходные
    }
    
    // Проверка времени сессии
    int session_start = ParseTimeString(SessionStartTime);
    int session_end = ParseTimeString(SessionEndTime);
    int current_time = time_struct.hour * 60 + time_struct.min;
    
    if(session_start == -1 || session_end == -1)
        return true;
    
    if(session_start <= session_end)
    {
        return (current_time >= session_start && current_time <= session_end);
    }
    else
    {
        return (current_time >= session_start || current_time <= session_end);
    }
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
//| Отправка торгового уведомления                                 |
//+------------------------------------------------------------------+
void SendTradingAlert(string title, const TradeSignal &signal)
{
    if(!EnableAlerts) return;
    
    string direction = signal.is_bearish ? "SELL 📉" : "BUY 📈";
    string message = StringFormat("%s\n🎯 %s %s\n💪 Сила: %.2f\n💰 Цена: %s\n🟢 TP: %s\n🔴 SL: %s\n📊 Символ: %s",
                                  title, direction, signal.type, signal.strength,
                                  DoubleToString(signal.entry_price, _Digits),
                                  DoubleToString(signal.tp_price, _Digits),
                                  DoubleToString(signal.sl_price, _Digits),
                                  _Symbol);
    
    SendAlert(message);
}

//+------------------------------------------------------------------+
//| Универсальная отправка уведомлений                             |
//+------------------------------------------------------------------+
void SendAlert(string message)
{
    if(EnableAlerts)
        Alert(message);
    
    if(EnableEmailAlerts)
        SendMail("DivergenceTrader EA - " + _Symbol, message);
    
    if(EnablePushAlerts)
        SendNotification(message);
}

//+------------------------------------------------------------------+
//| Деинициализация эксперта                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("=== Деинициализация DivergenceTrader EA ===");
    
    // Статистика
    double win_rate = (g_stats.total_trades > 0) ? (double)g_stats.winning_trades / g_stats.total_trades * 100 : 0;
    
    Print("📊 СТАТИСТИКА ТОРГОВЛИ:");
    Print("📈 Всего сигналов: ", g_stats.total_signals);
    Print("💼 Всего сделок: ", g_stats.total_trades);
    Print("✅ Прибыльных: ", g_stats.winning_trades, " (", DoubleToString(win_rate, 1), "%)");
    Print("❌ Убыточных: ", g_stats.losing_trades);
    Print("💰 Общая прибыль: ", DoubleToString(g_stats.total_profit, 2));
    
    // Освобождение ресурсов
    if(g_stoch_handle != INVALID_HANDLE)
        IndicatorRelease(g_stoch_handle);
    if(g_macd_handle != INVALID_HANDLE)
        IndicatorRelease(g_macd_handle);
    if(g_atr_handle != INVALID_HANDLE)
        IndicatorRelease(g_atr_handle);
    if(g_trend_ma_handle != INVALID_HANDLE)
        IndicatorRelease(g_trend_ma_handle);
    if(g_rsi_handle != INVALID_HANDLE)
        IndicatorRelease(g_rsi_handle);
        
    Print("✅ Деинициализация завершена");
}

//+------------------------------------------------------------------+
//| Интеллектуальное управление позициями                          |
//+------------------------------------------------------------------+
void SmartExitManagement()
{
    if(!EnableSmartExit) return;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(m_position.SelectByIndex(i))
        {
            if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
            {
                ulong ticket = m_position.Ticket();
                ENUM_POSITION_TYPE pos_type = m_position.PositionType();
                double profit_points = CalculatePositionProfitPoints(ticket);
                
                // Проверяем минимальную прибыль для умного закрытия
                if(profit_points < MinProfitPointsForSmartExit) continue;
                
                // Проверка противоположного сигнала
                if(CloseOnOppositeSignal && ShouldCloseOnOppositeSignal(pos_type))
                {
                    ClosePosition(ticket, "Противоположный сигнал");
                    continue;
                }
                
                // Проверка ослабления движения
                if(CloseOnWeakening && ShouldCloseOnWeakening(pos_type))
                {
                    if(UsePartialClose && profit_points > MinProfitPointsForSmartExit * 2)
                    {
                        PartialClosePosition(ticket, "Ослабление движения (частичное)");
                    }
                    else
                    {
                        ClosePosition(ticket, "Ослабление движения");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Расчет прибыли позиции в пунктах                               |
//+------------------------------------------------------------------+
double CalculatePositionProfitPoints(ulong ticket)
{
    if(!m_position.SelectByTicket(ticket)) return 0;
    
    double entry_price = m_position.PriceOpen();
    double current_price;
    
    if(m_position.PositionType() == POSITION_TYPE_BUY)
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        return (current_price - entry_price) / g_point;
    }
    else
    {
        current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        return (entry_price - current_price) / g_point;
    }
}

//+------------------------------------------------------------------+
//| Проверка необходимости закрытия по противоположному сигналу    |
//+------------------------------------------------------------------+
bool ShouldCloseOnOppositeSignal(ENUM_POSITION_TYPE pos_type)
{
    // Ищем текущие сигналы
    TradeSignal signals[];
    ArrayResize(signals, 0);
    
    // Обновляем пики
    FindPeaks(g_stoch_handle, 0, g_stoch_max_peaks, g_stoch_min_peaks, true);
    FindPeaks(g_macd_handle, 0, g_macd_max_peaks, g_macd_min_peaks, false);
    
    // Ищем противоположные сигналы
    if(pos_type == POSITION_TYPE_BUY)
    {
        // Для BUY ищем SELL сигналы
        if(StochBearish) FindTradingSignals(g_stoch_max_peaks, "StochBearish", true, false, signals);
        if(MACDBearish) FindTradingSignals(g_macd_max_peaks, "MACDBearish", true, true, signals);
    }
    else
    {
        // Для SELL ищем BUY сигналы
        if(StochBullish) FindTradingSignals(g_stoch_min_peaks, "StochBullish", false, false, signals);
        if(MACDBullish) FindTradingSignals(g_macd_min_peaks, "MACDBullish", false, true, signals);
    }
    
    // Проверяем силу найденных сигналов
    for(int i = 0; i < ArraySize(signals); i++)
    {
        if(signals[i].strength >= OppositeSignalMinStrength)
        {
            Print("🔄 Найден сильный противоположный сигнал: ", signals[i].type, 
                  " (сила: ", DoubleToString(signals[i].strength, 2), ")");
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка необходимости закрытия при ослаблении движения        |
//+------------------------------------------------------------------+
bool ShouldCloseOnWeakening(ENUM_POSITION_TYPE pos_type)
{
    // Проверка по RSI
    if(UseRSIForWeakening && g_rsi_handle != INVALID_HANDLE)
    {
        double rsi[];
        ArraySetAsSeries(rsi, true);
        
        if(CopyBuffer(g_rsi_handle, 0, 0, 3, rsi) > 0)
        {
            double current_rsi = rsi[0];
            double prev_rsi = rsi[1];
            double prev2_rsi = rsi[2];
            
            if(pos_type == POSITION_TYPE_BUY)
            {
                // Для BUY: RSI достиг перекупленности и начал снижаться
                if(current_rsi >= RSIWeakeningLevel && 
                   current_rsi < prev_rsi && prev_rsi < prev2_rsi)
                {
                    Print("📉 BUY ослабление: RSI ", DoubleToString(current_rsi, 2), 
                          " снижается от уровня ", DoubleToString(RSIWeakeningLevel, 1));
                    return true;
                }
            }
            else
            {
                // Для SELL: RSI достиг перепроданности и начал расти
                double sell_weakening_level = 100 - RSIWeakeningLevel; // Например, 30 для SELL
                if(current_rsi <= sell_weakening_level && 
                   current_rsi > prev_rsi && prev_rsi > prev2_rsi)
                {
                    Print("📈 SELL ослабление: RSI ", DoubleToString(current_rsi, 2), 
                          " растет от уровня ", DoubleToString(sell_weakening_level, 1));
                    return true;
                }
            }
        }
    }
    
    // Проверка по Stochastic (дополнительный фильтр)
    double stoch_main[], stoch_signal[];
    ArraySetAsSeries(stoch_main, true);
    ArraySetAsSeries(stoch_signal, true);
    
    if(CopyBuffer(g_stoch_handle, 0, 0, 3, stoch_main) > 0 && 
       CopyBuffer(g_stoch_handle, 1, 0, 3, stoch_signal) > 0)
    {
        // Проверяем разворот Stochastic
        if(pos_type == POSITION_TYPE_BUY)
        {
            // Для BUY: Stochastic в зоне перекупленности и %K пересекает %D вниз
            if(stoch_main[0] > StochOverboughtLevel && 
               stoch_main[1] > stoch_signal[1] && stoch_main[0] < stoch_signal[0])
            {
                Print("📉 BUY ослабление: Stochastic разворот вниз в зоне перекупленности");
                return true;
            }
        }
        else
        {
            // Для SELL: Stochastic в зоне перепроданности и %K пересекает %D вверх
            if(stoch_main[0] < StochOversoldLevel && 
               stoch_main[1] < stoch_signal[1] && stoch_main[0] > stoch_signal[0])
            {
                Print("📈 SELL ослабление: Stochastic разворот вверх в зоне перепроданности");
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Частичное закрытие позиции                                     |
//+------------------------------------------------------------------+
void PartialClosePosition(ulong ticket, string reason)
{
    if(!m_position.SelectByTicket(ticket)) return;
    
    double current_volume = m_position.Volume();
    double close_volume = NormalizeDouble(current_volume * PartialClosePercent / 100.0, 2);
    
    // Проверяем минимальный объем
    double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(close_volume < min_volume)
    {
        // Если частичный объем меньше минимального, закрываем полностью
        ClosePosition(ticket, reason + " (полное закрытие)");
        return;
    }
    
    // Частичное закрытие
    bool result = m_trade.PositionClosePartial(ticket, close_volume);
    
    if(result)
    {
        double profit = m_position.Profit() * (close_volume / current_volume);
        Print("🔸 Частичное закрытие: ", DoubleToString(close_volume, 2), " лотов | ", 
              reason, " | Прибыль: ", DoubleToString(profit, 2));
        
        if(AlertOnClose)
        {
            string alert_msg = StringFormat("ЧАСТИЧНОЕ ЗАКРЫТИЕ: %s | Закрыто %.2f из %.2f лотов | Прибыль: %.2f",
                                             reason, close_volume, current_volume, profit);
            SendAlert(alert_msg);
        }
    }
    else
    {
        Print("❌ Ошибка частичного закрытия: ", m_trade.ResultRetcode());
    }
} 