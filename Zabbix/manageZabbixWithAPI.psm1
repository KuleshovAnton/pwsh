#!/bin/pwsh

#Version 1.0.0.4
#Connect and Autorization to Zabbix API.
function Connect-ZabbixAPI {
    <#
    .SYNOPSIS
        Start using this commandlet. You can add it as a variable for further use of the created token and the token ID. 
        This cmdlet will be authorized on the Zabbix server API using the username and password provided by you, in response 
        Zabbix will return the created token to you. Use this token and token id in subsequent commandlets.
    .EXAMPLE
        Connect-ZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -User UserAdmin -TokenId 2
        Connect-ZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -User UserAdmin -TokenId 2 -Passwd "Passw0rd"
    #>
    param(
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$User,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3,ParameterSetName="Passwd")]$inPasswd
        )
        if ( $inPasswd ) {
            $str = $inPasswd
        } else {
            $passwdAdmin = Read-Host "Enter password" -AsSecureString
            $Ptr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($passwdAdmin)
            $str=[System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
        } 
        #Create token for connection Zabbix API.
        $data = @{
            "jsonrpc"="2.0";
            "method"="user.login";
            "params"=@{
                "user"=$User;
                "password"=$str;
            };
            "id"=$TokenId
        }
    $token = (Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body ($data | ConvertTo-Json) -ContentType "application/json;charset=UTF-8")
    return $token
}

#########################################
#Working with hosts and groups Zabbix API.
#Host Groups Zabbix API.
function Get-HostGroupsZabbixAPI {
    <#
    .Example
        #Output only the groups you are looking for.
        Get-HostGroupsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterGroupName "Linux servers,Admin Windows Server" | Format-Table
        #Output all groups.
        Get-HostGroupsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 | Format-Table

    #>
        param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][array]$filterGroupName              #Example: "Zabbix servers,Linux servers"
    )
    $getGroup = @{
        "jsonrpc"="2.0";
        "method"="hostgroup.get";
        "params" = @{
            "output"="extend";
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    if($filterGroupName){
        $arrGp = @()
        foreach ( $oneGp in ($filterGroupName -split ",") ) {
            $oneResGP = ('"'+ $oneGp +'"')
            $arrGp  += $oneResGP
        }
        $addGp = $arrGp -join ","
        $filterName = @{"name"= @("[$addGp]")}
        $getGroup.params.Add("filter",$filterName)
    }  
    $json = (ConvertTo-Json -InputObject $getGroup) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}

#Host Zabbix API
function Get-HostsZabbixAPI {
    <#
    .Example
        #Output only the groups you are looking for.
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 -filterHostName '"cgraf1,cgraf2"' | Format-Table
        #Output all groups.
        Get-HostsZabbixAPI -UrlApi 'http://IP_or_FQDN/zabbix/api_jsonrpc.php' -TokenApi Paste_Token_API -TokenId 2 | Format-Table
    #>
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][string]$filterHostName              #Example: "cgraf1,cgraf2"
    )
    $getHost = @{
        "jsonrpc"="2.0";
        "method"="host.get";
        "params"=@{
            "output"="extend"
            "selectGroups"="extend"     #Group member
            };
        "auth" = $TokenApi;
        "id" = $TokenId;
    }
    if($filterHostName){
        $arrHS = @()
        foreach ( $oneHS in ($filterHostName -split ",") ) {
            $oneResHS = ('"'+ $oneHS +'"')
            $arrHS += $oneResHS
        }
        $addHS = $arrHS -join ","
        $filterName = @{"host"=@("[$addHS ]")}
        $getHost.params.Add("filter",$filterName)
    }
    $json = (ConvertTo-Json -InputObject $getHost) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    $res.result
}

