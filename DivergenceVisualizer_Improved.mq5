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
input double MACDPickDif = 2.0;             // Минимальная разница для пиков MACD (в пунктах)
input int MinBarsBetweenPeaks = 5;          // Минимальное расстояние между пиками
input int MaxDivergencesToShow = 5;         // Максимальное количество дивергенций на экране
input int MaxBarsToAnalyze = 50;            // Максимальное количество баров для поиска дивергенций
input int NrLoad = 100;                     // Количество баров для анализа

//--- Настройки визуализации
input group "Настройки отображения"
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
    // Очистка предыдущих объектов
    RemoveOldDivergenceObjects();
    
    // Поиск пиков
    FindPeaks(g_stoch_handle, 0, g_stoch_max_peaks, g_stoch_min_peaks, true);
    FindPeaks(g_macd_handle, 0, g_macd_max_peaks, g_macd_min_peaks, false);
    
    // Поиск дивергенций
    if(StochBearish) FindDivergences(g_stoch_max_peaks, "StochBearish", true, false);
    if(StochBullish) FindDivergences(g_stoch_min_peaks, "StochBullish", false, false);
    if(MACDBearish) FindDivergences(g_macd_max_peaks, "MACDBearish", true, true);
    if(MACDBullish) FindDivergences(g_macd_min_peaks, "MACDBullish", false, true);
    
    // Поиск двойных дивергенций
    if(ShowOnlyDouble)
        FindDoubleDivergences();
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
    
    // Поиск локальных экстремумов с улучшенной логикой
    int lookback = 2; // Количество баров для сравнения с каждой стороны
    
    for(int i = lookback; i < copied - lookback; i++)
    {
        double curr_val = values[i];
        datetime bar_time = iTime(_Symbol, PERIOD_CURRENT, i);
        
        // Проверяем, является ли текущее значение максимумом
        bool is_max = true;
        bool is_min = true;
        
        for(int k = 1; k <= lookback; k++)
        {
            if(curr_val <= values[i - k] || curr_val <= values[i + k])
                is_max = false;
            if(curr_val >= values[i - k] || curr_val >= values[i + k])
                is_min = false;
        }
        
        // Дополнительная фильтрация для Stochastic
        if(is_stochastic)
        {
            // Для Stochastic ищем пики только в зонах перекупленности/перепроданности
            if(is_max && curr_val < 70.0) is_max = false;
            if(is_min && curr_val > 30.0) is_min = false;
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
    int peaks_count = ArraySize(peaks);
    if(peaks_count < 2) return;
    
    // Структура для хранения найденных дивергенций с их силой
    DivergenceInfo found_divergences[];
    ArrayResize(found_divergences, 0);
    
    // Ищем дивергенции только среди последних пиков
    int max_search_distance = MathMin(peaks_count, 10); // Максимум 10 последних пиков
    
    for(int i = 0; i < max_search_distance - 1; i++)
    {
        for(int j = i + 1; j < max_search_distance; j++)
        {
            // Проверка ограничений
            if(peaks[j].index - peaks[i].index < MinBarsBetweenPeaks) continue;
            if(peaks[i].index > MaxBarsToAnalyze) continue; // Слишком старые пики
            
            // Проверка условий дивергенции
            bool divergence_found = false;
            double strength = 0.0;
            
            if(is_bearish)
            {
                // Медвежья дивергенция: цена растет, индикатор падает
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
                // Бычья дивергенция: цена падает, индикатор растет
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
    
    // Сортируем дивергенции по силе (самые сильные первыми)
    SortDivergencesByStrength(found_divergences);
    
    // Отображаем только лучшие дивергенции
    int max_to_show = MathMin(ArraySize(found_divergences), MaxDivergencesToShow);
    for(int k = 0; k < max_to_show; k++)
    {
        DivergenceInfo div = found_divergences[k];
        
        DrawDivergence(peaks[div.peak1_idx], peaks[div.peak2_idx], type, is_bearish);
        SendDivergenceAlert(type, peaks[div.peak1_idx].index);
    }
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
//| Отрисовка дивергенции                                           |
//+------------------------------------------------------------------+
void DrawDivergence(const Peak &peak1, const Peak &peak2, string type, bool is_bearish)
{
    string base_name = "Div_" + type + "_" + IntegerToString(peak1.index) + "_" + IntegerToString(peak2.index);
    
    // Определяем цвет и стиль
    color line_color = is_bearish ? RegularBearish : RegularBullish;
    
    // Добавляем стрелку на первом пике
    string arrow_name = base_name + "_arrow";
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, peak1.time, peak1.price))
    {
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, is_bearish ? 242 : 241);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
        
        // Смещаем стрелку
        double offset = is_bearish ? 20 * g_point : -20 * g_point;
        ObjectSetDouble(0, arrow_name, OBJPROP_PRICE, peak1.price + offset);
    }
    
    // Добавляем текстовую метку
    string text_name = base_name + "_text";
    if(ObjectCreate(0, text_name, OBJ_TEXT, 0, peak1.time, peak1.price))
    {
        string div_text = is_bearish ? "МЕДВЕЖЬЯ" : "БЫЧЬЯ";
        if(StringFind(type, "Stoch") >= 0)
            div_text += " STOCH";
        else
            div_text += " MACD";
            
        ObjectSetString(0, text_name, OBJPROP_TEXT, div_text);
        ObjectSetInteger(0, text_name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, text_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        
        // Смещаем текст
        double text_offset = is_bearish ? 30 * g_point : -30 * g_point;
        ObjectSetDouble(0, text_name, OBJPROP_PRICE, peak1.price + text_offset);
    }
    
    // Добавляем TP/SL уровни
    DrawTPSLLevels(peak1, type, is_bearish, base_name);
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
    
    string message = StringFormat("Дивергенция %s обнаружена на баре %d (%s)", 
                                  type, bar_index, _Symbol);
    
    Alert(message);
    
    if(EnableEmailAlerts)
        SendMail("Divergence Alert - " + _Symbol, message);
        
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