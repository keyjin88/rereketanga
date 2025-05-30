# DivergenceTrader EA - Автоматическая торговля дивергенций

## 🤖 Описание

**DivergenceTrader EA** - это профессиональный советник для MetaTrader 5, который автоматически торгует дивергенциями между ценой и техническими индикаторами (Stochastic и MACD).

## ⚡ Ключевые особенности

### 🎯 Автоматическая торговля
- **Поиск дивергенций в реальном времени** на текущем баре
- **Автоматическое открытие позиций** при появлении сигналов
- **Умное управление рисками** с расчетом лота по депозиту
- **Автоматические TP/SL** на основе ATR или фиксированные

### 📊 Продвинутая аналитика
- **4 типа дивергенций**: StochBearish, StochBullish, MACDBearish, MACDBullish  
- **Фильтрация по силе сигнала** для качественных входов
- **Фильтры времени торговли** по дням недели и сессиям
- **Подробная статистика** торговли в реальном времени

### 🛡️ Управление рисками
- **Контроль максимального количества позиций**
- **Автоматический расчет лота** по проценту риска
- **Трейлинг стоп** для максимизации прибыли
- **Защита от противоположных позиций**

## 🔧 Настройки советника

### 📈 Настройки индикаторов

```
=== Настройки Stochastic ===
StochKPeriod = 8          // Период %K
StochDPeriod = 3          // Период %D  
StochSlowing = 5          // Замедление

=== Настройки MACD ===
MACDFastEMA = 12          // Быстрый EMA
MACDSlowEMA = 26          // Медленный EMA
MACDSignalPeriod = 9      // Период сигнальной линии
```

### 🎯 Настройки дивергенций

```
=== Настройки дивергенций ===
StochBearish = true       // Торговать медвежьи дивергенции Stochastic
StochBullish = true       // Торговать бычьи дивергенции Stochastic
MACDBearish = true        // Торговать медвежьи дивергенции MACD
MACDBullish = true        // Торговать бычьи дивергенции MACD
MACDPickDif = 0.5         // Минимальная разница для пиков MACD
MinBarsBetweenPeaks = 3   // Минимальное расстояние между пиками
MaxBarsToAnalyze = 50     // Максимальное количество баров для анализа
```

### 💰 Настройки торговли

```
=== Настройки торговли ===
EnableTrading = true      // Разрешить торговлю (false = только сигналы)
LotSize = 0.1            // Размер лота
UseAutoLotSize = false   // Автоматический расчет лота
RiskPercent = 2.0        // Риск на сделку (% от депозита)
MaxPositions = 1         // Максимальное количество позиций
AllowOpposite = false    // Разрешить противоположные позиции
MagicNumber = 123456     // Магический номер
```

### 🎯 Настройки TP/SL

```
=== Настройки TP/SL ===
ATRPeriod = 14                // Период ATR
ATRMultiplierTP = 2.0         // Множитель ATR для TP
ATRMultiplierSL = 1.0         // Множитель ATR для SL
UseFixedTPSL = false         // Использовать фиксированные TP/SL
FixedTPPoints = 500          // Фиксированный TP в пунктах
FixedSLPoints = 250          // Фиксированный SL в пунктах
```

### 📈 Настройки трейлинга

```
=== Настройки трейлинга ===
EnableTrailing = true        // Включить трейлинг стоп
TrailingStart = 200         // Начать трейлинг после (пунктов)
TrailingStop = 100          // Шаг трейлинга (пунктов)
TrailingStep = 50           // Минимальный шаг (пунктов)
```

### ⏰ Фильтр времени торговли

```
=== Фильтр времени торговли ===
EnableTimeFilter = true      // Включить фильтр времени
SessionStartTime = "08:00"   // Время начала торговой сессии
SessionEndTime = "17:00"     // Время окончания торговой сессии
TradeMonday = true          // Торговать в понедельник
TradeTuesday = true         // Торговать во вторник
TradeWednesday = true       // Торговать в среду
TradeThursday = true        // Торговать в четверг
TradeFriday = true          // Торговать в пятницу
```

### 💪 Фильтры силы сигнала

```
=== Фильтры силы сигнала ===
EnableStrengthFilter = true     // Включить фильтр силы сигнала
MinSignalStrength = 10.0        // Минимальная сила сигнала
RequireStochInZone = true       // Требовать Stochastic в зоне
StochOverboughtLevel = 70.0     // Уровень перекупленности
StochOversoldLevel = 30.0       // Уровень перепроданности
```

### 🔔 Настройки уведомлений

```
=== Настройки уведомлений ===
EnableAlerts = true             // Включить алерты
EnableEmailAlerts = false       // Включить email-уведомления
EnablePushAlerts = false        // Включить push-уведомления
AlertOnEntry = true             // Уведомлять о входах
AlertOnClose = true             // Уведомлять о закрытиях
```

## 🚀 Быстрый старт

### 1. **Установка**
```
1. Скопируйте DivergenceTrader_EA.mq5 в папку MQL5/Experts/
2. Перекомпилируйте в MetaEditor (F7)
3. Перезапустите MetaTrader 5
```

