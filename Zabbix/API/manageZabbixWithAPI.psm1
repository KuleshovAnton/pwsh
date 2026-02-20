#!/bin/pwsh

#Version 1.0.0.20
#Connect and Autorization to Zabbix API.
function Connect-ZabbixAPI {
    <#
    .SYNOPSIS
        Start using this commandlet. You can add it as a variable for further use of the created token and the token ID. 
        This cmdlet will be authorized on the Zabbix server API using the username and password provided by you, in response 
        Zabbix will return the created token to you. Use this token and token id in subsequent commandlets.
    .PARAMETER UrlApi
        Specify the URL to connect to the Zabbix API. Example -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php'
    .PARAMETER User
        A Zabbix user who has rights to connect to the Zabbix API. Example: -User UserAdmin
    .PARAMETER TokenId
        The user ID when logging into the Zabbix API. Set a random number. Example: -TokenId 2
    .PARAMETER inPasswd
        Enter the password. If you do not specify a password, the system will ask you to enter it.
    .EXAMPLE
        Connect-ZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -User UserAdmin -TokenId 2
        Connect-ZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -User UserAdmin -TokenId 2 -inPasswd "Passw0rd"
    #>
    param(
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$User,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3, ParameterSetName = "Passwd")]$inPasswd
    )
    if ( $inPasswd ) {
        $str = $inPasswd
    }
    else {
        $passwdAdmin = Read-Host "Enter password" -AsSecureString
        $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwdAdmin)
        $str = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    } 
    #Create token for connection Zabbix API.
    $data = @{
        "jsonrpc" = "2.0";
        "method"  = "user.login";
        "params"  = @{
            "user"     = $User;
            "password" = $str;
        };
        "id"      = $TokenId
    }
    $token = (Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body ($data | ConvertTo-Json) -ContentType "application/json;charset=UTF-8")
    return $token
}
#########################################
#Working with hosts groups Zabbix API.
function Get-HostGroupsZabbixAPI {
    <#
    .SYNOPSIS
        ...
    .PARAMETER filterGroupName
        Return only those results that exactly match the given filter. Example: -filterGroupName "Group_Host_1,Group_Host_2"
    .PARAMETER searchGroupName
        Return result that match the given pattern (case-insensitive). if no additional options are given, this will perform a LIKE "%...%" search. Example: -searchGroupName "Group_Host_1"
    .PARAMETER searchWildcardsEnabled
        If set to True, enables the use of "*" as a wildcard character in the search parameter. Example: -searchGroupName "Group_Host*" -searchWildcardsEnabled $True
    .PARAMETER searchStart
        The search parameter will compare the beginning of fields, that is, perform a LIKE "...%" search instead. Ignored if searchWildcardsEnabled is set to True. Example: -searchGroupName "Group_Host" -searchStart $True
    .PARAMETER searchByAny
        If set to true, return results that match any of the criteria given in the filter or search parameter instead of all of them. Example: -searchByAny $True
    .PARAMETER $groupids
        ...
    .Example
        #Output only the groups you are looking for.
        Get-HostGroupsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterGroupName "Linux servers,Admin Windows Server" | Format-Table
        #Output all groups.
        Get-HostGroupsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 | Format-Table
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][array]$filterGroupName,
        [Parameter(Mandatory = $false, position = 4)][string]$searchGroupName,
        [Parameter(Mandatory = $false, position = 5)][ValidateSet("True", "False")]$searchWildcardsEnabled,
        [Parameter(Mandatory = $false, position = 6)][ValidateSet("True", "False")]$searchStart,
        [Parameter(Mandatory = $false, position = 7)][ValidateSet("True", "False")]$searchByAny,
        [Parameter(Mandatory = $false, position = 8)][string]$groupids
    )
    $getGroup = @{
        "jsonrpc" = "2.0";
        "method"  = "hostgroup.get";
        "params"  = @{
            "output" = "extend";
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Filter
    if ($filterGroupName) {
        $arrGp = @()
        foreach ( $oneGp in ($filterGroupName -split ",") ) {
            $oneResGP = ('"' + $oneGp + '"')
            $arrGp += $oneResGP
        }
        $addGp = $arrGp -join ","
        $filterName = @{"name" = @("$addGp") }
        $getGroup.params.Add("filter", $filterName)
    }
    #Search
    if ($searchGroupName) {
        $searchName = @{"name" = "$searchGroupName"}
        $getGroup.params.Add("search", $searchName)
    }
    #searchWildcardsEnabled
    if($searchWildcardsEnabled){
        $getGroup.params.Add("searchWildcardsEnabled",$searchWildcardsEnabled)
    }
    #searchStart
    if($searchStart){
        $getGroup.params.Add("startSearch",$searchStart)
    }
    #searchByAny
    if($searchByAny){
        $getGroup.params.Add("searchByAny",$searchByAny)
    }
    #groupids
    if($groupids){
        $getGroup.params.Add("groupids",$groupids)
    }

    $json = (ConvertTo-Json -InputObject $getGroup -Depth 100 ) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"'
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Set-HostGroupsZabbixAPI {
    <#
    .SYNOPSIS
        ...
    .PARAMETER Mode
        Mode of action ADD or REMOVE. Example: -Mode Add
    .PARAMETER GroupsId
        Provide host groups. Example: -GroupsId "1,2,3,4"
    .PARAMETER HostsId
        Provide a list of hosts to add or remove from the host group. Example: -HostsId "12001,13002,14005"
    .PARAMETER TemplatesId
        Provide a list of templates to add or remove from the host group. Example: -TemplatesId "1,1001"
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    .Example
        Set-HostGroupsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -Mode Add -GroupsId "1004" -HostsId "12001,13002,14005"
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][ValidateSet("Add","Remove")]$Mode,
        [Parameter(Mandatory = $true, position = 4)][array]$GroupsId,
        [Parameter(Mandatory = $false,position = 5)][array]$HostsId,
        [Parameter(Mandatory = $false,position = 6)][array]$TemplatesId,
        [Parameter(Mandatory = $false, position = 7)][ValidateSet($True, $False)]$WhatIf = $False
    )
    
    if( $Mode -eq 'Add' ){
        $setGroup = @{"jsonrpc" = "2.0"; "method" = "hostgroup.massadd"; "params" = @{}; "auth" = $TokenApi; "id" = $TokenId}
        #Build element
        function addElement($name, $listArr){       
            $arrObjFun = @()
            foreach ( $oneObj in ($listArr -split ",") ) {
                $oneTXT = ('{"'+$name+'":"'+$oneObj+'"}')
                $arrObjfun += $oneTXT
            }
            return $arrObjFun
        }
        #Add GroupsId
        $addElementGroups = addElement 'groupid'  $GroupsId
        $setGroup.params.Add("groups", @($addElementGroups) )
        #Add HostsId
        if($HostsId){
            $addElementHosts = addElement 'hostid' $HostsId
            $setGroup.params.Add("hosts", @($addElementHosts) )
        }
        #Add TemplatesId
        if($TemplatesId){
            $addElementHosts = addElement 'templateid' $TemplatesId
            $setGroup.params.Add("templates", @($addElementHosts) )
        }
    }
    if ( $Mode -eq 'Remove' ){
        $setGroup = @{"jsonrpc" = "2.0"; "method" = "hostgroup.massremove"; "params" = @{}; "auth" = $TokenApi; "id" = $TokenId}
        #Clear GroupsId
        $setGroup.params.Add("groupids", @($GroupsId -replace ',','","' -replace '^','"' -replace '$','"'))
        #Remove HostsId
        if($HostsId){$setGroup.params.Add("hostids", @($HostsId -replace ',','","' -replace '^','"' -replace '$','"'))}
        #Remove Templates
        if($TemplatesId){$setGroup.params.Add("templateids", @($TemplatesId -replace ',','","' -replace '^','"' -replace '$','"'))}
    }

    $json = (ConvertTo-Json -InputObject $setGroup -Depth 100 ) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"' -replace '"{"','{"' -replace '"}"','"}'
    If($WhatIf -eq $true){
        return $json
    }else{
        $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
        if($res.error){
            return $res.error
        }else{ return $res.result }
    }
}
#########################################
#Working with hosts Zabbix API.
function Get-HostsZabbixAPI {
    <#
    .SYNOPSIS
        ...
        Additional output: Groups, Inventory, Tags, Interfaces, Macros
    .PARAMETER filterHostName
        Return only those results that exactly match the given filter.
    .PARAMETER searchHostName
        Return results that match the given pattern (case-insensitive).
    .PARAMETER $filterHostID
        Return only hosts with the given host IDs.
    .PARAMETER searchWildcardsEnabled
        If set to True, enables the use of "*" as a wildcard character in the search parameter. Example: -searchHostName "Host*" -searchWildcardsEnabled $True
    .PARAMETER searchStart
        The search parameter will compare the beginning of fields, that is, perform a LIKE "...%" search instead. Ignored if searchWildcardsEnabled is set to True. Example: -searchHostName "Host" -searchStart $True
    .PARAMETER searchByAny
        If set to true, return results that match any of the criteria given in the filter or search parameter instead of all of them. Example: -searchByAny $True
    .Example
        #Output only the hosts you are looking for (case sensitive).
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterHostName "host_1,host_2" | Format-Table
    .Example
        #Output all hosts.
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 | Format-Table
    .Example
        #Output only the hosts you are looking for (case-insensitive).
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -searchHostName "hoSt_1,Host_2" | Format-Table

    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][string]$filterHostName,
        [Parameter(Mandatory = $false, position = 4)][string]$searchHostName,
        [Parameter(Mandatory = $false, position = 5)][string]$filterHostID,
        #Search
        [Parameter(Mandatory = $false, position = 6)][ValidateSet("True", "False")]$searchWildcardsEnabled,
        [Parameter(Mandatory = $false, position = 7)][ValidateSet("True", "False")]$searchStart,
        [Parameter(Mandatory = $false, position = 8)][ValidateSet("True", "False")]$searchByAny
    )

    function jsonGetHostCore(){
        $getHostFn = @{
            "jsonrpc" = "2.0";
            "method"  = "host.get";
            "params"  = @{
                "output"       = "extend"
                "selectGroups" = @("groupid","name")     #Group member
                "selectInventory" = @("os")
                "selectTags" = "extend"
                #"selectTriggers" = "extend"
                <#
                main = 0 - not default; 1 - default.
                type = 1 - agent; 2 - SNMP; 3 - IPMI; 4 - JMX.
                useip = 0 - connect using host DNS name; 1 - connect using host IP address for this host interface.
                available = 0 - (default) unknown; 1 - available; 2 - unavailable.
                #>
                "selectInterfaces" = @("main","type","useip","ip","dns","port","available")
                "selectMacros" = @("macro","value")
            };
            "auth"    = $TokenApi;
            "id"      = $TokenId;
        }
        return $getHostFn
    }

    function filterListPreparation($filterList) {
        $arrFl = @() 
        foreach ( $oneFl in ($filterList -split ",") ) {
        $oneResFl = ('"' + $oneFl + '"')
        $arrFl += $oneResFl
        }
        $addFl = $arrFl -join ","
        return $addFl
    }

    #Search hosts.
    if ($searchHostName) {
        $arrSearchHS = @()
        foreach ( $oneSearchHS in ($searchHostName -split ",") ) {
            $filterSearchName = @{"host" = @($oneSearchHS)}
            $getHostSearch = jsonGetHostCore
            $getHostSearch.params.Add("search", $filterSearchName)

            #searchWildcardsEnabled
            if($searchWildcardsEnabled){
                $getHostSearch.params.Add("searchWildcardsEnabled",$searchWildcardsEnabled)
            }
            #searchStart
            if($searchStart){
                $getHostSearch.params.Add("startSearch",$searchStart)
            }
            #searchByAny
            if($searchByAny){
                $getHostSearch.params.Add("searchByAny",$searchByAny)
            }
            
            $json = (ConvertTo-Json -InputObject $getHostSearch) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
            $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
            $arrSearchHS += $res.result
        } 
        return $arrSearchHS
    }
    #Search for everything and by filter.
    else {
        $getHost = jsonGetHostCore
        #Filter hosts.
        if ($filterHostName) {
            $addFilterHostName = filterListPreparation($filterHostName)
            $filterName = @{"host" = @("[$addFilterHostName]") }
            $getHost.params.Add("filter", $filterName)
        }
        #Filter hostsId.
        if ($filterHostID) {
            $addFilterHostID = filterListPreparation($filterHostID)
            $filterID = @{"hostid" = @("[$addFilterHostID]") }
            $getHost.params.Add("filter", $filterID)
        }

        #searchByAny
        if($searchByAny){
            $getHost.params.Add("searchByAny",$searchByAny)
        }

        $json = (ConvertTo-Json -InputObject $getHost) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
        $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
        if($res.error){
            return $res.error
        }else{ return $res.result }
    }
}

