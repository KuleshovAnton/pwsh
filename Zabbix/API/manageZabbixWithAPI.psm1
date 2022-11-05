#!/bin/pwsh

#Version 1.0.0.6
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
        [Parameter(Mandatory=$false,position=3)][array]$filterGroupName
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
    #Filter
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
        [Parameter(Mandatory=$false,position=3)][string]$filterHostName
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
    #Filter
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
       [Parameter(Mandatory=$false,position=3)][array]$filterTemplateName
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
   #Filter
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

#########################################
#Working with Groups Users Zabbix API.
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][array]$filterUserGroup,
        [Parameter(Mandatory=$false,position=4)][switch]$IncomingUsers,
        [Parameter(Mandatory=$false,position=5)][switch]$ReturnRights
    )
    $getUserGroup = @{
        "jsonrpc"="2.0";
        "method"="usergroup.get";
        "params"=@{
            "output"="extend";       
            "status"=0
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #Filter
    if($filterUserGroup){
        $arrUSGP = @()
        foreach ( $oneUSGP in ($filterUserGroup -split ",") ) {
            $oneResUSGP = ('"'+ $oneUSGP +'"')
            $arrUSGP  += $oneResUSGP
        }
        $addUSGP = $arrUSGP -join ","
        $filterName = @{"name"= @("[$addUSGP]")}
        $getUserGroup.params.Add("filter",$filterName)
    }
    #Members of the group.
    If($IncomingUsers){
        $getUserGroup.params.Add("selectUsers","extend")
    }
    #Return permissions for a group of hosts. permission - the level of access rights to a group of hosts; id - ID of the host group.
    If($ReturnRights){
        $getUserGroup.params.Add("selectRights","extend")
    }
    $json = (ConvertTo-Json -InputObject $getUserGroup) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}
function New-UserGroupZabbixAPI {
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][string]$NewUserGroup,
        [Parameter(Mandatory=$true,position=4)][ValidateSet("SysDefault","Internal","LDAP","NotFrontend")]$GuiAccess
    )
    switch ($GuiAccess) {
        "SysDefault"    { $gAccess = 0 }
        "Internal"      { $gAccess = 1 }
        "LDAP"          { $gAccess = 2 }
        "NotFrontend"   { $gAccess = 3 }
    }
    $createUserGroup = @{
        "jsonrpc"="2.0";
        "method"="usergroup.create";
        "params"=@{
            "name"="$NewUserGroup";
            "gui_access"=$gAccess;
            "users_status"=0
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    $json = (ConvertTo-Json -InputObject $createUserGroup) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][array]$filterUser,
        [Parameter(Mandatory=$false,position=4)][switch]$SelectMedias,
        [Parameter(Mandatory=$false,position=5)][switch]$SelectMediaTypes,
        [Parameter(Mandatory=$false,position=6)][switch]$SelectUsrGrps
    )
    $getUser = @{
        "jsonrpc"="2.0";
        "method"="user.get";
        "params"=@{
            "output"="extend"
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #Filter
    if($filterUser){
        $arrUS = @()
        foreach ( $oneUS in ($filterUser -split ",") ) {
            $oneResUS = ('"'+ $oneUS +'"')
            $arrUS  += $oneResUS
        }
        $addUS = $arrUS -join ","
        $filterName = @{"username"= @("[$addUS]")}
        $getUser.params.Add("filter",$filterName)
    }
    #Return user alerts that are used by the user.
    If($SelectMedias){
        $getUser.params.Add("selectMedias","extend")
    }
    #Return the notification methods that the user is using.
    If($SelectMediaTypes){
        $getUser.params.Add("selectMediatypes","extend")
    }
    #Return user groups that users belong to.
    If($SelectUsrGrps){
        $getUser.params.Add("selectUsrgrps","extend")
    }
    $json = (ConvertTo-Json -InputObject $getUser) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][string]$NewUser,
        [Parameter(Mandatory=$true,position=4)][string]$NewUserPass,
        [Parameter(Mandatory=$true,position=5)][array]$UserGroupsId,
        [Parameter(Mandatory=$true,position=6)][int]$UserRolesId,
        [Parameter(Mandatory=$false,position=7)][string]$NewUserName,
        [Parameter(Mandatory=$false,position=8)][string]$NewUserSurname
        #[Parameter(Mandatory=$false,position=6)][array]$UserMedia
    )
    $createUser = @{
        "jsonrpc"="2.0";
        "method"="user.create";
        "params"=@{
            "alias"=$NewUser;
            "passwd"=$NewUserPass;
            "roleid"=$UserRolesId;
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #Add GroupsID to JSON.
    if($UserGroupsId){
        $arrUserGroups  = @()
        foreach ( $oneUserGroups  in ($UserGroupsId -split ",") ) {
            $resUserGroups  = ( '{"usrgrpid":"'+ $oneUserGroups  +'"}' )
            $arrUserGroups  += $resUserGroups
        }
        $addUserGroups  = $arrUserGroups -join ","
        $createUser.params.Add("usrgrps",@($addUserGroups))
    }
    if($NewUserName){
        $createUser.params.Add("name",$NewUserName)
    }
    if($NewUserSurname){
        $createUser.params.Add("surname",$NewUserSurname)
    }

    $json = (ConvertTo-Json -InputObject $createUser) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']' -replace '"\{','{' -replace '\}"','}'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][array]$RemoveUser
    )
    $delUser = @{
        "jsonrpc"="2.0";
        "method"="user.delete";
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    If($RemoveUser){
        $arrR = @()
        foreach ( $oneRemoveUser in ($RemoveUser -split ",") ){
        $resRemoveUser = ('"'+ $oneRemoveUser +'"')
        $arrR += $resRemoveUser
        }
        $addRemoveUser = $arrR -join ","
        $delUser.Add("params","[$addRemoveUser]")
    }
    $json = (ConvertTo-Json -InputObject $delUser) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][int]$UserId,
        [Parameter(Mandatory=$false,position=4)][string]$Username,
        [Parameter(Mandatory=$false,position=5)][string]$Name,
        [Parameter(Mandatory=$false,position=6)][string]$Surname,
        [Parameter(Mandatory=$false,position=7)][string]$UrlAfterLogin,
        [Parameter(Mandatory=$false,position=8)][string]$Passwd,
        [Parameter(Mandatory=$false,position=9)][int]$UserRoleId,
        [Parameter(Mandatory=$false,position=10)][array]$Usrgrps
    )

    $updateUser = @{
        "jsonrpc"="2.0";
        "method"="user.update";
        "params"=@{
            "userid"=$UserId;
        }
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #Rename User Name.
    If($Username){
        $updateUser.params.Add("username",$Username)
    }
    #Rename Name.
    If($Name){
        $updateUser.params.Add("name",$Name)
    }
    #Rename Surname.
    If($Surname){
        $updateUser.params.Add("surname",$Surname)
    }
    #Change Url After Login.
    If($UrlAfterLogin){
        $updateUser.params.Add("url",$UrlAfterLogin)
    }
    #Change User Password.
    If($Passwd){
        $updateUser.params.Add("passwd",$Passwd)
    }
    #Change User RoleID.
    If($UserRoleId){
        $updateUser.params.Add("roleid",$UserRoleId)
    }
    #Change\Add User Groups.
    if($Usrgrps){
        $arrUGC = @()
        foreach ( $oneUGC in ($Usrgrps -split ",") ) {
            $oneResUGC = ('{"usrgrpid":'+ $oneUGC +'}')
            $arrUGC  += $oneResUGC
        }
        $addUGC = $arrUGC -join ","
        $updateUser.params.Add("usrgrps","[$addUGC]")
    }
    $json = (ConvertTo-Json -InputObject $updateUser) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']' -replace '"\{','{' -replace '\}"','}'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
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
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][switch]$SelectRules,
        [Parameter(Mandatory=$false,position=4)][switch]$SelectUsers,
        [Parameter(Mandatory=$false,position=5)][array]$Roleids
    )
    $getRole = @{
        "jsonrpc"="2.0";
        "method"="role.get";
        "params"=@{
            "output"="extend";
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #Return role rules in the rules property.
    If($SelectRules){
        $getRole.params.Add("selectRules","extend")
    }
    #Select users this role is assigned to.
    If($selectUsers){
        $getRole.params.Add("selectUsers","extend")
    }
    #Return only roles with the given IDs.
    If($Roleids){
        $getRole.params.Add("roleids","[$Roleids]")
    }
    $json = (ConvertTo-Json -InputObject $getRole) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
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
    .Example
        Get-MaintenanceZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid
    .Example
        Get-MaintenanceZabbixAPI -UrlApi "http://zabbix.domain.local/zabbix/api_jsonrpc.php" -TokenApi Past_TokenApi -TokenId Past_Tokenid -FilterMaintenance "maintenance1,maintenance2"
    #>
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$false,position=3)][switch]$SelectGroups,
        [Parameter(Mandatory=$false,position=4)][switch]$SelectHosts,
        [Parameter(Mandatory=$false,position=5)][switch]$SelectTimeperiods,
        [Parameter(Mandatory=$false,position=6)][switch]$SelectTags,
        [Parameter(Mandatory=$false,position=7)][array]$FilterMaintenance,
        [Parameter(Mandatory=$false,position=8)][array]$FindHostIds,
        [Parameter(Mandatory=$false,position=9)][array]$FindGroupIds,
        [Parameter(Mandatory=$false,position=10)][array]$FindMaintenanceIds
    )
    $getMaintenance = @{
        "jsonrpc"="2.0";
        "method"="maintenance.get";
        "params"=@{
            "output"="extend";
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    If($SelectGroups){
        $getMaintenance.params.Add("selectGroups","extend")
    }
    If($SelectHosts){
        $getMaintenance.params.Add("selectHosts","extend")
    }
    If($SelectTimeperiods){
        $getMaintenance.params.Add("selectTimeperiods","extend")
    }
    If($SelectTags){
        $getMaintenance.params.Add("selectTags","extend")
    }
    #Filter
    if($FilterMaintenance){
        $arrMT = @()
        foreach ( $oneMT in ($FilterMaintenance -split ",") ) {
            $oneResMT = ('"'+ $oneMT +'"')
            $arrMT  += $oneResMT
        }
        $addMT = $arrMT -join ","
        $filterName = @{"name"= @("[$addMT]")}
        $getMaintenance.params.Add("filter",$filterName)
    }
    #Return only those services that are assigned to the specified network nodes.
    if($FindHostIds){
        $addFindH = $FindHostIds -replace "\s"
        $getMaintenance.params.Add("hostids","[$addFindH]")
    }
    #Return only those services that are assigned to the specified groups of network nodes.
    if($FindGroupIds){
        $addFindG = $FindGroupIds -replace "\s"
        $getMaintenance.params.Add("groupids","[$addFindG]")
    }
    #Return of services with specified IDs only.
    if($FindMaintenanceIds){
        $addFindM = $FindMaintenanceIds -replace "\s"
        $getMaintenance.params.Add("maintenanceids","[$addFindM]")
    } 
    $json = (ConvertTo-Json -InputObject $getMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}
function New-MaintenanceZabbixAPI {
    <#
    .SYNOPSIS
        This method allows to create new maintenances, via Zabbix API
    .PARAMETER NameMaintenance
        Name Maintenance. Example: -NameMaintenance "Maintenance_1"
    .PARAMETER ActiveSince
        Time when the maintenance becomes active. Example: -ActiveSince "31.10.2022 09:00"
    .PARAMETER ActiveTill
        Time when the maintenance stops being active. Example: -ActiveTill "22.11.2022 18:00"
    .PARAMETER MaintenanceType
        Type of maintenance. Possible values: WithData - (default) with data collection; NoData - without data collection. Example: -MaintenanceType NoData
    .PARAMETER groupids
        Host groups that will undergo maintenance. The host groups must have the groupid property defined. At least one object of groups or hosts must be specified. Example: -GroupIds "31,34,121"
    .PARAMETER hostids
        Hosts that will undergo maintenance.The hosts must have the hostid property defined. At least one object of groups or hosts must be specified. Example: -HostIds "13123,4456" 
    #>
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][string]$NameMaintenance,
        [Parameter(Mandatory=$true,position=4)][datetime]$ActiveSince,
        [Parameter(Mandatory=$true,position=5)][datetime]$ActiveTill,
        [Parameter(Mandatory=$false,position=6)][ValidateSet("WithData","NoData")]$MaintenanceType,
        [Parameter(Mandatory=$false,position=7)][array]$GroupIds,
        [Parameter(Mandatory=$false,position=8)][array]$HostIds
    )

    try {  
        $ErrorActionPreference = "Stop"
        $AS = Get-Date $ActiveSince -UFormat %s
        $AT = Get-Date $ActiveTill -UFormat %s

        switch ($MaintenanceType) {
            "NoData" { $mType = 1 }
            "WithData" { $mType = 0 }
            Default { $mType = 0 }
        }

        $createMaintenance = @{
            "jsonrpc"="2.0";
            "method"="maintenance.create";
            "params"=@{
                "name"="$NameMaintenance";
                "active_since"=$AS;
                "active_till"=$AT;
                "maintenance_type"=$mType
            };
            "auth" = $TokenApi;
            "id" = $TokenId
        }

        #Add periods
        $periodTimeType = 0
        $periodEvery = 1
        $periodMonth = 0
        $periodDayofweek = 0
        $periodDay = 0
        $periodStartTime = 0
        $Period = 31536000
        $periodStartDate = $AS
        $periods = @{
            "timeperiod_type"=$periodTimeType
            "every"=$periodEvery
            "month"=$periodMonth
            "dayofweek"=$periodDayofweek
            "day"=$periodDay
            "start_time"=$periodStartTime
            "period"=$Period
            "start_date"=$periodStartDate
        }
        $jsonPeriods = (ConvertTo-Json -InputObject $periods) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
        $createMaintenance.params.Add("timeperiods",@($jsonPeriods))

        #Add groupids or hostids
        $findVar = ($GroupIds + $HostIds)      
        if ( -Not $findVar ){
            Write-Error -Message "Please make sure to set one of the groupids or hostids parameters" -ErrorAction Stop
        }else{
            if($GroupIds){
                $cGroupids = $GroupIds -replace "\s"
                $createMaintenance.params.Add("groupids",@($cGroupids))
            }
            if($HostIds){
                $cHostids = $HostIds -replace "\s"
                $createMaintenance.params.Add("hostids",@($cHostids))
            }
        }

        $json = (ConvertTo-Json -InputObject $createMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
        $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
        return $res.result
    }
    catch {
        $err = $error[0] | format-list -Force
        $err
    }
}
function Update-MaintenanceZabbixAPI {
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][int]$MaintenanceId,
        [Parameter(Mandatory=$false,position=4)][string]$NameMaintenance,
        [Parameter(Mandatory=$false,position=5)][datetime]$ActiveSince,
        [Parameter(Mandatory=$false,position=6)][datetime]$ActiveTill,
        [Parameter(Mandatory=$false,position=7)][ValidateSet("WithData","NoData")]$MaintenanceType,
        [Parameter(Mandatory=$false,position=8)][array]$groupids,
        [Parameter(Mandatory=$false,position=9)][array]$hostids
    )
    $updateMaintenance = @{
        "jsonrpc"="2.0";
        "method"="maintenance.update";
        "params"=@{
            "maintenanceid"=$MaintenanceId
        };
        "auth" = $TokenApi;
        "id" = $TokenId
    }
    #name
    if($NameMaintenance){
        $updateMaintenance.params.add("name",$NameMaintenance)
    }
    #active_since
    if($ActiveSince){
        $AS = Get-Date $ActiveSince -UFormat %s
        $updateMaintenance.params.add("active_since",$AS)
    }
    #active_till
    if($ActiveTill){
        $AT = Get-Date $ActiveTill -UFormat %s
        $updateMaintenance.params.add("active_till",$AT)
    }
    #maintenance_type
    if($MaintenanceType){
        switch ($MaintenanceType) {
            "NoData" { $mType = 1 }
            "WithData" { $mType = 0 }
             Default { $mType = 0 }
        }
        $updateMaintenance.params.add("maintenance_type",$mType)
    }
    #Add groupids or hostids
    if($groupids){
        $cGroupids = $groupids -replace "\s"
        $updateMaintenance.params.Add("groupids",@($cGroupids))
    }
    if($hostids){
        $cHostids = $hostids -replace "\s"
        $updateMaintenance.params.Add("hostids",@($cHostids))
    }

        <#
        #Add periods
        $periodTimeType = 0
        $periodEvery = 1
        $periodMonth = 0
        $periodDayofweek = 0
        $periodDay = 0
        $periodStartTime = 0
        $Period = 31536000
        $periodStartDate = $AS
        $periods = @{
            "timeperiod_type"=$periodTimeType
            "every"=$periodEvery
            "month"=$periodMonth
            "dayofweek"=$periodDayofweek
            "day"=$periodDay
            "start_time"=$periodStartTime
            "period"=$Period
            "start_date"=$periodStartDate
        }
        $jsonPeriods = (ConvertTo-Json -InputObject $periods) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"{','{' -replace '}"','}'
        $updateMaintenance.params.Add("timeperiods",@($jsonPeriods))
        #>
    $json = (ConvertTo-Json -InputObject $updateMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}
