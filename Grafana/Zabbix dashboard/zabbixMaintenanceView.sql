Select --M.maintenanceid,
CASE
WHEN
--Если результат значения более 100, представляем значение как 100%
(
    (
        EXTRACT(month FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*43200 +
        EXTRACT(day FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*1140 +      
        EXTRACT(hour FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*60 +
        EXTRACT(minutes FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))
    ) /
    (TP.period / 60)
)*100 > 100 THEN '100'
ELSE
--Если результат значения менее или равно 100, оставляем как есть.
(
    (
        EXTRACT(month FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*43200 +
        EXTRACT(day FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*1140 +      
        EXTRACT(hour FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))*60 +
        EXTRACT(minutes FROM date_trunc('second', age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK')))
    ) /
    (TP.period / 60)
)*100
END as "Remained %",
M.name, 
M.description,
TP.period,
to_timestamp(TP.start_date) at time zone 'MSK' as "start_date",
to_timestamp(TP.start_date + TP.period) at time zone 'MSK' as "end_date",
age(to_timestamp(TP.start_date + TP.period) at time zone 'MSK', now() at time zone 'MSK') as "Remained"
    From maintenances M
    left join maintenances_windows MW on M.maintenanceid = MW.maintenanceid
    left join timeperiods TP on MW.timeperiodid = TP.timeperiodid
    Where 
    --Выбираем если не более 2-х недель (указывается в секундах 1209600)
    TP.period < 5184000
    --Выбираем дату окончания задания + 600 секунд (для показа на дашборде)
    AND ( now() at time zone 'MSK' < to_timestamp(TP.start_date + TP.period + 600) at time zone 'MSK' )
    --Выбираем за какой период необходимо производить выборку начала запуска ПГ, расчитываем количество дней между стартом ПГ и текущем временем, результат дней < 14 дней
    AND date_part('day', (age(to_timestamp(TP.start_date), now() at time zone 'MSK' ))) < 14
    --Выбираем за какой период необходимо производить выборку начала запуска ПГ, расчитываем количество месяцев между стартом ПГ и текущем временем, результат месяцев < 1 месяц
    AND date_part('month', (age(to_timestamp(TP.start_date), now() at time zone 'MSK' ))) < 1