function New-HostZabbixAPI {
    <#
    .SYNOPSIS
        Creating a host in Zabbix, via Zabbix API.
    .DESCRIPTION
        Creating a host in Zabbix, via Zabbix API. If none of the SNMP, IPMA or Zabbix Agent network protocols is selected, then Zabbix Agent is used and created by default.
    .PARAMETER UrlApi
        Url Zabbix API. Example 'http://DNS_name_or_IP_address/zabbix/api_jsonrpc.php'
    .PARAMETER TokenApi
        A user token when logging in to the Zabbix API.
    .PARAMETER TokenId
        A user id when logging in to the Zabbix API.
    .PARAMETER HostName
        The "Host name" parameter in the Zabbix GUI. Example: -HostName "host"
    .PARAMETER IP
        IP address Host. Example: -IP "192.168.1.2"
    .PARAMETER DNS
        DNS name Host. Example: -DNS "host.domain.info"
    .PARAMETER Group_HostId
        Group Host ID. Which group are we adding the host to. Example: -Group_HostId "51,32,44"
    .PARAMETER Proxy_HostId
        Proxy Host ID. Which proxy do we use for this host. Example: -Proxy_HostId 10518
    .PARAMETER Use_SNMPv2
        Use SNMP protocol for management Host. Choose SNMPv2. Example: -Use_SNMPv2
    .PARAMETER Use_SNMPv3
        Use SNMP protocol for management Host. Choose SNMPv3. Example: -Use_SNMPv3
    .PARAMETER SNMPv2_community
        SNMP community (required). Used only by SNMPv1 and SNMPv2 interfaces. Example: -SNMPv2_community "public" or -SNMPv2_community '{$SNMP.COMMUNITY}'
    .PARAMETER SNMPv3_securityname
        SNMPv3 security name. Example: -SNMPv3_securityname "securityname" or -SNMPv3_securityname '{$SNMP.securityname}'
    .PARAMETER SNMPv3_securitylevel
        SNMPv3 security level. Example: -SNMPv3_securitylevel (switch select: authNoPriv,authNoPriv,authPriv).
    .PARAMETER SNMPv3_authpassphrase
        SNMPv3 authentication passphrase. Example -SNMPv3_authpassphrase "authpassphrase" or -SNMPv3_authpassphrase '{$SNMP.authpassphrase}'
    .PARAMETER SNMPv3_privpassphrase
        SNMPv3 privacy passphrase. Example: -SNMPv3_privpassphrase "privpassphrase" or -SNMPv3_privpassphrase '{$SNMP.privpassphrase}'
    .PARAMETER SNMPv3_authprotocol
        SNMPv3 authentication protocol. Example -SNMPv3_authprotocol (switch select: MD5,SHA1,SHA224,SHA256,SHA384,SHA512)
    .PARAMETER SNMPv3_privprotocol
        SNMPv3 privacy protocol. Example: -SNMPv3_privprotocol (switch select: DES,AES128,AES192,AES256,AES192C,AES256C)
    .PARAMETER Use_IP_SNMP
        If the option is selected, the connection be made via an IP address. Example: -Use_IP_SNMP
    .PARAMETER Use_IPMI
        Use IPMI protocol for management Host. Example: -Use_IPMI
    .PARAMETER Use_IP_IPMI
        If the option is selected, the connection be made via an IP address. Example: -Use_IP_IPMI
    .PARAMETER Use_Agent
        Use Zabbix Agent protocol for management Host. Example: -Use_Agent
    .PARAMETER Use_IP_Agent
        If the option is selected, the connection be made via an IP address. Example: -Use_IP_Agent
    .PARAMETER Tags
        Set a tags for the host. Example -Tags 'srv:SERVER,subsys:LINUX'
    .PARAMETER TemplateId
        Template Host ID. Which template are we adding the host to. Example: -TemplateId "77,3,9"
    .PARAMETER Inventory_Mode
        Enable Inventory data. Select Manual or automatic filling of inventory data. Example: -Inventory_Mode (switch select: Manual,Auto)
    .PARAMETER Macros
        Add custom MACROS in Host. Example: -Macros '{$USERID};123423;User ID,{$HOSTID};00001;Host ID}'
    .PARAMETER Description
        Add description object.
    .EXAMPLE
        #Use Agent interface.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "Host" -IP "192.168.1.2" -DNS "Host.domain.info" -Group_HostId 2 -Proxy_HostId 10518 -Use_Agent -TemplateId 1001 -Tags "srv:SERVER,subsys:LINUX"
    .EXAMPLE
        #Use SNMPv2 interface.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "host" -IP "192.168.1.2" -DNS "host.domain.info" -Group_HostId 2 -Use_SNMPv2 -Use_IP_SNMP -SNMPv2_community "public"
    .EXAMPLE
        #Use SNMPv3 interface Secure level noAuthNoPriv.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "host" -IP "192.168.1.2" -DNS "host.domain.info" -Group_HostId 2 -Use_SNMPv3 -Use_IP_SNMP -SNMPv3_securityname "Name" -SNMPv3_securitylevel noAuthNoPriv
    .EXAMPLE
        #Use SNMPv3 interface Secure level noAuthNoPriv.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "host" -IP "192.168.1.2" -DNS "host.domain.info" -Group_HostId 2 -Use_SNMPv3 -Use_IP_SNMP -SNMPv3_securityname "Name" -SNMPv3_securitylevel authNoPriv -SNMPv3_authprotocol MD5 -SNMPv3_authpassphrase "Hello"
    .EXAMPLE
        #Use SNMPv3 interface Secure level authPriv.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "host" -IP "192.168.1.2" -DNS "host.domain.info" -Group_HostId 2 -Use_SNMPv3 -Use_IP_SNMP -SNMPv3_securityname "Name" -SNMPv3_securitylevel authNoPriv -SNMPv3_authprotocol MD5 -SNMPv3_authpassphrase "Hello" -SNMPv3_privprotocol DES -SNMPv3_privpassphrase "Good"
    .Example
        #Use Agent interface and SNMPv2 interface and IPMI interface.
        New-HostZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -HostName "host" -IP "192.168.1.2" -DNS "host.domain.info" -Group_HostId 2 -Use_Agent -Use_SNMPv2 -SNMPv2_community "public" -Use_IPMI -Tags "srv:SERVER,subsys:LINUX"
    #>
    param(
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi, #URL Zabbix API.
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi, #User Token Zabbix API.
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId, #User ID Zabbix API.
        [Parameter(Mandatory = $true, position = 3)][string]$HostName, #Host Name.
        [Parameter(Mandatory = $true, position = 4)][ValidatePattern("\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")]$IP, #Host IP address.
        [Parameter(Mandatory = $true, position = 5)][string]$DNS, #Host DNS Name.
        [Parameter(Mandatory = $true, position = 6)][array]$Group_HostId, #Group Host ID.
        [Parameter(Mandatory = $false, position = 7)][int]$Proxy_HostId, #Proxy Host ID.
        [Parameter(Mandatory = $false, position = 8)][switch]$Use_Agent, 
        [Parameter(Mandatory = $false, position = 9)][switch]$Use_IP_Agent,
        [Parameter(Mandatory = $false, position = 10)][switch]$Use_SNMPv2,
        [Parameter(Mandatory = $false, position = 11)][switch]$Use_SNMPv3,
        [Parameter(Mandatory = $false, position = 12)][string]$SNMPv2_community,
        [Parameter(Mandatory = $false, position = 13)][string]$SNMPv3_securityname,
        [Parameter(Mandatory = $false, position = 14)][ValidateSet("noAuthNoPriv", "authNoPriv", "authPriv")]$SNMPv3_securitylevel,
        [Parameter(Mandatory = $false, position = 15)][ValidateSet("MD5", "SHA1", "SHA224", "SHA256", "SHA384", "SHA512")]$SNMPv3_authprotocol,
        [Parameter(Mandatory = $false, position = 16)][string]$SNMPv3_authpassphrase,
        [Parameter(Mandatory = $false, position = 17)][ValidateSet("DES", "AES128", "AES192", "AES256", "AES192C", "AES256C")]$SNMPv3_privprotocol,
        [Parameter(Mandatory = $false, position = 18)][string]$SNMPv3_privpassphrase,
        [Parameter(Mandatory = $false, position = 19)][switch]$Use_IP_SNMP,
        [Parameter(Mandatory = $false, position = 20)][switch]$Use_IPMI, 
        [Parameter(Mandatory = $false, position = 21)][switch]$Use_IP_IPMI,
        [Parameter(Mandatory = $false, position = 22)][string]$Tags,                                    #Tags Host.
        [Parameter(Mandatory = $false, position = 23)][array]$TemplateId,                               #Template.
        [Parameter(Mandatory = $false, position = 24)][ValidateSet("Manual", "Auto")]$Inventory_Mode,   #Enable Inventory data.
        [Parameter(Mandatory = $false, position = 25)][array]$Macros,                                   #Users Custom Macros.
        [Parameter(Mandatory = $false, position = 26)][string]$Description
    )
    ###Interface #######################################
    ##Agent Interfaces##
    if ( $Use_Agent ) {
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_IP_Agent ) { 
            $useipAgent = 1 
        }
        else { 
            $useipAgent = 0 
        }
        $interfacesAgent = @{
            "type"  = 1;
            "main"  = 1;
            "useip" = $useipAgent;
            "ip"    = $IP;
            "dns"   = $DNS;
            "port"  = "10050"
        }
        $jsonAgent = (ConvertTo-Json -InputObject $interfacesAgent) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{', '{' -replace '}"', '}'
    }
    ##SNMP Interfaces##
    if ( $Use_SNMPv2 -or $Use_SNMPv3 ) {
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_ip_SNMP ) { 
            $useipSNMP = 1 
        }
        else { 
            $useipSNMP = 0 
        }
        $interfacesSNMP = @{
            "type"  = 2;
            "main"  = 1;
            "useip" = $useipSNMP;
            "ip"    = $ip;
            "dns"   = $dns;
            "port"  = "161";
        }
       
        #Do not use SNMPv2 and SNMPv3.
        if ( $Use_SNMPv2 -and $Use_SNMPv3 ) {
            Write-Error "Simultaneous use of SNMPv2 and SNMPv3 is not allowed. Please use only one version of the SNMP protocol."
        }
        #Use SNMP v2.
        elseif ( $Use_SNMPv2 ) {
            if ( $SNMPv2_community -match "\{\$.*\}" ) {
                $community = ('"""' + $SNMPv2_community + '"""')
            }
            else {
                $community = ('"' + $SNMPv2_community + '"')
            } 
            $detailsSNMP = ( '"version":2,"bulk":1,"community":' + $community )
        }
        #Use SNMP v3.
        elseif ( $Use_SNMPv3 ) {
            #securitylevel
            switch ($SNMPv3_securitylevel) {
                "noAuthNoPriv" { $sLevel = 0 }
                "authNoPriv" { $sLevel = 1 }
                "authPriv" { $sLevel = 2 }
            }
            #authprotocol
            switch ($SNMPv3_authprotocol) {
                "MD5" { $aProtocol = 0 }
                "SHA1" { $aProtocol = 1 }
                "SHA224" { $aProtocol = 2 }
                "SHA256" { $aProtocol = 3 }
                "SHA384" { $aProtocol = 4 }
                "SHA512" { $aProtocol = 5 }
            }
            #privprotocol
            switch ($SNMPv3_privprotocol) {
                "DES" { $pProtocol = 0 }
                "AES128" { $pProtocol = 1 }
                "AES192" { $pProtocol = 2 }
                "AES256" { $pProtocol = 3 }
                "AES192C" { $pProtocol = 4 }
                "AES256C" { $pProtocol = 5 }
            }
            if ($SNMPv3_securityname -match "\{\$.*\}") {
                $securityname = ('"securityname":"""' + $SNMPv3_securityname + '"""')
            }
            else { $securityname = ('"securityname":"' + $SNMPv3_securityname + '"') }
            if ($SNMPv3_authpassphrase -match "\{\$.*\}") {
                $authpassphrase = ('"authpassphrase":"""' + $SNMPv3_authpassphrase + '"""')
            }
            else { $authpassphrase = ('"authpassphrase":"' + $SNMPv3_authpassphrase + '"') }
            if ($SNMPv3_privpassphrase -match "\{\$.*\}") {
                $privpassphrase = ('"privpassphrase":"""' + $SNMPv3_privpassphrase + '"""')
            }
            else { $privpassphrase = ('"privpassphrase":"' + $SNMPv3_privpassphrase + '"') }
            $detailsSNMP = ( '"version":3,"bulk":1,"contextname":"","securitylevel":' + $sLevel + ',"authprotocol":' + $aProtocol + ',"privprotocol":' + $pProtocol + ',' + $securityname + "," + $authpassphrase + "," + $privpassphrase)
        }
        $interfacesSNMP.Add("details", ("{$detailsSNMP}"))
        $jsonInterfacesSNMP = $interfacesSNMP
        $jsonSNMP = (ConvertTo-Json -InputObject $jsonInterfacesSNMP) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{', '{' -replace '}"', '}'
    }
    ##IPMI Interfaces##
    if ( $Use_IPMI ) {
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_ip_IPMI ) { $useipIPMI = 1 }
        else { $useipIPMI = 0 }

        $interfacesIPMI = @{
            "type"  = 3;
            "main"  = 1;
            "useip" = $useipIPMI;
            "ip"    = $ip;
            "dns"   = $dns;
            "port"  = "623"
        }
        $jsonIPMI = (ConvertTo-Json -InputObject $interfacesIPMI) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{', '{' -replace '}"', '}'
    }
    #If not Variable $Use_Agent, $Use_SNMP, $Use_IPMI. Is used default Zabbix Agent.
    if ( -not $Use_Agent -and -not $Use_SNMPv2 -and -not $Use_SNMPv3 -and -not $Use_IPMI ) {
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_IP_Agent ) { $useipAgent = 1 }
        else { $useipAgent = 0 }
        $interfacesAgent = @{
            "type"  = 1;
            "main"  = 1;
            "useip" = $useipAgent;
            "ip"    = $IP;
            "dns"   = $DNS;
            "port"  = "10050"
        }
        $jsonAgent = (ConvertTo-Json -InputObject $interfacesAgent) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{', '{' -replace '}"', '}'
    }
    ###Interface End####################################
    ###Create Host JSON#################################
    $createHost = @{
        "jsonrpc" = "2.0";
        "method"  = "host.create";
        "params"  = @{
            "host" = $hostName;
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId;
    }
    #Add Group Host to JSON.
    $arrGroupId = @()
    foreach ( $oneGroupId in ($group_HostId -split ",") ) {
        $resGroupId = ( '{"groupid":"' + $oneGroupId + '"}' )
        $arrGroupId += $resGroupId
    }
    $addGroupId = $arrGroupId -join ","
    $createHost.params.Add("groups", @($addGroupId))
    #Add interfaces Host to JSON.
    $joinJsonInterface = @()
    if ( $jsonAgent) { $joinJsonInterface += $jsonAgent }
    if ( $jsonSNMP ) { $joinJsonInterface += $jsonSNMP }
    if ( $jsonIPMI ) { $joinJsonInterface += $jsonIPMI }
    [string]$joinJsonInterfaceAdd = $joinJsonInterface -join ","
    $createHost.params.Add("interfaces", @($joinJsonInterfaceAdd))
    #Add Tags Host to JSON.
    if ($Tags) {
        $arrTags = @()
        foreach ( $oneTag in ($Tags -split ",") ) {
            $oTag = $oneTag -split ":"
            $resTag = ( '{"tag":"' + $oTag[0] + '","value":"' + $oTag[1] + '"}' )
            $arrTags += $resTag
        }
        $addTags = $arrTags -join ","
        $createHost.params.Add("tags", @($addTags))
    }     
    #Add Zabbix Proxy Host to JSON.
    if ($Proxy_HostId) {
        $createHost.params.Add("proxy_hostid", $Proxy_HostId)
    }
    #Add template to JSON.
    if ($TemplateId) {
        $arrTemplateId = @()
        foreach ( $oneTemplateId in ($TemplateId -split ",") ) {
            $resTemplateId = ( '{"templateid":"' + $oneTemplateId + '"}' )
            $arrTemplateId += $resTemplateId
        }
        $addTemplateId = $arrTemplateId -join ","
        $createHost.params.Add("templates", @($addTemplateId))
    }
    #Add Inventory to JSON.
    if ($Inventory_Mode) {
        switch ($Inventory_Mode) {
            "Manual" { [int]$InvMode = 0 }
            "Auto" { [int]$InvMode = 1 }
        }
        $createHost.params.Add("inventory_mode", $InvMode)
    }    
    #Add Macros Host to JSON.
    if ($Macros) {
        $arrMacros = @()
        foreach ( $oneMacros in ($Macros -split ",") ) {
            $oMacros = $oneMacros -split ";"
            if($oMacros[2]){
                $oDescription = $oMacros[2]
            }else { $oDescription = ''}
            $resMacros = ( '{"macro":""' + $oMacros[0] + '"","value":"' + $oMacros[1] + '","description":"' + $oDescription + '"}' )
            $arrMacros += $resMacros
        }
        $addMacros = $arrMacros -join ","
        $createHost.params.Add("macros", @($addMacros))
    }
    #Add Description to JSON.
    if ($Description) {
        $createHost.params.Add("description", $Description)
    }

    $jsonCreate = $createHost
    $json = (ConvertTo-Json -InputObject $jsonCreate) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '\["{', '[{' -replace '}"\]', '}]' -replace '"{', '{' -replace '}"', '}'
    ###Create Host JSON END###############################
    ###Create Host########################################
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Remove-HostsZabbixAPI {
    <#
    .Example
        #Output only the groups you are looking for.
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterHostName '"cgraf1,cgraf2"' | Format-Table
        #Output all groups.
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 | Format-Table
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][array]$HostsID
    )

    $hostIdApi = $HostsID -split "," -replace '^','"' -replace '$','"' -join ","
    $removeHost = @{
        "jsonrpc" = "2.0";
        "method"  = "host.delete";
        "params"  = @($hostIdApi);
        "auth"    = $TokenApi;
        "id"      = $TokenId;
    }

    $json = (ConvertTo-Json -InputObject $removeHost) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"'
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}
<#In Developer
#Massadd Host to Zabbix API _v1
function Add-HostsZabbixAPI {

    param(
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][int]$HostID
    )

    $massAddHosts = @{
        "jsonrpc" = "2.0";
        "method"  = "host.massadd";
        "params"  = @{
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId;
    }


}
#>

