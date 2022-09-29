#!/bin/pwsh

#Version 1.0.0.1
function manageGrafanaNewTeamsLdapToml {
  <#
   .SYNOPSIS
      Create new teams in Grafana from the ldap.toml configuration file. 
   .DESCRIPTION
      Use the script, so far only on Linux.
   .PARAMETER login
      User with administrator rights in Grafana. Example: userGrafana
   .PARAMETER passwd
      The password of a user with administrator rights in Grafana.
   .PARAMETER url
      URL GRAFANA API. Example: grafana.domain.local.
   .PARAMETER urlProtocol
      The protocol used to connect to the GRAFANA API. Example: https or http.
   .PARAMETER orgId
      Organization ID in Grafana. Example: 1
   .PARAMETER ldapTomlfile
      The path to the ldap.toml configuration file for Grafana. Example: /etc/grafana/ldap.toml
   .EXAMPLE
      manageGrafanaNewTeamsLdapToml "userGrafana" "Passw0rd" "grafana.domain.local" "https" "1" "/etc/grafana/ldap.toml"
  #>
  param(
    [Parameter(Mandatory=$true,position=0)][string]$login,
    [Parameter(Mandatory=$true,position=1)][string]$passwd,
    [Parameter(Mandatory=$true,position=2)][string]$url,
    [Parameter(Mandatory=$true,position=3)][string]$urlProtocol,
    [Parameter(Mandatory=$true,position=4)][int]$orgId,
	  [Parameter(Mandatory=$true,position=5)][string]$ldapTomlfile
  )
  try{
    $ErrorActionPreference = "Stop"
    #Importing a module to work with the Grafana API.
    import-module manageGrafanaWithAPI
    $contentLdap = ((Get-Content -Path $ldapTomlfile) -match "^group_dn") -notmatch "\*"
    $findContentLdapGp = (($contentLdap -replace "cn=" -replace ",ou.*" -replace "group_dn" -replace "=" -replace '"' -replace "\s\s+") | Select-Object -Unique)
    $urls = ($urlProtocol+"://"+$url)
    $findContentGrafGp = (Get-GrafTeams -Login $login -Password $passwd -Url $urls).name
        
    $compareObject = (Compare-Object -ReferenceObject $findContentLdapGp -DifferenceObject $findContentGrafGp -IncludeEqual | Where-Object { $_.SideIndicator -eq "<=" })
    if ( $compareObject ) {
      foreach ( $oneCompareObject in $compareObject ) {
        New-GrafTeam -Login $login -Password $passwd -Url $urls -NameTeam $oneCompareObject.InputObject -OrgId $orgId
      }
    }
    else { exit }
  }
  catch {
    $err = $error[0] | format-list -Force
    $err | Out-File /tmp/manageGrafanaNewTeamsLdapToml_Error.log -Append -Encoding utf8
  }
}
manageGrafanaNewTeamsLdapToml -login $args[0] -passwd $args[1] -url $args[2] -urlProtocol $args[3] -orgId $args[4] -ldapTomlfile $args[5]
