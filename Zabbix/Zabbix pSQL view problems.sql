--Viewing problems created in Zabbix via SQL query.
WITH 
tabEvents( eventidEV, objectidEV, dateEV, valueEV, acknowledgedEV, nsEV, nameEV, severityEV ) AS (
	Select eventid as eventidEV, objectid as objectidEV, to_timestamp(clock) at time zone 'MSK' as dateEV, value as valueEV, 
	acknowledged as acknowledgedEV, ns as nsEV, name as nameEV, severity as severityEV	
		from (
		SELECT eventid, objectid, clock, value, acknowledged, ns, name, severity,
		ROW_NUMBER() OVER (Partition BY objectid Order By clock desc ) RN
			FROM events) LastEvents
			Where RN=1
			AND acknowledged = 0
			AND value = 1
			order by clock desc
),
tabTriggers( hostTG, triggeridTG, valueTG ) AS (
Select DISTINCT h.host as hostTG, f.triggerid as triggeridTG, t.value as valueTG
	FROM triggers t
	INNER JOIN functions f ON f.triggerid = t.triggerid
	INNER JOIN items i ON i.itemid = f.itemid
	INNER JOIN hosts h ON i.hostid = h.hostid
		where h.host in( Select host From hosts Where status = 0)
		and t.value = 1
)
Select tTGS.hostTG as "Host",
Case
	When tEVS.severityEV = 0 Then 'NotClassified'
	When tEVS.severityEV = 1 Then 'Information'
	When tEVS.severityEV = 2 Then 'Warning'
	When tEVS.severityEV = 3 Then 'Average'
	When tEVS.severityEV = 4 Then 'High'
	When tEVS.severityEV = 5 Then 'Disaster'
End As "Severity",
tEVS.nameEV as "Problem",
date_trunc('minute', age(current_timestamp, tEVS.dateEV)) as "Age",
tEVS.dateEV as "Time"
	From tabEvents tEVS
	Left Join tabTriggers tTGS on tEVS.objectidEV = tTGS.triggeridTG
	Where tTGS.hostTG IS NOT NULL