#########################################
#Get all Template Zabbix API
function Get-TemplateZabbixAPI {
    <#
   .Example
        #Output all Template.
        Get-TemplateZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2
        #Output only the Template you are looking for.
        Get-TemplateZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterTemplateName  "Linux by Zabbix agent,Template 1"
   #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][array]$filterTemplateName
    )
    $getTemplate = @{
        "jsonrpc" = "2.0";
        "method"  = "template.get";
        "params"  = @{
            "output" = "extend";
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Filter
    if ($filterTemplateName) {
        $arrTm = @()
        foreach ( $oneTm in ($filterTemplateName -split ",") ) {
            $oneResTm = ('"' + $oneTm + '"')
            $arrTm += $oneResTm
        }
        $addTm = $arrTm -join ","
        $filterName = @{"host" = @("[$addTm]") }
        $getTemplate.params.Add("filter", $filterName)
    }
    $json = (ConvertTo-Json -InputObject $getTemplate) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working with Users Groups Zabbix API.
function Get-UserGroupZabbixAPI {
    <#
    .SYNOPSIS
        The method allows to retrieve users according to the given parameters, via Zabbix API.
    .PARAMETER filterUserGroup
        Select User Groups.
    .PARAMETER IncomingUsers
        Return the users from the user group in the users property.
    .PARAMETER ReturnRights
        Return user group rights in the rights property. It has the following properties: permission - access level to the host group; id - ID of the host group.
    .Example
        Get-UserGroupZabbixAPI "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid
    .Example
        Get-UserGroupZabbixAPI "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -filterUserGroup "Group1,Group2" -IncomingUsers -ReturnRights
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][array]$filterUserGroup,
        [Parameter(Mandatory = $false, position = 4)][switch]$IncomingUsers,
        [Parameter(Mandatory = $false, position = 5)][switch]$ReturnRights,
        [Parameter(Mandatory = $false, position = 6)][switch]$ReturnTagFilters
        
    )
    $getUserGroup = @{
        "jsonrpc" = "2.0";
        "method"  = "usergroup.get";
        "params"  = @{
            "output" = "extend";       
            "status" = 0
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Filter
    if ($filterUserGroup) {
        $arrUSGP = @()
        foreach ( $oneUSGP in ($filterUserGroup -split ",") ) {
            $oneResUSGP = ('"' + $oneUSGP + '"')
            $arrUSGP += $oneResUSGP
        }
        $addUSGP = $arrUSGP -join ","
        $filterName = @{"name" = @("$addUSGP") }
        $getUserGroup.params.Add("filter", $filterName)
    }
    #Members of the group.
    If ($IncomingUsers) {
        $getUserGroup.params.Add("selectUsers", "extend")
    }
    #Return permissions for a group of hosts. permission - the level of access rights to a group of hosts; id - ID of the host group.
    If ($ReturnRights) {
        $getUserGroup.params.Add("selectRights", "extend")
    }
    #Return permissions for a group of hosts. permission - the level of access rights to a tag filter of hosts
    If ($ReturnTagFilters) {
        $getUserGroup.params.Add("selectTagFilters", "extend")
    }
    $json = (ConvertTo-Json -InputObject $getUserGroup -Depth 100 ) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function New-UserGroupZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][string]$NewUserGroup,
        [Parameter(Mandatory = $true, position = 4)][ValidateSet("SysDefault", "Internal", "LDAP", "NotFrontend")]$GuiAccess
    )
    switch ($GuiAccess) {
        "SysDefault" { $gAccess = 0 }
        "Internal" { $gAccess = 1 }
        "LDAP" { $gAccess = 2 }
        "NotFrontend" { $gAccess = 3 }
    }
    $createUserGroup = @{
        "jsonrpc" = "2.0";
        "method"  = "usergroup.create";
        "params"  = @{
            "name"         = "$NewUserGroup";
            "gui_access"   = $gAccess;
            "users_status" = 0
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    $json = (ConvertTo-Json -InputObject $createUserGroup -Depth 100) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Set-UserGroupZabbixAPI {
    <#
    .SYNOPSIS
        ...
    .PARAMETER usrgrpid
        Select User Groups ID. Example -usrgrpid 543
    .PARAMETER Permissions_groupid
        Select the ID of the Host groups for which access will be granted. Example -Permissions_groupid "980,981,982"
    .PARAMETER Permission_group
        Select lever access - denied=0; read-only=2; read-write=3. Example: -Permission_group read-only
    .PARAMETER ARR_Permission_groupid
        Select array the ID of the Host groups for which access will be granted and lever access. Example: "2:980,2:981,3:982"
    .PARAMETER tag_Filters_groupid
        Select the ID of the Host groups for which access will be granted. Example -tag_Filters_groupid "980,981,982"
    .PARAMETER tag_Filters_tagvalue
        Select the tag:value of the Host groups for which access will be granted. Example -tag_Filters_tagvalue "tag1:value1,tag2:value2". Example all tag: -tag_Filters_tagvalue ""
    .PARAMETER ARR_Filters_tagvalue_groupid
        Select the tag:value:groupid of the Host groups for which access will be granted. Example -ARR_Filters_tagvalue_groupid 'tag1:value1:group1_id,tag2:value2:group2_id,::group3_id'
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    .Example
        Set-UserGroupZabbixAPI "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -Permissions_groupid "980,981,982" -tag_Filters_groupid "980,981,982" -tag_Filters_tagvalue ""
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][int]$usrgrpid,
        ##Permissions
        [Parameter(Mandatory = $false, position = 4)][string]$Permissions_groupid,
        #0-denied; 2-read-only; 3-read-write
        [Parameter(Mandatory = $false, position = 5)][ValidateSet("denied", "read-only", "read-write")]$Permission_group,
        #Permissions ARR
        [Parameter(Mandatory = $false, position = 6)][string]$ARR_Permission_groupid,
        ##Tag Filter
        [Parameter(Mandatory = $false, position = 7)][string]$tag_Filters_groupid,
        [Parameter(Mandatory = $false, position = 8)][string]$tag_Filters_tagvalue,
        #Tag Filter ARR
        [Parameter(Mandatory = $false, position = 9)][string]$ARR_Filters_tagvalue_groupid,
        [Parameter(Mandatory = $false, position = 10)][ValidateSet($True, $False)]$WhatIf = $False
    )

    $userGroupUpdate = @{
        "jsonrpc" = "2.0";
        "method"  = "usergroup.update";
        "params"  = @{
            "usrgrpid"     = $usrgrpid;
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }

    $perm = switch ($Permission_group){
        'denied'    { 0 }
        'read-only' { 2 }
        'read-write'{ 3 }
    }

    #Permissions
    if ($Permissions_groupid){
        $arrHGR = @()
        foreach ( $oneHGR in ($Permissions_groupid -split ",") ) {
            $oneResHGR = ( '{"id":"'+ $oneHGR +'","permission":' + $perm +'}')
            $arrHGR += $oneResHGR
        }
        $addHGR = $arrHGR -join ","
        $userGroupUpdate.params.Add("rights", "[$addHGR]")
    }
    #Permissions ARR
    if ($ARR_Permission_groupid){
        $arrHGR2 = @()
        foreach ( $oneHGR2 in ($ARR_Permission_groupid -split ",") ) {

            $oneHGR_perm = ($oneHGR2 -split ":")[0]
            $oneHGR_id   = ($oneHGR2 -split ":")[1]

            $oneResHGR2 = ( '{"id":"'+ $oneHGR_id +'","permission":' + $oneHGR_perm +'}')
            $arrHGR2 += $oneResHGR2
        }
        $addHGR2 = $arrHGR2 -join ","
        $userGroupUpdate.params.Add("rights", "[$addHGR2]")
    }
    #Tag filter
    if($tag_Filters_groupid) {
        $arrTags = @()
        foreach( $oneTagGRP in ($tag_Filters_groupid -split ",") ) {
            $arrTagValue = @()
            foreach ( $oneTagValue in ($tag_Filters_tagValue -split ",") ){  
                $jsonTagValue = $oneTagValue -split ":"
                $oneResTGRP = ( '{"groupid":'+  $oneTagGRP +',"tag":"'+ $jsonTagValue[0] +'","value":"'+ $jsonTagValue[1] +'"}' )
                $arrTagValue += $oneResTGRP
            }
            $arrTags += $arrTagValue
        }
        $addTags = $arrTags -join ","
        $userGroupUpdate.params.Add("tag_filters","[$addTags]")
    }
    #Tag filter ARR, format tag:value:groupid
    if($ARR_Filters_tagvalue_groupid){
        $arrTags2 = @()
        foreach( $oneTagGRP2 in ($ARR_Filters_tagvalue_groupid -split ',')){
            $oneTag     = ($oneTagGRP2 -split ':')[0]
            $oneValue   = ($oneTagGRP2 -split ':')[1]
            $oneGroupid = ($oneTagGRP2 -split ':')[2]

            $oneResTGRP2 = ( '{"groupid":'+  $oneGroupid +',"tag":"'+ $oneTag +'","value":"'+ $oneValue +'"}' )
            $arrTags2 += $oneResTGRP2
        }
        $addTags2 = $arrTags2 -join ","
        $userGroupUpdate.params.Add("tag_filters","[$addTags2]")
    }

    $json = (ConvertTo-Json -InputObject $userGroupUpdate) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    #WhatIf
    if($WhatIf -eq $true){
        $json 
    }else {
        $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
        if($res.error){
            return $res.error
        }else{ return $res.result }
    }
}

#########################################
#Working with Users Zabbix API.
function Get-UserZabbixAPI {
    <#
    .SYNOPSIS
        The method allows to retrieve users according to the given parameters, via Zabbix API.
    .PARAMETER filterUser
        Select Users.
    .PARAMETER SelectMedias
        Return media used by the user in the medias property.
    .PARAMETER SelectMediaTypes
        Return media types used by the user in the mediatypes property.
    .PARAMETER SelectUsrGrps
        Return user groups that the user belongs to in the usrgrps property
    .Example
        Get-UserZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid
    .Example
        Get-UserZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -filterUser "User1,User2" -SelectMedias -SelectMediaTypes -SelectUsrGrps
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][array]$filterUser,
        [Parameter(Mandatory = $false, position = 4)][switch]$SelectMedias,
        [Parameter(Mandatory = $false, position = 5)][switch]$SelectMediaTypes,
        [Parameter(Mandatory = $false, position = 6)][switch]$SelectUsrGrps
    )
    $getUser = @{
        "jsonrpc" = "2.0";
        "method"  = "user.get";
        "params"  = @{
            "output" = "extend"
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Filter
    if ($filterUser) {
        $arrUS = @()
        foreach ( $oneUS in ($filterUser -split ",") ) {
            $oneResUS = ('"' + $oneUS + '"')
            $arrUS += $oneResUS
        }
        $addUS = $arrUS -join ","
        $filterName = @{"username" = @($addUS) }
        $getUser.params.Add("filter", $filterName)
    }
    #Return user alerts that are used by the user.
    If ($SelectMedias) {
        $getUser.params.Add("selectMedias", "extend")
    }
    #Return the notification methods that the user is using.
    If ($SelectMediaTypes) {
        $getUser.params.Add("selectMediatypes", "extend")
    }
    #Return user groups that users belong to.
    If ($SelectUsrGrps) {
        $getUser.params.Add("selectUsrgrps", "extend")
    }
    $json = (ConvertTo-Json -InputObject $getUser -Depth 100) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function New-UserZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to create new users, via Zabbix API.
    .PARAMETER NewUser
        User Name.
    .PARAMETER NewUserPass
        User password.
    .PARAMETER UserGroupsId
        User groups to add the user to. Use group id. Example -UserGroups "5,6"
    .PARAMETER UserRolesId
        User role to add the user to. Use role id. Example: -UserRolesId 1
    .Example
        New-UserZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -NewUser TestPS -NewUserPass "Passw0rd" -UserGroupsId "13,15" -UserRolesId 1
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][string]$NewUser,
        [Parameter(Mandatory = $true, position = 4)][string]$NewUserPass,
        [Parameter(Mandatory = $true, position = 5)][array]$UserGroupsId,
        [Parameter(Mandatory = $true, position = 6)][int]$UserRolesId,
        [Parameter(Mandatory = $false, position = 7)][string]$NewUserName,
        [Parameter(Mandatory = $false, position = 8)][string]$NewUserSurname
        #[Parameter(Mandatory=$false,position=6)][array]$UserMedia
    )
    $createUser = @{
        "jsonrpc" = "2.0";
        "method"  = "user.create";
        "params"  = @{
            "alias"  = $NewUser;
            "passwd" = $NewUserPass;
            "roleid" = $UserRolesId;
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Add GroupsID to JSON.
    if ($UserGroupsId) {
        $arrUserGroups = @()
        foreach ( $oneUserGroups  in ($UserGroupsId -split ",") ) {
            $resUserGroups = ( '{"usrgrpid":"' + $oneUserGroups + '"}' )
            $arrUserGroups += $resUserGroups
        }
        $addUserGroups = $arrUserGroups -join ","
        $createUser.params.Add("usrgrps", @($addUserGroups))
    }
    if ($NewUserName) {
        $createUser.params.Add("name", $NewUserName)
    }
    if ($NewUserSurname) {
        $createUser.params.Add("surname", $NewUserSurname)
    }

    $json = (ConvertTo-Json -InputObject $createUser -Depth 100) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '"\{', '{' -replace '\}"', '}'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Remove-UserZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to delete users, via Zabbix API.
    .PARAMETER RemoveUser
        Select UsersId. Example: -RemoveUser "4" or -RemoveUser "4,6,45,104"
    .Example
        Remove-UserZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -RemoveUser "3,44"
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][array]$RemoveUser
    )
    $delUser = @{
        "jsonrpc" = "2.0";
        "method"  = "user.delete";
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    If ($RemoveUser) {
        $arrR = @()
        foreach ( $oneRemoveUser in ($RemoveUser -split ",") ) {
            $resRemoveUser = ('"' + $oneRemoveUser + '"')
            $arrR += $resRemoveUser
        }
        $addRemoveUser = $arrR -join ","
        $delUser.Add("params", "[$addRemoveUser]")
    }
    $json = (ConvertTo-Json -InputObject $delUser) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Set-UserZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to update existing users, via Zabbix API. The userid property must be defined for each user, all other properties are optional. Only the passed properties will be updated, all others will remain unchanged. Passed properties overwrite, existing data
    .PARAMETER Username
        Change User Name.
    .PARAMETER Name
        Change Name.
    .PARAMETER Surname
        Change Surname.
    .PARAMETER UrlAfterLogin
        Change URL of the page to redirect the user to after logging in.
    .PARAMETER Passwd
        Change User Password.
    .PARAMETER $UserRoleId
        Change Role ID of the user.
    .PARAMETER $Usrgrps
        Change User groups to replace existing user groups. The user groups must have the usrgrpid property defined. Example: -Usrgrps "1" or -Usrgrps "2,14,105"
    .Example
        Set-UserZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -UserId 47 -Username User1 -Usrgrps "13,14,15" -UserRoleId 2 
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][int]$UserId,
        [Parameter(Mandatory = $false, position = 4)][string]$Username,
        [Parameter(Mandatory = $false, position = 5)][string]$Name,
        [Parameter(Mandatory = $false, position = 6)][string]$Surname,
        [Parameter(Mandatory = $false, position = 7)][string]$UrlAfterLogin,
        [Parameter(Mandatory = $false, position = 8)][string]$Passwd,
        [Parameter(Mandatory = $false, position = 9)][int]$UserRoleId,
        [Parameter(Mandatory = $false, position = 10)][array]$Usrgrps
    )

    $updateUser = @{
        "jsonrpc" = "2.0";
        "method"  = "user.update";
        "params"  = @{
            "userid" = $UserId;
        }
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Rename User Name.
    If ($Username) {
        $updateUser.params.Add("username", $Username)
    }
    #Rename Name.
    If ($Name) {
        $updateUser.params.Add("name", $Name)
    }
    #Rename Surname.
    If ($Surname) {
        $updateUser.params.Add("surname", $Surname)
    }
    #Change Url After Login.
    If ($UrlAfterLogin) {
        $updateUser.params.Add("url", $UrlAfterLogin)
    }
    #Change User Password.
    If ($Passwd) {
        $updateUser.params.Add("passwd", $Passwd)
    }
    #Change User RoleID.
    If ($UserRoleId) {
        $updateUser.params.Add("roleid", $UserRoleId)
    }
    #Change\Add User Groups.
    if ($Usrgrps) {
        $arrUGC = @()
        foreach ( $oneUGC in ($Usrgrps -split ",") ) {
            $oneResUGC = ('{"usrgrpid":' + $oneUGC + '}')
            $arrUGC += $oneResUGC
        }
        $addUGC = $arrUGC -join ","
        $updateUser.params.Add("usrgrps", "[$addUGC]")
    }
    $json = (ConvertTo-Json -InputObject $updateUser -Depth 100) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '"\{', '{' -replace '\}"', '}'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}
