//+------------------------------------------------------------------+
//|                                         DivergenceVisualizer.mq5 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Входные параметры для Stochastic
input string StochName = "Stoch(8,3,5)"; // Имя индикатора Stochastic
input int StochKPeriod = 8;              // Период %K
input int StochDPeriod = 3;              // Период %D
input int StochSlowing = 5;              // Замедление

// Входные параметры для MACD
input string MACDName = "MACD(12,26,9)"; // Имя индикатора MACD
input int MACDFastEMA = 12;              // Быстрый EMA
input int MACDSlowEMA = 26;              // Медленный EMA
input int MACDSignalPeriod = 9;          // Период сигнальной линии

// Настройки отображения дивергенций
input bool StochBearish = true;          // Искать медвежьи дивергенции Stochastic
input bool StochBullish = true;          // Искать бычьи дивергенции Stochastic
input bool MACDBearish = true;           // Искать медвежьи дивергенции MACD
input bool MACDBullish = true;           // Искать бычьи дивергенции MACD
input bool ShowOnlyDouble = false;       // Показывать только двойные дивергенции
input bool CustomStyles = false;         // Использовать пользовательские стили линий
input color RegularBearish = clrAqua;    // Цвет обычной медвежьей дивергенции
input int RegularBearishStyle = STYLE_SOLID; // Стиль обычной медвежьей дивергенции
input color HiddenBearish = clrBlue;     // Цвет скрытой медвежьей дивергенции
input int HiddenBearishStyle = STYLE_DASH; // Стиль скрытой медвежьей дивергенции
input color RegularBullish = clrRed;     // Цвет обычной бычьей дивергенции
input int RegularBullishStyle = STYLE_SOLID; // Стиль обычной бычьей дивергенции
input color HiddenBullish = clrOrange;   // Цвет скрытой бычьей дивергенции
input int HiddenBullishStyle = STYLE_DASH; // Стиль скрытой бычьей дивергенции
input color DoubleText = clrYellow;      // Цвет текста двойной дивергенции
input double MACDPickDif = 2.0;          // Минимальная разница для пиков MACD
input int NrLoad = 100;                   // Количество баров для анализа

