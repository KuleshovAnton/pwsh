#!/bin/pwsh

#Version 1.0.5.5
#Synchronization of Zabbix groups and composition of groups with LDAP groups and users
function manageZabbixSyncLDAPgroups {
    <#
    .SYNOPSIS
        Synchronization of users groups Zabbix with LDAP groups. The list of LDAP groups comes in the form of JSON '[{"name":"group_LDAP_1"},{"name":"group_LDAP_2"}]'. The log is written in, by errors "/tmp/manageZabbixSyncLDAPgroups_Linux_Error.log". If parameter logsOn activate , the progress of the module stages is written in "/tmp/manageZabbixSyncLDAPgroups_Linux_Module.log".
    .PARAMETER apiUser
        The user to connect to the Zabbix API. Example: -apiUser userZabbixAPI
    .PARAMETER apiUserPass
        The password of the user to connect to the Zabbix API.
    .PARAMETER apiUrl
        The URL of the connection to the Zabbix API. Example: -apiUrl "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" OR "https://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php"
    .PARAMETER apiToken
        A random number for generating a token in the Zabbix API. Example: -apiToken 7
    .PARAMETER jsonQuery
        The list of LDAP groups comes in the form of JSON. Example: -jsonQuery '[{"name":"group_LDAP_1"},{"name":"group_LDAP_2"}]'
    .PARAMETER ldapsearchUser
        The user to connect to LDAP. Example: -ldapsearchUser "user@domain.local"
    .PARAMETER ldapsearchPass
        The password of the user to connect to LDAP.
    .PARAMETER ldapsearchServer
        Server LDAP. Example: -ldapsearchServer "ldap://ldapServer.domain.local" OR "ldaps://ldapServer.domain.local:636" OR "ldap://domain.local"
    .PARAMETER ldapsearchBase
        The search location in the LDAP database. Example: -ldapsearchBase "dc=domain,dc=local" OR "ou=groups,dc=domain,dc=local"
    .PARAMETER zabbixNewUserPass
        Password for new Zabbix users. When using an LDAP connection, a password is also required to create an account.
    .PARAMETER zabbixUserRolesId
        Specify the User roles id from Zabbix, required to create an account. Example: -zabbixUserRolesId 1
    .PARAMETER userGroupsDisable
        A group for disabled users from LDAP. Specify the name of the group taken from Zabbix. Example: -userGroupsDisable "NoUsers_InGroupsLDAP"
    .PARAMETER guiAccess
        Definition of Frontend access for User groups being created. Accepts parameters "SysDefault" "Internal" "LDAP" "NotFrontend"
    .PARAMETER logsOn
        True - write logs "/tmp/manageZabbixSyncLDAPgroups_Linux_Module.log". False - not write logs, default.
    .EXAMPLE
        manageZabbixSyncADgroups "userZabbixAPI" "PassZbxAPI" "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" 7 '[{"name":"group_LDAP_1"},{"name":"group_LDAP_2"}]' "user@domain.local" "PassLDAP" "ldaps://ldapServer.domain.local:636" "dc=domain,dc=local" "passNewUserZbx" 1 LDAP
    .EXAMPLE
        Check, ldap query manual example.
        Find CN group       : ldapsearch -x -D User@domain.local -w Passw0rd -H ldaps://srv-ldap.domain.local:636 -b "dc=domain,dc=local" "(&(objectCategory=group)(|(cn=GroupName)))" dn -o ldif-wrap=no -LLL 2
        Find Users in groups: ldapsearch -x -D User@domain.local -w Passw0rd -H ldaps://srv-ldap.domain.local:636 -b "dc=domain,dc=local" "(&(objectCategory=person)(objectClass=user)(|(memberOf=CN=GroupName,OU=Folder,DC=domain,DC=local))(userAccountControl=512))" sAMAccountName -o ldif-wrap=no -LLL 2
    #>
    param(
        [Parameter(Mandatory=$true,position=0)][string]$apiUser,
        [Parameter(Mandatory=$true,position=1)][string]$apiUserPass,
        [Parameter(Mandatory=$true,position=2)][string]$apiUrl,
        [Parameter(Mandatory=$true,position=3)][int]$apiToken,
        [Parameter(Mandatory=$true,position=4)][string]$jsonQuery,
        [Parameter(Mandatory=$true,position=5)][string]$ldapsearchUser,
        [Parameter(Mandatory=$true,position=6)][string]$ldapsearchPass,
        [Parameter(Mandatory=$true,position=7)][string]$ldapsearchServer,
        [Parameter(Mandatory=$true,position=8)][string]$ldapsearchBase,
        [Parameter(Mandatory=$true,position=9)][string]$zabbixNewUserPass,
        [Parameter(Mandatory=$true,position=10)][int]$zabbixUserRolesId,
        [Parameter(Mandatory=$true,position=11)][string]$userGroupsDisable,
        [Parameter(Mandatory=$false,position=12)][ValidateSet("SysDefault","Internal","LDAP","NotFrontend")]$guiAccess = "SysDefault",
        [Parameter(Mandatory=$false,position=13)][ValidateSet("True","False")]$logsOn = "False"
    )
      
    try{
        $ErrorActionPreference = "Stop"
        #Importing a module to work with Zabbix.
        Import-Module manageZabbixWithAPI

        #We connect to Zabbix and get an API token.
        $token = Connect-ZabbixAPI -UrlApi $apiUrl -User $apiUser -TokenId $apiToken -inPasswd $apiUserPass

        #Converting incoming JSON data into an object.
        $convertJsonQuery = ConvertFrom-Json -InputObject $jsonQuery
        $toFindGroup = ($convertJsonQuery).name -join ","

        ###Logs
        #The number of the running task.
        $taskNum = "TASK$(Get-Random)"
        #Time mark.
        $taskRunTime = get-date -Format 'yyyy MMM dd HH:mm:ss'
        #Write logs
        function Out-WriteLogs ($inputDataLogs,$logsOnFun = $logsOn ){
            if($logsOnFun -eq "True"){
                $inputDataLogs | Out-File -FilePath "/tmp/manageZabbixSyncLDAPgroups_Linux_Module.log" -Append -Encoding utf8 -ErrorAction Ignore
            }else{
                $inputDataLogs *> /dev/null
            }
        }

        ###Module_1_#############################################
        #########################################################
        ###Search for the necessary groups in LDAP for matching with groups (Incoming data $convertJsonQuery), primary analysis.
        #Temporary file for recording ldapsearch errors.
        $errLdap = New-TemporaryFile
        #Search for CN groups by the necessary groups in LDAP.
        $arrFindGpLdapCN = @()
        foreach ( $buildFindGpLdapCn in $toFindGroup -split "," ) {
            $buildQueryLdapGpCN = ("(cn="+ $buildFindGpLdapCN +")")
            $arrFindGpLdapCN += $buildQueryLdapGpCN
        }
        $buildFindLdapGpCN = ( $arrFindGpLdapCN -join "" ) -replace "\s"
        $queryFindLdapGpCN = (ldapsearch -x -D $ldapsearchUser -w $ldapsearchPass -H $ldapsearchServer -b "$ldapsearchBase" "(&(objectCategory=group)(|$buildFindLdapGpCN))" dn -o ldif-wrap=no -LLL 2>$errLdap.FullName)

        ###LDAP groups and users ( $arrFindGpLdapMemOf ). Search for users belonging to LDAP groups.
        $arrFindGpLdapMemOf = @()
        foreach ( $buildFindGpLdapMemOf in ($queryFindLdapGpCN -match "(^dn.*)(CN=.*)" -replace "dn: ","") )  {
            $buildQueryLdapGpMemOf = ("(memberOf="+ $buildFindGpLdapMemOf +")")
            #$queryFindLdapGpMemOf = (ldapsearch -x -D $ldapsearchUser -w $ldapsearchPass -H $ldapsearchServer -b "$ldapsearchBase" "(&(objectCategory=person)(objectClass=user)$buildQueryLdapGpMemOf(userAccountControl=66048))" sAMAccountName -o ldif-wrap=no -LLL 2>$errLdap.FullName)
            $queryFindLdapGpMemOf = (ldapsearch -x -D $ldapsearchUser -w $ldapsearchPass -H $ldapsearchServer -b "$ldapsearchBase" "(&(objectCategory=person)(objectClass=user)$buildQueryLdapGpMemOf)" sAMAccountName -o ldif-wrap=no -LLL 2>$errLdap.FullName)

            $objLdapGroup = $buildFindGpLdapMemOf -replace "CN=","" -replace ",.*",""
            $findsAMAccountNameAll = ($queryFindLdapGpMemOf -match "^sAMAccountName") -replace "sAMAccountName:" -replace "\s"
            if ( -Not $findsAMAccountNameAll ){
                $findsAMAccountName = ''
            }else {
                $findsAMAccountName = $findsAMAccountNameAll
            }
            
            $arrObjMemOf = @()
            foreach ( $onefindsAMAccountName in $findsAMAccountName ){
            $objMemOf = New-Object System.Object
            $objMemOf | Add-Member -Type NoteProperty -Name ldapGroup -Value $objLdapGroup
            $objMemOf | Add-Member -Type NoteProperty -Name ldapUser -Value $onefindsAMAccountName
            $arrObjMemOf += $objMemOf
            }
            $arrFindGpLdapMemOf += $arrObjMemOf
        }

        #Errors working with LDAP
        $errLdapRead = Get-Content $errLdap.FullName
        if ( $errLdapRead.Length -gt 0 ){
            #Logs.
            Write-Error -Message "$errLdapRead" -ErrorAction Stop
            Write-Host "$taskRunTime;$taskNum;ERROR;module_1;LDAP_groups_and_user;NOT_COMPLETED;;;cmd_run_bash;ldapsearch" -ForegroundColor Red
        }else{
            Remove-Item $errLdap.FullName
            #Logs.
            $textLogs = "$taskRunTime;$taskNum;FIND;module_1;LDAP_groups_and_user;COMPLETED;;;cmd_run_bash;ldapsearch"
            Write-Host $textLogs -ForegroundColor Blue
            Out-WriteLogs $textLogs
        }

        ###Module_2_#############################################
        #########################################################
        ###We check and create groups in Zabbix.
        #Search for the necessary groups in Zabbix to map to groups in LDAP ($arrFindGpLdapMemOf ).
        $toFindGroupLdap = ($arrFindGpLdapMemOf | Select-Object ldapGroup -Unique).ldapGroup -join ","
        #Primary analysis. Getting all the groups in Zabbix from the list ( $toFindGroupLdap ).
        $findGroupInZabbix_1 = Get-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUserGroup $toFindGroupLdap -IncomingUsers
        
        #If groups from the list are detected.
        if ( $findGroupInZabbix_1 ) {
            #Compare groups from LDAP ( $arrFindGpLdapMemOf ) with groups from Zabbix ( $findGroupInZabbix_1 ).
            $compareGroups = (Compare-Object -ReferenceObject ($arrFindGpLdapMemOf | Select-Object ldapGroup -Unique).ldapGroup -DifferenceObject $findGroupInZabbix_1.name | Where-Object { $_.SideIndicator -eq "<="}).InputObject
            #If groups from LDAP ( $arrFindGpLdapMemOf ) are missing in Zabbix ( $findGroupInZabbix_1 ), then create these groups.
            if ($compareGroups){
                foreach ( $oneCompareGroups in $compareGroups ){  
                    $newUserGroupZabbixAPI = New-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -NewUserGroup $oneCompareGroups -GuiAccess $guiAccess
                    #Logs
                    $textLogs = "$taskRunTime;$taskNum;CREATE;module_2;add_usergroup;$oneCompareGroups;add_usergroupid;$($newUserGroupZabbixAPI.usrgrpids);cmd_run_zabbix_API;New-UserGroupZabbixAPI" 
                    Write-Host $textLogs -ForegroundColor Blue
                    Out-WriteLogs $textLogs
                }
            }
        } 
        #If all groups from the list are not found.
        elseif ( -Not $findGroupInZabbix_1) {
            foreach ( $oneCreateAllGroups in ($toFindGroupLdap -split "," ) ){        
                $newUserGroupZabbixAPI = New-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -NewUserGroup $oneCreateAllGroups -GuiAccess $guiAccess
                #Logs.
                $textLogs = "$taskRunTime;$taskNum;CREATE;module_2;all_usergroup;$oneCreateAllGroups;add_usergroupid;$($newUserGroupZabbixAPI.usrgrpids);cmd_run_zabbix_API;New-UserGroupZabbixAPI"
                Write-Host $textLogs -ForegroundColor Blue
                Out-WriteLogs $textLogs
            }
        }

        #Search for the necessary groups from LDAP to Zabbix, after creating the missing groups, we write the result to the variable ( $findGroupInZabbixAPI).
        if ( $newUserGroupZabbixAPI ) {
            #If you have created new groups.
            #Secondary analysis. Getting all the groups in Zabbix from the list $toFindGroupLdap
            $findGroupInZabbix_2 = Get-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUserGroup $toFindGroupLdap -IncomingUsers
            $findGroupInZabbixAPI = $findGroupInZabbix_2
        } else {
            #If no new groups have been created
            $findGroupInZabbixAPI = $findGroupInZabbix_1
        }

        ###Module_3_#############################################
        #########################################################
        ###Checking and creating users
        #The list of which users will be searched from LDAP( $tofindUserLdap ).
        $tofindUserLdap = ( ($arrFindGpLdapMemOf | Select-Object ldapUser -Unique).ldapUser | Where-Object { $_ -notlike $null} )
        #Request a list of users from Zabbix. Required to detect existing users.
        $inUsersZabbix_1 = Get-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUser ($tofindUserLdap -join ",") -SelectUsrGrps

        <#
        #Comparison of LDAP users with existing Zabbix users.
        #If there is no object for comparison ($findInUsersGpZabbix), we create a new user.
        #If there are no objects to compare, we create users from the LDAP list ($tofindUserLdap).
        #>  
        if ( $inUsersZabbix_1 ){  
            $compareUsersRun1 = (Compare-Object -ReferenceObject $tofindUserLdap -DifferenceObject $inUsersZabbix_1.username -IncludeEqual | Where-Object { $_.SideIndicator -eq "<=" }).InputObject
            $compareUsers = $compareUsersRun1
        } 
        elseif (-Not $findInUsersGpZabbix ){
            $compareUsers = $tofindUserLdap
        }

        #Creaet USER.
        #If the user is not in Zabbix
        if ( $compareUsers ){
            foreach ( $oneUser in $compareUsers ){
                #We look at which LDAP groups the user is in
                $findGroups = ($arrFindGpLdapMemOf | Where-Object { $_.ldapUser -eq $oneUser }).ldapGroup
                #Search for the group id in Zabbix, the id is needed to create a user.
                $arrfindGroupsId = @()
                foreach ( $oneGroups in $findGroups ){
                    $findGroupsId = ($findGroupInZabbixAPI | Where-Object { $_.name -eq $oneGroups }).usrgrpid
                    $arrfindGroupsId += $findGroupsId 
                }
                $UserGroupsId = $arrfindGroupsId -join ","
                #Create user.
                $newUserZabbixAPI = New-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -NewUser $oneUser -NewUserPass $zabbixNewUserPass -UserGroupsId $UserGroupsId -UserRolesId $zabbixUserRolesId
                #Logs.
                $textLogs = "$taskRunTime;$taskNum;CREATE;module_3;add_user;$oneUser;add_userid;$($newUserZabbixAPI.result.userids);cmd_run_zabbix_API;New-UserZabbixAPI"
                Write-Host $textLogs -ForegroundColor Blue
                Out-WriteLogs $textLogs
            }
        }

        ###Module_4_#############################################
        #########################################################
        ###Synchronize the composition of the modified groups from LDAP and Zabbix.
        #Search for users in existing Zabbix groups (groups created from LDAP).
        $inUsersGpZabbix_2 = Get-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUserGroup ($toFindGroupLdap+","+ $userGroupsDisable) -IncomingUsers
        $inUsersZabbix_2 = Get-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUser ($tofindUserLdap -join ",") -SelectUsrGrps

        #Creating an array of matching group id, group name, user id, user name from Zabbix User Groups.
        $arrGpZabbixAll = @()
        foreach ( $oneUsersGpZabbix in $inUsersGpZabbix_2 ) {
            $syncGpName = $oneUsersGpZabbix.name
            $syncGpId = $oneUsersGpZabbix.usrgrpid
            $arrGpZabbix = @()
            If ( -not $oneUsersGpZabbix.users ) {
                $objOneMemberOf = New-Object System.Object
                $objOneMemberOf | Add-Member -Type NoteProperty -name grpid -Value $syncGpId
                $objOneMemberOf | Add-Member -Type NoteProperty -name grpname -Value $syncGpName
                $objOneMemberOf | Add-Member -Type NoteProperty -name userid -Value 000
                $objOneMemberOf | Add-Member -Type NoteProperty -name username -Value "null"
                $arrGpZabbix += $objOneMemberOf
            }else {
                foreach ( $oneMemberOf in $oneUsersGpZabbix.users ) {
                    $objOneMemberOf = New-Object System.Object
                    $objOneMemberOf | Add-Member -Type NoteProperty -name grpid -Value $syncGpId
                    $objOneMemberOf | Add-Member -Type NoteProperty -name grpname -Value $syncGpName
                    $objOneMemberOf | Add-Member -Type NoteProperty -name userid -Value $oneMemberOf.userid
                    $objOneMemberOf | Add-Member -Type NoteProperty -name username -Value $oneMemberOf.username
                    $arrGpZabbix += $objOneMemberOf
                }
            }
            $arrGpZabbixAll += $arrGpZabbix
        }

        #Change USER. $tofindUserLdap 
        #We find users who have different group contents in LDAP and in Zabbix
        $arrChangeUsrCheck = @()
        foreach ( $sOneUser in $tofindUserLdap ){
            #Which groups does the user belong to in LDAP
            $fUserLdap = $arrFindGpLdapMemOf| Where-Object { $_.ldapUser -eq $sOneUser }
            $fUserZabx = $arrGpZabbixAll | Where-Object { $_.username -eq $sOneUser }
            $zabbixUsrId = $inUsersZabbix_2 | Where-Object { $_.username -eq $sOneUser } | Select-Object userid, username, usrgrps
            #Step_1
            if (-Not $fUserZabx ){
                $fArrOneUserLDAP1 = @()
                foreach ( $fOneUserLDAP1 in $fUserLdap.ldapGroup ){
                    $fGrpIdForLDAP1 = ($arrGpZabbixAll | Where-Object { $_.grpname -eq $fOneUserLDAP1 }).grpid | Select-Object -Unique
                    $fArrOneUserLDAP1 += $fGrpIdForLDAP1
                }
                $setGrp = ($fArrOneUserLDAP1) -join ","
                #Convert $setUsrId* to type int.
                [int]$setUsrId41 = $zabbixUsrId.userid         
                Set-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -UserId $zabbixUsrId.userid -Usrgrps $setGrp
                #Logs.
                $textLogs = "$taskRunTime;$taskNum;CHANGE;module_4;step_1_change_user;$sOneUser;step_1_change_userid;$setUsrId41;cmd_run_zabbix_API;Set-UserZabbixAPI"
                Write-Host $textLogs -ForegroundColor DarkYellow
                Out-WriteLogs $textLogs
                #Add array.
                $arrChangeUsrCheck += $zabbixUsrId
                #Remove-Variable -Name $fArrOneUserLDAP1 -ErrorAction Ignore
            }
            #Step_2
            if ( $fUserZabx ){
                #fDiffObj unite all the groups in which the user is a member, to compare discrepancies
                $f1 = ($zabbixUsrId.usrgrps.name) -join ","
                $f2 = ($fUserZabx.grpname) -join ","
                $fDiffObj = ($f1+","+$f2) -split "," | Select-Object -Unique
                $fCompare = Compare-Object -ReferenceObject $fUserLdap.ldapGroup -DifferenceObject $fDiffObj -IncludeEqual
                if ( $fCompare.SideIndicator -eq "<=" -OR $fCompare.SideIndicator -eq "=>"){
                    $fArrOneUserLDAP2 = @()
                    foreach ( $fOneUserLDAP2 in $fUserLdap.ldapGroup ){
                        $fGrpIdForLDAP2 = ($arrGpZabbixAll | Where-Object { $_.grpname -eq $fOneUserLDAP2 }).grpid | Select-Object -Unique
                        $fArrOneUserLDAP2 += $fGrpIdForLDAP2
                    }
                    $setGrp = ($fArrOneUserLDAP2) -join ","
                    #Convert #setUsrId* to type int.
                    [int]$setUsrId42 = $zabbixUsrId.userid         
                    Set-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -UserId $zabbixUsrId.userid -Usrgrps $setGrp
                    #Logs.
                    $textLogs = "$taskRunTime;$taskNum;CHANGE;module_4;step_2_change_user;$sOneUser;step_2_change_userid;$setUsrId42;cmd_run_zabbix_API;Set-UserZabbixAPI"
                    Write-host $textLogs -ForegroundColor Green
                    Out-WriteLogs $textLogs
                    #Add array.
                    $arrChangeUsrCheck += $zabbixUsrId
                    #Remove-Variable -Name $fArrOneUserLDAP2 -ErrorAction Ignore
                }
            }     
        }

        ###Module_5_#############################################
        #########################################################
        #We clean groups from users outside LDAP groups.
        if( $arrChangeUsrCheck ) {
            $inUsersGpZabbix_3 = Get-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUserGroup ($toFindGroupLdap+","+ $userGroupsDisable) -IncomingUsers
        }
        if(-Not $arrChangeUsrCheck ) {
            $inUsersGpZabbix_3 = $inUsersGpZabbix_2
        }

        #Comparing LDAP groups with Zabbix.
        $fClearGrpCompare = (Compare-Object -ReferenceObject ($arrFindGpLdapMemOf | Select-Object ldapGroup -Unique).ldapGroup -DifferenceObject $inUsersGpZabbix_3.name -IncludeEqual | Where-Object { $_.SideIndicator -eq "=="}).InputObject
        #We find the user ID of the user name in the mapped groups in Zabbix.
        $arrUsrGpRes = @()
        $fClearGrpCompare | ForEach-Object -Process { 
            $gp = $_
            $gpRes = ($inUsersGpZabbix_3 | Where-Object { $_.name -eq $gp}).users | Select-Object userid, username
            $arrUsrGpRes += $gpRes
        }
        $cUsrGpRes = $arrUsrGpRes | Select-Object userid, username -Unique

        #We find the difference between users from LDAP groups and users from Zabbix groups. If the user is not present from LDAP, then move him to the $userGroupsDisable group in Zabbix.
        $fClearUsrCompare = ( Compare-Object -ReferenceObject $tofindUserLdap -DifferenceObject  $cUsrGpRes.username -IncludeEqual | Where-Object { $_.SideIndicator -eq "=>"}).InputObject
        if ( $fClearUsrCompare ) {
            foreach ( $oneDisUser in $fClearUsrCompare ){
                $disUsrId = ( $cUsrGpRes | Where-Object { $_.username -ccontains $oneDisUser })
                [int]$setUsrId5 = $disUsrId.userid -replace "\s"
                #Convert $setGrpId5 to type array.
                [int]$setGrpId5 = ($inUsersGpZabbix_3 | Where-Object {$_.name -eq $userGroupsDisable}).usrgrpid
                Set-UserZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -UserId $setUsrId5 -Usrgrps $setGrpId5
                #Logs.
                $textLogs = "$taskRunTime;$taskNum;DISABLE;module_5;disable_user;$oneDisUser;disable_userid;$setUsrId5;cmd_run_zabbix_API;Set-UserZabbixAPI"
                Write-Host $textLogs -ForegroundColor Cyan
                Out-WriteLogs $textLogs
            }
        }
        $textLogsEnd = "$taskRunTime;$taskNum;END;;;;;;;;"
        Write-Host $textLogsEnd -ForegroundColor Green
        Out-WriteLogs $textLogsEnd
    }
    catch{
        #If an error occurs, write the log to /tmp/manageZabbixSyncLDAPgroups_Linux.log
        $err = $error[0] | format-list -Force
        $err | Out-File /tmp/manageZabbixSyncLDAPgroups_Linux_Error.log -Append -Encoding utf8
    }
}

manageZabbixSyncLDAPgroups -apiUser $args[0] -apiUserPass $args[1] -apiUrl $args[2] -apiToken $args[3] -jsonQuery $args[4] -ldapsearchUser $args[5] -ldapsearchPass $args[6] -ldapsearchServer $args[7] -ldapsearchBase $args[8] -zabbixNewUserPass $args[9] -zabbixUserRolesId $args[10] -userGroupsDisable $args[11] -guiAccess $args[12] -logsOn $args[13]
