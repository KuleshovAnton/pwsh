#!/bin/pwsh
#v_1.0.0.5
function manageZabbixAccessUserGrp {
    <#
    .SYNOPSIS
        ...
        v_1.0.0.5
        Adding permissions to Zabbix -> Administration -> User groups -> (FOR RECEIVED GROUPS BY LIST) -> Permissions And Tag Filter.
        The error result is output for Windows to terminal , for Linux /tmp/manageZabbixAccessUserGrp_Linux_Error.log
        ...
    .PARAMETER apiUrl
        Specify the URL to connect to the Zabbix API. Example: -apiUrl "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" OR "https://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php"
    .PARAMETER apiUser
        A Zabbix user who has rights to connect to the Zabbix API. Example: -apiUser userZabbixAPI
    .PARAMETER apiUserPass
        User Password for connection to the Zabbix API.
    .PARAMETER apiToken
        The user ID when logging into the Zabbix API. Set a random number. Example: -apiToken 7
    .PARAMETER searchGrpName
        Search for a group of hosts to add. Example -searchGrpName "findHostGroup1,findHostGroup2/Obj"
    .PARAMETER searchGrpNameLevel
        Search for a group of hosts to add, level resolution -searchGrpName_LevelPermission read-only
    .PARAMETER searchSubGrpName
        Search for subgroups of hosts to add. Example: -searchSubGrpName True
    .PARAMETER excludeGrpName
        Groups of hosts for exclude. Example -excludeGrpName "Group3/Obj,Group4/Obj"
    .PARAMETER filterUserGroup
        User groups that will be updated. Example: -filterUserGroup "userGroup1,userGroup2" or -filterUserGroup '[{"name":"userGroup1"},{"name":"userGroup2"}]'
    .PARAMETER excludeUserGroup
        User groups that will be exclude for updated. Example: -excludeUserGroup "userGroup1,userGroup2" or -excludeUserGroup '[{"name":"userGroup1"},{"name":"userGroup2"}]'
    .PARAMETER logsOn
        Enable logging to a file. Default disable, output to the screen. Example: -logsOn "True"
        For Windows $env:SystemDriv\temp\manageZabbixAccessUserGrp_Win.log"
        For Linux /tmp/manageZabbixAccessUserGrp_Linux.log
    .PARAMETER WhatIf
        Dispays a message describing the effect of the command, but does not execute it. Examle -WhatIf True
    .PARAMETER Action
        Define actions to Add or Remove objects. Required parameter. Example: -Action Add
    .EXAMPLE
        manageZabbixAccessUserGrp -apiUser "userZabbixAPI" -apiUserPass "PassZbxAPI" -apiUrl "http://IP_or_FQDN_Zabbix/zabbix/api_jsonrpc.php" -apiToken 7 -searchGrpName "findHostGroup1,findHostGroup2" -searchGrpName_LevelPermission read-only -searchSubGrpName True -filterUserGroup "userGroup1,userGroup2" -logsOn False -WhatIf True -Action Add
    #>

    param(
        [Parameter(Mandatory=$true,position=0)][string]$apiUrl,
        [Parameter(Mandatory=$true,position=1)][string]$apiUser,
        [Parameter(Mandatory=$true,position=2)][string]$apiUserPass,
        [Parameter(Mandatory=$true,position=3)][int]$apiToken,
        [Parameter(Mandatory=$false,position=4)][ValidatePattern("^\w")][string]$searchGrpName,
        [Parameter(Mandatory=$false,position=5)][ValidateSet("denied", "read-only", "read-write")]$searchGrpName_LevelPermission = 'read-only',
        [Parameter(Mandatory=$false,position=6)][ValidateSet($True, $False)]$searchSubGrpName = $True,
        [Parameter(Mandatory=$false,position=7)][string]$excludeGrpName = "",
        [Parameter(Mandatory=$false,position=8)][ValidatePattern("^\[\{.*\}\]|^\w")][string]$filterUserGroup,
        [Parameter(Mandatory=$false,position=9)][ValidatePattern("^\[\{.*\}\]|^\w")][string]$excludeUserGroup,
        [Parameter(Mandatory=$false,position=10)][ValidateSet("True","False")]$logsOn = "False",
        [Parameter(Mandatory=$true,position=12)][ValidateSet("Add","Remove")]$Action,
        [Parameter(Mandatory=$false,position=11)][ValidateSet($True, $False)]$WhatIf
    )

    ###OS Platform
    function global:GetOS {
        if ( $PSVersionTable.PSVersion.Major -le "5" ) { return "Win32NT" }
        elseif ( $PSVersionTable.PSVersion.Major -ge "6" -and $PSVersionTable.Platform -eq "Win32NT" ) { return "Win32NT" }
        elseif ( $PSVersionTable.PSVersion.Major -ge "6" -and $PSVersionTable.Platform -eq "Unix" ) { return "Unix" }
    }

    ###Tme mark.
	$global:taskRunTime = get-date -Format 'yyyy MMM dd HH:mm:ss'
    ###WriteLogs to file.
	function global:Out-WriteLogs{
        param(
            [Parameter(Mandatory=$true, Position=0)]$inputDataLogs,
            [Parameter(Mandatory=$false,Position=1)][ValidateSet("True","False")]$logsOn
        )
		if($logsOn -match 'True'){
            $logsOut = ($taskRunTime +";"+ $inputDataLogs)
            $OS = GetOS
            If($OS -eq 'Win32NT'){
                $logsOut | Out-File ($env:SystemDrive +"\temp\manageZabbixAccessUserGrp_Win.log") -Append -Encoding utf8 -ErrorAction Ignore
            }
            If($OS -match 'Unix'){
                $logsOut | Out-File "/tmp/manageZabbixAccessUserGrp_Linux.log" -Append -Encoding utf8 -ErrorAction Ignore
            }
		}
        if($logsOn -eq 'False' -or !$logsOn ){
            return $inputDataLogs 
		}
	}

    try{
        $ErrorActionPreference = "Stop"
        Import-Module -Name manageZabbixWithAPI
        <#
        ###Detection of a subgroup enable-True disable-False
        if($searchSubGrpName -eq "True"){
            [boolean]$searchSubGrpName = $true
        }elseif($searchSubGrpName -eq "False"){
            [boolean]$searchSubGrpName = $false
        }
        #>

        ###Create api token.
        $token = Connect-ZabbixAPI -UrlApi $apiUrl -User $apiUser -TokenId $apiToken -inPasswd $apiUserPass 

        #################################################
        ###Input string for User Group.
        function InputString_UserGroup($InputString){
            if( $InputString -match '\[\{.*\}\]' ){ 
                (ConvertFrom-Json -InputObject $InputString).name -join ","
            }elseif($InputString -match '^\w'){
                $InputString
            }
        }
        ###Input string $filterUserGroup.
        $InputUserGroupResult = InputString_UserGroup($filterUserGroup)

        if($excludeUserGroup){
            #Input string $excludeUserGroup for exclude is $filterUserGroup
            $inputExcludeUserGroup = (InputString_UserGroup($excludeUserGroup)) -split ','
            $filterUserGroupResult = ( $InputUserGroupResult -split ',' | Where-Object { $_ -notin $inputExcludeUserGroup } ) -join ','
        } else {
            $filterUserGroupResult = $InputUserGroupResult
        }
        ##################################################

        ###Search for host group ID to add to the resolution - Permission in Tag.
        $arrSearchGrpName = @()
        foreach ( $oneGrpName in ($searchGrpName -split ",")) {
            #Adding a subgroup search.
            if($searchSubGrpName -eq $True){
                $subGp = ($oneGrpName +'/*')
            }else{ $subGp = "" }
            #
            $oneSearchGrpName = Get-HostGroupsZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -searchGroupName $oneGrpName -searchStart 'True' | Where-Object { $_.name -clike "$oneGrpName" -or $_.name -clike "$subGp" }
            #Exclude.
            if($excludeGrpName){
                $excGp = ("("+ $excludeGrpName +")") -replace ",","|"
                $arrSearchGrpName += $oneSearchGrpName | Where-Object { $_.name -notmatch $excGp }
            }else { 
                $arrSearchGrpName += $oneSearchGrpName 
            }
        }

        ###Search for user groups IDs for which we grant resolution - Permission in Tag.  
        $gp = Get-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -filterUserGroup $filterUserGroupResult -ReturnRights -ReturnTagFilters
        
        ###Search for which host groups to add. Comparing the host groups located in "User groups" with the chain of groups that we want to add? in the absence, we form an array to add.
        $arrCompare = @()
        ###Action Add
        if($Action -eq 'Add'){
            foreach ( $oneCompare in $gp ){

                #Если объекты rights.id присутствуют = rights.id или вставляем заглушку = 0 , для сравнения в Compare-Object
                if($oneCompare.rights.id){
                    $oneCompareRights = $oneCompare.rights.id
                }else { $oneCompareRights = 0 }
                #Если объекты tag_filters.groupid присутствуют = tag_filters.groupid или вставляем заглушку = 0, для сравнения в Compare-Object
                if($oneCompare.tag_filters.groupid){
                    $oneCompareTgF = $oneCompare.tag_filters.groupid
                }else { $oneCompareTgF = 0 }

                #Compare-Object of which host ID groups are missing to Rights and TagFilters.
                $compareRights = (Compare-Object $oneCompareRights -DifferenceObject ($arrSearchGrpName).groupid | Where-Object { $_.SideIndicator -eq '=>' }).InputObject
                $compareTagFilters = (Compare-Object $oneCompareTgF -DifferenceObject ($arrSearchGrpName).groupid | Where-Object { $_.SideIndicator -eq '=>' }).InputObject

                IF ($compareRights -or $compareTagFilters){
                    ###################################################################################
                    #Join $oneCompare.rights.id and $compareRights
                    if($compareRights){

                        #Level resolution. 
                        $perm = switch ($searchGrpName_LevelPermission){
                            'denied'    { '0' }
                            'read-only' { '2' }
                            'read-write'{ '3' }
                            default { '2' }
                            }

                        #Add level resolution for searchGrpName.
                        $arrCR2 = @()
                        foreach ( $oneCR2 in $compareRights ){
                            $txtCR2 = ( $perm +':'+ $oneCR2 )
                            $arrCR2 += $txtCR2 
                            }

                        #If there are NO access objects in the group filterUserGroup, adding objects from searchGrpName.
                        if($oneCompareRights -eq 0){
                            $plusCompareRights = ($arrCR2 -join ',')
                        #If there are access objects in the group filterUserGroup, adding objects from searchGrpName and join with object filterUserGroup.
                        }else{ 
                            $arrCR1 = @()
                            foreach ( $oneCR1 in $oneCompare.rights ){
                                $txtCR1 = ( $oneCR1.permission +':'+ $oneCR1.id )
                                $arrCR1 += $txtCR1 
                                }
                            $plusCompareRights = ( $($arrCR1 -join ',') +","+ $($arrCR2 -join ',') )     
                        }
                    }else{ $plusCompareRights = "" }
                    ###################################################################################
                    #Join $oneCompare.tag_filters.groupid and $oneCompareTgF
                    if($compareTagFilters){

                        $arrCTF2 = @()
                        foreach ( $oneCTF2 in $compareTagFilters){
                            $txtCTF2 = ('::'+ $oneCTF2)
                            $arrCTF2 += $txtCTF2   
                            }  

                        if($oneCompareTgF -eq 0 ){
                            $plusCompareTgF = ($arrCTF2 -join ',')
                        }else{ 
                            $arrCTF1 = @()
                            foreach( $oneCTF1 in $oneCompare.tag_filters ){
                                $txtCTF1 = ( $oneCTF1.tag +':'+ $oneCTF1.value +':'+ $oneCTF1.groupid )
                                $arrCTF1 += $txtCTF1
                                }
                            
                            $plusCompareTgF = ( $($arrCTF1 -join ',') +","+ $($arrCTF2 -join ',') )
                        }
                    }else{ $plusCompareTgF = "" }
                    
                    ###################################################################################
                    $compareObj = New-Object System.Object
                    $compareObj | Add-Member -Type NoteProperty -Name usrgrpid -Value $oneCompare.usrgrpid
                    $compareObj | Add-Member -Type NoteProperty -Name name -Value $oneCompare.name
                    $compareObj | Add-Member -Type NoteProperty -Name action -Value 'Add'
                    $compareObj | Add-Member -Type NoteProperty -Name rightsAdd -Value $plusCompareRights
                    $compareObj | Add-Member -Type NoteProperty -Name tagFiltersAdd -Value $plusCompareTgF
                    $arrCompare += $compareObj  
                }
            }
        }
        ###Action Remove
        if($Action -eq 'Remove'){
            
            foreach ( $oneRemoveGp in $gp ){
                
                #Сравниваем и находим однотипные groupid в Permissions.
                $compare_Remove_rights =  (Compare-Object $oneRemoveGp.rights.id -DifferenceObject $arrSearchGrpName.groupid -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' }).InputObject
                #Сравниваем и находим однотипные groupid в TagFilter Permissions.
                $compare_Remove_filTag =  (Compare-Object $oneRemoveGp.tag_filters.groupid -DifferenceObject $arrSearchGrpName.groupid -IncludeEqual | Where-Object { $_.SideIndicator -eq '==' }).InputObject
            
                if($compare_Remove_rights -or $compare_Remove_filTag){
                    
                    if($compare_Remove_rights){
                        #Исключаем searchGrpName из filterUserGroup в параметрах Permissions.
                        $Remove_rights = $oneRemoveGp.rights | Where-Object { $_.id -notin $arrSearchGrpName.groupid }
                        $arrRR1 = @()
                        foreach ( $oneRR1 in $Remove_rights){
                            $txtRR1 = ( $oneRR1.permission  +':'+ $oneRR1.id )
                            $arrRR1 += $txtRR1 
                        }
                    }else{ $arrRR1 = @() }


                    if($compare_Remove_filTag){
                        #Исключаем searchGrpName из filterUserGroup в параметрах TagFilter Permission
                        $Remove_filTag = $oneRemoveGp.tag_filters | Where-Object { $_.groupid -notin $arrSearchGrpName.groupid }
                        $arrFT1 = @()
                        foreach ( $oneFT1 in $Remove_filTag){
                            $txtFT1 = ( $oneFT1.tag  +':'+ $oneFT1.value +':'+ $oneFT1.groupid )
                            $arrFT1 += $txtFT1 
                        } 
                    }else{ $arrFT1 = @() }

                    $removeObj = New-Object System.Object
                    $removeObj | Add-Member -Type NoteProperty -Name usrgrpid -Value $oneRemoveGp.usrgrpid
                    $removeObj | Add-Member -Type NoteProperty -Name name -Value $oneRemoveGp.name
                    $removeObj | Add-Member -Type NoteProperty -Name action -Value 'Remove'
                    $removeObj | Add-Member -Type NoteProperty -Name rightsAdd -Value ($arrRR1 -join ',')
                    $removeObj | Add-Member -Type NoteProperty -Name tagFiltersAdd -Value ($arrFT1 -join ',')
                    $arrCompare += $removeObj
                }
            }
            
        }

        ###################################################################################
        #Making change Set-UserGroupZabbixAPI.
        IF($arrCompare){
            #WhatIf = True
            if($WhatIf -eq $true){
                $arrCompare
            }
            #WhatIf = False (Default)
            else{
                #Add resolution to user groups.
                foreach ( $oneUpdateGrp in $arrCompare ) {
                    IF($oneUpdateGrp.rightsAdd){
                        Set-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -usrgrpid $oneUpdateGrp.usrgrpid -ARR_Permission_groupid $oneUpdateGrp.rightsAdd
                        #Write-Host "Update Rights for User Groups" -ForegroundColor Green
                        $logtR = ("Set;"+ $oneUpdateGrp.action +";User Groups;"+ $oneUpdateGrp.usrgrpid +';Rights;'+ $oneUpdateGrp.rightsAdd)
                        Out-WriteLogs -inputDataLogs $logtR -logsOn $logsOn 
                    }
                    IF($oneUpdateGrp.tagFiltersAdd){
                        Set-UserGroupZabbixAPI -UrlApi $apiUrl -TokenApi $token.result -TokenId $token.id -usrgrpid $oneUpdateGrp.usrgrpid -ARR_Filters_tagvalue_groupid $oneUpdateGrp.tagFiltersAdd
                        #Write-Host "Update Tag Filters for User Groups" -ForegroundColor Green
                        $logtF = ("Set;"+ $oneUpdateGrp.action +";User Groups;"+ $oneUpdateGrp.usrgrpid +';TagFilters;'+ $oneUpdateGrp.tagFiltersAdd)
                        Out-WriteLogs -inputDataLogs $logtF -logsOn $logsOn 
                    }
                }
            }
        }ELSE{
            #Write-Host "Not Update Rights and Tag Filters for User Groups" -BackgroundColor Cyan
            Out-WriteLogs -inputDataLogs ('Set;none;UserGroups;0;RightsAndTagFilters;') -logsOn $logsOn 
        }
        ###################################################################################
    }
    catch{
        Switch (GetOS){
            Win32NT { 
                $err = $error[0] | format-list -Force
                return $err
            }
            Unix { 
                #If an error occurs, we write the log in /tmp/
                $err = $error[0] | format-list -Force
                $err | Out-File "/tmp/manageZabbixAccessUserGrp_Linux_Error.log" -Append -Encoding utf8 -ErrorAction Ignore
            }
        }
    }
}

#manageZabbixAccessUserGrp -apiUrl $args[0] -apiUser $args[1] -apiUserPass $args[2] -apiToken $args[3] -searchGrpName $args[4] `
#-searchGrpName_LevelPermission $args[5] -searchSubGrpName $args[6] -excludeGrpName $args[7] -filterUserGroup $args[8] -excludeUserGroup $args[9] -logsOn $args[10] -Action $args[11]

manageZabbixAccessUserGrp -apiUrl $args[0] -apiUser $args[1] -apiUserPass $args[2] -apiToken $args[3] -searchGrpName $args[4] -filterUserGroup $args[5] -logsOn $args[6] -WhatIf $args[7]
