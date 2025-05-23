//+------------------------------------------------------------------+
//|                                   DivergenceVisualizer_Improved.mq5 |
//|                                      Copyright 2024, Improved Version |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Improved Version"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Структура для хранения пика                                     |
//+------------------------------------------------------------------+
struct Peak
{
   int      index;
   double   value;
   double   price;
   datetime time;
};

//+------------------------------------------------------------------+
//| Структура для хранения информации о дивергенции                 |
//+------------------------------------------------------------------+
struct DivergenceInfo
{
    int peak1_idx;
    int peak2_idx;
    double strength;  // Сила дивергенции
};

//--- Входные параметры для Stochastic
input group "Настройки Stochastic"
input string StochName = "Stoch(8,3,5)";    // Имя индикатора Stochastic
input int StochKPeriod = 8;                 // Период %K
input int StochDPeriod = 3;                 // Период %D
input int StochSlowing = 5;                 // Замедление

//--- Входные параметры для MACD
input group "Настройки MACD"
input string MACDName = "MACD(12,26,9)";   // Имя индикатора MACD
input int MACDFastEMA = 12;                 // Быстрый EMA
input int MACDSlowEMA = 26;                 // Медленный EMA
input int MACDSignalPeriod = 9;             // Период сигнальной линии

//--- Настройки отображения дивергенций
input group "Настройки дивергенций"
input bool StochBearish = true;             // Искать медвежьи дивергенции Stochastic
input bool StochBullish = true;             // Искать бычьи дивергенции Stochastic
input bool MACDBearish = true;              // Искать медвежьи дивергенции MACD
input bool MACDBullish = true;              // Искать бычьи дивергенции MACD
input bool ShowOnlyDouble = false;          // Показывать только двойные дивергенции
input bool EnableRealtimeSignals = true;   // Включить сигналы в реальном времени
input double MACDPickDif = 0.5;             // Минимальная разница для пиков MACD (в пунктах)
input int MinBarsBetweenPeaks = 3;          // Минимальное расстояние между пиками
input int MaxDivergencesToShow = 5;         // Максимальное количество дивергенций на экране
input int MaxBarsToAnalyze = 50;            // Максимальное количество баров для поиска дивергенций
input int NrLoad = 100;                     // Количество баров для анализа

//--- Настройки отображения
input group "Настройки отображения"
input bool KeepHistorySignals = true;       // Сохранять исторические сигналы на графике
input int MaxSignalsToKeep = 50;            // Максимальное количество сигналов на графике (0 = без ограничений)
input color RegularBearish = clrAqua;       // Цвет обычной медвежьей дивергенции
input ENUM_LINE_STYLE RegularBearishStyle = STYLE_SOLID; // Стиль обычной медвежьей дивергенции
input color HiddenBearish = clrBlue;        // Цвет скрытой медвежьей дивергенции
input ENUM_LINE_STYLE HiddenBearishStyle = STYLE_DASH; // Стиль скрытой медвежьей дивергенции
input color RegularBullish = clrRed;        // Цвет обычной бычьей дивергенции
input ENUM_LINE_STYLE RegularBullishStyle = STYLE_SOLID; // Стиль обычной бычьей дивергенции
input color HiddenBullish = clrOrange;      // Цвет скрытой бычьей дивергенции
input ENUM_LINE_STYLE HiddenBullishStyle = STYLE_DASH; // Стиль скрытой бычьей дивергенции
input color DoubleText = clrYellow;         // Цвет текста двойной дивергенции

//--- Настройки риск-менеджмента
input group "Настройки ATR и TP/SL"
input int ATRPeriod = 14;                   // Период ATR
input double ATRMultiplierTP = 2.0;         // Множитель ATR для TP
input double ATRMultiplierSL = 1.0;         // Множитель ATR для SL

//--- Настройки алертов
input group "Настройки алертов"
input bool EnableAlerts = true;             // Включить алерты
input bool EnableEmailAlerts = false;       // Включить email-алерты
input bool EnablePushAlerts = false;        // Включить push-алерты

//--- Настройки времени торговой сессии
input group "Фильтр по времени сессии"
input bool EnableTimeFilter = true;         // Включить фильтр по времени
input string SessionStartTime = "08:00";    // Время начала сессии (по серверу)
input string SessionEndTime = "17:00";      // Время окончания сессии (по серверу)
input bool ShowOnlySessionSignals = true;   // Показывать только сигналы в рамках сессии
input string TimeZoneInfo = "Установите время по серверу MT5"; // Информация о часовом поясе

//--- Глобальные переменные
int g_stoch_handle;                         // Хендл индикатора Stochastic
int g_macd_handle;                          // Хендл индикатора MACD
int g_atr_handle;                           // Хендл индикатора ATR
double g_point;                             // Точка для текущего символа
datetime g_last_calculation_time;           // Время последнего расчета
bool g_first_run;                           // Флаг первого запуска

//--- Массивы для хранения пиков
Peak g_stoch_max_peaks[];
Peak g_stoch_min_peaks[];
Peak g_macd_max_peaks[];
Peak g_macd_min_peaks[];

//+------------------------------------------------------------------+
//| Инициализация индикатора                                        |
//+------------------------------------------------------------------+
int OnInit()
{
    // Валидация входных параметров
    if(!ValidateInputs())
        return INIT_PARAMETERS_INCORRECT;
    
    // Инициализация хендлов индикаторов
    g_stoch_handle = iStochastic(_Symbol, PERIOD_CURRENT, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, STO_LOWHIGH);
    if(g_stoch_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора Stochastic: ", GetLastError());
        return INIT_FAILED;
    }
    
    g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, MACDFastEMA, MACDSlowEMA, MACDSignalPeriod, PRICE_CLOSE);
    if(g_macd_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора MACD: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        return INIT_FAILED;
    }
    
    g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("Ошибка создания индикатора ATR: ", GetLastError());
        IndicatorRelease(g_stoch_handle);
        IndicatorRelease(g_macd_handle);
        return INIT_FAILED;
    }
    
    // Инициализация переменных
    g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    g_last_calculation_time = 0;
    g_first_run = true;
    
    // Изменение размера массивов
    ArrayResize(g_stoch_max_peaks, 0);
    ArrayResize(g_stoch_min_peaks, 0);
    ArrayResize(g_macd_max_peaks, 0);
    ArrayResize(g_macd_min_peaks, 0);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Валидация входных параметров                                    |
