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
    return $result = (Invoke-RestMethod @datasourceParameters).teams
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
    return $result = Invoke-RestMethod @datasourceParameters
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
    $result = (Invoke-RestMethod @datasourceParameters -Body $body).message 
    return $arr = @(New-Object PSObject -Property @{"userId"=$userId; "message"=$result; "teamId"=$teamId})
}

#Create Team.
function Create-GrafTeam {
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
    return $result = Invoke-RestMethod @datasourceParameters -Body $bodyJson
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
    return $result = Invoke-RestMethod @datasourceParameters 
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
    return $result = Invoke-RestMethod @datasourceParameters 
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
    return $result = Invoke-RestMethod @datasourceParameters 
}

Export-ModuleMember -Function Get-GrafTeams,Get-GrafTeamMembers,Add-GrafTeamMembers,Create-GrafTeam,Get-GrafUsers,Get-GrafUser,Get-GrafUserTeams
