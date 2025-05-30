# Руководство по настройке DivergenceTrader EA для M15 EURUSD

## 🎯 Основные оптимизации

Данная версия советника специально оптимизирована для торговли дивергенциями на таймфрейме M15 пары EURUSD.

## 📊 Ключевые изменения параметров

### Индикаторы
- **Stochastic K Period**: 14 (увеличено с 8) - лучше для M15
- **Stochastic Slowing**: 3 (уменьшено с 5) - быстрая реакция
- **Stochastic зоны**: 25-75 (расширены) - меньше ложных сигналов
- **ATR Period**: 14 (стандартный для M15)

### Поиск дивергенций  
- **MinBarsBetweenPeaks**: 8 баров (увеличено с 5)
- **MaxBarsToAnalyze**: 80 баров (увеличено с 50)
- **MACD PickDif**: 0.8 (оптимизировано для EURUSD)

### Управление рисками
- **RiskPercent**: 1.5% (уменьшено для M15)
- **MaxPositions**: 2 (можно больше позиций)
- **AllowOpposite**: true (разрешены противоположные позиции)

### TP/SL
- **ATR Multiplier TP**: 2.0 (уменьшено)
- **ATR Multiplier SL**: 1.5 (оптимизировано)
- **Fixed TP**: 300 пунктов (30 пипсов)
- **Fixed SL**: 150 пунктов (15 пипсов)

### Время торговли
- **Торговая сессия**: 07:00-20:00 GMT
- Охватывает европейскую и американскую сессии
- Максимальная волатильность для EURUSD

### Трейлинг и безубыток
- **Trailing Start**: 150 пунктов (15 пипсов)
- **Breakeven Trigger**: 40% от TP
- **Breakeven Offset**: 8 пунктов

## 🔧 Рекомендуемые настройки брокера

### Спред
- Максимальный спред: 3 пипса
- Лучше торговать при спреде 1-2 пипса
- Избегать торговли при расширенных спредах

### Исполнение
- Тип исполнения: Market Execution
- Максимальное отклонение: 3-5 пунктов
- Частичное заполнение: разрешено

## 📅 Оптимальное время торговли

### Лучшие часы (GMT)
- **07:00-10:00**: Начало европейской сессии
- **13:00-17:00**: Пересечение европейской и американской сессий  
- **15:00-18:00**: Максимальная волатильность

### Избегать торговли
- 22:00-07:00 GMT (низкая волатильность)
- Во время важных новостей EUR/USD
- В пятницу после 18:00 GMT

## 📈 Стратегия тестирования

### Параметры тестирования
1. **Период**: минимум 3 месяца
2. **Модель**: "Все тики" или "OHLC на M1"
3. **Спред**: фиксированный 2 пипса
4. **Депозит**: от $1000

### Критерии успешности
- **Profit Factor**: > 1.3
- **Максимальная просадка**: < 20%
- **Winrate**: > 45%
- **Количество сделок**: > 50 за 3 месяца

## ⚡ Дополнительные рекомендации

### Фильтры новостей
- Отключать торговлю за 30 минут до важных новостей EUR/USD
- Особенно: решения ECB, NFP, GDP, CPI

### Размер позиции
- При автоматическом расчете: риск 1-1.5%
- При фиксированном лоте: начинать с 0.01-0.1 лота
- Увеличивать размер постепенно

### Мониторинг
- Проверять производительность еженедельно
- Корректировать параметры при изменении рыночных условий
- Ведите торговый журнал

## 🚨 Важные предупреждения

1. **Не используйте на демо-счете более 1 месяца** - переходите на центовый счет
2. **Начинайте с минимальных лотов** даже после успешного тестирования
3. **Учитывайте комиссии брокера** при расчете прибыльности
4. **Регулярно обновляйте параметры** в зависимости от рыночных условий

## 📞 Поддержка и оптимизация

При необходимости дополнительной оптимизации под конкретного брокера или изменения рыночных условий, параметры можно корректировать:

- **Для более агрессивной торговли**: увеличить MaxPositions до 3-4
- **Для консервативной торговли**: уменьшить RiskPercent до 1%
- **При высоких спредах**: увеличить MinStopDistanceMultiplier до 2.0 