// Глобальные переменные
int g_stoch_handle;                      // Хендл индикатора Stochastic
int g_macd_handle;                       // Хендл индикатора MACD
int g_stoch_window;                      // Номер окна индикатора Stochastic
int g_macd_window;                       // Номер окна индикатора MACD
double g_point;                          // Точка для текущего символа
int g_stoch_max_peaks[];                 // Массив для хранения индексов максимумов Stochastic
int g_stoch_min_peaks[];                 // Массив для хранения индексов минимумов Stochastic
int g_macd_max_peaks[];                  // Массив для хранения индексов максимумов MACD
int g_macd_min_peaks[];                  // Массив для хранения индексов минимумов MACD
int g_bearish_divs[][4];                 // Массив для хранения медвежьих дивергенций
int g_bullish_divs[][4];                 // Массив для хранения бычьих дивергенций
int g_bearish_count = 0;                 // Счетчик медвежьих дивергенций
int g_bullish_count = 0;                 // Счетчик бычьих дивергенций
int g_atr_handle; // Хендл индикатора ATR

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Инициализация хендлов индикаторов
    g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, STO_LOWHIGH);
    if(g_stoch_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора Stochastic: ", GetLastError());
        return(INIT_FAILED);
    }
    
    g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACDFastEMA, MACDSlowEMA, MACDSignalPeriod, PRICE_CLOSE);
    if(g_macd_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора MACD: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        return(INIT_FAILED);
    }

    // Настройка глобальных переменных
    g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    ArrayResize(g_stoch_max_peaks, NrLoad);
    ArrayResize(g_stoch_min_peaks, NrLoad);
    ArrayResize(g_macd_max_peaks, NrLoad);
    ArrayResize(g_macd_min_peaks, NrLoad);
    ArrayResize(g_bearish_divs, NrLoad);
    ArrayResize(g_bullish_divs, NrLoad);

    // Получаем номера окон индикаторов
    string stoch_short_name = "Stochastic";
    string macd_short_name = "MACD";
    
    // Ищем окна индикаторов
    int total_windows = ChartGetInteger(0, CHART_WINDOWS_TOTAL);
    for(int i = 0; i < total_windows; i++)
    {
        string name = ChartIndicatorName(0, i, 0);
        if(StringFind(name, stoch_short_name) >= 0)
            g_stoch_window = i;
        else if(StringFind(name, macd_short_name) >= 0)
            g_macd_window = i;
    }
    
    // Если индикаторы не найдены, создаем их
    if(g_stoch_window == -1)
    {
        g_stoch_window = ChartGetInteger(0, CHART_WINDOWS_TOTAL);
        if(!ChartIndicatorAdd(0, g_stoch_window, g_stoch_handle))
        {
            Print("Ошибка добавления Stochastic на график: ", GetLastError());
            IndicatorRelease(g_stoch_handle);
            IndicatorRelease(g_macd_handle);
            return(INIT_FAILED);
        }
    }
    
    if(g_macd_window == -1)
    {
        g_macd_window = ChartGetInteger(0, CHART_WINDOWS_TOTAL);
        if(!ChartIndicatorAdd(0, g_macd_window, g_macd_handle))
        {
            Print("Ошибка добавления MACD на график: ", GetLastError());
            IndicatorRelease(g_stoch_handle);
            IndicatorRelease(g_macd_handle);
            return(INIT_FAILED);
        }
    }

    // Инициализация ATR
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора ATR: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        IndicatorRelease(g_macd_handle);
        return(INIT_FAILED);
    }

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
    // Проверяем, достаточно ли баров для расчета
    if(rates_total < NrLoad)
        return(rates_total);
        
    // Проверяем, есть ли новые данные
    static datetime last_time = 0;
    datetime current_time = time[0];
    
    if(current_time != last_time)
    {
        last_time = current_time;
        
        // Проверяем готовность данных индикаторов
        double stoch_main[];
        double macd_main[];
        ArraySetAsSeries(stoch_main, true);
        ArraySetAsSeries(macd_main, true);
        
        // Пробуем получить данные индикаторов
        if(CopyBuffer(g_stoch_handle, 0, 0, 1, stoch_main) > 0 &&
           CopyBuffer(g_macd_handle, 0, 0, 1, macd_main) > 0)
        {
            // Если данные доступны, ищем дивергенции
            FindDivergences();
        }
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Удаление всех объектов
    ObjectsDeleteAll(0, "Div_");
    
    // Освобождение хендлов индикаторов
    IndicatorRelease(g_stoch_handle);
    IndicatorRelease(g_macd_handle);
    IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
//| Поиск дивергенций                                               |
//+------------------------------------------------------------------+
void FindDivergences()
{
    // Очистка предыдущих объектов
    ObjectsDeleteAll(0, "Div_");
    
    // Сброс счетчиков
    g_bearish_count = 0;
    g_bullish_count = 0;
    
    // Поиск пиков Stochastic
    FindStochPeaks();
    
    // Поиск пиков MACD
    FindMACDPeaks();
    
    // Поиск дивергенций
    if(StochBearish) FindStochBearishDivergences();
    if(StochBullish) FindStochBullishDivergences();
    if(MACDBearish) FindMACDBearishDivergences();
    if(MACDBullish) FindMACDBullishDivergences();
    
    // Поиск двойных дивергенций
    FindDoubleDivergences();
}

//+------------------------------------------------------------------+
//| Поиск пиков Stochastic                                          |
//+------------------------------------------------------------------+
void FindStochPeaks()
{
    double stoch_main[];
    ArraySetAsSeries(stoch_main, true);
    
    // Сброс счетчиков
    g_bearish_count = 0;
    g_bullish_count = 0;
    
    // Очистка массивов пиков
    ArrayInitialize(g_stoch_max_peaks, 0);
    ArrayInitialize(g_stoch_min_peaks, 0);
    
    // Копируем все значения Stochastic
    int copied = CopyBuffer(g_stoch_handle, 0, 0, NrLoad, stoch_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера Stochastic: ", GetLastError());
        return;
    }
    
    // Ждем, пока данные будут рассчитаны
    int attempts = 0;
    while(copied <= 0 && attempts < 10)
    {
        Sleep(100);
        copied = CopyBuffer(g_stoch_handle, 0, 0, NrLoad, stoch_main);
        attempts++;
    }
    
    if(copied <= 0)
    {
        Print("Не удалось получить данные Stochastic после нескольких попыток");
        return;
    }
    
    for(int i = 1; i < copied-1; i++)
    {
        double stoch_prev = stoch_main[i+1];
        double stoch_curr = stoch_main[i];
        double stoch_next = stoch_main[i-1];
        
        // Поиск максимумов
        if(stoch_curr > stoch_prev && stoch_curr > stoch_next)
        {
            if(g_bearish_count < NrLoad)
            {
                g_stoch_max_peaks[g_bearish_count] = i;
                g_bearish_count++;
            }
        }
        
        // Поиск минимумов
        if(stoch_curr < stoch_prev && stoch_curr < stoch_next)
        {
            if(g_bullish_count < NrLoad)
            {
                g_stoch_min_peaks[g_bullish_count] = i;
                g_bullish_count++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск пиков MACD                                                |
//+------------------------------------------------------------------+
void FindMACDPeaks()
{
    double macd_main[];
    ArraySetAsSeries(macd_main, true);
    
    // Сброс счетчиков
    g_bearish_count = 0;
    g_bullish_count = 0;
    
    // Очистка массивов пиков
    ArrayInitialize(g_macd_max_peaks, 0);
    ArrayInitialize(g_macd_min_peaks, 0);
    
    // Копируем все значения MACD
    int copied = CopyBuffer(g_macd_handle, 0, 0, NrLoad, macd_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера MACD: ", GetLastError());
        return;
    }
    
    for(int i = 1; i < copied-1; i++)
    {
        double macd_prev = macd_main[i+1];
        double macd_curr = macd_main[i];
        double macd_next = macd_main[i-1];
        
        // Поиск максимумов
        if(macd_curr > macd_prev && macd_curr > macd_next)
        {
            if(g_bearish_count < NrLoad)
            {
                g_macd_max_peaks[g_bearish_count] = i;
                g_bearish_count++;
            }
        }
        
        // Поиск минимумов
        if(macd_curr < macd_prev && macd_curr < macd_next)
        {
            if(g_bullish_count < NrLoad)
            {
                g_macd_min_peaks[g_bullish_count] = i;
                g_bullish_count++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск медвежьих дивергенций Stochastic                          |
//+------------------------------------------------------------------+
void FindStochBearishDivergences()
{
    double stoch_main[];
    ArraySetAsSeries(stoch_main, true);
    
    int copied = CopyBuffer(g_stoch_handle, 0, 0, NrLoad, stoch_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера Stochastic: ", GetLastError());
        return;
    }
    
    for(int i = 0; i < g_bearish_count-1; i++)
    {
        for(int j = i+1; j < g_bearish_count; j++)
        {
            int idx1 = g_stoch_max_peaks[i];
            int idx2 = g_stoch_max_peaks[j];
            
            if(idx2 - idx1 < 5) continue;
            
            double stoch1 = stoch_main[idx1];
            double stoch2 = stoch_main[idx2];
            
            double price1 = iHigh(_Symbol, PERIOD_CURRENT, idx1);
            double price2 = iHigh(_Symbol, PERIOD_CURRENT, idx2);
            
            // Проверка на дивергенцию
            if(stoch1 < stoch2 && price1 > price2)
            {
                // Отрисовка линий
                DrawDivergenceLine(idx1, idx2, price1, price2, stoch1, stoch2, "StochBearish", RegularBearish, RegularBearishStyle);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск бычьих дивергенций Stochastic                             |
//+------------------------------------------------------------------+
void FindStochBullishDivergences()
{
    double stoch_main[];
    ArraySetAsSeries(stoch_main, true);
    
    int copied = CopyBuffer(g_stoch_handle, 0, 0, NrLoad, stoch_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера Stochastic: ", GetLastError());
        return;
    }
    
    for(int i = 0; i < g_bullish_count-1; i++)
    {
        for(int j = i+1; j < g_bullish_count; j++)
        {
            int idx1 = g_stoch_min_peaks[i];
            int idx2 = g_stoch_min_peaks[j];
            
            if(idx2 - idx1 < 5) continue;
            
            double stoch1 = stoch_main[idx1];
            double stoch2 = stoch_main[idx2];
            
            double price1 = iLow(_Symbol, PERIOD_CURRENT, idx1);
            double price2 = iLow(_Symbol, PERIOD_CURRENT, idx2);
            
            // Проверка на дивергенцию
            if(stoch1 > stoch2 && price1 < price2)
            {
                // Отрисовка линий
                DrawDivergenceLine(idx1, idx2, price1, price2, stoch1, stoch2, "StochBullish", RegularBullish, RegularBullishStyle);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск медвежьих дивергенций MACD                                |
//+------------------------------------------------------------------+
void FindMACDBearishDivergences()
{
    double macd_main[];
    ArraySetAsSeries(macd_main, true);
    
    int copied = CopyBuffer(g_macd_handle, 0, 0, NrLoad, macd_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера MACD: ", GetLastError());
        return;
    }
    
    for(int i = 0; i < g_bearish_count-1; i++)
    {
        for(int j = i+1; j < g_bearish_count; j++)
        {
            int idx1 = g_macd_max_peaks[i];
            int idx2 = g_macd_max_peaks[j];
            
            if(idx2 - idx1 < 5) continue;
            
            double macd1 = macd_main[idx1];
            double macd2 = macd_main[idx2];
            
            double price1 = iHigh(_Symbol, PERIOD_CURRENT, idx1);
            double price2 = iHigh(_Symbol, PERIOD_CURRENT, idx2);
            
            // Проверка на дивергенцию
            if(MathAbs(macd1 - macd2) >= MACDPickDif * g_point)
            {
                if(macd1 < macd2 && price1 > price2)
                {
                    // Отрисовка линий
                    DrawDivergenceLine(idx1, idx2, price1, price2, macd1, macd2, "MACDBearish", RegularBearish, RegularBearishStyle);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск бычьих дивергенций MACD                                   |
//+------------------------------------------------------------------+
void FindMACDBullishDivergences()
{
    double macd_main[];
    ArraySetAsSeries(macd_main, true);
    
    int copied = CopyBuffer(g_macd_handle, 0, 0, NrLoad, macd_main);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера MACD: ", GetLastError());
        return;
    }
    
    for(int i = 0; i < g_bullish_count-1; i++)
    {
        for(int j = i+1; j < g_bullish_count; j++)
        {
            int idx1 = g_macd_min_peaks[i];
            int idx2 = g_macd_min_peaks[j];
            
            if(idx2 - idx1 < 5) continue;
            
            double macd1 = macd_main[idx1];
            double macd2 = macd_main[idx2];
            
            double price1 = iLow(_Symbol, PERIOD_CURRENT, idx1);
            double price2 = iLow(_Symbol, PERIOD_CURRENT, idx2);
            
            // Проверка на дивергенцию
            if(MathAbs(macd1 - macd2) >= MACDPickDif * g_point)
            {
                if(macd1 > macd2 && price1 < price2)
                {
                    // Отрисовка линий
                    DrawDivergenceLine(idx1, idx2, price1, price2, macd1, macd2, "MACDBullish", RegularBullish, RegularBullishStyle);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск двойных дивергенций                                       |
//+------------------------------------------------------------------+
void FindDoubleDivergences()
{
    // Здесь будет реализована логика поиска двойных дивергенций
    // Аналогично оригинальному коду, но адаптированная для MQL5
}

//+------------------------------------------------------------------+
//| Отрисовка линий дивергенции                                     |
//+------------------------------------------------------------------+
void DrawDivergenceLine(int idx1, int idx2, double price1, double price2, 
                       double ind1, double ind2, string type, color clr, int style)
{
    string name = "Div_" + type + "_" + IntegerToString(idx1);
    datetime time1 = iTime(_Symbol, PERIOD_CURRENT, idx1);
    datetime time2 = iTime(_Symbol, PERIOD_CURRENT, idx2);
    
    // Определяем, является ли дивергенция бычьей
    bool is_bullish = (StringFind(type, "Bullish") >= 0);
    
    // Добавляем стрелки для лучшей визуализации
    string arrow_name = name + "_arrow";
    if(!ObjectCreate(0, arrow_name, OBJ_ARROW, 0, time1, price1))
    {
        Print("Ошибка создания стрелки: ", GetLastError());
        return;
    }
    
    ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, is_bullish ? 241 : 242);
    ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 1);
    ObjectSetDouble(0, arrow_name, OBJPROP_PRICE, price1 + (is_bullish ? -15 * g_point : 15 * g_point));
    
    // Получаем цену закрытия свечи, на которой возник сигнал
    double close_price = iClose(_Symbol, PERIOD_CURRENT, idx1);
    
    // Расчёт TP и SL на основе ATR
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) > 0)
    {
        double atr_value = atr[0];
        double tp, sl;
        if(is_bullish)
        {
            tp = close_price + 2 * atr_value;
            sl = close_price - atr_value;
        }
        else
        {
            tp = close_price - 2 * atr_value;
            sl = close_price + atr_value;
        }
        Print("Дивергенция ", type, " на баре ", idx1, ": TP = ", tp, ", SL = ", sl);
        
        // Отрисовка уровня SL в виде крестика
        string sl_name = name + "_sl";
        if(!ObjectCreate(0, sl_name, OBJ_ARROW, 0, time1, sl))
        {
            Print("Ошибка создания SL: ", GetLastError());
            return;
        }
        ObjectSetInteger(0, sl_name, OBJPROP_ARROWCODE, 251); // Крестик
        ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 1);
        
        // Отрисовка уровня TP в виде галочки
        string tp_name = name + "_tp";
        if(!ObjectCreate(0, tp_name, OBJ_ARROW, 0, time1, tp))
        {
            Print("Ошибка создания TP: ", GetLastError());
            return;
        }
        ObjectSetInteger(0, tp_name, OBJPROP_ARROWCODE, 252); // Галочка
        ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 1);
    }
} 