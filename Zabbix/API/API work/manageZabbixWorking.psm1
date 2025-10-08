#!/bin/pwsh

#Version 1.0.0.4

##################################################################################
#Used Monitoring.
function Get-HostUsedMonitoring{
    <#
    .SYNOPSIS
        ...
    .PARAMETER apiUrl
        URL подключения к API Zabbix. Example: -apiUrl "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" OR "https://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php"
    .PARAMETER apiTokenResult
        API token для подключения к Zabbix API. Example: -apiTokenResult 'jhhsgdFHSFDtyf35fffD5'
    .PARAMETER apiTokenId
        API token id для подключения к Zabbix API. Example: -apiTokenId 132
    .PARAMETER searchHostName
        Поиск объектов. Example -searchHostName "findHost1,findHost2,etc"
    #>
        param(
        [Parameter(Mandatory=$true,position=1)][Alias('UrlApi')][string]$apiUrl,
        [Parameter(Mandatory=$true,position=2)][Alias('TokenApi')][string]$apiTokenResult,
        [Parameter(Mandatory=$true,position=3)][Alias('TokenId')][int]$apiTokenId,
        [Parameter(Mandatory=$true,position=4)][string]$searchHostName
    )

    #Zabbix Search host (case-insensitive)
    $searchHostf = Get-HostsZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -searchHostName $searchHostName
    $searchHostArr = @()
    foreach ( $searchHostOne in $searchHostf ){
        $searchInterface = Get-HostInterfaceZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Hostid $searchHostOne.hostid
        
        switch($searchHostOne.status){
            0 { $status = 'monitored'}
            1 { $status = 'unmonitored'}
        }

        switch($searchInterface.available){
            0{$available = '0-default'}
            1{$available = '1-available'}
            2{$available = '2-unavailable'}
        }

        $objHosts = New-Object System.Object
        $objHosts | Add-Member -Type NoteProperty -Name hostid -Value $searchHostOne.hostid
        $objHosts | Add-Member -Type NoteProperty -Name proxy_hostid -Value $searchHostOne.proxy_hostid
        $objHosts | Add-Member -Type NoteProperty -Name host -Value $searchHostOne.host
        $objHosts | Add-Member -Type NoteProperty -Name status -Value $status
        $objHosts | Add-Member -Type NoteProperty -Name maintenanceid -Value $searchHostOne.maintenanceid
        $objHosts | Add-Member -Type NoteProperty -Name ip -Value $searchInterface.ip
        $objHosts | Add-Member -Type NoteProperty -Name available -Value $available
        $objHosts | Add-Member -Type NoteProperty -Name error -Value $searchInterface.error
        $searchHostArr += $objHosts
    }
    Write-Host "--Object beging monitored in Zabbix. Total: $($searchHostArr.Count) " -ForegroundColor Green
    $searchHostArr | Sort-Object host | Format-Table

    #Сравниваем объекты из массива список хостов для поиска "$arrрHosts" и найденых объектов на мониторинге в Zabbix "$searchHost"
    #Вывод хостов не обнаруженных стоящими на мониоринге в Zabbix согласно списку хостов для поиска.
    Write-Host "--Object NOT beging monitored in Zabbix." -ForegroundColor Red
    if($searchHostf){
        $compareHostf = (Compare-Object -ReferenceObject $($searchHostName -split ",") -DifferenceObject $searchHostf.host | Where-Object {$_.SideIndicator -eq "<="}).InputObject
        $compareHostf
    } else {
        $compareHostf = ($arrHostsf -split ",")
        $compareHostf
        }
}
##################################################################################
#Export Template\Host item and trigger configuration.
function Export-TemplateHostZabbix {
    param(
        [Parameter(Mandatory=$true,position=1)][Alias('UrlApi')][string]$apiUrl,
        [Parameter(Mandatory=$true,position=2)][Alias('TokenApi')][string]$apiTokenResult,
        [Parameter(Mandatory=$true,position=3)][Alias('TokenId')][int]$apiTokenId,
        [Parameter(Mandatory=$true,position=4)][int]$ID,
        [Parameter(Mandatory=$true,position=5)][ValidateSet('Template','Host')]$Object,
        [Parameter(Mandatory=$true,position=6)][string]$exportCsvPatch
    )
    #Item Template
    if($Object -eq 'Template'){
        $item     = Get-ItemZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Item Static -Templateids $ID -Hosts 0
        $itemProt = Get-ItemZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Item Prototype -Templateids $ID -Hosts 0

    }
    #Item Host
    if($Object -eq 'Host'){
        $item     = Get-ItemZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Item Static -Hosts $ID
        $itemProt = Get-ItemZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Item Prototype -Hosts $ID
    }
    #Trigger Template\Host
    $trigger = Get-TriggerZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Trigger Static -Templateids $ID -ExpandComment -ExpandDescription -ExpandItems -ExpandExpression | `
    Select-Object triggerid, @{n="itemid";e={$_.Items.itemid}}, expression, recovery_expression, description, priority, status, comments
    $triggerProt = Get-TriggerZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -Trigger Prototype -Templateids $ID -ExpandComment -ExpandDescription -ExpandItems -ExpandExpression | `
    Select-Object triggerid, @{n="itemid";e={$_.Items.itemid}}, expression, recovery_expression, description, priority, status, comments

    #Item join
    $itemStat = @()
    $itemStat += $item
    $itemStat += $itemProt
    #Trigger join
    $triggerStat = @()
    $triggerStat += $trigger
    $triggerStat += $triggerProt

    #Build Item
    $arrItem = @()
    foreach ( $itemOne in $triggerStat ){

        #priority Not classified Information Warning Average High Disaster
        switch($itemOne.priority){
            0 { $priority = 'Not classified'}
            1 { $priority = 'Information'}
            2 { $priority = 'Warning'}
            3 { $priority = 'Average'}
            4 { $priority = 'High'}
            5 { $priority = 'Disaster'}
        }

        #status Enable Disable
        switch($itemOne.status){
            0 { $statusT = 'Enable'}
            1 { $statusT = 'Disabled'}
        }

        $objItem = New-Object System.Object
        $objItem | Add-Member -Type NoteProperty -Name triggerid -Value $itemOne.triggerid
        $objItem | Add-Member -Type NoteProperty -Name expression -Value $itemOne.expression
        $objItem | Add-Member -Type NoteProperty -Name recovery_expression -Value $itemOne.'recovery_expression'
        $objItem | Add-Member -Type NoteProperty -Name description -Value $itemOne.description
        $objItem | Add-Member -Type NoteProperty -Name priority -Value $priority
        $objItem | Add-Member -Type NoteProperty -Name status -Value $statusT
        $objItem | Add-Member -Type NoteProperty -Name comments -Value $itemOne.comments
 
        $findItem = $itemStat | Where-Object { $_.itemid -eq $itemOne.itemid }
        $objItem | Add-Member -Type NoteProperty -Name itemid -Value $findItem.itemid
        $objItem | Add-Member -Type NoteProperty -Name type -Value $findItem.type
        $objItem | Add-Member -Type NoteProperty -Name name -Value $findItem.name
        $objItem | Add-Member -Type NoteProperty -Name key_ -Value $findItem.'key_'
        $objItem | Add-Member -Type NoteProperty -Name delay -Value $findItem.delay
        $objItem | Add-Member -Type NoteProperty -Name istatus -Value $findItem.status
        $objItem | Add-Member -Type NoteProperty -Name idescription -Value $findItem.description
        $objItem | Add-Member -Type NoteProperty -Name master_itemid -Value $findItem.'master_itemid'

        $arrItem += $objItem
    }
    $arrItemStat = $itemStat | Where-Object { $_.itemid -notin $arrItem.itemid } | Select-Object `
    @{n="triggerid";e={$null}}, `
    @{n="expression";e={$null}}, `
    @{n="recovery_expression";e={$null}}, `
    @{n="description";e={$null}}, `
    @{n="priority";e={$null}}, `
    @{n="status";e={$null}}, `
    @{n="comments";e={$null}}, `
    itemid, type, name, key_, delay, @{n="istatus";e={$_.status}}, @{n="idescription";e={$_.description}}, master_itemid

    $itemStatJoin = $arrItem + $arrItemStat
    $itemStatJoinCSV = $itemStatJoin | Select-Object itemid, type, name, key_, delay, istatus, idescription, master_itemid, triggerid, description, priority, status, expression, recovery_expression, comments 
    $itemStatJoinCSV | Export-Csv -Path $exportCsvPatch -Encoding UTF8 -Delimiter ';'
}

##################################################################################
Export-ModuleMember -Function Get-HostUsedMonitoring, `
Export-TemplateHostZabbix
