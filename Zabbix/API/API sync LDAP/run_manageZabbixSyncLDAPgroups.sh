#!/bin/bash

apiUser=$1
apiUserPass=$2
apiUrl=$3
apiToken=$4
jsonQuery=$5
ldapsearchUser=$6
ldapsearchPass=$7
ldapsearchServer=$8
ldapsearchBase=$9
zabbixNewUserPass=${10}
zabbixUserRolesId=${11}
userGroupsDisable=${12}
guiAccess=${13}
logsOn='True'

VAR=`/usr/lib/zabbix/alertscripts/./manageZabbixSyncLDAPgroups.ps1 $apiUser $apiUserPass $apiUrl $apiToken $jsonQuery $ldapsearchUser $ldapsearchPass $ldapsearchServer $ldapsearchBase $zabbixNewUserPass $zabbixUserRolesId $userGroupsDisable $guiAccess $logsOn > /dev/null 2>&1 &`