#########################################
#Working with User Roles Zabbix API.
function Get-UserRoleZabbixAPI {
    <#
    .SYNOPSIS
        The method allows to retrieve roles according to the given parameters, via Zabbix API.
    .PARAMETER SelectRules
        Return role rules in the rules property.
    .PARAMETER SelectUsers
        Select users this role is assigned to.
    .PARAMETER Roleids
        Return only roles with the given IDs. Example: 
    .Example
        Get-UserRoleZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -SelectUsers -roleids "5,6"
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][switch]$SelectRules,
        [Parameter(Mandatory = $false, position = 4)][switch]$SelectUsers,
        [Parameter(Mandatory = $false, position = 5)][array]$Roleids
    )
    $getRole = @{
        "jsonrpc" = "2.0";
        "method"  = "role.get";
        "params"  = @{
            "output" = "extend";
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #Return role rules in the rules property.
    If ($SelectRules) {
        $getRole.params.Add("selectRules", "extend")
    }
    #Select users this role is assigned to.
    If ($selectUsers) {
        $getRole.params.Add("selectUsers", "extend")
    }
    #Return only roles with the given IDs.
    If ($Roleids) {
        $getRole.params.Add("roleids", "[$Roleids]")
    }
    $json = (ConvertTo-Json -InputObject $getRole) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working with Maintenance Zabbix API.
function Get-MaintenanceZabbixAPI {
    <#
    .SYNOPSIS
        The method allows to retrieve maintenances according to the given parameters, via Zabbix API.
    .PARAMETER SelectGroups
        Return a groups property with host groups assigned to the maintenance. Example: -SelectGroups
    .PARAMETER SelectHosts
        Return a hosts property with hosts assigned to the maintenance. Example: -SelectHosts
    .PARAMETER SelectTimeperiods
        Return a timeperiods property with time periods of the maintenance. Example: -SelectTimeperiods
    .PARAMETER SelectTags
        Return a tags property with problem tags of the maintenance. Example: -SelectTags
    .PARAMETER FilterMaintenance
        Search by Name maintenance. Example: -FilterMaintenance "maintenance1,maintenance2"
    .PARAMETER FindHostIds
        Return only maintenances that are assigned to the given hosts. Example: -FindHostIds "10001,13409"
    .PARAMETER FindGroupIds
        Return only maintenances that are assigned to the given host groups. Example: -FindGroupIds "2324,2453"
    .PARAMETER FindMaintenanceIds
        Return only maintenances with the given IDs. Example: -FindMaintenanceIds "4555,6555"
    .PARAMETER SearchDescription
        Return list maintenances with the given Description. Example: -SearchDescription "Find maintenance number 3456" or Example: -SearchDescription "number 3456"
    .PARAMETER SearchMaintenance
        Return list maintenances with the given Name. Example: -SearchMaintenance "mainte"
    .PARAMETER searchWildcardsEnabled
        If set to True, enables the use of "*" as a wildcard character in the search parameter.
    .PARAMETER searchStart
        The search parameter will compare the beginning of fields, that is, perform a LIKE "...%" search instead. Ignored if searchWildcardsEnabled is set to True.
    .PARAMETER searchByAny
        If set to true, return results that match any of the criteria given in the filter or search parameter instead of all of them.
    .Example
        Get-MaintenanceZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid
    .Example
        Get-MaintenanceZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -FilterMaintenance "maintenance1,maintenance2"
    .Example
        Get-MaintenanceZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -SearchMaintenance "mainte"
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][switch]$SelectGroups,
        [Parameter(Mandatory = $false, position = 4)][switch]$SelectHosts,
        [Parameter(Mandatory = $false, position = 5)][switch]$SelectTimeperiods,
        [Parameter(Mandatory = $false, position = 6)][switch]$SelectTags,
        [Parameter(Mandatory = $false, position = 7)][array]$FilterMaintenance,
        [Parameter(Mandatory = $false, position = 8)][array]$FindHostIds,
        [Parameter(Mandatory = $false, position = 9)][array]$FindGroupIds,
        [Parameter(Mandatory = $false, position = 10)][array]$FindMaintenanceIds,
        [Parameter(Mandatory = $false, position = 11)][string]$SearchDescription,
        [Parameter(Mandatory = $false, position = 12)][string]$SearchMaintenance,
        [Parameter(Mandatory = $false, position = 13)][ValidateSet("True", "False")]$searchWildcardsEnabled,
        [Parameter(Mandatory = $false, position = 14)][ValidateSet("True", "False")]$searchStart,
        [Parameter(Mandatory = $false, position = 15)][ValidateSet("True", "False")]$searchByAny
    )
    $getMaintenance = @{
        "jsonrpc" = "2.0";
        "method"  = "maintenance.get";
        "params"  = @{
            "output" = "extend";
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    If ($SelectGroups){$getMaintenance.params.Add("selectGroups", "extend")}
    If ($SelectHosts) {$getMaintenance.params.Add("selectHosts", "extend")}
    If ($SelectTimeperiods) {$getMaintenance.params.Add("selectTimeperiods", "extend")}
    If ($SelectTags) {$getMaintenance.params.Add("selectTags", "extend")}
    #Filter
    if ($FilterMaintenance) {
        $arrMT = @()
        foreach ( $oneMT in ($FilterMaintenance -split ",") ) {
            #Trim $oneMT to 128 characters.
            $oneResMT = ('"' + [string]$oneMT.Substring(0, [System.Math]::Min(128, $oneMT.length)) + '"')
            $arrMT += $oneResMT
        }
        $addMT = $arrMT -join ","
        $filterName = @{"name" = @("[$addMT]") }
        $getMaintenance.params.Add("filter", $filterName)
    }
    #Return only those services that are assigned to the specified network nodes.
    if ($FindHostIds) {
        $addFindH = $FindHostIds -replace "\s"
        $getMaintenance.params.Add("hostids", "[$addFindH]")
    }
    #Return only those services that are assigned to the specified groups of network nodes.
    if ($FindGroupIds) {
        $addFindG = $FindGroupIds -replace "\s"
        $getMaintenance.params.Add("groupids", "[$addFindG]")
    }
    #Return of services with specified IDs only.
    if ($FindMaintenanceIds) {
        $addFindM = $FindMaintenanceIds -replace "\s"
        $getMaintenance.params.Add("maintenanceids", "[$addFindM]")
    }
    #searchDescription  or SearchMaintenance
    if ($searchDescription -or $SearchMaintenance){
        $getMaintenance.params.Add("search",@{})
        if($searchDescription){
            $getMaintenance.params.search.Add("description", @($searchDescription))
        }
        if($SearchMaintenance){
            #Trim $SearchMaintenance to 128 characters.
            $getMaintenance.params.search.Add("name", @( [string]$SearchMaintenance.Substring(0, [System.Math]::Min(128, $SearchMaintenance.length)) ))
        }
    }
    #searchWildcardsEnabled or searchStart or searchByAny
    if($searchWildcardsEnabled){$getMaintenance.params.Add("searchWildcardsEnabled",$searchWildcardsEnabled)}
    if($searchStart){$getMaintenance.params.Add("startSearch",$searchStart)}
    if($searchByAny){$getMaintenance.params.Add("searchByAny",$searchByAny)}

    $json = (ConvertTo-Json -InputObject $getMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function New-MaintenanceZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to create new maintenances, via Zabbix API
    .PARAMETER NameMaintenance
        Name Maintenance. Example: -NameMaintenance "Maintenance_1"
    .PARAMETER ActiveSince
        Time when the maintenance becomes active. Example: -ActiveSince "20.04.2024 00:00"
    .PARAMETER ActiveTill
        Time when the maintenance stops being active. Example: -ActiveTill "20.05.2024 00:00"
    .PARAMETER MaintenanceType
        Type of maintenance. Possible values: WithData - (default) with data collection; NoData - without data collection. Example: -MaintenanceType NoData
    .PARAMETER GroupIds
        Host groups that will undergo maintenance. The host groups must have the groupid property defined. At least one object of groups or hosts must be specified. Example: -GroupIds "31,34,121"
    .PARAMETER HostIds
        Hosts that will undergo maintenance.The hosts must have the hostid property defined. At least one object of groups or hosts must be specified. Example: -HostIds "13123,4456" 
    .PARAMETER Timeperiod_type
        "One time only"=0, "daily"=2, "weekly"=3, "mounthly"=4.Release only "One time only". Example: -Timeperiod_type 0
    .PARAMETER Start_date
        Datetime start period. Example: -Start_date "25.04.20024 23:00"
    .PARAMETER Period
        Maintenance period scheduled, parameters day-1d, or hours-1h or minutes-30m. Example: -Period 1d. Example -Period 1d;6h;30m
    .PARAMETER Description
        ...
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][string]$NameMaintenance ,
        [Parameter(Mandatory = $true, position = 4)][string]$ActiveSince,
        [Parameter(Mandatory = $true, position = 5)][string]$ActiveTill,
        [Parameter(Mandatory = $false, position = 6)][ValidateSet("WithData", "NoData")]$MaintenanceType,
        [Parameter(Mandatory = $false, position = 7)][array]$GroupIds,
        [Parameter(Mandatory = $false, position = 8)][array]$HostIds,
        #Periods for only=0
        #One time only=0, daily=2, weekly=3, mounthly=4
        [Parameter(Mandatory = $true, position = 9)][ValidateSet(0)]$Timeperiod_type,
        [Parameter(Mandatory = $false, position = 10)][string]$Start_date,
        #1d or 2h or 30m
        [Parameter(Mandatory = $false, position = 11)][string]$Period,
        #Description
        [Parameter(Mandatory = $false, position = 12)][string]$Description,
        [Parameter(Mandatory = $false, position = 13)][ValidateSet($True, $False)]$WhatIf = $False
    )
        $AS = (Get-Date $ActiveSince -UFormat %s) - 10800
        $AT = (Get-Date $ActiveTill -UFormat %s) - 10800

        switch ($MaintenanceType) {
            "NoData" { $mType = 1 }
            "WithData" { $mType = 0 }
            Default { $mType = 0 }
        }

        $NameMaintenanceJ = $NameMaintenance.Substring(0, [System.Math]::Min(128, $NameMaintenance.length))

        $createMaintenance = @{
            "jsonrpc" = "2.0";
            "method"  = "maintenance.create";
            "params"  = @{
                "name"             = "$NameMaintenanceJ";
                "active_since"     = $AS;
                "active_till"      = $AT;
                "maintenance_type" = $mType
            };
            "auth"    = $TokenApi;
            "id"      = $TokenId
        }

        #Periods for only=0
        if( $Timeperiod_type -eq 0){
            #Converting the launch date and time to unix format.
            $periodStartDate = (Get-Date $Start_date -UFormat %s) - 10800

            #Period time tranclate it into seconds.
            $periods = $Period -split ';'
            $arrPeriod = @()
            foreach ($onePeriod in $periods){
                    if     ( $onePeriod -like "*d" ){ $fPeriod = [int]($onePeriod -replace "d") * 86400 }
                    elseif ( $onePeriod -like "*h" ){ $fPeriod = [int]($onePeriod -replace "h") * 3600  }
                    elseif ( $onePeriod -like "*m" ){ $fPeriod = [int]($onePeriod -replace "m") * 60    }
                    else   { $fPeriod = 3600 }
                    $arrPeriod += $fPeriod
                }
            $fPeriodR = ($arrPeriod | Measure-Object -Sum).sum

            #Add periods
            $periods = @{
                "timeperiod_type" = $Timeperiod_type
                "period"          = $fPeriodR
                "start_date"      = $periodStartDate  
            }
            
            $jsonPeriods = (ConvertTo-Json -InputObject $periods -Depth 10 -Compress) -replace '\\"','"' -replace '"\[', '[' -replace '\]"', ']' -replace '"{', '{' -replace '}"', '}'
            $createMaintenance.params.Add("timeperiods", @($jsonPeriods))
        }

        #Add groupids or hostids
        $findVar = ($GroupIds + $HostIds)      
        if ( -Not $findVar ) {
            Write-Error -Message "Please make sure to set one of the groupids or hostids parameters" -ErrorAction Stop
        }
        else {
            if ($GroupIds) {
                $arrGroupId = @()
                foreach( $oneGroupId in ($GroupIds -split ",") ){
                    $resGroupId = ( '{"groupid":"' + $oneGroupId + '"}' )
                    $arrGroupId += $resGroupId
                }
                $addGroupId = $arrGroupId -join ","
                $createMaintenance.params.Add("groups", @($addGroupId))
            }
            if ($HostIds) {
                $arrHostId = @()
                foreach( $oneHostId in ($HostIds -split ",") ){
                    $resHostId = ( '{"hostid":"' + $oneHostId + '"}' )
                    $arrHostId += $resHostId
                }
                $addHostId = $arrHostId -join ","
                $createMaintenance.params.Add("hosts", @($addHostId))
            }
        }

        #Description
        if($Description){
            $createMaintenance.params.Add("description", $Description)
        }

        $json = (ConvertTo-Json -InputObject $createMaintenance -Depth 10 -Compress) -replace '\\"','"' -replace '"\[', '[' -replace '\]"', ']' -replace '"{', '{' -replace '}"', '}' -replace '\\r'
        If($WhatIf -eq $true){
            return $json
        }else{
            $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
            if($res.error){
                return $res.error
            }else{ return $res.result }
        }
}

function Set-MaintenanceZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to create new maintenances, via Zabbix API
    .PARAMETER NameMaintenance
        Name Maintenance. Example: -NameMaintenance "Maintenance_1"
    .PARAMETER ActiveSince
        Time when the maintenance becomes active. Example: -ActiveSince "20.04.2024 00:00"
    .PARAMETER ActiveTill
        Time when the maintenance stops being active. Example: -ActiveTill "20.05.2024 00:00"
    .PARAMETER MaintenanceType
        Type of maintenance. Possible values: WithData - (default) with data collection; NoData - without data collection. Example: -MaintenanceType NoData
    .PARAMETER GroupIds
        Host groups that will undergo maintenance. The host groups must have the groupid property defined. At least one object of groups or hosts must be specified. Example: -GroupIds "31,34,121"
    .PARAMETER HostIds
        Hosts that will undergo maintenance.The hosts must have the hostid property defined. At least one object of groups or hosts must be specified. Example: -HostIds "13123,4456" 
    .PARAMETER Timeperiod_type
        "One time only"=0, "daily"=2, "weekly"=3, "mounthly"=4.Release only "One time only". Example: -Timeperiod_type 0
    .PARAMETER Start_date
        Datetime start period. Example: -Start_date "25.04.20024 23:00"
    .PARAMETER Period
        Maintenance period scheduled, parameters day-1d, or hours-1h or minutes-30m. Example: -Period 1d. Example -Period 1d;6h;30m
    .PARAMETER PeriodJSON
        Example: [{"timeperiod_type":"0","every":"1","month":"0","dayofweek":"0","day":"0","start_time":"0","period":"40200","start_date":"1695189000"}] 
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][int]$MaintenanceId,
        [Parameter(Mandatory = $false, position = 4)][string]$NameMaintenance,
        [Parameter(Mandatory = $false, position = 5)][datetime]$ActiveSince,
        [Parameter(Mandatory = $false, position = 6)][datetime]$ActiveTill,
        [Parameter(Mandatory = $false, position = 7)][ValidateSet("WithData", "NoData")]$MaintenanceType,
        [Parameter(Mandatory = $false, position = 8)][array]$GroupIds,
        [Parameter(Mandatory = $false, position = 9)][array]$HostIds,
        #Periods
        #One time only = 0, Daily = 2, Weekly = 3, Monthly = 4.
        [Parameter(Mandatory = $false, position = 10)][ValidateSet(0)][int]$timeperiod_type,
        [Parameter(Mandatory = $false, position = 11)][string]$Start_date,
        [Parameter(Mandatory = $false, position = 12)][string]$Period,
        #PeriodsJSON
        [Parameter(Mandatory = $false, position = 13)][string]$PeriodJSON,
        [Parameter(Mandatory = $false, position = 14)][ValidateSet($True, $False)]$WhatIf = $False
    )
    $updateMaintenance = @{
        "jsonrpc" = "2.0";
        "method"  = "maintenance.update";
        "params"  = @{
            "maintenanceid" = $MaintenanceId
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }
    #name
    if ($NameMaintenance) {
        $updateMaintenance.params.add("name", $NameMaintenance.Substring(0, [System.Math]::Min(128, $NameMaintenance.length)) )
    }
    #active_since
    if ($ActiveSince) {
        $AS = Get-Date $ActiveSince -UFormat %s
        $updateMaintenance.params.add("active_since", $AS)
    }
    #active_till
    if ($ActiveTill) {
        $AT = Get-Date $ActiveTill -UFormat %s
        $updateMaintenance.params.add("active_till", $AT)
    }
    #maintenance_type
    if ($MaintenanceType) {
        switch ($MaintenanceType) {
            "NoData" { $mType = 1 }
            "WithData" { $mType = 0 }
            Default { $mType = 0 }
        }
        $updateMaintenance.params.add("maintenance_type", $mType)
    }
    #Add groupids
    if ($groupids) {
        $cGroupids = $groupids -replace "\s" -replace '([^,]+)','"$1"'
        $updateMaintenance.params.Add("groupids", @($cGroupids))
    }
    #Add hostids
    if ($hostids) {
        $cHostids = $hostids -replace "\s" -replace '([^,]+)','"$1"'
        $updateMaintenance.params.Add("hostids", @($cHostids))
    }

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
            #"every"=$periodEvery   #"month"=$periodMonth   #"dayofweek"=$periodDayofweek   #"day"=$periodDay   #"start_time"=$periodStartTime
            "period" = $fPeriodR
            "start_date" = $fDateJ
        }
        return $periodObj
    }
    #If only variables are present $timeperiod_type , $Start_date , $Period
    if($timeperiod_type -match '\w' -and $Start_date -match '\w' -and $Period -match '\w' -and $PeriodJSON -notmatch '\w' ){   
        $resultPeriods = (manualPeriods -timeperiod_type $timeperiod_type -Start_date $Start_date -Period $Period) | ConvertTo-Json
    }
    #If only variables are present $PeriodJSON 
    if ($PeriodJSON -match '\w' -and $timeperiod_type -notmatch '\w' -and $Start_date -notmatch '\w' -and $Period -notmatch '\w') { 
        $resultPeriods = $PeriodJSON
    }
    #If all variables are present $timeperiod_type , $Start_date , $Period , $PeriodJSON 
    if ($timeperiod_type -match '\w' -and $Start_date -match '\w' -and $Period -match '\w' -and $PeriodJSON -match '\w') { 
       [array]$arrPeriodJSON = ($PeriodJSON | ConvertFrom-Json) | Select-Object timeperiod_type, period, start_date
       $arrPeriodManual_ = (manualPeriods -timeperiod_type $timeperiod_type -Start_date $Start_date -Period $Period) | ConvertTo-Json | ConvertFrom-Json
       $arrPeriodManual = $arrPeriodManual_ | Select-Object timeperiod_type, period, start_date

       $arrPeriodsJoin = @()
       $arrPeriodsJoin += $arrPeriodJSON 
       $arrPeriodsJoin += $arrPeriodManual

       #Build JSON
       $arrBuildJson = @()
       foreach( $onePeriodsJoin in $arrPeriodsJoin){
            $buildJson = ('{"timeperiod_type":"'+ $onePeriodsJoin.timeperiod_type +'","period":"'+ $onePeriodsJoin.period +'","start_date":"'+ $onePeriodsJoin.start_date +'"}')
            $arrBuildJson += $buildJson
       }
       $resultPeriods = ($arrBuildJson -join ',')
    }
    $updateMaintenance.params.Add("timeperiods",@($resultPeriods))
    
    $json = (ConvertTo-Json -InputObject $updateMaintenance -Compress) -replace '\\r\\n' -replace '\\' -replace '\s\s+' -replace '"\[', '[' -replace '\]"', ']' -replace '"{','{' -replace '}"','}' -replace '""','"'
    If($WhatIf -eq $true){
        return $json
    }else{
        $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
        if($res.error){
            return $res.error
        }else{ return $res.result }
    }
}

