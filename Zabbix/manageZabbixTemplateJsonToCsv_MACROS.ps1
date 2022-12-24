#!/bin/pwsh

#Version 1.0.0.2
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

    #Replacing the macro value in a string
    function replacingMacroValueString {
        param (
            [Parameter(Mandatory=$false)][string]$stringInput
        )
        $strWork = $stringInput
        #We find Macros used in the text.
        $strSplit = @($strWork -replace "{\$"," {$" -replace "}","} " -split " ") | Where-Object { $_ -like "{`$*.*}" }
        
        #Create an array and add the first line to change
        $arrMacrosValue = @($strWork)
        foreach ( $fMacrosValue in $strSplit ){
            #Preparing the macro for the search, removing from the Macro { and } and $
            $resChangeMacro1 = $fMacrosValue -replace "{","" -replace "}","" -replace "\$","" -replace ":.*",""
            
            #Searching for a value macro in a JSON macro array
            $finChangeMacro1 = ("{$"+$resChangeMacro1+"}")
            $resChangeMacro_2 = ($templateJSONMacros | Where-Object { $_.macro -like $finChangeMacro1 })
            $resChangeMacro2 = ( $resChangeMacro_2.macro +" = "+ $resChangeMacro_2.value ) -replace "{\$" -replace "}"

            #Select the last value from the array and change the string
            $resChangeMacro3 = $arrMacrosValue[$arrMacrosValue.Count -1] -replace "$resChangeMacro1","$resChangeMacro2"
            #Adding to the array
            $arrMacrosValue += $resChangeMacro3 
        }
        return $arrMacrosValue[$arrMacrosValue.Count -1]
    }

    ###Create a table with an Item
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

    ###Create a table with an Discovery
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
    
    #We work with each detection rule
    $discoveryJSON = $templateJSON.discovery_rules
    foreach ( $oneDiscoveryJSON in $discoveryJSON ) {
        #Adding the found elements of the discovery rule to the discovery table.
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
        
        #Adding all the elements , triggers present in the discovery rule to the discovery table.
        foreach ( $oneItemDiscoverJSON in $OneDiscoveryJSON.item_prototypes ) {   
            #Length. We find out how many triggers have been created for one element, 
            #this is necessary to record data for each element and its trigger in the discovery table
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
                $createArrDiscover += $fOneItemDiscoverJSON
            }
        }
    }
    $itemsWork += $createArrDiscover
    $itemsWork | Export-Csv -Path "$OutputFile\$templateJSONName.csv" -Encoding utf8 -Delimiter ";" -Append
}