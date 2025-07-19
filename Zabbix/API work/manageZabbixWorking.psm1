#!/bin/pwsh

#Version 1.0.0.2
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
    Write-Host "--Object beging monitored in Zabbix." -ForegroundColor Green
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

#########################################
Export-ModuleMember -Function Get-HostUsedMonitoring
