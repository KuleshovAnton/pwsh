#!/bin/pwsh

#Version 1.0.0.1
#It Simple
function manageZabbixTemplateJSONtoCSV {
    param (
        [Parameter(Mandatory=$true)][string]$InputFile,
        [Parameter(Mandatory=$true)][string]$OutputFile
    )
    
    [string]$fileJSON = (Get-Content -Path "$InputFile")

    $fromJSON = ConvertFrom-Json -InputObject $fileJSON
    $templateJSON = $fromJSON.zabbix_export.templates
    $templateJSONName = $templateJSON.name

    #Item
    $itemsJSON = $templateJSON.items
    #items: value_type,
    $itemsWork = $itemsJSON | Select-Object @{n="Template";e={"Item"}}, `
        @{n="DiscoveryName";e="null"}, `
        @{n="ItemName";e={$_.name}}, `
        type, `
        delay, `
        @{n="Params";e={$_.params -replace "\n"}}, `
        units, `
        @{n="MasterItem";e={$_.master_item.key}}, `
        description, `
        @{n="TriggerName";e={$_.triggers.name}}, `
        @{n="TriggersExpression";e={$_.triggers.expression}}, `
        @{n="TriggersPriority";e={$_.triggers.priority}}, `
        @{n="TriggersDescription";e={$_.triggers.description}}

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

    #Discovery
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
            TriggerName = $oneDiscoveryJSON.trigger_prototypes.name;
            TriggersExpression = $oneDiscoveryJSON.trigger_prototypes.expression;
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
                    $TriggerName = $Trigger.name
                    $TriggerExpression = $Trigger.expression
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