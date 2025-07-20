SELECT name as "Name",
(
	(
	EXTRACT(hour FROM date_trunc('second', age(to_timestamp(active_till) at time zone 'MSK', now() at time zone 'MSK')))*60 +
	EXTRACT(minutes FROM date_trunc('second', age(to_timestamp(active_till) at time zone 'MSK', now() at time zone 'MSK')))
	) /
	(
	EXTRACT(hour FROM age(to_timestamp(active_till) at time zone 'MSK', to_timestamp(active_since) at time zone 'MSK'))*60 +
	EXTRACT(minutes FROM age(to_timestamp(active_till) at time zone 'MSK', to_timestamp(active_since) at time zone 'MSK'))
	)
)*100 as "Remained %",
date_trunc('second', age(to_timestamp(active_till) at time zone 'MSK', now() at time zone 'MSK')) as "Remained",
age(to_timestamp(active_till) at time zone 'MSK', to_timestamp(active_since) at time zone 'MSK') as "Age",
to_timestamp(active_since) at time zone 'MSK' as "Start", 
to_timestamp(active_till) at time zone 'MSK' as "End"
FROM maintenances
Where (now() at time zone 'MSK' > to_timestamp(active_since) at time zone 'MSK' 
	   AND now() at time zone 'MSK' < to_timestamp(active_till) at time zone 'MSK')