#New Create Host to Zabbix API _v7
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
        Set a tags for the host "tagName:valueParam,tagName:valueParam". Example -Tags "srv:SERVER,subsys:LINUX"
    .PARAMETER TemplateId
        Template Host ID. Which template are we adding the host to. Example: -TemplateId "77,3,9"
    .PARAMETER Inventory_Mode
        Enable Inventory data. Select Manual or automatic filling of inventory data. Example: -Inventory_Mode (switch select: Manual,Auto)
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
        [Parameter(Mandatory=$true, position=0)][string]$UrlApi,                                                 #URL Zabbix API.
        [Parameter(Mandatory=$true, position=1)][string]$TokenApi,                                               #User Token Zabbix API.
        [Parameter(Mandatory=$true, position=2)][int]$TokenId,                                                   #User ID Zabbix API.
        [Parameter(Mandatory=$true, position=3)][string]$HostName,                                               #Host Name.
        [Parameter(Mandatory=$true, position=4)][ValidatePattern("\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b")]$IP,  #Host IP address.
        [Parameter(Mandatory=$true, position=5)][string]$DNS,                                                    #Host DNS Name.
        [Parameter(Mandatory=$true, position=6)][array]$Group_HostId,                                            #Group Host ID.
        [Parameter(Mandatory=$false,position=7)][int]$Proxy_HostId,                                              #Proxy Host ID.
        [Parameter(Mandatory=$false,position=8)][switch]$Use_Agent, 
        [Parameter(Mandatory=$false,position=9)][switch]$Use_IP_Agent,
        [Parameter(Mandatory=$false,position=10)][switch]$Use_SNMPv2,
        [Parameter(Mandatory=$false,position=11)][switch]$Use_SNMPv3,
        [Parameter(Mandatory=$false,position=12)][string]$SNMPv2_community,
        [Parameter(Mandatory=$false,position=13)][string]$SNMPv3_securityname,
        [Parameter(Mandatory=$false,position=14)][ValidateSet("noAuthNoPriv","authNoPriv","authPriv")]$SNMPv3_securitylevel,
        [Parameter(Mandatory=$false,position=15)][ValidateSet("MD5","SHA1","SHA224","SHA256","SHA384","SHA512")]$SNMPv3_authprotocol,
        [Parameter(Mandatory=$false,position=16)][string]$SNMPv3_authpassphrase,
        [Parameter(Mandatory=$false,position=17)][ValidateSet("DES","AES128","AES192","AES256","AES192C","AES256C")]$SNMPv3_privprotocol,
        [Parameter(Mandatory=$false,position=18)][string]$SNMPv3_privpassphrase,
        [Parameter(Mandatory=$false,position=19)][switch]$Use_IP_SNMP,
        [Parameter(Mandatory=$false,position=20)][switch]$Use_IPMI, 
        [Parameter(Mandatory=$false,position=21)][switch]$Use_IP_IPMI,
        [Parameter(Mandatory=$false,position=22)][string]$Tags,                                                 #Tags Host.
        [Parameter(Mandatory=$false,position=23)][array]$TemplateId,                                            #Template.
        [Parameter(Mandatory=$false,position=24)][ValidateSet("Manual","Auto")]$Inventory_Mode                  #Enable Inventory data.
    )
    ###Interface #######################################
    ##Agent Interfaces##
    if ( $Use_Agent ){
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_IP_Agent ) { 
            $useipAgent = 1 
        } else { 
            $useipAgent = 0 
        }
        $interfacesAgent = @{
            "type"=1;
            "main"=1;
            "useip"=$useipAgent;
            "ip"=$IP;
            "dns"=$DNS;
            "port"="10050"
        }
        $jsonAgent = (ConvertTo-Json -InputObject $interfacesAgent) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
    }
    ##SNMP Interfaces##
    if ( $Use_SNMPv2 -or $Use_SNMPv3 ){
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_ip_SNMP ){ 
            $useipSNMP = 1 
        }else { 
            $useipSNMP = 0 
        }
        $interfacesSNMP = @{
            "type"=2;
            "main"=1;
            "useip"=$useipSNMP;
            "ip"=$ip;
            "dns"=$dns;
            "port"="161";
        }
       
        #Do not use SNMPv2 and SNMPv3.
        if( $Use_SNMPv2 -and $Use_SNMPv3 ){
            Write-Error "Simultaneous use of SNMPv2 and SNMPv3 is not allowed. Please use only one version of the SNMP protocol."
        }
        #Use SNMP v2.
        elseif( $Use_SNMPv2 ){
            if ( $SNMPv2_community -match "\{\$.*\}" ) {
                $community = ('"""'+ $SNMPv2_community +'"""')
            } else {
                $community = ('"'+ $SNMPv2_community +'"')
            } 
            $detailsSNMP = ( '"version":2,"bulk":1,"community":'+ $community )
        }
        #Use SNMP v3.
        elseif( $Use_SNMPv3 ){
            #securitylevel
            switch ($SNMPv3_securitylevel){
                "noAuthNoPriv"  { $sLevel = 0 }
                "authNoPriv"    { $sLevel = 1 }
                "authPriv"      { $sLevel = 2 }
            }
            #authprotocol
            switch ($SNMPv3_authprotocol){
               "MD5"    { $aProtocol = 0 }
               "SHA1"   { $aProtocol = 1 }
               "SHA224" { $aProtocol = 2 }
               "SHA256" { $aProtocol = 3 }
               "SHA384" { $aProtocol = 4 }
               "SHA512" { $aProtocol = 5 }
            }
            #privprotocol
            switch ($SNMPv3_privprotocol){
                "DES"       { $pProtocol = 0 }
                "AES128"    { $pProtocol = 1 }
                "AES192"    { $pProtocol = 2 }
                "AES256"    { $pProtocol = 3 }
                "AES192C"   { $pProtocol = 4 }
                "AES256C"   { $pProtocol = 5 }
            }
            if ($SNMPv3_securityname -match "\{\$.*\}"){
                $securityname = ('"securityname":"""'+ $SNMPv3_securityname +'"""')
            } else {  $securityname = ('"securityname":"'+ $SNMPv3_securityname +'"') }
            if ($SNMPv3_authpassphrase -match "\{\$.*\}"){
                $authpassphrase = ('"authpassphrase":"""'+ $SNMPv3_authpassphrase +'"""')
            } else { $authpassphrase = ('"authpassphrase":"'+ $SNMPv3_authpassphrase +'"') }
            if ($SNMPv3_privpassphrase -match "\{\$.*\}"){
                $privpassphrase = ('"privpassphrase":"""'+ $SNMPv3_privpassphrase +'"""')
            } else { $privpassphrase = ('"privpassphrase":"'+ $SNMPv3_privpassphrase +'"') }
            $detailsSNMP = ( '"version":3,"bulk":1,"contextname":"","securitylevel":'+ $sLevel +',"authprotocol":'+ $aProtocol +',"privprotocol":'+ $pProtocol +','+ $securityname +","+ $authpassphrase +","+ $privpassphrase)
        }
        $interfacesSNMP.Add("details",("{$detailsSNMP}"))
        $jsonInterfacesSNMP = $interfacesSNMP
        $jsonSNMP = (ConvertTo-Json -InputObject $jsonInterfacesSNMP) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
    }
    ##IPMI Interfaces##
    if ( $Use_IPMI ){
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_ip_IPMI ) { $useipIPMI = 1 }
        else { $useipIPMI = 0 }

        $interfacesIPMI = @{
            "type"=3;
            "main"=1;
            "useip"=$useipIPMI;
            "ip"=$ip;
            "dns"=$dns;
            "port"="623"
        }
        $jsonIPMI = (ConvertTo-Json -InputObject $interfacesIPMI) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
    }
    #If not Variable $Use_Agent, $Use_SNMP, $Use_IPMI. Is used default Zabbix Agent.
    if ( -not $Use_Agent -and -not $Use_SNMPv2 -and -not $Use_SNMPv3 -and -not $Use_IPMI ){
        #Use SNMP protocol for management Host.#Should the connection be made via an IP address.
        if ( $Use_IP_Agent ) { $useipAgent = 1 }
        else { $useipAgent = 0 }
        $interfacesAgent = @{
            "type"=1;
            "main"=1;
            "useip"=$useipAgent;
            "ip"=$IP;
            "dns"=$DNS;
            "port"="10050"
        }
        $jsonAgent = (ConvertTo-Json -InputObject $interfacesAgent) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
    }
    ###Interface End####################################
    ###Create Host JSON#################################
    $createHost = @{
        "jsonrpc"="2.0";
        "method"="host.create";
        "params"=@{
            "host"=$hostName;
        };
        "auth" = $TokenApi;
        "id" = $TokenId;
    }
    #Add Group Host to JSON.
    $arrGroupId = @()
    foreach ( $oneGroupId in ($group_HostId -split ",") ) {
        $resGroupId = ( '{"groupid":"'+ $oneGroupId +'"}' )
        $arrGroupId += $resGroupId
    }
    $addGroupId = $arrGroupId -join ","
    $createHost.params.Add("groups",@($addGroupId))
    #Add interfaces Host to JSON.
    $joinJsonInterface = @()
    if ( $jsonAgent) { $joinJsonInterface += $jsonAgent}
    if ( $jsonSNMP ) { $joinJsonInterface += $jsonSNMP }
    if ( $jsonIPMI ) { $joinJsonInterface += $jsonIPMI }
    [string]$joinJsonInterfaceAdd = $joinJsonInterface -join ","
    $createHost.params.Add("interfaces",@($joinJsonInterfaceAdd))
    #Add Tags Host to JSON.
    if ($Tags){
        $arrTags = @()
        foreach ( $oneTag in ($Tags -split ",") ) {
            $oTag = $oneTag -split ":"
            $resTag = ( '{"tag":"'+ $oTag[0] +'","value":"'+ $oTag[1] +'"}' )
            $arrTags += $resTag
        }
        $addTags = $arrTags -join ","
        $createHost.params.Add("tags",@($addTags))
    }     
    #Add Zabbix Proxy Host to JSON.
    if ($Proxy_HostId){
        $createHost.params.Add("proxy_hostid",$Proxy_HostId)
    }
    #Add template to JSON.
    if($TemplateId){
        $arrTemplateId = @()
        foreach ( $oneTemplateId in ($TemplateId -split ",") ) {
            $resTemplateId = ( '{"templateid":"'+ $oneTemplateId +'"}' )
            $arrTemplateId += $resTemplateId
        }
        $addTemplateId = $arrTemplateId -join ","
        $createHost.params.Add("templates",@($addTemplateId))
    }
    #Add Inventory to JSON.
    if($Inventory_Mode){
        switch ($Inventory_Mode) {
            "Manual" { [int]$InvMode = 0 }
            "Auto"   { [int]$InvMode = 1 }
        }
        $createHost.params.Add("inventory_mode",$InvMode)
    } 
    $jsonCreate = $createHost
    $json = (ConvertTo-Json -InputObject $jsonCreate) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '\["{','[{' -replace '}"\]','}]' -replace '"{','{' -replace '}"','}'
    ###Create Host JSON END###############################
    ###Create Host########################################
    $res = Invoke-RestMethod -Method 'Post' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res
}

#########################################
#Working with Template Zabbix API.
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
       [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
       [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
       [Parameter(Mandatory=$true,position=2)][int]$TokenId,
       [Parameter(Mandatory=$false,position=3)][array]$filterTemplateName       #Example: "Linux by Zabbix agent,Template 1"
   )
   $getTemplate = @{
       "jsonrpc"="2.0";
       "method"="template.get";
       "params" = @{
           "output"="extend";
       };
       "auth" = $TokenApi;
       "id" = $TokenId
   }
   if($filterTemplateName){
        $arrTm = @()
        foreach ( $oneTm in ($filterTemplateName -split ",") ) {
            $oneResTm = ('"'+ $oneTm +'"')
            $arrTm  += $oneResTm
        }
        $addTm = $arrTm -join ","
        $filterName = @{"host"= @("[$addTm]")}
        $getTemplate.params.Add("filter",$filterName)
    }
   $json = (ConvertTo-Json -InputObject $getTemplate) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
   $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
   return $res.result
}

Export-ModuleMember -Function Connect-ZabbixAPI, Get-HostGroupsZabbixAPI, Get-HostsZabbixAPI, New-HostZabbixAPI, Get-TemplateZabbixAPI