function Remove-MaintenanceZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][array]$MaintenanceId
    )

    $deleteMaintenance = @{
        "jsonrpc" = "2.0";
        "method"  = "maintenance.delete";
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }

    $deleteMaintenance.Add("params", @($MaintenanceId -split ","))

    $json = (ConvertTo-Json -InputObject $deleteMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working with Item Zabbix API.
function New-ItemZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][string]$itemName,
        [Parameter(Mandatory = $true, position = 4)][string]$itemKey,
        [Parameter(Mandatory = $true, position = 5)][int]$hostIDorTemplateID,
        <#Type: Possible values:
        0 - Zabbix agent;
        2 - Zabbix trapper;
        3 - Simple check;
        5 - Zabbix internal;
        7 - Zabbix agent (active);
        9 - Web item;
        10 - External check;
        11 - Database monitor;
        12 - IPMI agent;
        13 - SSH agent;
        14 - Telnet agent;
        15 - Calculated;
        16 - JMX agent;
        17 - SNMP trap;
        18 - Dependent item;
        19 - HTTP agent;
        20 - SNMP agent;
        21 - Script
        #>
        [Parameter(Mandatory = $true, position = 6)][int]$itemType = 7

        <#Value Type Possible values:
        0 - numeric float;
        1 - character;
        2 - log;
        3 - numeric unsigned;
        4 - text.
        #>
    )  
    $createItem = @{
        "jsonrpc" = "2.0";
        "method"  = "item.create";
        "params"  = @{
            "name"        = "$itemName";
            "key_"        = "$itemKey";
            "hostid"      = $hostIDorTemplateID ;
            "type"        = $itemType;
            "value_type"  = 2;
            "delay"       = "2m";
            "description" = ""
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    }   
    $json = (ConvertTo-Json -InputObject $createItem) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}