//+------------------------------------------------------------------+
bool ValidateInputs()
{
    if(StochKPeriod < 1 || StochKPeriod > 100)
    {
        Print("Неверный период %K для Stochastic: ", StochKPeriod);
        return false;
    }
    
    if(StochDPeriod < 1 || StochDPeriod > 100)
    {
        Print("Неверный период %D для Stochastic: ", StochDPeriod);
        return false;
    }
    
    if(MACDFastEMA >= MACDSlowEMA)
    {
        Print("Быстрый EMA должен быть меньше медленного EMA");
        return false;
    }
    
    if(NrLoad < 10 || NrLoad > 1000)
    {
        Print("Количество баров должно быть от 10 до 1000");
        return false;
    }
    
    if(MinBarsBetweenPeaks < 2)
    {
        Print("Минимальное расстояние между пиками должно быть не менее 2");
        return false;
    }
    
    if(MaxDivergencesToShow < 1 || MaxDivergencesToShow > 20)
    {
        Print("Количество дивергенций должно быть от 1 до 20");
        return false;
    }
    
    if(MaxBarsToAnalyze < 10 || MaxBarsToAnalyze > NrLoad)
    {
        Print("Максимальное количество баров для анализа должно быть от 10 до ", NrLoad);
        return false;
    }
    
    if(MaxSignalsToKeep < 0 || MaxSignalsToKeep > 200)
    {
        Print("Максимальное количество сигналов должно быть от 0 до 200");
        return false;
    }
    
    // Валидация времени сессии
    if(EnableTimeFilter)
    {
        if(ParseTimeString(SessionStartTime) == -1)
        {
            Print("Неверный формат времени начала сессии: ", SessionStartTime, ". Используйте формат HH:MM");
            return false;
        }
        
        if(ParseTimeString(SessionEndTime) == -1)
        {
            Print("Неверный формат времени окончания сессии: ", SessionEndTime, ". Используйте формат HH:MM");
            return false;
        }
        
        Print("Фильтр времени активен: ", SessionStartTime, " - ", SessionEndTime, " (время сервера)");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Основная функция расчета                                        |
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
    if(rates_total < NrLoad)
        return rates_total;
    
    // Проверяем, нужно ли пересчитывать
    datetime current_time = time[rates_total - 1];
    if(current_time == g_last_calculation_time && !g_first_run)
        return rates_total;
    
    g_last_calculation_time = current_time;
    g_first_run = false;
    
    // Ждем готовности данных индикаторов
    if(!WaitForIndicatorData())
        return rates_total;
    
    // Поиск дивергенций
    FindAllDivergences();
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Ожидание готовности данных индикаторов                         |
//+------------------------------------------------------------------+
bool WaitForIndicatorData()
{
    // Проверяем готовность данных
    double temp_buffer[];
    
    if(CopyBuffer(g_stoch_handle, 0, 0, 1, temp_buffer) <= 0)
        return false;
    if(CopyBuffer(g_macd_handle, 0, 0, 1, temp_buffer) <= 0)
        return false;
    if(CopyBuffer(g_atr_handle, 0, 0, 1, temp_buffer) <= 0)
        return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Поиск всех дивергенций                                          |
//+------------------------------------------------------------------+
void FindAllDivergences()
{
    Print("ОТЛАДКА: Начинаем поиск всех дивергенций...");
    
    // Управляем историей сигналов только если это необходимо
    if(!KeepHistorySignals)
    {
        RemoveOldDivergenceObjects();
    }
    else if(MaxSignalsToKeep > 0)
    {
        LimitSignalsOnChart();
    }
    
    // Поиск пиков
    FindPeaks(g_stoch_handle, 0, g_stoch_max_peaks, g_stoch_min_peaks, true);
    FindPeaks(g_macd_handle, 0, g_macd_max_peaks, g_macd_min_peaks, false);
    
    Print("ОТЛАДКА: Найдено Stoch MAX пиков: ", ArraySize(g_stoch_max_peaks));
    Print("ОТЛАДКА: Найдено Stoch MIN пиков: ", ArraySize(g_stoch_min_peaks));
    Print("ОТЛАДКА: Найдено MACD MAX пиков: ", ArraySize(g_macd_max_peaks));
    Print("ОТЛАДКА: Найдено MACD MIN пиков: ", ArraySize(g_macd_min_peaks));
    
    // Поиск дивергенций
    if(StochBearish) 
    {
        Print("ОТЛАДКА: Ищем медвежьи дивергенции Stochastic...");
        FindDivergences(g_stoch_max_peaks, "StochBearish", true, false);
    }
    if(StochBullish) 
    {
        Print("ОТЛАДКА: Ищем бычьи дивергенции Stochastic...");
        FindDivergences(g_stoch_min_peaks, "StochBullish", false, false);
    }
    if(MACDBearish) 
    {
        Print("ОТЛАДКА: Ищем медвежьи дивергенции MACD...");
        FindDivergences(g_macd_max_peaks, "MACDBearish", true, true);
    }
    if(MACDBullish) 
    {
        Print("ОТЛАДКА: Ищем бычьи дивергенции MACD...");
        FindDivergences(g_macd_min_peaks, "MACDBullish", false, true);
    }
    
    // Поиск двойных дивергенций
    if(ShowOnlyDouble)
        FindDoubleDivergences();
    
    Print("ОТЛАДКА: Поиск дивергенций завершен");
}

//+------------------------------------------------------------------+
//| Универсальная функция поиска пиков                              |
//+------------------------------------------------------------------+
void FindPeaks(int indicator_handle, int buffer_index, Peak &max_peaks[], Peak &min_peaks[], bool is_stochastic)
{
    double values[];
    ArraySetAsSeries(values, true);
    
    int copied = CopyBuffer(indicator_handle, buffer_index, 0, NrLoad, values);
    if(copied <= 0)
    {
        Print("Ошибка копирования буфера индикатора: ", GetLastError());
        return;
    }
    
    // Очистка массивов пиков
    ArrayResize(max_peaks, 0);
    ArrayResize(min_peaks, 0);
    
    // Временные массивы для всех найденных пиков
    Peak temp_max_peaks[];
    Peak temp_min_peaks[];
    ArrayResize(temp_max_peaks, 0);
    ArrayResize(temp_min_peaks, 0);
    
    // Поиск локальных экстремумов с улучшенной логикой для реального времени
    int lookback = 2; // Количество баров для сравнения слева
    
    // Определяем диапазон поиска
    int start_bar, end_bar;
    if(EnableRealtimeSignals)
    {
        start_bar = 0;  // Включаем текущий бар (0)
        end_bar = copied;
    }
    else
    {
        start_bar = lookback;  // Консервативный режим
        end_bar = copied - lookback;
    }
    
    for(int i = start_bar; i < end_bar; i++)
    {
        double curr_val = values[i];
        datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);
        
        // Проверяем, является ли текущее значение максимумом/минимумом
        bool is_max = true;
        bool is_min = true;
        
        // Для текущего бара (i=0) проверяем только с правой стороны (исторические бары)
        if(i == 0 && EnableRealtimeSignals)
        {
            // Для бара 0 сравниваем только с предыдущими барами (1, 2, 3...)
            for(int k = 1; k <= lookback && k < copied; k++)
            {
                if(curr_val <= values[k])  // Сравниваем с барами 1, 2
                    is_max = false;
                if(curr_val >= values[k])
                    is_min = false;
            }
            
            // Добавляем отладочную информацию
            if(is_max || is_min)
            {
                Print("ОТЛАДКА: Найден пик на баре 0! Тип: ", (is_max ? "MAX" : "MIN"), 
                      ", Значение: ", curr_val, ", Цена: ", (is_max ? iHigh(_Symbol, PERIOD_CURRENT, 0) : iLow(_Symbol, PERIOD_CURRENT, 0)));
            }
        }
        else if(i == 1 && EnableRealtimeSignals)
        {
            // Для бара 1 сравниваем с баром 0 и барами 2, 3...
            if(curr_val <= values[0] || curr_val <= values[2])
                is_max = false;
            if(curr_val >= values[0] || curr_val >= values[2])
                is_min = false;
        }
        else if(i < lookback)
        {
            // Для баров близко к началу - проверяем что можем
            for(int k = 1; k <= i && (i - k) >= 0; k++)
            {
                if(curr_val <= values[i - k])
                    is_max = false;
                if(curr_val >= values[i - k])
                    is_min = false;
            }
            for(int k = 1; k <= lookback && (i + k) < copied; k++)
            {
                if(curr_val <= values[i + k])
                    is_max = false;
                if(curr_val >= values[i + k])
                    is_min = false;
            }
        }
        else
        {
            // Для исторических баров - стандартная проверка с обеих сторон
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
        
        // Дополнительная фильтрация для Stochastic - СМЯГЧЕННАЯ
        if(is_stochastic)
        {
            // Для Stochastic ищем пики в расширенных зонах
            if(is_max && curr_val < 60.0) is_max = false;  // Было 70, стало 60
            if(is_min && curr_val > 40.0) is_min = false;  // Было 30, стало 40
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
            
            // Отладка для всех найденных пиков
            Print("ОТЛАДКА: Пик MAX на баре ", i, ", Значение: ", curr_val, ", Цена: ", price);
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
            
            // Отладка для всех найденных пиков
            Print("ОТЛАДКА: Пик MIN на баре ", i, ", Значение: ", curr_val, ", Цена: ", price);
        }
    }
    
    // Фильтруем пики по расстоянию между ними
    FilterPeaksByDistance(temp_max_peaks, max_peaks);
    FilterPeaksByDistance(temp_min_peaks, min_peaks);
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
        
        // Проверяем расстояние до уже добавленных пиков
        for(int j = 0; j < ArraySize(filtered_peaks); j++)
        {
            if(MathAbs(source_peaks[i].index - filtered_peaks[j].index) < MinBarsBetweenPeaks)
            {
                // Если новый пик сильнее, заменяем старый
                if(IsPeakStronger(source_peaks[i], filtered_peaks[j]))
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
    
    // Ограничиваем количество пиков
    if(ArraySize(filtered_peaks) > 15) // Максимум 15 пиков
    {
        ArrayResize(filtered_peaks, 15);
    }
}

//+------------------------------------------------------------------+
//| Проверка, какой пик сильнее                                     |
//+------------------------------------------------------------------+
bool IsPeakStronger(const Peak &peak1, const Peak &peak2)
{
    // Более свежий пик считается сильнее при прочих равных
    if(peak1.index < peak2.index) return true;
    
    // Иначе сравниваем по абсолютному значению
    return MathAbs(peak1.value) > MathAbs(peak2.value);
}

//+------------------------------------------------------------------+
//| Универсальная функция поиска дивергенций                        |
//+------------------------------------------------------------------+
void FindDivergences(Peak &peaks[], string type, bool is_bearish, bool is_macd)
{
    if(EnableRealtimeSignals)
    {
        FindDivergencesRealtime(peaks, type, is_bearish, is_macd);
    }
    else
    {
        FindDivergencesConservative(peaks, type, is_bearish, is_macd);
    }
}

//+------------------------------------------------------------------+
//| Поиск дивергенций в режиме реального времени                    |
//+------------------------------------------------------------------+
void FindDivergencesRealtime(Peak &peaks[], string type, bool is_bearish, bool is_macd)
{
    int peaks_count = ArraySize(peaks);
    Print("ОТЛАДКА: FindDivergencesRealtime - тип: ", type, ", количество пиков: ", peaks_count);
    
    if(peaks_count < 2) 
    {
        Print("ОТЛАДКА: Недостаточно пиков для анализа: ", peaks_count);
        return;
    }
    
    // Проверяем, есть ли пик на текущем баре (индекс 0)
    int current_bar_peak_idx = -1;
    for(int i = 0; i < peaks_count; i++)
    {
        Print("ОТЛАДКА: Пик ", i, " - индекс бара: ", peaks[i].index, ", значение: ", peaks[i].value);
        if(peaks[i].index == 0)
        {
            current_bar_peak_idx = i;
            Print("ОТЛАДКА: Найден пик на текущем баре (индекс 0)!");
            break;
        }
    }
    
    // Если на текущем баре нет пика - нет сигнала
    if(current_bar_peak_idx == -1) 
    {
        Print("ОТЛАДКА: НЕТ пика на текущем баре - выход");
        return;
    }
    
    Peak current_peak = peaks[current_bar_peak_idx];
    Print("ОТЛАДКА: Текущий пик - бар: ", current_peak.index, ", значение: ", current_peak.value, ", цена: ", current_peak.price);
    
    // Структура для хранения найденных дивергенций
    DivergenceInfo found_divergences[];
    ArrayResize(found_divergences, 0);
    
    // Ищем дивергенции только между текущим пиком и историческими пиками
    for(int i = 0; i < peaks_count; i++)
    {
        if(i == current_bar_peak_idx) continue; // Пропускаем сам текущий пик
        
        Peak historical_peak = peaks[i];
        Print("ОТЛАДКА: Проверка с историческим пиком - бар: ", historical_peak.index, ", значение: ", historical_peak.value, ", цена: ", historical_peak.price);
        
        // Проверка ограничений
        if(historical_peak.index - current_peak.index < MinBarsBetweenPeaks) 
        {
            Print("ОТЛАДКА: Слишком близко - расстояние: ", historical_peak.index - current_peak.index, " < ", MinBarsBetweenPeaks);
            continue;
        }
        if(historical_peak.index > MaxBarsToAnalyze) 
        {
            Print("ОТЛАДКА: Слишком старый пик - индекс: ", historical_peak.index, " > ", MaxBarsToAnalyze);
            continue;
        }
        
        // Фильтр по времени торговой сессии
        if(EnableTimeFilter && ShowOnlySessionSignals)
        {
            if(!IsTimeInSession(current_peak.time) || !IsTimeInSession(historical_peak.time))
            {
                Print("ОТЛАДКА: Пик вне торговой сессии");
                continue;
            }
        }
        
        // Проверка условий дивергенции между ТЕКУЩИМ пиком и историческим
        bool divergence_found = false;
        double strength = 0.0;
        
        if(is_bearish)
        {
            // Медвежья дивергенция: цена растет, индикатор падает
            // Сравниваем исторический пик с текущим
            bool price_condition = historical_peak.price < current_peak.price;
            bool indicator_condition = historical_peak.value > current_peak.value;
            
            Print("ОТЛАДКА: Медвежья дивергенция - цена растет: ", price_condition, " (", historical_peak.price, " < ", current_peak.price, "), индикатор падает: ", indicator_condition, " (", historical_peak.value, " > ", current_peak.value, ")");
            
            if(price_condition && indicator_condition)
            {
                if(is_macd)
                {
                    double macd_diff = MathAbs(historical_peak.value - current_peak.value);
                    Print("ОТЛАДКА: MACD diff: ", macd_diff, ", требуется: ", MACDPickDif * g_point);
                    if(macd_diff >= MACDPickDif * g_point)
                    {
                        divergence_found = true;
                        strength = macd_diff + (current_peak.price - historical_peak.price) / g_point;
                        Print("ОТЛАДКА: MACD дивергенция найдена! Сила: ", strength);
                    }
                }
                else
                {
                    divergence_found = true;
                    strength = (historical_peak.value - current_peak.value) + (current_peak.price - historical_peak.price) / g_point;
                    Print("ОТЛАДКА: Stoch дивергенция найдена! Сила: ", strength);
                }
            }
        }
        else
        {
            // Бычья дивергенция: цена падает, индикатор растет
            bool price_condition = historical_peak.price > current_peak.price;
            bool indicator_condition = historical_peak.value < current_peak.value;
            
            Print("ОТЛАДКА: Бычья дивергенция - цена падает: ", price_condition, " (", historical_peak.price, " > ", current_peak.price, "), индикатор растет: ", indicator_condition, " (", historical_peak.value, " < ", current_peak.value, ")");
            
            if(price_condition && indicator_condition)
            {
                if(is_macd)
                {
                    double macd_diff = MathAbs(historical_peak.value - current_peak.value);
                    Print("ОТЛАДКА: MACD diff: ", macd_diff, ", требуется: ", MACDPickDif * g_point);
                    if(macd_diff >= MACDPickDif * g_point)
                    {
                        divergence_found = true;
                        strength = macd_diff + (historical_peak.price - current_peak.price) / g_point;
                        Print("ОТЛАДКА: MACD дивергенция найдена! Сила: ", strength);
                    }
                }
                else
                {
                    divergence_found = true;
                    strength = (current_peak.value - historical_peak.value) + (historical_peak.price - current_peak.price) / g_point;
                    Print("ОТЛАДКА: Stoch дивергенция найдена! Сила: ", strength);
                }
            }
        }
        
        if(divergence_found)
        {
            DivergenceInfo div_info;
            div_info.peak1_idx = current_bar_peak_idx;  // Всегда текущий пик
            div_info.peak2_idx = i;                      // Исторический пик
            div_info.strength = strength;
            ArrayResize(found_divergences, ArraySize(found_divergences) + 1);
            found_divergences[ArraySize(found_divergences) - 1] = div_info;
            
            Print("ОТЛАДКА: Дивергенция добавлена в список! Всего: ", ArraySize(found_divergences));
        }
    }
    
    // Если нашли дивергенции, берем только самую сильную для текущего бара
    if(ArraySize(found_divergences) > 0)
    {
        Print("ОТЛАДКА: Найдено дивергенций: ", ArraySize(found_divergences), " - отображаем лучшую");
        
        // Сортируем по силе
        SortDivergencesByStrength(found_divergences);
        
        // Показываем только ОДНУ самую сильную дивергенцию на текущем баре
        DivergenceInfo best_div = found_divergences[0];
        
        Print("ОТЛАДКА: Отображаем дивергенцию с силой: ", best_div.strength);
        
        // Стрелка ВСЕГДА на текущем баре (бар 0)
        DrawDivergence(peaks[best_div.peak1_idx], peaks[best_div.peak2_idx], type, is_bearish);
        SendDivergenceAlert(type, 0); // Всегда бар 0
    }
    else
    {
        Print("ОТЛАДКА: Дивергенции НЕ найдены");
    }
}

//+------------------------------------------------------------------+
//| Отрисовка дивергенции в режиме реального времени                |
//+------------------------------------------------------------------+
void DrawDivergence(const Peak &peak1, const Peak &peak2, string type, bool is_bearish)
{
    // В новой логике peak1 всегда текущий пик (индекс 0), peak2 - исторический
    Peak current_peak = peak1;  // Текущий пик (всегда на баре 0)
    Peak historical_peak = peak2; // Исторический пик
    
    string base_name = "Div_" + type + "_" + IntegerToString(current_peak.index) + "_" + IntegerToString(historical_peak.index);
    
    // Определяем цвет и стиль
    color line_color = is_bearish ? RegularBearish : RegularBullish;
    
    // Стрелка ВСЕГДА на текущем пике (бар 0)
    string arrow_name = base_name + "_arrow";
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, current_peak.time, current_peak.price))
    {
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, is_bearish ? 242 : 241);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
        
        // Смещаем стрелку
        double offset = is_bearish ? 20 * g_point : -20 * g_point;
        ObjectSetDouble(0, arrow_name, OBJPROP_PRICE, current_peak.price + offset);
    }
    
    // Текстовая метка ВСЕГДА на текущем баре
    string text_name = base_name + "_text";
    if(ObjectCreate(0, text_name, OBJ_TEXT, 0, current_peak.time, current_peak.price))
    {
        string div_text = is_bearish ? "МЕДВЕЖЬЯ" : "БЫЧЬЯ";
        if(StringFind(type, "Stoch") >= 0)
            div_text += " STOCH";
        else
            div_text += " MACD";
        
        // Добавляем время текущего бара
        MqlDateTime time_struct;
        TimeToStruct(current_peak.time, time_struct);
        string time_str = StringFormat("%02d:%02d", time_struct.hour, time_struct.min);
        
        if(EnableTimeFilter)
        {
            string session_mark = IsTimeInSession(current_peak.time) ? "✓" : "✗";
            div_text += StringFormat(" [%s %s]", time_str, session_mark);
        }
        else
        {
            div_text += StringFormat(" [%s]", time_str);
        }
        
        // Всегда добавляем маркер LIVE, так как сигнал всегда на текущем баре
        div_text += " 🔴LIVE";
        
        // Добавляем информацию об историческом пике
        MqlDateTime hist_time_struct;
        TimeToStruct(historical_peak.time, hist_time_struct);
        string hist_time_str = StringFormat("%02d:%02d", hist_time_struct.hour, hist_time_struct.min);
        div_text += StringFormat(" vs %s", hist_time_str);
            
        ObjectSetString(0, text_name, OBJPROP_TEXT, div_text);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        
        // Смещаем текст
        double text_offset = is_bearish ? 30 * g_point : -30 * g_point;
        ObjectSetDouble(0, text_name, OBJPROP_PRICE, current_peak.price + text_offset);
    }
    
    // TP/SL уровни на основе текущего пика
    DrawTPSLLevels(current_peak, type, is_bearish, base_name);
}

//+------------------------------------------------------------------+
//| Сортировка дивергенций по силе                                  |
//+------------------------------------------------------------------+
void SortDivergencesByStrength(DivergenceInfo &divergences[])
{
    int size = ArraySize(divergences);
    if(size < 2) return;
    
    // Простая сортировка пузырьком по убыванию силы
    for(int i = 0; i < size - 1; i++)
    {
        for(int j = 0; j < size - 1 - i; j++)
        {
            if(divergences[j].strength < divergences[j + 1].strength)
            {
                // Меняем местами
                DivergenceInfo temp;
                temp.peak1_idx = divergences[j].peak1_idx;
                temp.peak2_idx = divergences[j].peak2_idx;
                temp.strength = divergences[j].strength;
                
                divergences[j].peak1_idx = divergences[j + 1].peak1_idx;
                divergences[j].peak2_idx = divergences[j + 1].peak2_idx;
                divergences[j].strength = divergences[j + 1].strength;
                
                divergences[j + 1].peak1_idx = temp.peak1_idx;
                divergences[j + 1].peak2_idx = temp.peak2_idx;
                divergences[j + 1].strength = temp.strength;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск дивергенций в консервативном режиме (с задержкой)          |
//+------------------------------------------------------------------+
void FindDivergencesConservative(Peak &peaks[], string type, bool is_bearish, bool is_macd)
{
    int peaks_count = ArraySize(peaks);
    if(peaks_count < 2) return;
    
    // Структура для хранения найденных дивергенций с их силой
    DivergenceInfo found_divergences[];
    ArrayResize(found_divergences, 0);
    
    // Ищем дивергенции среди исторических пиков (исключаем последние 2 бара)
    int max_search_distance = MathMin(peaks_count, 10);
    
    for(int i = 0; i < max_search_distance - 1; i++)
    {
        for(int j = i + 1; j < max_search_distance; j++)
        {
            // Исключаем пики на последних 2 барах
            if(peaks[i].index < 2 || peaks[j].index < 2) continue;
            
            // Проверка ограничений
            if(peaks[j].index - peaks[i].index < MinBarsBetweenPeaks) continue;
            if(peaks[i].index > MaxBarsToAnalyze) continue;
            
            // Фильтр по времени торговой сессии
            if(EnableTimeFilter && ShowOnlySessionSignals)
            {
                if(!IsTimeInSession(peaks[i].time) || !IsTimeInSession(peaks[j].time))
                    continue;
            }
            
            // Проверка условий дивергенции
            bool divergence_found = false;
            double strength = 0.0;
            
            if(is_bearish)
            {
                if(peaks[i].price < peaks[j].price && peaks[i].value > peaks[j].value)
                {
                    if(is_macd)
                    {
                        double macd_diff = MathAbs(peaks[i].value - peaks[j].value);
                        if(macd_diff >= MACDPickDif * g_point)
                        {
                            divergence_found = true;
                            strength = macd_diff + (peaks[j].price - peaks[i].price) / g_point;
                        }
                    }
                    else
                    {
                        divergence_found = true;
                        strength = (peaks[i].value - peaks[j].value) + (peaks[j].price - peaks[i].price) / g_point;
                    }
                }
            }
            else
            {
                if(peaks[i].price > peaks[j].price && peaks[i].value < peaks[j].value)
                {
                    if(is_macd)
                    {
                        double macd_diff = MathAbs(peaks[i].value - peaks[j].value);
                        if(macd_diff >= MACDPickDif * g_point)
                        {
                            divergence_found = true;
                            strength = macd_diff + (peaks[i].price - peaks[j].price) / g_point;
                        }
                    }
                    else
                    {
                        divergence_found = true;
                        strength = (peaks[j].value - peaks[i].value) + (peaks[i].price - peaks[j].price) / g_point;
                    }
                }
            }
            
            if(divergence_found)
            {
                DivergenceInfo div_info;
                div_info.peak1_idx = i;
                div_info.peak2_idx = j;
                div_info.strength = strength;
                ArrayResize(found_divergences, ArraySize(found_divergences) + 1);
                found_divergences[ArraySize(found_divergences) - 1] = div_info;
            }
        }
    }
    
    // Сортируем и показываем лучшие дивергенции
    if(ArraySize(found_divergences) > 0)
    {
        SortDivergencesByStrength(found_divergences);
        
        int max_to_show = MathMin(ArraySize(found_divergences), MaxDivergencesToShow);
        for(int k = 0; k < max_to_show; k++)
        {
            DivergenceInfo div = found_divergences[k];
            DrawDivergenceConservative(peaks[div.peak1_idx], peaks[div.peak2_idx], type, is_bearish);
            SendDivergenceAlert(type, peaks[div.peak1_idx].index);
        }
    }
}

//+------------------------------------------------------------------+
//| Отрисовка дивергенции в консервативном режиме                   |
//+------------------------------------------------------------------+
void DrawDivergenceConservative(const Peak &peak1, const Peak &peak2, string type, bool is_bearish)
{
    // В консервативном режиме выбираем более свежий пик
    Peak signal_peak = (peak1.index < peak2.index) ? peak1 : peak2;
    
    string base_name = "Div_" + type + "_" + IntegerToString(peak1.index) + "_" + IntegerToString(peak2.index);
    
    color line_color = is_bearish ? RegularBearish : RegularBullish;
    
    string arrow_name = base_name + "_arrow";
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, signal_peak.time, signal_peak.price))
    {
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, is_bearish ? 242 : 241);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
        
        double offset = is_bearish ? 20 * g_point : -20 * g_point;
        ObjectSetDouble(0, arrow_name, OBJPROP_PRICE, signal_peak.price + offset);
    }
    
    string text_name = base_name + "_text";
    if(ObjectCreate(0, text_name, OBJ_TEXT, 0, signal_peak.time, signal_peak.price))
    {
        string div_text = is_bearish ? "МЕДВЕЖЬЯ" : "БЫЧЬЯ";
        if(StringFind(type, "Stoch") >= 0)
            div_text += " STOCH";
        else
            div_text += " MACD";
        
        MqlDateTime time_struct;
        TimeToStruct(signal_peak.time, time_struct);
        string time_str = StringFormat("%02d:%02d", time_struct.hour, time_struct.min);
        
        div_text += StringFormat(" [%s] КОНСЕРВ.", time_str);
            
        ObjectSetString(0, text_name, OBJPROP_TEXT, div_text);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        
        double text_offset = is_bearish ? 30 * g_point : -30 * g_point;
        ObjectSetDouble(0, text_name, OBJPROP_PRICE, signal_peak.price + text_offset);
    }
    
    DrawTPSLLevels(signal_peak, type, is_bearish, base_name);
}

//+------------------------------------------------------------------+
//| Отрисовка TP/SL уровней                                         |
//+------------------------------------------------------------------+
void DrawTPSLLevels(const Peak &peak, string type, bool is_bearish, string base_name)
{
    double atr[];
    ArraySetAsSeries(atr, true);
    
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) > 0)
    {
        double close_price = iClose(_Symbol, PERIOD_CURRENT, peak.index);
        double atr_value = atr[0];
        
        double tp, sl;
        if(is_bearish)
        {
            tp = close_price - ATRMultiplierTP * atr_value;
            sl = close_price + ATRMultiplierSL * atr_value;
        }
        else
        {
            tp = close_price + ATRMultiplierTP * atr_value;
            sl = close_price - ATRMultiplierSL * atr_value;
        }
        
        // Рисуем TP с галочкой
        string tp_name = base_name + "_tp";
        if(ObjectCreate(0, tp_name, OBJ_ARROW, 0, peak.time, tp))
        {
            ObjectSetInteger(0, tp_name, OBJPROP_ARROWCODE, 252); // Галочка
            ObjectSetInteger(0, tp_name, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 3);
        }
        
        // Рисуем SL с крестиком
        string sl_name = base_name + "_sl";
        if(ObjectCreate(0, sl_name, OBJ_ARROW, 0, peak.time, sl))
        {
            ObjectSetInteger(0, sl_name, OBJPROP_ARROWCODE, 251); // Крестик
            ObjectSetInteger(0, sl_name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 3);
        }
        
        // Добавляем текстовые метки с точными значениями
        string tp_text = base_name + "_tp_text";
        if(ObjectCreate(0, tp_text, OBJ_TEXT, 0, peak.time, tp))
        {
            ObjectSetString(0, tp_text, OBJPROP_TEXT, "TP: " + DoubleToString(tp, _Digits));
            ObjectSetInteger(0, tp_text, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, tp_text, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, tp_text, OBJPROP_ANCHOR, ANCHOR_LEFT);
            
            // Смещаем текст вправо от стрелки
            datetime text_time = peak.time + 2 * PeriodSeconds(PERIOD_CURRENT);
            ObjectSetInteger(0, tp_text, OBJPROP_TIME, text_time);
        }
        
        string sl_text = base_name + "_sl_text";
        if(ObjectCreate(0, sl_text, OBJ_TEXT, 0, peak.time, sl))
        {
            ObjectSetString(0, sl_text, OBJPROP_TEXT, "SL: " + DoubleToString(sl, _Digits));
            ObjectSetInteger(0, sl_text, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, sl_text, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, sl_text, OBJPROP_ANCHOR, ANCHOR_LEFT);
            
            // Смещаем текст вправо от стрелки
            datetime text_time = peak.time + 2 * PeriodSeconds(PERIOD_CURRENT);
            ObjectSetInteger(0, sl_text, OBJPROP_TIME, text_time);
        }
    }
}

//+------------------------------------------------------------------+
//| Поиск двойных дивергенций                                       |
//+------------------------------------------------------------------+
void FindDoubleDivergences()
{
    // Проходим по всем объектам дивергенций и ищем близкие по времени
    int total_objects = ObjectsTotal(0);
    string names[];
    ArrayResize(names, 0);
    
    // Собираем все объекты дивергенций (стрелки)
    for(int i = 0; i < total_objects; i++)
    {
        string obj_name = ObjectName(0, i);
        if(StringFind(obj_name, "Div_") == 0 && StringFind(obj_name, "_arrow") > 0)
        {
            ArrayResize(names, ArraySize(names) + 1);
            names[ArraySize(names) - 1] = obj_name;
        }
    }
    
    // Ищем пары близких дивергенций
    for(int i = 0; i < ArraySize(names) - 1; i++)
    {
        for(int j = i + 1; j < ArraySize(names); j++)
        {
            datetime time1 = (datetime)ObjectGetInteger(0, names[i], OBJPROP_TIME, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, names[j], OBJPROP_TIME, 0);
            
            // Если дивергенции близки по времени (в пределах 3 баров)
            if(MathAbs(time1 - time2) <= 3 * PeriodSeconds(PERIOD_CURRENT))
            {
                // Помечаем как двойную дивергенцию
                MarkAsDoubleDivergence(names[i], names[j]);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Пометка двойной дивергенции                                     |
//+------------------------------------------------------------------+
void MarkAsDoubleDivergence(string name1, string name2)
{
    // Меняем цвет стрелок на специальный цвет для двойных дивергенций
    ObjectSetInteger(0, name1, OBJPROP_COLOR, DoubleText);
    ObjectSetInteger(0, name2, OBJPROP_COLOR, DoubleText);
    ObjectSetInteger(0, name1, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, name2, OBJPROP_WIDTH, 4);
    
    // Добавляем текстовую метку о двойной дивергенции
    datetime time1 = (datetime)ObjectGetInteger(0, name1, OBJPROP_TIME, 0);
    double price1 = ObjectGetDouble(0, name1, OBJPROP_PRICE, 0);
    
    string text_name = StringSubstr(name1, 0, StringFind(name1, "_arrow")) + "_double";
    if(ObjectCreate(0, text_name, OBJ_TEXT, 0, time1, price1))
    {
        ObjectSetString(0, text_name, OBJPROP_TEXT, "ДВОЙНАЯ!");
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, DoubleText);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        
        // Смещаем текст вниз от стрелки
        ObjectSetDouble(0, text_name, OBJPROP_PRICE, price1 - 50 * g_point);
    }
}

//+------------------------------------------------------------------+
//| Отправка алерта о дивергенции                                   |
//+------------------------------------------------------------------+
void SendDivergenceAlert(string type, int bar_index)
{
    if(!EnableAlerts) return;
    
    datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, bar_index);
    MqlDateTime time_struct;
    TimeToStruct(bar_time, time_struct);
    
    string time_str = StringFormat("%02d:%02d", time_struct.hour, time_struct.min);
    string session_status = IsTimeInSession(bar_time) ? "В СЕССИИ" : "ВНЕ СЕССИИ";
    
    // Определяем тип сигнала
    string signal_type = (bar_index == 0) ? "🔴 LIVE СИГНАЛ" : "📊 Исторический сигнал";
    
    string message = StringFormat("%s: Дивергенция %s обнаружена!\n⏰ Время: %s (%s)\n📊 Символ: %s\n📍 Бар: %d%s", 
                                  signal_type, type, time_str, session_status, _Symbol, bar_index,
                                  (bar_index == 0) ? " (ТЕКУЩИЙ)" : "");
    
    Alert(message);
    
    if(EnableEmailAlerts)
        SendMail("Divergence Alert - " + _Symbol + " " + signal_type, message);
        
    if(EnablePushAlerts)
        SendNotification(message);
}

//+------------------------------------------------------------------+
//| Удаление старых объектов дивергенций                           |
//+------------------------------------------------------------------+
void RemoveOldDivergenceObjects()
{
    int total = ObjectsTotal(0);
    
    for(int i = total - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i);
        if(StringFind(obj_name, "Div_") == 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Ограничение количества сигналов на графике                      |
//+------------------------------------------------------------------+
void LimitSignalsOnChart()
{
    if(MaxSignalsToKeep <= 0) return;
    
    // Собираем все объекты дивергенций с их временными метками
    struct DivergenceObject
    {
        string name;
        datetime time;
    };
    
    DivergenceObject div_objects[];
    ArrayResize(div_objects, 0);
    
    int total = ObjectsTotal(0);
    for(int i = 0; i < total; i++)
    {
        string obj_name = ObjectName(0, i);
        // Проверяем только основные объекты (стрелки), чтобы не дублировать подсчет
        if(StringFind(obj_name, "Div_") == 0 && StringFind(obj_name, "_arrow") > 0)
        {
            datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
            
            int idx = ArraySize(div_objects);
            ArrayResize(div_objects, idx + 1);
            div_objects[idx].name = StringSubstr(obj_name, 0, StringFind(obj_name, "_arrow")); // Базовое имя без суффикса
            div_objects[idx].time = obj_time;
        }
    }
    
    // Если сигналов больше лимита, удаляем самые старые
    int objects_count = ArraySize(div_objects);
    if(objects_count > MaxSignalsToKeep)
    {
        // Сортируем по времени (самые старые в начале)
        for(int i = 0; i < objects_count - 1; i++)
        {
            for(int j = i + 1; j < objects_count; j++)
            {
                if(div_objects[i].time > div_objects[j].time)
                {
                    // Меняем местами
                    string temp_name = div_objects[i].name;
                    datetime temp_time = div_objects[i].time;
                    
                    div_objects[i].name = div_objects[j].name;
                    div_objects[i].time = div_objects[j].time;
                    
                    div_objects[j].name = temp_name;
                    div_objects[j].time = temp_time;
                }
            }
        }
        
        // Удаляем самые старые объекты
        int to_remove = objects_count - MaxSignalsToKeep;
        for(int i = 0; i < to_remove; i++)
        {
            string base_name = div_objects[i].name;
            
            // Удаляем все связанные объекты
            ObjectDelete(0, base_name + "_arrow");
            ObjectDelete(0, base_name + "_text");
            ObjectDelete(0, base_name + "_tp");
            ObjectDelete(0, base_name + "_sl");
            ObjectDelete(0, base_name + "_tp_text");
            ObjectDelete(0, base_name + "_sl_text");
            ObjectDelete(0, base_name + "_double");
        }
        
        Print("ОТЛАДКА: Удалено ", to_remove, " старых сигналов. Осталось на графике: ", MaxSignalsToKeep);
    }
}

//+------------------------------------------------------------------+
//| Деинициализация индикатора                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Удаление всех объектов дивергенций
    RemoveOldDivergenceObjects();
    
    // Освобождение хендлов индикаторов
    if(g_stoch_handle != INVALID_HANDLE)
        IndicatorRelease(g_stoch_handle);
    if(g_macd_handle != INVALID_HANDLE)
        IndicatorRelease(g_macd_handle);
    if(g_atr_handle != INVALID_HANDLE)
        IndicatorRelease(g_atr_handle);
}

//+------------------------------------------------------------------+
//| Проверка, попадает ли время в торговую сессию                   |
//+------------------------------------------------------------------+
bool IsTimeInSession(datetime check_time)
{
    if(!EnableTimeFilter) return true;
    
    MqlDateTime time_struct;
    TimeToStruct(check_time, time_struct);
    
    int session_start_minutes = ParseTimeString(SessionStartTime);
    int session_end_minutes = ParseTimeString(SessionEndTime);
    int current_minutes = time_struct.hour * 60 + time_struct.min;
    
    if(session_start_minutes == -1 || session_end_minutes == -1)
        return true; // Если ошибка парсинга, не фильтруем
    
    // Проверяем, не переходит ли сессия через полночь
    if(session_start_minutes <= session_end_minutes)
    {
        // Обычная сессия в рамках одного дня
        return (current_minutes >= session_start_minutes && current_minutes <= session_end_minutes);
    }
    else
    {
        // Сессия переходит через полночь (например, 22:00-06:00)
        return (current_minutes >= session_start_minutes || current_minutes <= session_end_minutes);
    }
}

//+------------------------------------------------------------------+
//| Парсинг строки времени в минуты от начала дня                   |
//+------------------------------------------------------------------+
int ParseTimeString(string time_str)
{
    // Ожидаем формат "HH:MM"
    int colon_pos = StringFind(time_str, ":");
    if(colon_pos == -1 || colon_pos == 0 || colon_pos == StringLen(time_str) - 1)
        return -1;
    
    string hour_str = StringSubstr(time_str, 0, colon_pos);
    string min_str = StringSubstr(time_str, colon_pos + 1);
    
    int hours = (int)StringToInteger(hour_str);
    int minutes = (int)StringToInteger(min_str);
    
    if(hours < 0 || hours > 23 || minutes < 0 || minutes > 59)
        return -1;
    
    return hours * 60 + minutes;
} 