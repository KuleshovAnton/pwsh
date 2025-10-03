--Viewing problems created in Zabbix via SQL query. Table events
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

--######################################################################################################
--Viewing problems created in Zabbix via SQL query. Table problems
SELECT distinct 
h.host as "Host",
CASE
    WHEN h.maintenance_status = 1 THEN 'data:image/png;base64,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'
    When h.maintenance_status = 0 THEN ''
END as "Mnt",
e.severity as "Severity",
--i.name as "iname", 
e.name as "Problem",
date_trunc('minute', age(current_timestamp, to_timestamp(e.clock))) as "Age", 
to_timestamp(e.clock) as "Time"
--last(e.objectid, to_timestamp(e.clock)) as lastobjectid
	FROM triggers t
	INNER JOIN functions f ON f.triggerid = t.triggerid
	INNER JOIN items i ON i.itemid = f.itemid
	--INNER JOIN hosts h ON i.hostid = h.hostid
	INNER JOIN (Select HS.*
            From hstgrp HSTGP
            Inner join hosts_groups HSTGPS on HSTGP.groupid = HSTGPS.groupid
            Inner join hosts HS on HSTGPS.hostid = HS.hostid
                Where HSTGP.name similar to '(Zabbix servers)%'
                AND HS.status = 0) h ON i.hostid = h.hostid
	INNER JOIN problem e ON e.objectid = t.triggerid
		Where e.r_clock = 0
		And e.acknowledged = 0
        And t.value = 1
		And i.status = 0
		And t.status = 0
        and (select count(*) from problem where objectid in (select triggerid_up from trigger_depends where triggerid_down=e.objectid) and r_clock = 0)=0 --отбросить зависимые триггеры