function Get-ItemZabbixAPI {
    <#
    .SYNOPSIS
        ...
    .PARAMETER Item
        Required parameter. Select item is Static or is Prototype (created in discovery). 
    .PARAMETER Hosts
        Return only items that belong to a host with the given name. Return only items that belong to the given hosts.
    .PARAMETER Groupids
        Return only items that belong to the hosts from the given groups.
    .PARAMETER GroupName
        Return only items that belong to a group with the given name.
    .PARAMETER Templated
        Return only items that belong to the given templates.
    .PARAMETER Webitems
        Include web items in the result.
    .PARAMETER Inherited
        If set to true return only items inherited from a template.
    .PARAMETER Templated
        If set to true return only items that belong to templates.
    .PARAMETER Monitored
        If set to true return only enabled items that belong to monitored hosts.
    .PARAMETER With_triggers
        If set to true return only items that are used in triggers.
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][ValidateSet('Static', 'Prototype')]$Item,
        #Возврат только тех элементов данных, которые принадлежат заданным узлам сети hostid\host.
        [Parameter(Mandatory = $false, position = 4)]$Hosts,
        #Возврат только тех элементов данных, которые принадлежат узлам сети с заданных групп узлов сети.
        [Parameter(Mandatory = $false, position = 5)][int]$Groupids,
        [Parameter(Mandatory = $false, position = 6)][string]$GroupName,
        #Возврат только тех элементов данных, которые принадлежат заданным шаблонам. строка/массив
        [Parameter(Mandatory = $false, position = 7)][int]$Templateids,
        #Включение в результат веб элементов данных. Enable=1
        [Parameter(Mandatory = $false, position = 8)][switch]$Webitems,
        #Если задано значение true, возвращать только те элементы, которые унаследованы из шаблона.
        [Parameter(Mandatory = $false, position = 9)][ValidateSet('true', 'false')]$Inherited,
        #Если задано значение true, возвращать только те элементы, которые принадлежат шаблонам.
        [Parameter(Mandatory = $false, position = 10)][ValidateSet('true', 'false')]$Templated,
        #Если задано значение true, возвращать только активированные элементы данных, которые принадлежат узлам сети под наблюдением.
        [Parameter(Mandatory = $false, position = 11)][ValidateSet('true', 'false')]$Monitored,
        #Если задано значение true, возвращать только те элементы данных, которые используются в триггерах.
        [Parameter(Mandatory = $false, position = 12)][ValidateSet('true', 'false')]$With_triggers
    )

    if($Item -eq 'Static'){
        $itemGet = @{
            "jsonrpc" = "2.0";
            "method" = "item.get";
            "params" = @{
                "output" = "extend";         
                "sortfield" = "name"
            };
            "auth" = $TokenApi;
            "id" = $TokenId
        }
    }
    if($Item -eq 'Prototype'){
        $itemGet = @{
            "jsonrpc" = "2.0";
            "method" = "itemprototype.get";
            "params" = @{
                "output" = "extend";         
                "sortfield" = "name"
            };
            "auth" = $TokenApi;
            "id" = $TokenId
        }
    }
    
    if ( $Hosts.GetType().Name -eq "String" ) {
        $itemGet.params.Add("host",$Hosts)
    }
    if ( $Hosts.GetType().Name -eq "Int32" ) {
        $itemGet.params.Add("hostids",$Hosts)
    }
    #Group
    if($Groupids){ $itemGet.params.Add("groupids", $Groupids)}
    if($GroupName){ $itemGet.params.Add("group", $GroupName)}
    #Template
    if($Templateids){ $itemGet.params.Add("templateids", $Templateids)}
    ###
    if($Webitems){ $itemGet.params.Add("webitems", 1)}
    if($Inherited){ $itemGet.params.Add("inherited", $Inherited)}
    if($Templated){ $itemGet.params.Add("templated", $Templated)}
    if($Monitored){ $itemGet.params.Add("monitored", $Monitored)}
    if($With_triggers){ $itemGet.params.Add("with_triggers", $With_triggers)}

     
    $json = (ConvertTo-Json -InputObject $itemGet) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working with Trigger Zabbix API.
function New-TriggerZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][string]$triggerName,
        #Trigger key example: "logeventid(/Name_Tamplate_Or_Host/eventlog[,,,,5555,,skip],#1)=1"
        [Parameter(Mandatory = $true, position = 4)][string]$triggerKey,
        [Parameter(Mandatory = $true, position = 5)][string]$triggerDescription
    )
    $createTrigger = @{
        "jsonrpc" = "2.0";
        "method"  = "trigger.create";
        "params"  = @(@{
                "description"  = "$triggerName";
                "expression"   = "$triggerKey";
                "hostid"       = $hostIDorTemplateID ;
                "comments"     = $triggerDescription;
                "priority"     = 3;
                "type"         = 0;
                "manual_close" = 1
            });
        "auth"    = $TokenApi;
        "id"      = $TokenId
    } 
    $json = (ConvertTo-Json -InputObject $createTrigger) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

