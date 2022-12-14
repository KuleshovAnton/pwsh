#!/bin/pwsh

#Version 1.0.0.5
#OS Platform
function GetOS {
    if ( $PSVersionTable.PSVersion.Major -le "5" ) {   
        return $Platform = "Win32NT"
        }
    elseif ( $PSVersionTable.PSVersion.Major -ge "6" -and $PSVersionTable.Platform -eq "Win32NT" ) {
        return $Platform = "Win32NT"
        }
    elseif ( $PSVersionTable.PSVersion.Major -ge "6" -and $PSVersionTable.Platform -eq "Unix" ) {
        return $Platform = "Unix"
        }
}

#Credential
function Convert-GrafCredential{
    <#
    .SYNOPSIS
        Function for converting plain text authentication informations to base 64
    .EXAMPLE
        Convert-GrafCredential -login foo -password bar
    #>
    param(
        [Parameter(Mandatory=$true)][string]$Login,
        [Parameter(Mandatory=$true)][string]$Password
        )
    return [Convert]::ToBase64String( [Text.Encoding]::ASCII.GetBytes(( "{0}:{1}" -f $login,$password) ) )
}

#DatasourceParameters
function Create-GrafDatasourceParameters {
    param(
        [parameter(Mandatory=$true,position=0)]$Method,
        [parameter(Mandatory=$true,position=1)]$URI,
        [parameter(Mandatory=$true,position=2)]$Credential
        )
    $datasourceParameters = @{
        Method = $Method
        URI = $URI
        Headers = @{"Authorization" = "Basic $Credential"}
        ContentType = "application/json;charset=UTF-8"
        }
    return $datasourceParameters
}

###TEAMS
#Get all Teams.
function Get-GrafTeams {
    <#
    .SYNOPSIS
        Grafana Function Get all Teams. 
    .EXAMPLE
        Get-GrafTeams -Login foo -Password foo -Url "http://_IP_or_DNS_:Port"
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/teams/search?"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return (Invoke-RestMethod @datasourceParameters).teams }
        Unix { return (Invoke-RestMethod @datasourceParameters -SkipCertificateCheck).teams }
        }
}

##Get Team members.
function Get-GrafTeamMembers {
    <#
    .SYNOPSIS
        Grafana Function Get Teams members. 
    .EXAMPLE
        Get-GrafTeamsMember -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -teamId number_TeamId
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$teamId 
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/teams/$teamId/members"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters }
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

#Add a user to the Team.
function Add-GrafTeamMembers {
    <#
    .SYNOPSIS
        Grafana Function Add a user to the Team.
    .EXAMPLE
        Add-GrafTeamsMembers -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -teamId number_TeamId -userId number_UserId
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$teamId,
        [parameter(Mandatory=$true,position=4)]$userId
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/teams/$teamId/members"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "POST" -URI $createDatasourceUri -Credential $credential
    $body = ("{"+"""userId"""+":"+ $userId +"}")
    Switch (GetOS){
        Win32NT { $result = (Invoke-RestMethod @datasourceParameters -Body $body) }
        Unix { $result = (Invoke-RestMethod @datasourceParameters -Body $body -SkipCertificateChec) }
        }
    return $arr = @(New-Object PSObject -Property @{"userId"=$userId; "message"=$result.message; "teamId"=$teamId})
}

#Create Team.
function New-GrafTeam {
        <#
    .SYNOPSIS
        Grafana Function Create Team.
    .EXAMPLE
        Add-GrafTeamsMembers -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -NameTeam Name_Team -EmailTeam Email_Team -OrgId Org_Id
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$NameTeam,
        [parameter(Mandatory=$false,position=4)]$EmailTeam,
        [parameter(Mandatory=$true,position=5)]$OrgId
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/teams"
    $body = @{
        "name"= $NameTeam;
        "email"= "$EmailTeam";
        "orgId"= $orgId 
    }
    $bodyJson = (ConvertTo-Json $body) -replace "\s\s+"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "POST" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters -Body $bodyJson }
        Unix { return Invoke-RestMethod @datasourceParameters -Body $bodyJson -SkipCertificateCheck }
        }
}

###USER
#Get all users.
function Get-GrafUsers {
    <#
    .SYNOPSIS
        Grafana Function Get all users
    .EXAMPLE
        Get-GrafUsers -Login foo -Password foo -Url "http://_IP_or_DNS_:Port"
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/users"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters }
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

#Get user using Id or login/email.
function Get-GrafUser {
    <#
    .SYNOPSIS
        Grafana Function Get user using Id or login/email.
    .EXAMPLE
        Get-GrafUser -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -$userId number_UserId
        Get-GrafUser -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -$userLoginOrEmail User1
        Get-GrafUser -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -$userLoginOrEmail User1@email.foo
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$false,position=3)]$userId,
        [parameter(Mandatory=$false,position=4)]$userLoginOrEmail
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    if ( $userId ) {
        $createDatasourceUri = "$Url/api/users/$userId"
        }
    else {
        $createDatasourceUri = "$Url/api/users/lookup?loginOrEmail=$userLoginOrEmail"
        }
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters }
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