### 2. **Настройка для начинающих**
```
EnableTrading = false          // Сначала тестируем без торговли
EnableAlerts = true           // Смотрим на сигналы
LotSize = 0.01               // Минимальный лот для теста
MaxPositions = 1             // Одна позиция за раз
```

### 3. **Настройка для продвинутых**
```
EnableTrading = true          // Включаем автоторговлю
UseAutoLotSize = true        // Автоматический расчет лота
RiskPercent = 2.0            // 2% риска на сделку
EnableTrailing = true        // Трейлинг стоп
MaxPositions = 3             // До 3-х позиций одновременно
```

## 📊 Как работает советник

### 🔍 Алгоритм работы

1. **Поиск пиков** на каждом новом баре
2. **Анализ дивергенций** между ценой и индикаторами
3. **Фильтрация сигналов** по силе и времени
4. **Расчет TP/SL** на основе ATR или фиксированных значений
5. **Открытие позиций** с автоматическим управлением
6. **Трейлинг стоп** для максимизации прибыли

### 💡 Логика дивергенций

**Медвежья дивергенция (SELL):**
- Цена формирует новый максимум
- Индикатор показывает более низкий максимум
- Сигнал к продаже

**Бычья дивергенция (BUY):**  
- Цена формирует новый минимум
- Индикатор показывает более высокий минимум
- Сигнал к покупке

### 🎯 Сила сигнала

Сила рассчитывается по формуле:
```
Сила = Разница_индикатора + Разница_цены_в_пунктах
```

Более сильные сигналы обрабатываются в первую очередь.

## 📈 Статистика и мониторинг

### 📋 Отображение в журнале

```
=== Инициализация DivergenceTrader EA ===
✅ Инициализация завершена успешно
📊 Торговля: ВКЛЮЧЕНА
💰 Размер лота: Авто (2.0%)
🎯 Максимум позиций: 1
🕒 Фильтр времени: 08:00 - 17:00

📈 ТОРГОВЫЙ СИГНАЛ: StochBearish | Сила: 15.25 | Цена: 1.12345
✅ Позиция открыта: SELL | Лот: 0.15 | Цена: 1.12345
📉 Трейлинг SELL: 1.12300
✅ Позиция закрыта: Take Profit | Прибыль: 25.30
```

### 📊 Статистика при завершении

```
📊 СТАТИСТИКА ТОРГОВЛИ:
📈 Всего сигналов: 45
💼 Всего сделок: 32
✅ Прибыльных: 20 (62.5%)
❌ Убыточных: 12
💰 Общая прибыль: 1250.75
```

## ⚙️ Рекомендуемые настройки

### 🏃 Для скальпинга (M1, M5)
```
SessionStartTime = "08:00"
SessionEndTime = "18:00"
MinSignalStrength = 5.0
TrailingStart = 50
TrailingStop = 25
ATRMultiplierTP = 1.5
MaxPositions = 2
```

### 📊 Для дневной торговли (H1, H4)
```
SessionStartTime = "09:00"  
SessionEndTime = "17:00"
MinSignalStrength = 15.0
TrailingStart = 200
TrailingStop = 100
ATRMultiplierTP = 2.0
MaxPositions = 1
```

### 📈 Для свинг-торговли (D1)
```
EnableTimeFilter = false
MinSignalStrength = 25.0
TrailingStart = 500
TrailingStop = 300
ATRMultiplierTP = 3.0
MaxPositions = 3
```

## ⚠️ Важные замечания

### 🛡️ Безопасность

1. **Всегда тестируйте** на демо-счете перед реальной торговлей
2. **Начинайте с EnableTrading = false** для изучения сигналов
3. **Используйте минимальные лоты** при первых запусках
4. **Мониторьте статистику** для оценки эффективности

### ⚡ Производительность

1. **Работает только на новых барах** - оптимально для CPU
2. **Автоматическое управление памятью** индикаторов
3. **Встроенная валидация** всех параметров
4. **Подробное логирование** для отладки

### 📱 Уведомления

1. **Алерты** - всплывающие окна в терминале
2. **Email** - отправка на почту (настройте в MT5)
3. **Push** - уведомления на мобильное приложение MT5

## 🔧 Устранение неполадок

### ❌ Нет сигналов
```
1. Проверьте EnableTimeFilter - возможно, вне сессии
2. Снизьте MinSignalStrength до 5.0
3. Проверьте StochOverboughtLevel/StochOversoldLevel
4. Убедитесь, что включены нужные типы дивергенций
```

### ❌ Позиции не открываются
```
1. Проверьте EnableTrading = true
2. Проверьте настройки брокера (лоты, левередж)
3. Убедитесь в достаточности средств на счете
4. Проверьте MaxPositions
```

### ❌ Частые ложные сигналы
```
1. Увеличьте MinSignalStrength
2. Включите RequireStochInZone = true
3. Увеличьте MinBarsBetweenPeaks
4. Добавьте фильтр времени торговли
```

## 🎯 Результат

**DivergenceTrader EA** - это полноценная автоматическая торговая система, которая:

✅ **Торгует в режиме реального времени** без задержек  
✅ **Управляет рисками** автоматически  
✅ **Максимизирует прибыль** с трейлинг стопом  
✅ **Предоставляет полную статистику** торговли  
✅ **Настраивается под любой стиль** торговли  

**Готов к реальной торговле!** 🚀 