function Remove-MaintenanceZabbixAPI {
    param (
        [Parameter(Mandatory=$true,position=0)][string]$UrlApi,
        [Parameter(Mandatory=$true,position=1)][string]$TokenApi,
        [Parameter(Mandatory=$true,position=2)][int]$TokenId,
        [Parameter(Mandatory=$true,position=3)][array]$MaintenanceId
    )

    $deleteMaintenance = @{
        "jsonrpc"="2.0";
        "method"="maintenance.delete";
        "auth" = $TokenApi;
        "id" = $TokenId
    }

    $deleteMaintenance.Add("params",@($MaintenanceId -split ","))

    $json = (ConvertTo-Json -InputObject $deleteMaintenance) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']'
    $res = Invoke-RestMethod -Method 'POST' -Uri $urlApi -Body $json -ContentType "application/json;charset=UTF-8"
    return $res.result
}

Export-ModuleMember -Function Connect-ZabbixAPI, Get-HostGroupsZabbixAPI, Get-HostsZabbixAPI, New-HostZabbixAPI, Get-TemplateZabbixAPI, Get-UserGroupZabbixAPI, New-UserGroupZabbixAPI, Get-UserZabbixAPI, New-UserZabbixAPI, Remove-UserZabbixAPI, Set-UserZabbixAPI, Get-UserRoleZabbixAPI, Get-MaintenanceZabbixAPI, Get-MaintenanceZabbixAPI, New-MaintenanceZabbixAPI, Update-MaintenanceZabbixAPI, Remove-MaintenanceZabbixAPI