function Get-TriggerZabbixAPI{
    <#
    .SYNOPSIS
        ...
    .PARAMETER Trigger
        Required parameter. Select triger is Static or is Prototype (created in discovery). Example -Trigger Static
    .PARAMETER Templateids
        Return only triggers that belong to the given templates
    .PARAMETER Inherited
        If set to true return only triggers inherited from a template
    .PARAMETER Templated
        If set to true return only triggers that belong to templates
    .PARAMETER Monitored
        Return only enabled triggers that belong to monitored hosts and contain only enabled items
    .PARAMETER Active
        Return only enabled triggers that belong to monitored hosts
    .PARAMETER Only_true
        Return only triggers that have recently been in a problem state
    .PARAMETER ExpandComment
        Expand macros in the trigger description.
    .PARAMETER ExpandDescription
        Expand macros in the name of the trigger
    .PARAMETER ExpandExpression
        Expand functions and macros in the trigger expression
    .PARAMETER ExpandTags
        Expand Tag in the trigger
    .PARAMETER ExpandItems
        Return items contained by the trigger in the items property
    .PARAMETER Legend
        Return Legend for status, value, priority
    .EXAMPLE
        Get-TriggerZabbixAPI -urlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi 'Created_by_you_Token' -TokenId 'Created_by_you__id' -Trigger Static -HostName host.domain.local -Monitored -expandComment -expandDescription -selectTags
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,

        [Parameter(Mandatory = $true, position = 3)][ValidateSet('Static', 'Prototype')]$Trigger,

        #Возврат только тех триггеров, которые принадлежат заданным узлам сети.
        [Parameter(Mandatory = $false, position = 4)][int]$Hostids,
        [Parameter(Mandatory = $false, position = 5)][string]$HostName,
        #Возврат только тех триггеров, которые принадлежат узлам сети из заданных групп узлов сети.
        [Parameter(Mandatory = $false, position = 6)][int]$Groupids,
        [Parameter(Mandatory = $false, position = 7)][string]$GroupName,
        #Возврат только тех триггеров, которые принадлежат заданным шаблонам.
        [Parameter(Mandatory = $false, position = 8, HelpMessage='Return only triggers that belong to the given templates')][int]$Templateids,
        [Parameter(Mandatory = $false, position = 9)][switch]$ExpandTriggerDiscovery,

        #Если задано значение true, возвращать только те триггеры, которые унаследованы из шаблона.
        [Parameter(Mandatory = $false, position = 10, HelpMessage='If set to true return only triggers inherited from a template')][ValidateSet('true', 'false')]$Inherited,
        #Если задано значение true, возвращать только те триггеры, которые принадлежат шаблонам.
        [Parameter(Mandatory = $false, position = 11, HelpMessage='If set to true return only triggers that belong to templates')][ValidateSet('true', 'false')]$Templated,

        #Возврат только активированных триггеров, которые принадлежат узлам сети под наблюдением и содержат только активированные элементы данных. Enable=1
        [Parameter(Mandatory = $false, position = 12, HelpMessage='Return only enabled triggers that belong to monitored hosts and contain only enabled items')][switch]$Monitored,
        #Возврат только активированных триггеров, которые принадлежат узлам сети под наблюдением. Enable=1
        [Parameter(Mandatory = $false, position = 13, HelpMessage='Return only enabled triggers that belong to monitored hosts')][switch]$Active,
        #Возврат только тех триггеров, которые недавно были в состоянии проблема. Enable=1
        [Parameter(Mandatory = $false, position = 14, HelpMessage='Return only triggers that have recently been in a problem state')][switch]$Only_true,

        #Раскрытие макросов в описании к триггеру. Enable=1
        [Parameter(Mandatory = $false, position = 15, HelpMessage='Expand macros in the trigger description')][switch]$ExpandComment,
        #Раскрытие макросов в имени триггера. Enable=1
        [Parameter(Mandatory = $false, position = 16, HelpMessage='Expand macros in the name of the trigger')][switch]$ExpandDescription,
        #Раскрытие функций и макросов в выражении триггера. Enable=1
        [Parameter(Mandatory = $false, position = 17, HelpMessage='Expand functions and macros in the trigger expression')][switch]$ExpandExpression,
        
        #Возврат тегов триггера в свойстве tags.
        [Parameter(Mandatory = $false, position = 18)][switch]$ExpandTags,
    
        #Возврат элементов данных, которые содержатся в выражении триггера, в свойстве items.
        [Parameter(Mandatory = $false, position = 19)][switch]$ExpandItems,
        [Parameter(Mandatory = $false, position = 20)][switch]$Legend
    )

    If($Trigger -eq 'Static'){
        $getTrigger = @{
            "jsonrpc" = "2.0";
            "method"  = "trigger.get";
            "params"  = @{
                "output"= "extend";
                };
            "auth"    = $TokenApi;
            "id"      = $TokenId
        }
    }
    If($Trigger -eq 'Prototype'){
        $getTrigger = @{
            "jsonrpc" = "2.0";
            "method"  = "triggerprototype.get";
            "params"  = @{
                "output"= "extend";
                };
            "auth"    = $TokenApi;
            "id"      = $TokenId
        }
    }

    #Host
    if($Hostids  ){ $getTrigger.params.add("hostids", $Hostids)}
    if($HostName ){ $getTrigger.params.add("host", $HostName)}
    #Groups
    if($Groupids){ $getTrigger.params.add("groupids", $Groupids)}
    if($GroupName){ $getTrigger.params.add("group", $GroupName)}
    #Template
    if($templateids){ $getTrigger.params.add("templateids", $templateids)}
    if($inherited){ $getTrigger.params.add("inherited", $inherited)}
    if($templated){ $getTrigger.params.add("templated", $templated)}
    if($ExpandTriggerDiscovery){ $getTrigger.params.add("selectTriggerDiscovery", "extend")}
    #Trigers
    if($monitored){ $getTrigger.params.add("monitored", 1)}
    if($active){ $getTrigger.params.add("active", 1)}
    if($only_true){ $getTrigger.params.add("only_true", 1)}
    #Macros
    if($expandComment){ $getTrigger.params.add("expandComment", 1)}
    if($expandDescription){ $getTrigger.params.add("expandDescription", 1)}
    if($expandExpression){ $getTrigger.params.add("expandExpression", 1)}
    #Tag
    if($ExpandTags){ $getTrigger.params.add("selectTags", "extend")}
    #Items
    if($ExpandItems){ $getTrigger.params.add("selectItems", "extend")}

    if($Legend){
        Write-Host '#LEGEND                                                                       ' -BackgroundColor Green
        Write-Host '#Status  : 0-Enable        1-Disable                                          ' -BackgroundColor Green
        Write-Host '#Value   : 0-Ok            1-Problem                                          ' -BackgroundColor Green
        Write-Host '#Priority: 0-notClassified 1-information 2-warning 3-average 4-high 5-disaster' -BackgroundColor Green
        }

    $json = (ConvertTo-Json -InputObject $getTrigger) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Work with Graph Zabbix API.
function Get-GraphZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][int]$hostids
    )
    $getGraph = @{
        "jsonrpc" = "2.0";
        "method"  = "graph.get";
        "params"  = @{
            "output"    = "extend";
            "hostids"   = $hostids;
            "sortfield" = "name"
        };
        "auth"    = $TokenApi;
        "id"      = $TokenId
    } 
    $json = (ConvertTo-Json -InputObject $getGraph) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}
#Connect and Autorization to Zabbix WEB.
function Connect-ZabbixWEB {
    <#
    .SYNOPSIS
        Authorization and receipt of cookie on the Zabbix website (Example: http://IP_or_FQDN/zabbix/index.php?login=1). Cookie is necessary for further access to the web without the need to enter a login and password.
        Add the command as a variable to save and use the web session in other commands, based on cookies.
    .PARAMETER UrlWeb
        Specify the URL to connect to the Zabbix Web. Example -UrlWeb 'http://IP_or_FQDN/zabbix'
    .PARAMETER User
        A Zabbix user who has rights to connect to the Zabbix Web. Example: -User UserAdmin
    .PARAMETER inPasswd
        Enter the password. If you do not specify a password, the system will ask you to enter it.
    .EXAMPLE
        Connect-ZabbixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -User UserAdmin
        Connect-ZabbixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -User UserAdmin -inPasswd "Passw0rd"
    #>
    param(
        [Parameter(Mandatory = $true, position = 0)][string]$UrlWeb,
        [Parameter(Mandatory = $true, position = 1)][string]$User,
        [Parameter(Mandatory = $false, position = 2, ParameterSetName = "Passwd")]$inPasswd
    )
    if ( $inPasswd ) {
        $str = $inPasswd
    }
    else {
        $passwdAdmin = Read-Host "Enter password" -AsSecureString
        $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwdAdmin)
        $str = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
    } 

    $loginPostData = @{
        name     = $User;
        password = $str;
        enter    = "Enter"
    }
    $invokeWebReq = Invoke-WebRequest -Method Post -Uri ($UrlWeb + "/index.php?login=1") -Body $loginPostData -SessionVariable zabbixSession -UserAgent Chrome
    return $zabbixSession
}
#Save the graph as a PNG file.
function Save-GraphZabixWEB {
    <#
    .SYNOPSIS
        Original url with PNG Graph Host "http://IP_or_FQDN/zabbix/chart2.php?graphid=2292&from=now-60m&to=now&height=201&width=1436&profileIdx=web.charts.filter"
        Original url with PNG Graph Item  "http://IP_or_FQDN/zabbix/chart.php?from=now-1h&to=now&itemids%5B0%5D=42714&type=0&profileIdx=web.item.graph.filter&profileIdx2=46112&width=1530&height=200&_=vuvt401w"
        ####
        If we use the host graph. Example:
        #1.
        Use commandlet Connect-ZabbixWEB then Get-graphZabbixAPI.
        #2.
        Save-GraphZabixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -graphId 33065 -timeFrom "now-24h" -timeTo "now" -imgHeight "200" -imgWidth "1530" -imgSave "C:\img\graphHost.png" -WebSession $sessionCookie 
        ####
        If we use the item graph. Example:
        #1.
        Use commandle Connect-ZabbixWEB then Get-ItemZabbixAPI.
        #2.
        Save-GraphZabixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -graphId_Item 44658 -timeFrom "now-24h" -timeTo "now" -imgHeight "200" -imgWidth "1530" -imgSave "C:\img\graphItem.png" -WebSession $sessionCookie
    .PARAMETER UrlWeb
        Specify the URL to connect to the Zabbix Web. Example -UrlWeb 'http://IP_or_FQDN/zabbix'
    .PARAMETER graphId
        The ID of the graph, we will find out through Get-graphZabbixAPI. Example: -graphId 22013
    .PARAMETER graphId_Item
        The ID of the item, we will find out through Get-ItemZabbixAPI. Example: -graphId_Item 36276
    .PARAMETER timeFrom
        m - minutes; h - hour; d - day; M - months; y - year. Example: -timeFrom "now-15m"
    .PARAMETER timeTo
        Example: -timeTo "now"
    .PARAMETER imgHeight
        Image height. Example -imgHeight 201
    .PARAMETER imgWidth
        Imagw width. Example -imgWidth 1436
    .PARAMETER imgSave
        Where do we save the downloaded files. Example: -$imgSave "C:\img\imgFile.png"
    .PARAMETER WebSession
        Send cookie to a web session, execute Connect-ZabbixWEB. Example: -WebSession $sessionCookie
    .EXAMPLE
        Save-GraphZabixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -graphId 22013 -timeFrom "now-2d" -timeTo "now" -imgHeight "201" -imgWidth "1436" -imgSave "C:\img\imgFile.png" -WebSession $sessionCookie
    .EXAMPLE
        Save-GraphZabixWEB -UrlWeb 'http://IP_or_FQDN/zabbix' -graphId_Item $itemId -timeFrom "now-24h" -timeTo "now" -imgHeight "200" -imgWidth "1530" -imgSave "C:\img\graphItem.png" -WebSession $sessionCookie
        #>
    param(
        [Parameter(Mandatory = $true,  position = 0)][string]$UrlWeb,
        [Parameter(Mandatory = $false, position = 1)][int]$graphId,
        [Parameter(Mandatory = $false, position = 2)][int]$graphId_Item,
        [Parameter(Mandatory = $true,  position = 3)][string]$timeFrom,
        [Parameter(Mandatory = $true,  position = 4)][string]$timeTo,
        [Parameter(Mandatory = $false, position = 5)][int]$imgHeight = 201,
        [Parameter(Mandatory = $false, position = 6)][int]$imgWidth = 1436,
        [Parameter(Mandatory = $true,  position = 7)][string]$imgSave,
        [Parameter(Mandatory = $true,  position = 8)]$WebSession
    )
    if ( $graphId ) {
        $imgUrlJoin = ($UrlWeb +"/chart2.php?graphid="+ $graphId +"&from="+ $timeFrom +"&to="+ $timeTo +"&height="+ $imgHeight +"&width="+ $imgWidth +"&profileIdx=web.charts.filter")
    }
    if ( $graphId_Item ){
        $imgUrlJoin = ($UrlWeb +"/chart.php?from="+ $timeFrom +"&to="+ $timeTo +"&itemids%5B0%5D="+ $graphId_Item +"&type=0&profileIdx=web.item.graph.filter&profileIdx2=46112&width="+ $imgWidth +"&height="+ $imgHeight +"&_=vuvt401w")
    }
    Invoke-WebRequest -Method Post -Uri $imgUrlJoin -WebSession $WebSession -UserAgent Chrome -OutFile $imgSave
}

