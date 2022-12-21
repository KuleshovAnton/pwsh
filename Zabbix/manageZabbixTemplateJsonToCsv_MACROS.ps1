#!/bin/pwsh

#Version 1.0.0.1
#with MACROS
function manageZabbixTemplateJSONtoCSV {
    param (
        [Parameter(Mandatory=$true)][string]$InputFile,
        [Parameter(Mandatory=$true)][string]$OutputFile
    )

    [string]$fileJSON = (Get-Content -Path "$InputFile")

    $fromJSON = ConvertFrom-Json -InputObject $fileJSON
    $templateJSON = $fromJSON.zabbix_export.templates
    $templateJSONName = $templateJSON.name
    $templateJSONMacros = $templateJSON.macros

    #Замена значения макроса в строке. Replacing the macro value in a string
    function replacingMacroValueString {
        param (
            [Parameter(Mandatory=$false)][string]$stringInput
        )
        $strInput = $stringInput -replace "{$"," {$" -replace "}","} "
        $strWork = $strInput
        $strMacros = "{`$*.*}"
        #Находим Макросы используемые в тексте.
        $strSplit = @($strWork -replace "{\$"," {$" -split " ") | Where-Object { $_ -like $strMacros }
        #Подготовка строки для поиска, удаляем из Макроса { и } и $
        $resChangeMacro0 = $strWork -replace "{\$","" -replace "}","" -replace "{"," "
        
        #Создаем массив и добавлем первую строку для изменения
        $arrMacrosValue = @($resChangeMacro0)
        foreach ( $fMacrosValue in $strSplit ){
            #Подготовка макроса для поиска, удаляем из Макроса { и } и $
            $resChangeMacro1 = $fMacrosValue -replace "{","" -replace "}","" -replace "\$","" -replace ":.*",""
            $finChangeMacro1 = ("{$"+$resChangeMacro1+"}")
            #Поиск value макроса в массиве макросов JSON
            $resChangeMacro_2 = ($templateJSONMacros | Where-Object { $_.macro -like $finChangeMacro1 })
            $resChangeMacro2 = ( $resChangeMacro_2.macro +"="+ $resChangeMacro_2.value )
            #Выбираем последние значение из массива и изменяем строку
            $resChangeMacro3 = $arrMacrosValue[$arrMacrosValue.Count -1] -replace "$resChangeMacro1","$resChangeMacro2"
            #Добавляем в массив
            $arrMacrosValue += $resChangeMacro3 
        }
        $arrMacrosValue[$arrMacrosValue.Count -1]
    }

    ###Item
    $itemsJSON = $templateJSON.items
    $itemsWork = $itemsJSON | Select-Object @{n="Template";e={"Item"}}, `
        @{n="DiscoveryName";e="null"}, `
        @{n="ItemName";e={$_.name}}, `
        type, `
        delay, `
        @{n="Params";e={$_.params -replace "\n"}}, `
        units, `
        @{n="MasterItem";e={$_.master_item.key}}, `
        description, `
        @{n="TriggerName";e={replacingMacroValueString -stringInput $_.triggers.name}}, `
        @{n="TriggersExpression";e={replacingMacroValueString -stringInput $_.triggers.expression}}, `
        @{n="TriggersPriority";e={$_.triggers.priority}}, `
        @{n="TriggersDescription";e={$_.triggers.description}}

    ###Discovery
    $createArrDiscover = @(New-Object psobject -Property @{
        Template = "Discovery";
        DiscoveryName = "";
        ItemName = "";
        Type = "";
        Delay = "";
        Params = "";
        Uints = "";
        MasterItem = "";
        Description = "";
        TriggerName = "";
        TriggersExpression = "";
        TriggersPriority = "";
        TriggersDescription = ""
    })

    $discoveryJSON = $templateJSON.discovery_rules
    foreach ( $oneDiscoveryJSON in $discoveryJSON ) {

        $fOneDiscoveryJSON = @(New-Object psobject -Property @{
            Template="Discovery";
            DiscoveryName = $oneDiscoveryJSON.name;
            ItemName = $oneDiscoveryJSON.name;
            Type = $oneDiscoveryJSON.type;
            Delay = $oneDiscoveryJSON.delay;
            Params = [string]$oneDiscoveryJSON.params -replace '\n';
            Description = [string]$oneDiscoveryJSON.description -replace '\n';
            TriggerName = replacingMacroValueString -stringInput $oneDiscoveryJSON.trigger_prototypes.name;
            TriggersExpression = replacingMacroValueString -stringInput $oneDiscoveryJSON.trigger_prototypes.expression;
            TriggersPriority = $oneDiscoveryJSON.trigger_prototypes.priority;
            TriggersDescription = $oneDiscoveryJSON.trigger_prototypes.description -replace '\n'
            }
        )
        $createArrDiscover += $fOneDiscoveryJSON 

        foreach ( $oneItemDiscoverJSON in $OneDiscoveryJSON.item_prototypes ) {   
            #Length
            if ( $oneItemDiscoverJSON.trigger_prototypes){
                $length = @($oneItemDiscoverJSON.trigger_prototypes.name).Length -1
            } else { $length = 0 }

            for ( $i = 0 ; $i -le $length ; $i++ ) {
                #Delay
                if ( $oneItemDiscoverJSON.delay) {
                    $Delay = $oneItemDiscoverJSON.delay
                } else { $Delay = "" }
                #Params
                if ( $oneItemDiscoverJSON.params ) {
                    $Params = $oneItemDiscoverJSON.params -replace '\n'
                } else { $Params = "" }
                #Description
                if ( $oneItemDiscoverJSON.description ) {
                    $Description = $oneItemDiscoverJSON.description -replace '\n'
                } else { $Description = "" }
                #Master_item
                if ( $oneItemDiscoverJSON.master_item ){
                    $MasterItem = $oneItemDiscoverJSON.master_item.key
                } else { $MasterItem = "" }
                #Name and Type
                $Name = $oneItemDiscoverJSON.name
                $Type = $oneItemDiscoverJSON.type

                #Trigger Name, Expression, Priority, Description
                if ( $oneItemDiscoverJSON.trigger_prototypes ){
                    $Trigger = $oneItemDiscoverJSON.trigger_prototypes[$i]
                    $TriggerName = replacingMacroValueString -stringInput $Trigger.name
                    $TriggerExpression = replacingMacroValueString -stringInput $Trigger.expression
                    $TriggerPriority = $Trigger.priority
                    $TriggerDescription = $Trigger.description
                } else { 
                    $TriggerName = ""
                    $TriggerExpression = ""
                    $TriggerPriority = ""
                    $TriggerDescription = ""  
                }

                $fOneItemDiscoverJSON = @(New-Object psobject -Property @{
                    Template = "Discovery";
                    DiscoveryName = $oneDiscoveryJSON.name;
                    ItemName = $Name;
                    Type = $Type;
                    Delay = $Delay;
                    Params = $Params;
                    MasterItem = $MasterItem;
                    Description = $Description;
                    TriggerName = $TriggerName;
                    TriggersExpression = "$TriggerExpression";
                    TriggersPriority = "$TriggerPriority";
                    TriggersDescription = "$TriggerDescription"
                    }
                )
                #$fOneItemDiscoverJSON
                $createArrDiscover += $fOneItemDiscoverJSON
            }
        }
    }

    $itemsWork += $createArrDiscover
    $itemsWork | Export-Csv -Path "$OutputFile\$templateJSONName.csv" -Encoding utf8 -Delimiter ";" -Append
}