#Get which groups the user is in.
function Get-GrafUserTeams {
    <#
    .SYNOPSIS
        Grafana Function Get which groups the user is in.
    .EXAMPLE
        Get-GrafUser -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -$userId number_UserId
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$userId
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/users/$userId/teams"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential 
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters }
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

###DASHBOARD
#Get Folders And Dashboards.
function Get-GrafFoldersAndDashboards {
	<#
    .SYNOPSIS
        Grafana Function Get Folders And Dashboards.
    .EXAMPLE
        Get-GrafFoldersAndDashboards -Login foo -Password foo -Url "http://_IP_or_DNS_:Port"
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/search?query="
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters}
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

#Get permissions for a dashboard. Working before version 9.0.
function Get-GrafPermissionsDashboard {
	<#
    .SYNOPSIS
        Grafana Function Get permissions for a dashboard. Working before version 9.0.
	.PARAMETER id
		Dashboard id number.
    .EXAMPLE
        Get-GrafPermissionsDashboard -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -id 6
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$id
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/dashboards/id/$id/permissions"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return Invoke-RestMethod @datasourceParameters}
        Unix { return Invoke-RestMethod @datasourceParameters -SkipCertificateCheck }
        }
}

#Update permissions for a dashboard.
function Add-GrafPermissionsDashboard {
	<#
    .SYNOPSIS
        Grafana Function updates permissions for a dashboard. This operation will remove existing permissions if they’re not included in the request.
		Permissions cannot be set for Admins - they always have access to everything.
	.PARAMETER id
		Dashboard id number.
	.PARAMETER Access
		parameter schema: role:(id||role),permission
		transfer a role: team, user - compare with id. Example: "team:20,1","user:32,2"
		transfer a role: role - compare with Viewer or Editor. Example: "role:Viewer,4"
		transfer permission: View=1 Editor=2 Admin=4
    .EXAMPLE
        Get-GrafPermissionsDashboard -Login foo -Password foo -Url "http://_IP_or_DNS_:Port" -id 6 -Access "team:20,1","user:32,2","role:Viewer,4"
    #>
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url,
        [parameter(Mandatory=$true,position=3)]$id,
        [parameter(Mandatory=$true,position=4)]$Access 
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/dashboards/id/$id/permissions"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "POST" -URI $createDatasourceUri -Credential $credential
    $arr = @()
    foreach ( $oneAccess in $Access ){
        $findVariable = $oneAccess -split ","
        $findRole = $findVariable[0] -split ":"
        $findPerm = $findVariable[1]
        switch ($findRole[0]) {
            "team" { $roleid = "teamId";break }
            "user" { $roleid = "userId";break }
            "role" { $roleid = "role";break }
        }
        $arr += $addPermission = ('{"'+ $roleid +'":'+ $findRole[1] +',"permission":'+ $findPerm +'}')
    }
    $defPermission = @{
        "items"=@(
            $arr
        )
    }
    $json = (ConvertTo-Json -InputObject $defPermission) -replace "\\r\\n" -replace "\\" -replace "\s\s+" -replace '"\[','[' -replace '\]"',']' -replace '"{','{' -replace '}"','}'
    Switch (GetOS){
        Win32NT { $result = (Invoke-RestMethod @datasourceParameters -Body $json) }
        Unix { $result = (Invoke-RestMethod @datasourceParameters -Body $json -SkipCertificateCheck) }
        }
    $return = ("ID:"+$id +" "+ $result.message +" for "+ $allAccess)
    return $return
}

#Grontend Settings
function Get-GrafFrontendSettings {
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/frontend/settings"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return (Invoke-RestMethod @datasourceParameters) }
        Unix { return (Invoke-RestMethod @datasourceParameters -SkipCertificateCheck) }
        }
}

#Grafana Health
function Get-GrafHealth {
    param(
        [parameter(Mandatory=$true,position=0)]$Login,
        [parameter(Mandatory=$true,position=1)]$Password,
        [parameter(Mandatory=$true,position=2)]$Url
        )
    $credential = Convert-GrafCredential -Login $Login -Password $Password
    $createDatasourceUri = "$Url/api/health"
    $datasourceParameters = Create-GrafDatasourceParameters -Method "Get" -URI $createDatasourceUri -Credential $credential
    Switch (GetOS){
        Win32NT { return (Invoke-RestMethod @datasourceParameters) }
        Unix { return (Invoke-RestMethod @datasourceParameters -SkipCertificateCheck) }
        }
}

Export-ModuleMember -Function Get-GrafTeams, Get-GrafTeamMembers, Add-GrafTeamMembers, New-GrafTeam, Get-GrafUsers, Get-GrafUser, Get-GrafUserTeams, Get-GrafFoldersAndDashboards, Get-GrafPermissionsDashboard, Add-GrafPermissionsDashboard, Get-GrafFrontendSettings, Get-GrafHealth