#########################################
#Work with Action Zabbix API.
function Get-ActionZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        #Вернуть только действия с заданными идентификаторами
        [Parameter(Mandatory = $false, position = 3)][int]$Actionids,
        #Вернуть только действия, использующие в своих условиях заданные группы узлов сети
        [Parameter(Mandatory = $false, position = 4)][int]$Hostids,
        #Вернуть только действия, использующие в своих условиях указанные узлы сети
        [Parameter(Mandatory = $false, position = 5)][int]$Groupids,
        #Вернуть только действия, использующие в своих условиях данные триггеры
        [Parameter(Mandatory = $false, position = 6)][int]$Triggerids,

        #Вернуть только действия, использующие данные способы оповещения для отправки сообщений.
        [Parameter(Mandatory = $false, position = 7)][int]$Mediatypeids,
        #Вернуть только действия, настроенные на отправку сообщений указанным группам пользователей.
        [Parameter(Mandatory = $false, position = 8)][int]$Usrgrpids,
        #Вернуть только действия, настроенные на отправку сообщений указанным пользователям.
        [Parameter(Mandatory = $false, position = 9)][int]$Userids,
        #Вернуть только действия, настроенные для запуска заданных сценариев.
        [Parameter(Mandatory = $false, position = 10)][int]$Scriptids

    )
    $getAction = @{
        "jsonrpc" = "2.0";
        "method" = "action.get";
        "params" = @{
            "output" = "extend";         
            "selectOperations" = "extend";
            "selectRecoveryOperations" = "extend";
            "selectUpdateOperations" = "extend";
            "selectFilter" = "extend";
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }

    if($Actionids ){ $getAction.params.add("actionids" , $Actionids)}
    if($Hostids   ){ $getAction.params.add("hostids"   , $Hostids)}
    if($Groupids  ){ $getAction.params.add("groupids"  , $Groupids)}
    if($Triggerids){ $getAction.params.add("triggerids", $Triggerids)}

    if($mediatypeids){ $getAction.params.add("mediatypeids", $mediatypeids)}
    if($usrgrpids   ){ $getAction.params.add("usrgrpids"   , $usrgrpids)}
    if($userids     ){ $getAction.params.add("userids"     , $userids)}
    if($scriptids   ){ $getAction.params.add("scriptids"   , $scriptids)}


    $json = (ConvertTo-Json -InputObject $getAction) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working with hosts interface Zabbix API.
function Get-HostInterfaceZabbixAPI{
    <#
    .Example
        #Return all host interface used..
        Get-HostInterfaceZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2
    .Example
        #Return only host interface used by the given hosts..
        Get-HostInterfaceZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -Search 50023 -SearchObj hostid
    .Example
        #Return a hosts property with an array of host that use the interface.
        Get-HostInterfaceZabbixAPI  -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -Search "host1,host2" -SearchObj dns
    #>
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $false, position = 3)][int]$Hostid,
        [Parameter(Mandatory = $false, position = 4)][int]$interfaceid,
        [Parameter(Mandatory = $false, position = 5)][string]$Search,
        [Parameter(Mandatory = $false, position = 6)][ValidateSet("hostid", "dns", "ip", "port", "available", "error")]$SearchObj
    )

    function jsonGetHostInterfaceCore(){
        $getHost = @{
            "jsonrpc" = "2.0";
            "method"  = "hostinterface.get";
            "params"  = @{
                "output"       = "extend"
            };
            "auth"    = $TokenApi;
            "id"      = $TokenId;
        }
        return $getHost
    }

    function InvokeRestMethod_HostInterface($InputObject){
        $json = (ConvertTo-Json -InputObject $InputObject) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
        $res = Invoke-RestMethod -Method 'Post' -Uri $UrlApi -Body $json -ContentType "application/json;charset=UTF-8"
        return $res
    }

    #Output SearchObj.
    if ($search) {
        $arrSearchHS = @()
        foreach ( $oneSearchHS in ($Search -split ",") ) {
            $filterSearchName = @{ $SearchObj = @($oneSearchHS)}
            $getHostSearch = jsonGetHostInterfaceCore
            $getHostSearch.params.Add("search", $filterSearchName)
            $res = InvokeRestMethod_HostInterface($getHostSearch)
            $arrSearchHS += $res.result
        } 
        return $arrSearchHS
    }
    #Output All interface
    else{
        $getHostSearch = jsonGetHostInterfaceCore
        if ($Hostid){ $getHostSearch.params.Add("hostids",$Hostid) }
        if ($interfaceid){ $getHostSearch.params.Add("interfaceids", $interfaceid) }
        $res = InvokeRestMethod_HostInterface($getHostSearch)
        return $res.result
    }
}

#Host update Interface Zabbix API.
function Set-HostInterfaceZabbixAPI{

    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        [Parameter(Mandatory = $true, position = 3)][int]$InterfaceId,

        [Parameter(Mandatory = $false, position = 4)][string]$DNS,
        [Parameter(Mandatory = $false, position = 5)][string]$IP,
        [Parameter(Mandatory = $false, position = 6)][int]$Port,
        #Possible values: 1 - Zabbix agent; 2 - SNMP; 3 - IPMI; 4 - JMX.
        [Parameter(Mandatory = $false, position = 7)][ValidateSet("1-Agent","2-SNMP","3-IPMI","4-JMX")]$Type,
        #Possible values: 0-Defaut; 1- NotDefault.
        [Parameter(Mandatory = $false, position = 8)][ValidateSet("0-Default","1-NotDefault")]$Main,
        #Possible values: 0 - use DNS; 1 - use IP
        [Parameter(Mandatory = $false, position = 9)][ValidateSet("0-DNS use","1-IP use")]$UseIP,
        #Possible values: 1 - SNMPv1; 2 - SNMPv2c; 3 - SNMPv3.
        [Parameter(Mandatory = $false, position = 10)][ValidateSet("1-SNMPv1","2-SNMPv2c","3-SNMPv3")]$SNMP_Version,
        [Parameter(Mandatory = $false, position = 11)][string]$Contextname,
        [Parameter(Mandatory = $false, position = 12)][string]$Community,
        [Parameter(Mandatory = $false, position = 13)][string]$SecurityName,
        #Possible values are: 0 - noAuthNoPriv; 1 - authNoPriv; 2 - authPriv.
        [Parameter(Mandatory = $false, position = 14)][ValidateSet("0-noAuthNoPriv","1-authNoPriv","2-authPriv")]$Securitylevel,
        #Possible values are: 0 - MD5; 1 - SHA1; 2 - SHA224; 3 - SHA256; 4 - SHA384; 5 - SHA512.
        [Parameter(Mandatory = $false, position = 15)][ValidateSet("0-MD5","1-SHA1","2-SHA224","3-SHA256","4-SHA384","5-SHA512")]$Authprotocol,
        [Parameter(Mandatory = $false, position = 16)][string]$Authpassphrase,
        #Possible values are: 0 - DES; 1 - AES128; 2 - AES192; 3 - AES256; 4 - AES192C; 5 - AES256C.
        [Parameter(Mandatory = $false, position = 17)][ValidateSet("0-DES","1-AES128","2-AES192","3-AES256","4-AES192C","5-AES256C")]$Privprotocol,
        [Parameter(Mandatory = $false, position = 18)][string]$Privpassphrase,
        #Possible values: 0 - don't use bulk requests; 1 - (default) - use bulk requests.
        [Parameter(Mandatory = $false, position = 19)][ValidateSet("0-not builk requests","1-builk requests")]$Bulk
    )

    function jsonSetHostInterfaceCore(){
        $HostInterfaceUpdate = @{
            "jsonrpc" = "2.0";
            "method"  = "hostinterface.update";
            "params"  = @{
                "output"       = "extend"
                "details"      = @{}
            };
            "auth"    = $TokenApi;
            "id"      = $TokenId;
        }
        return $HostInterfaceUpdate
    }
    <#
    $arrInterfaceId = @()
    foreach ( $oneInterfaceId in ($InterfaceId -split ",") ){
       $arrInterfaceId += ('"'+ $oneInterfaceId +'"')
    }
    $allInterfaceId = $arrInterfaceId -join ","
    #>
    $setHostInterface = jsonSetHostInterfaceCore

    $setHostInterface.params.Add("interfaceid", $InterfaceId ) 
    if($DNS)            { $setHostInterface.params.Add("dns", $DNS ) }
    if($IP)             { $setHostInterface.params.Add("ip", $IP ) }
    if($Port)           { $setHostInterface.params.Add("Port", $Port ) }
    if($Contextname)    { $setHostInterface.params.details.Add("contextname", $Contextname ) }
    if($Community)      { $setHostInterface.params.details.Add("community", $Community ) }
    if($SecurityName)   { $setHostInterface.params.details.Add("securityname", $SecurityName ) }
    if($Authpassphrase) { $setHostInterface.params.details.Add("authpassphrase", $Authpassphrase ) }
    if($Privpassphrase) { $setHostInterface.params.details.Add("privpassphrase", $Privpassphrase ) }
    if($Type)           { $setHostInterface.params.Add("type", $($Type -split "-")[0] ) }
    if($Main)           { $setHostInterface.params.Add("main", $($Main -split "-")[0] ) }
    if($UseIP)          { $setHostInterface.params.Add("useip", $($UseIP -split "-")[0] ) }
    if($SNMP_Version)   { $setHostInterface.params.details.Add("version", $($SNMP_Version -split "-")[0] ) }
    if($Bulk)           { $setHostInterface.params.details.Add("bulk", $($Bulk -split "-")[0] ) }
    if($Securitylevel)  { $setHostInterface.params.details.Add("securitylevel", $($Securitylevel -split "-")[0] ) }
    if($Authprotocol)   { $setHostInterface.params.details.Add("authprotocol", $($Authprotocol -split "-")[0] ) }
    if($Privprotocol)   { $setHostInterface.params.details.Add("privprotocol", $($Privprotocol -split "-")[0] ) }

    $json = (ConvertTo-Json -InputObject $setHostInterface) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']' -replace '""','"'
    $res = Invoke-RestMethod -Method 'Post' -Uri $UrlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}

#########################################
#Working withMedia type Zabbix API.
function Get-MediaTypeZabbixAPI {
    param (
        [Parameter(Mandatory = $true, position = 0)][string]$UrlApi,
        [Parameter(Mandatory = $true, position = 1)][string]$TokenApi,
        [Parameter(Mandatory = $true, position = 2)][int]$TokenId,
        #Return only media types with the given IDs.
        [Parameter(Mandatory = $false, position = 3)][int]$Mediatypeids,
        #Return only media types used by the given media.
        [Parameter(Mandatory = $false, position = 4)][int]$Mediaids,
        #Return only media types used by the given users.
        [Parameter(Mandatory = $false, position = 5)][int]$Userids,
        #Return a message_templates property with an array of media type messages.
        [Parameter(Mandatory = $false, position = 6)][int]$SelectMessageTemplatess,
        #Return a users property with the users that use the media type.
        [Parameter(Mandatory = $false, position = 7)][int]$SelectUsers,
        #Search
        [Parameter(Mandatory = $false, position = 8)][string]$searchName,
        [Parameter(Mandatory = $false, position = 9)][string]$searchValue,
        [Parameter(Mandatory = $false, position = 10)][ValidateSet("True", "False")]$searchWildcardsEnabled,
        [Parameter(Mandatory = $false, position = 11)][ValidateSet("True", "False")]$searchStart,
        [Parameter(Mandatory = $false, position = 12)][ValidateSet("True", "False")]$searchByAny,
        #Filter Example: -filterNameValues 'status:0,1;type:1,4' 
        [Parameter(Mandatory = $false, position = 13)][string]$filterNameValues
    )
    $getMediaType = @{
        "jsonrpc" = "2.0";
        "method" = "mediatype.get";
        "params" = @{
            "output" = "extend";         
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }

    #Search
    if ($searchName) {
        $arrValue = @()
        foreach( $oneValue in $searchValue -split ',' ){
            $addOneValue = ('"'+ $oneValue +'"')
            $arrValue += $addOneValue
        }

        $searchObj = @{"$searchName" = ('['+ $($arrValue -join ',') +']') }
        $getMediaType.params.Add("search", $searchObj)
        }

    #searchWildcardsEnabled
    if($searchWildcardsEnabled){
        $getMediaType.params.Add("searchWildcardsEnabled",$searchWildcardsEnabled)
    }
    #searchStart
    if($searchStart){
        $getMediaType.params.Add("startSearch",$searchStart)
    }
    #searchByAny
    if($searchByAny){
        $getMediaType.params.Add("searchByAny",$searchByAny)
    }
    #Filter
    if ($filterNameValues) {
        $hashNameValues = @{}
        foreach( $oneObgF in $filterNameValues -split ';' ){
            $filterName = ($oneObgF -split ":")[0]
            $filterValue = @()
            foreach( $oneValueF in ($($oneObgF -split ":")[1]) -split ',' ){
                $addOneValueF = ('"'+ $oneValueF +'"')
                $filterValue += $addOneValueF
            }
            $filterObj = @{"$filterName" = ('['+ $($filterValue -join ',') +']') }
            $hashNameValues += $filterObj
        }
        $getMediaType.params.Add("filter", $hashNameValues)
    }

    $json = (ConvertTo-Json -InputObject $getMediaType -Compress) -replace "\\" -replace "\s\s+" -replace '"\[', '[' -replace '\]"', ']'
    $json
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    if($res.error){
        return $res.error
    }else{ return $res.result }
}


#########################################
Export-ModuleMember -Function Connect-ZabbixAPI, `
Get-HostGroupsZabbixAPI, `
Set-HostGroupsZabbixAPI, `
Get-HostsZabbixAPI, `
New-HostZabbixAPI, `
Remove-HostsZabbixAPI, `
#Massdd-HostsZabbixAPI
Get-TemplateZabbixAPI, `
Get-UserGroupZabbixAPI, `
New-UserGroupZabbixAPI, `
Set-UserGroupZabbixAPI, `
Get-UserZabbixAPI, `
New-UserZabbixAPI, `
Remove-UserZabbixAPI, `
Set-UserZabbixAPI, `
Get-UserRoleZabbixAPI, `
Get-MaintenanceZabbixAPI, `
New-MaintenanceZabbixAPI, `
Set-MaintenanceZabbixAPI, `
Remove-MaintenanceZabbixAPI, `
#New-ItemZabbixAPI, `
Get-ItemZabbixAPI, `
#New-TriggerZabbixAPI, `
Get-TriggerZabbixAPI, `
Get-GraphZabbixAPI, `
Connect-ZabbixWEB, `
Save-GraphZabixWEB, `
Get-ActionZabbixAPI, `
Get-HostInterfaceZabbixAPI, `
Set-HostInterfaceZabbixAPI, `
Get-MediaTypeZabbixAPI
