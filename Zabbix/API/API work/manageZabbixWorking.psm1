#!/bin/pwsh

#Version 1.0.0.5

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
#Modify and crete maintenance use CSV file
function Set-PgMaintenanceZabbixAPI{
    <#
    .SYNOPSIS
        v_1.0.0.9
        #Performing maintenance mode from a CSV dataset. CSV file structure:
        Наименование ПГ;Наименование пункта ПГ;Кому назначено;Время начала работ;Время окончания работ;Ссылка на ПГ;Принадлежность;Тип элемента;Путь
        Обновление ПО. Серверов;Постановка в режим обслуживания серверов в системе мониторинга на период проведения работ: 31.10.2025 с 18:00 по 23:00;"Администраторы;#352";30.10.2025 9:00;30.10.2025 16:00;/Shared Documents/Плановые работы/2025/Сервера;ЦОД;Элемент;Lists/List5
        #
        #It is possible to add additional column names for data in the CSV file: host;hostgroup
    .PARAMETER apiUrl
        URL connect to API Zabbix. Example: -apiUrl "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" OR "https://IP_or_FQDN_Zabbix:PORT/zabbix/api_jsonrpc.php"
    .PARAMETER apiTokenResult
        API token for connect to Zabbix API. Example: -apiTokenResult 'jhhsgdFHSFDtyf35fffD5'
    .PARAMETER apiTokenId
        API token id for connect to Zabbix API. Example: -apiTokenId 132
    .PARAMETER pathCsvFile
        The path for the CSV file.
    .PARAMETER startWorkAdm
        Start date of the work for the administrator. Example: -startWorkAdm '30.11.2025'
    .PARAMETER outExecution
        Output of data on completed work. Example: -outExecution FormatList
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    #>

    param(
        [Parameter(Mandatory=$true,position=1)][Alias('UrlApi')][string]$apiUrl,
        [Parameter(Mandatory=$true,position=2)][Alias('TokenApi')][string]$apiTokenResult,
        [Parameter(Mandatory=$true,position=3)][Alias('TokenId')][int]$apiTokenId,
        [Parameter(Mandatory=$true,position=4)][string]$pathCsvFile,
        [Parameter(Mandatory=$true,position=5)][ValidatePattern("\d{1,2}\.\d{1,2}\.\d{4}")]$startWorkAdm,
        [Parameter(Mandatory=$false,position=6)][ValidateSet("FormatList", "OutGridView")]$outExecution = 'FormatList',
        [Parameter(Mandatory=$false,position=7)][ValidateSet($true, $false)]$WhatIf = $true
    )

    #Importing a file from a web portal/
    $readPG = Import-Csv -Path $pathCsvFile -Delimiter ";" -Encoding Default | Where-Object { $_."Время начала работ" -match "$startWorkAdm .*"}

    ########################################################
    #Creating data for use in Zabbix/
    #Data format:
    #StartWork;NamePG;StartDate;StartTime;EndDate;EndTime;Period;HostId;HostGroupId
    $arrDateBuild = @()
    Write-host "## Forming objects based on data." -ForegroundColor Green
    foreach( $onePG in $readPG ){
        if( $onePG.'Наименование ПГ' -match "\w" -or $onePG.'Наименование пункта ПГ' -match "\w" ){

            ###Create variables.###
            $nameObjectPG = $onePG."Наименование пункта ПГ"
            $namePG = $onePG."Наименование ПГ"  #.Substring(0, [System.Math]::Min(128, $onePG."Наименование ПГ".Length))
            $startWork = $onePG."Время начала работ"
            #$endWork = $onePG."Время окончания работ"
            $regDataTime1 = "^\d{1,2}\.\d{1,2}\.\d{4} \d{1,2}\:\d{2} \d{1,2}\:\d{2}"
            $regDataTime2 = "^\d{1,2}\.\d{1,2}\.\d{4} \d{1,2}\:\d{2} \d{1,2}\.\d{1,2}\.\d{4} \d{1,2}\:\d{2}"

            ###Date find.###
            $arrDate = @()
            foreach ( $oneDate in $nameObjectPG -split "\s" -split '<br>' -split '-' ){
                #If 21.10.2024
                if($oneDate -match "^\d{1,2}\.\d{1,2}\.\d{4}"){
                    $arrDate += $oneDate
                    }
                #Else fi 09:00 or 9:00
                elseif($oneDate -match "\d{1,2}\:\d{2}"){
                    $arrDate += ($oneDate -split '' | ForEach-Object { If($_ -match "\d|\:"){$_} }) -join ''
                    }
                }
            #If there is no data in array 1 or no data for time '9:00 or 09:00', we request data from the user.
            if( -Not $arrDate -Or -Not (ForEach-Object { $arrDate -match "\d{1,2}\:\d{2}"}) -Or -Not (ForEach-Object { $arrDate -match "^\d{1,2}\.\d{1,2}\.\d{4}"}) ){
                #Requesting user actions to receive the date and time of work.
                do{
                    Write-host '## I can it determine the format "dd.MM.yyyy HH:mm HH:mm" or "dd.MM.yyyy HH:mm dd.MM.yyyy HH:mm" or skip enter: skip/s ##Set the START or END time of the work:' -BackgroundColor DarkRed
                    $selectDataTime = Read-Host -Prompt "## $namePG ##Start work: $startWork"
                }until( $selectDataTime -eq 'skip' -or $selectDataTime -eq 's' -or $selectDataTime -match $regDataTime1 -or $selectDataTime -match $regDataTime2 )
                
                if($selectDataTime -match $regDataTime1 -or $selectDataTime -match $regDataTime2){ foreach( $oneSelectDataTime in $selectDataTime -split '\s' ){ $arrDate += $oneSelectDataTime } }
                if($selectDataTime -eq 'skip' -or $selectDataTime -eq 's') { $arrDate += '' }
            }
            
            ###Create object.###
            $obj = New-Object System.Object
            $obj | Add-Member -Type NoteProperty -Name StartWork -Value $startWork
            $obj | Add-Member -Type NoteProperty -Name NamePG -Value $namePG
            $obj | Add-Member -Type NoteProperty -Name StartDate -Value ($arrDate -match "\d{1,2}\.\d{1,2}\.\d{4}")[0]
            $obj | Add-Member -Type NoteProperty -Name StartTime -Value ($arrDate -match "\d{1,2}\:\d{2}")[0]

            #End Data
            if( ($arrDate -match "\d{2}\.\d{2}\.\d{4}")[1] ){
                $obj | Add-Member -Type NoteProperty -Name EndDate -Value ($arrDate -match "\d{2}\.\d{2}\.\d{4}")[1]
                }
            else{
                $obj | Add-Member -Type NoteProperty -Name EndDate -Value ($arrDate -match "\d{1,2}\.\d{1,2}\.\d{4}")[0]
                }

            #End Time
            $obj | Add-Member -Type NoteProperty -Name EndTime -Value ($arrDate -match "\d{1,2}\:\d{2}")[1]

            #Period
            if($obj.StartDate -and $obj.StartTime){
                $start = Get-Date ( $obj.StartDate +" "+ $obj.StartTime )
                #Convert time 24:00 to 23:59
                if($obj.EndTime -like '24:00' -and (New-TimeSpan -Start $obj.EndDate -End $obj.StartDate).Days -eq '0'){
                    $endTimeConvert = '23:59'
                }
                elseif($obj.EndTime -like '24:00' -and (New-TimeSpan -Start $obj.EndDate -End $obj.StartDate).Days -le '-1'){
                    $endTimeConvert = '23:59'
                }
                elseif($obj.EndTime -like '00:00' -and (New-TimeSpan -Start $obj.EndDate -End $obj.StartDate).Days -eq '0'){
                    $endTimeConvert = '23:59'
                }
                else{ $endTimeConvert = $obj.EndTime}

                $end   = Get-Date ( $obj.EndDate +" "+ $endTimeConvert )
                [string]$timeSpan = ([string](New-TimeSpan -Start $start -End $end).TotalMinutes +'m')
                $obj | Add-Member -Type NoteProperty -Name Period -Value $timeSpan
                }
            else{ $obj | Add-Member -Type NoteProperty -Name Period -Value ""}

            #Find Host ID
            if ($onePG.host){
                
                $findHostNm = ($onePG.host -replace '\n',',' -replace ',,',',' -replace '\s')
                $findHostId = Get-HostsZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -searchHostName $findHostNm
                $obj | Add-Member -Type NoteProperty -Name HostId -Value ($findHostId.hostid -join ",")
                
                #Compare the list of hosts from the list with the list of found hosts.
                $findHostCompare = (Compare-Object @($findHostNm -split ',') -DifferenceObject $findHostId.host -IncludeEqual | Where-Object { $_.SideIndicator -eq '<=' }).inputObject -join ','
                #We display hosts that could not be found or are not monitored.
                $obj | Add-Member -Type NoteProperty -Name HostNotFind -Value $findHostCompare

                }
            else{ 
                $obj | Add-Member -Type NoteProperty -Name HostId -Value ""
                $obj | Add-Member -Type NoteProperty -Name HostNotFind -Value ""
                }
            #Find HostGroup ID
            if ($onePG.hostgroup){
                $findHostGroupId = Get-HostGroupsZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -filterGroupName $onePG.hostgroup
                $obj | Add-Member -Type NoteProperty -Name HostGroupId -Value ($findHostGroupId.hostgroup -join ",")
                }
            else{ $obj | Add-Member -Type NoteProperty -Name HostGroupId -Value "" }

            $arrDateBuild += $obj
        }
    }
    #$arrDateBuild | FT

    #Accept 'y' formatted data for working with Zabbix or reject 'n' it by ending the script.
    do{
        $arrDateBuild | Format-Table
        Write-host ('## Number of objects in the list: '+ $arrDateBuild.Count) -ForegroundColor Green
        Write-host ('## The data for working with Zabbix is generated and only the filled values are used StartDate & Period. Number of objects: '+  $($arrDateBuild.startdate -match '\w').count ) -ForegroundColor Green
        Write-host ('## URL connected '+ $apiUrl) -ForegroundColor Green
        $pgCompleteForZabbix = Read-Host -Prompt "## Start execution Maintenance. Enter to continue y/n"
    }until($pgCompleteForZabbix -eq 'y' -or $pgCompleteForZabbix -eq 'n')
    
    if($pgCompleteForZabbix -eq 'n'){
        break
    }

    #We use automatic mode 'y/n'.
    do{
        $applayAuto = Read-Host -Prompt "## Continue in automatic mode.  Enter to continue y/n"
    }until($applayAuto -eq 'y' -or $applayAuto -eq 'n')

    #####################################################################################################
    #####################################################################################################

    #Задать вопрос для добавления объектов если отсутствуют хосты или группы из файла.
    function get-askQuestion {
        param($object, $questionString, $color)
        
        if($color){
            [string]$colorF = $color
        }else{
            [string]$colorF = 'Red'
        }

        Write-Host "$questionString" -ForegroundColor $colorF
        if($object){ 
            $searchObject = $object 
            return $searchObject
        }
        else{
            do{$continue = Read-Host -Prompt "Enter y/n"}
            until($continue -eq 'y' -or $continue -eq 'n')

            if($continue -eq 'n'){ break }

            if($continue -eq 'y'){ 
                do{$searchObject = Read-Host -Prompt "Enter string"}
                until($searchObject -match "\w") 
            }
            return $searchObject
        }
    }

    #Ask questions to find hostsId.    
    function get-askQuestionSearchHosts{
        param($object, $namePG, $color)
        do{
            #Enterring a list of hosts.
            $srchHostNameQ = get-askQuestion -object $object -questionString $('##1 Add a list of HOSTs separated "," for.....: '+ $namePG) -color $color
            #Search hostsID.
            if($srchHostNameQ){
                $searchH1 = ( Get-HostsZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -searchHostName $srchHostNameQ -searchByAny $True ).hostid -join ','
                Write-host ("##2 Detected HostsID: "+ $searchH1) -ForegroundColor $color

                do{ $applayHostId = Read-Host -Prompt "##3 Apply parameters HostsId. Enter y/n" }
                until( $applayHostId -eq "y" -or $applayHostId -eq "n" )

                if($applayHostId -eq "y"){ return $searchH1 }
            }
        }until($applayHostId -match 'y')
    }  

    #Ask questions to find hostGroupId.    
    function get-askQuestionSearcGroups{
        param($object, $namePG, $color)
        do{
            #Enterring a list of hosts.
            $srchHostGNameQ = get-askQuestion -object $object -questionString $('##1 Add a list of HOSTGROUPS separated "," for: '+ $namePG) -color $color
            #Search hostsID.
            if($srchHostGNameQ){
                $searchG1 = (Get-HostGroupsZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -filterGroupName $srchHostGNameQ).groupid -join ','
                Write-host ("##2 Detected HostGroupsID: "+ $searchG1) -ForegroundColor $color

                do{ $applayHostGId = Read-Host -Prompt "##3 Apply parameters HostGroupsID. Enter y/n" }
                until( $applayHostGId -eq "y" -or $applayHostGId -eq "n" )

                if($applayHostGId -eq "y"){ return $searchG1 }
            }
        }until($applayHostGId -match 'y')
    }

    #Calculation of start and service duration in UNIX time format.
    function manualPeriods{ 
        #Time calculation set by the user in the format dd.MM.yyyy hh:mm 
        param ( $timeperiod_type, $Start_date, $Period )
        #Start maintenance date.
        $fDate = (Get-Date $start_date).addHours(-3) ; 
        $fDateJ = Get-Date $fDate -UFormat %s
        
        #Period time.
        $periods = $Period -split ';'
        $arrPeriod = @()
        foreach ($onePeriod in $periods){
            #Period time.
            if     ( $onePeriod -like "*d" ){ $fPeriod = [int]($onePeriod -replace "d") * 86400 }
            elseif ( $onePeriod -like "*h" ){ $fPeriod = [int]($onePeriod -replace "h") * 3600  }
            elseif ( $onePeriod -like "*m" ){ $fPeriod = [int]($onePeriod -replace "m") * 60    }
            else   { $fPeriod = 3600 }
            $arrPeriod += $fPeriod
        }
        $fPeriodR = ($arrPeriod | Measure-Object -Sum).sum
            
        $periodObj = @{        
            #One time only = 0, Daily = 2, Weekly = 3, Monthly = 4.
            "timeperiod_type" = $timeperiod_type
            "period" = $fPeriodR
            "start_date" = $fDateJ
        }
        return $periodObj
    }

    $arrDateBuilds = $arrDateBuild | Where-Object { $_.StartDate -match '\w' -and $_.Period -match '\w' }
    #ОБНОВЛЯЕМ создаем НОВЫЙ режим обслуживания.
    $arrDateResult = @()
    foreach( $oneGetMaint in $arrDateBuilds ){

        ###Поиск режима облуживания по имени и описанию.###
        $searchNameDesc = $oneGetMaint.NamePG -replace '"','*'
        $SearchName = Get-MaintenanceZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -SearchMaintenance $searchNameDesc -SelectHosts -SelectGroups -SelectTimeperiods -searchWildcardsEnabled True
        $SearchDescription = Get-MaintenanceZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -SearchDescription ( $searchNameDesc +'*' ) -SelectHosts -SelectGroups -SelectTimeperiods -searchWildcardsEnabled True

        ###Create object.###
        $objR = New-Object System.Object
        $objR | Add-Member -Type NoteProperty -Name StartWork -Value $oneGetMaint.startWork
        $objR | Add-Member -Type NoteProperty -Name NamePG -Value $oneGetMaint.NamePG
        $objR | Add-Member -Type NoteProperty -Name StartDate -Value $oneGetMaint.StartDate
        $objR | Add-Member -Type NoteProperty -Name StartTime -Value $oneGetMaint.StartTime
        $objR | Add-Member -Type NoteProperty -Name EndDate -Value $oneGetMaint.EndDate
        $objR | Add-Member -Type NoteProperty -Name EndTime -Value $oneGetMaint.EndTime
        $objR | Add-Member -Type NoteProperty -Name Period -Value $oneGetMaint.Period
        $objR | Add-Member -Type NoteProperty -Name HostNotFind -Value $oneGetMaint.HostNotFind

        #####################################################################################################
        ### Если Maintenance обнаружен, обновляем его.
        ### Output array: StartWork, NamePG, StartDate, StartTime, EndDate, EndTime, Period, HostNotFind, MaintenancePP, MaintenanceEmail, MaintenanceSCOM, HostId, MaintenanceMode
        if($SearchName -or $SearchDescription){
            #Выводим ID режима обслуживания с $SearchName и $SearchDescription
            $maintenanceid = ($SearchName.maintenanceid,$SearchDescription.maintenanceid) | Select-Object -Unique
            #Выводим Название режима обслуживания
            $maintenanceName = ($SearchName.name,$SearchDescription.name) | Select-Object -Unique

            #Выводим Timeperiods полученные с Zabbix.
            $jsonTimeperiodFind = (($SearchName.timeperiods | Select-Object timeperiod_type,period,start_date | ConvertTo-Json),($SearchDescription.timeperiods | Select-Object timeperiod_type,period,start_date | ConvertTo-Json) | Select-Object -Unique) -replace '\s'
            #Если массив json, контролируем нужное количество скобок.
            $jsonTimeperiods = ('['+ $jsonTimeperiodFind +']') -replace '\[\[','[' -replace '\]\]',']'
            #Исключаем возможность повторного добавления даты и периода обслуживания.
            $compare1 = manualPeriods -timeperiod_type '0' -Start_date ($oneGetMaint.StartDate +' '+ $oneGetMaint.StartTime) -Period $oneGetMaint.Period | ConvertTo-Json | ConvertFrom-Json
            $compare2 = $jsonTimeperiods | ConvertFrom-Json
            $compareDatePeriod = Compare-Object $compare1 $compare2 -Property period,start_date -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' }

            #Выводим Описания режима обслуживания.
            $maintenanceDesc = ($SearchName.description,$SearchDescription.description) | Select-Object -Unique
            #Поиск номера пункта ПГ #Find g/g
            $findTextNum = ($maintenanceDesc -split '\n' | Select-String -Pattern '(g\/g*|g\/g\s\s\d|п\/п*|п\/п\s\s\d)' -Context 0,0) -replace 'g.g','' -replace 'п.п','' -replace '\s','' | Select-Object -Unique
            #Поиск email ответственных по ПГ #Find email
            $findTextEml = ($maintenanceDesc -split '\n' | Select-String -Pattern '@.*\.ru' -Context 0,0) -join ';'
            #Поиск присутствия ПГ в SCOM #Find SCOM
            $findTextScm = ($maintenanceDesc -split '\n' | Select-String -Pattern 'SCOM' -Context 0,0) | Select-Object -Unique

            #Add object
            $objR | Add-Member -Type NoteProperty -Name MaintenancePP -Value $findTextNum
            $objR | Add-Member -Type NoteProperty -Name MaintenanceEmail -Value $findTextEml
            $objR | Add-Member -Type NoteProperty -Name MaintenanceSCOM -Value ($findTextScm.Line -replace '\s')

            #Если обнаружилось повторное добавление даты и периода обслуживания
            if ($compareDatePeriod.SideIndicator -eq '=='){
                Write-host "### UPDATE. Action rejected exists Maintenance: $maintenanceName - $($oneGetMaint.StartDate +' '+ $oneGetMaint.StartTime)" -ForegroundColor Red
                $MaintenanceMode = 'noUpdate'
            }else{
                #If We use automatic mode 'N'
                if($applayAuto -eq 'n') {
                    #Write-host '### UPDATE. Maintenance mode found.' -ForegroundColor Yellow
                    #Request user action to update.
                    do{
                        $selectUpd = Read-Host -Prompt "### UPDATE. Execute Maintenance...............: $maintenanceName y/n"
                    }until($selectUpd -eq 'y' -or $selectUpd -eq 'n')
                }else{
                    #If We use automatic mode 'Y'
                    Write-host "### UPDATE. Execute Maintenance...............: $maintenanceName" -ForegroundColor Yellow
                }

                #If We use update 'Y' or If We use automatic mode 'Y'
                if($selectUpd -eq 'y' -or $applayAuto -eq 'y'){
                    #Add hostId
                    if($oneGetMaint.HostId){
                        $setHostId = $oneGetMaint.HostId
                    }else{
                        #If We use automatic mode 'N'
                        if($applayAuto -eq 'n'){
                            #We provide a list of hosts and get a list hostId.
                            $colorU = 'Green'
                            $setHostId = get-askQuestionSearchHosts -namePG $maintenanceName -color $colorU
                        }
                    }

                    $objR | Add-Member -Type NoteProperty -Name HostId -Value $setHostId

                    #Write-host $MaintenanceMode -ForegroundColor Yellow
                    #Whatif
                    if($WhatIf -eq $true){
                        $MaintenanceMode = 'updateIf'
                    }else{     
                        #Updating maintenance mode.
                        $SetMaintenanceZabbixAPI = Set-MaintenanceZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -MaintenanceId $maintenanceid -Start_date ($oneGetMaint.StartDate +' '+ $oneGetMaint.StartTime) -Period $oneGetMaint.Period -HostIds $setHostId -PeriodJSON $jsonTimeperiods
                        $MaintenanceMode = ('update id:'+ $SetMaintenanceZabbixAPI.maintenanceids)
                    }
                }

                if($selectUpd -eq 'n'){
                    #Write-host $MaintenanceMode -BackgroundColor Red
                    #Whatif
                    if($WhatIf -eq $true){
                        $MaintenanceMode = 'noUpdateIf'
                    }else{
                        $MaintenanceMode = 'noUpdate'
                    }
                }  
            }


        }
        #####################################################################################################
        ### Если Maintenance НЕ обнаружен, создаем его.
        ### Output array: StartWork, NamePG, StartDate, StartTime, EndDate, EndTime, Period, HostNotFind, MaintenancePP, MaintenanceEmail, MaintenanceSCOM, HostId, MaintenanceMode
        else{
            #Название Режима обслуживания, обрезаем до 129 символов. #129 символов в имени maintenance.
            $namePG = [string]$oneGetMaint.NamePG.Substring(0, [System.Math]::Min(129, $oneGetMaint.NamePG.Length) )

            #Запрос действий пользователя на создание.  
            do{
                #Write-host '### CREATE. Not Maintenance mode found.' -ForegroundColor Red
                $selectCreate = Read-Host -Prompt "### CREATE. Execute Maintenance...............: $namePG y/n"
            }until($selectCreate -eq 'y' -or $selectCreate -eq 'n')

            #Создаем.
            if($selectCreate -eq 'y'){
                #Write-host $MaintenanceMode -ForegroundColor Red
                $colorC = 'Red'
                #Add hostId.
                if($oneGetMaint.HostId){
                    $setHostId = $oneGetMaint.HostId
                }else{
                    #Подаём список хостов и получаем спиcок hostId.
                    $setHostId = get-askQuestionSearchHosts -namePG $namePG -color $colorC
                }

                #Add hostGroupId.
                if($oneGetMaint.HostGroupId){
                    $setHostGId = $oneGetMaint.HostGroupId
                }else{
                    #Подаём список групп и получаем спиcок hostgroupId.
                    $setHostGId = get-askQuestionSearcGroups -namePG $namePG -color $colorC
                }

                #Получаем описание Maintenance
                $addDescName = $oneGetMaint.NamePG
                do{
                    $addDesc = get-askQuestion -questionString '##1 Add Maintenance description:'
                    $addDesc1 = ($addDesc -replace "\n",";") -split ";" | Where-Object { $_.trim() -ne "" }
                    Write-host '##2 Add Maintenance description result:' -ForegroundColor Red
                    $createDescription = ($addDescName,' ',$addDesc1) | Out-String
                    $createDescription
                    $applayDesc = Read-Host -Prompt "##3 Apply the added Maintenance description. Enter 'y'"
                }until( $applayDesc -eq "y" )

                #Add object array $arrDateResult
                if ($createDescription){
                    $objMaintenancePP = (($createDescription | Out-String) -split '\n' | Select-String -Pattern '(g\/g*|g\/g\s\s\d|п\/п*|п\/п\s\s\d)' -Context 0,0) -replace 'g.g','' -replace 'п.п','' -replace '\s','' | Select-Object -Unique
                    $objMaintenanceEmail = (($createDescription | Out-String) -split '\n' | Select-String -Pattern '@.*\.ru' -Context 0,0) -join ';'
                }else{
                    if(!$objMaintenancePP){$objMaintenancePP = $null}
                    if(!$objMaintenanceEmail){$objMaintenanceEmail = $null}
                }

                $objR | Add-Member -Type NoteProperty -Name MaintenancePP -Value $objMaintenancePP
                $objR | Add-Member -Type NoteProperty -Name MaintenanceEmail -Value $objMaintenanceEmail
                $objR | Add-Member -Type NoteProperty -Name MaintenanceSCOM -Value $null
                $objR | Add-Member -Type NoteProperty -Name HostId -Value $setHostId

                ###What if.###
                if($WhatIf -eq $true){
                    $MaintenanceMode = 'createIf'
                }else{
                    #Создаем новый Режим обслуживания.
                    $NewMaintenanceZabbixAPI = New-MaintenanceZabbixAPI -UrlApi $apiUrl -TokenApi $apiTokenResult -TokenId $apiTokenId -NameMaintenance $namePG -Description $createDescription -ActiveSince (Get-date -Format "dd.MM.yyyy") `
                    -ActiveTill (Get-date -Format "30.12.yyyy") -MaintenanceType WithData -Start_date ($oneGetMaint.StartDate +' '+ $oneGetMaint.StartTime) -Period $oneGetMaint.Period -Timeperiod_type 0 -HostIds $setHostId -GroupIds $setHostGId

                    $MaintenanceMode = ('create id:'+ $NewMaintenanceZabbixAPI.maintenanceids)
                }
                
            }
            #Не создаем.
            elseif($selectCreate -eq 'n'){
                $MaintenanceMode = 'noCreate'
                #Write-host $MaintenanceMode -BackgroundColor Red
            }              
        }
        
        $objR | Add-Member -Type NoteProperty -Name MaintenanceMode -Value $MaintenanceMode   
        $arrDateResult += $objR
    }

    ########################################################
    if($outExecution -eq 'FormatList'){
        $arrDateResult | Format-List
    }
    if($outExecution -eq 'OutGridView'){
        $arrDateResult | Out-GridView
    }
}
##################################################################################
Export-ModuleMember -Function Get-HostUsedMonitoring, `
Export-TemplateHostZabbix, `
Set-PgMaintenanceZabbixAPI
