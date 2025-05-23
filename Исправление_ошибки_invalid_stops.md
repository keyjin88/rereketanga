# Исправление ошибки "Invalid stops" в DivergenceTrader EA

## 🚨 Проблема

При тестировании советника в тестере стратегий возникали ошибки:
```
failed market buy 0.1 EURUSD sl: 1.12512 tp: 1.13222 [Invalid stops]
CTrade::OrderSend: market buy 0.10 EURUSD sl: 1.12512 tp: 1.13222 [invalid stops]
❌ Ошибка открытия позиции: 10016 - invalid stops
```

## 🔍 Причины ошибки

1. **Использование цены пика вместо текущей** - советник пытался открыть позицию по цене исторического пика
2. **Игнорирование минимальных дистанций брокера** - не учитывались требования `SYMBOL_TRADE_STOPS_LEVEL`
3. **Неправильная нормализация** - TP/SL не соответствовали требованиям точности
4. **Отсутствие валидации** - уровни не проверялись перед отправкой ордера

## ✅ Исправления

### 1. Исправлен расчет TP/SL
**Было:**
```mql5
// Использовалась цена пика из истории
signal.entry_price = recent_peak.price;
signal.tp_price = signal.entry_price + tp_distance;
```

**Стало:**
```mql5
// Используется ТЕКУЩАЯ рыночная цена
double current_price = signal.is_bearish ? current_bid : current_ask;
signal.entry_price = current_price;
signal.tp_price = current_price + tp_distance;
```

### 2. Добавлена проверка минимальных дистанций
```mql5
// Получаем требования брокера
int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
double min_distance = stops_level * g_point * MinStopDistanceMultiplier;

// Гарантируем минимальные дистанции
tp_distance = MathMax(tp_distance, min_distance);
sl_distance = MathMax(sl_distance, min_distance);
```

### 3. Добавлена валидация уровней
```mql5
bool ValidateTPSL(double price, double tp, double sl, bool is_buy)
{
    // Проверяем направление (для BUY: SL ниже, TP выше)
    // Проверяем минимальные дистанции
    // Возвращаем false при ошибках
}
```

### 4. Обновлены параметры по умолчанию
```mql5
UseFixedTPSL = true              // Включены фиксированные TP/SL
FixedTPPoints = 800             // Увеличен TP (было 500)
FixedSLPoints = 400             // Увеличен SL (было 250)
MinStopDistanceMultiplier = 2.0 // Множитель безопасности
```

## 🔧 Новые параметры

- **`MinStopDistanceMultiplier`** - множитель минимальной дистанции (по умолчанию 2.0)
- **`UseFixedTPSL = true`** - использовать фиксированные TP/SL по умолчанию
- Увеличены значения `FixedTPPoints` и `FixedSLPoints`

## 📊 Диагностика

При открытии позиции теперь выводится подробная информация:
```
🔄 Открытие позиции: BUY | Цена: 1.12800 | SL: 1.12400 | TP: 1.13600
ОТЛАДКА TP/SL: Текущая цена: 1.12800 | TP: 1.13600 | SL: 1.12400 | Мин.дистанция: 0.00100
```

При ошибках:
```
❌ SL слишком близко для BUY: 0.00050 < 0.00100
🔍 Диагностика: Bid=1.12795 Ask=1.12805 Спред=0.00010
```

## 🎯 Результат

- ✅ Устранена ошибка "Invalid stops"
- ✅ Корректный расчет TP/SL от текущей цены
- ✅ Соблюдение требований брокера
- ✅ Подробная диагностика ошибок
- ✅ Безопасные параметры по умолчанию

**Теперь советник должен открывать позиции без ошибок!** 🚀 