#!/bin/pwsh

#We send a specific schedule graph of item to telegram
function Invoke-ZabbixGraphToTelegram {
    param(
        #Zabbix
        [Parameter(Mandatory = $true, position = 0)][string]$ZbxUrlWWW,
        [Parameter(Mandatory = $true, position = 1)][string]$ZbxUser,
        [Parameter(Mandatory = $true, position = 2, ParameterSetName = "Passwd")][string]$ZbxInPasswd,
        [Parameter(Mandatory = $true, position = 3)][int]$ZbxGraphId,
        #Telegram
        [Parameter(Mandatory = $true, position = 4)][string]$TgmToken,
        [Parameter(Mandatory = $true, position = 5)][string]$TgmChatid,
        [Parameter(Mandatory = $false,position = 6)][ValidateSet("True","False")]$Sound
    )
    try{
        Import-Module manageZabbixWithAPI
        #Autorization Zabbix Web and save Graph
        $cookie = Connect-ZabbixWEB -UrlWeb $ZbxUrlWWW -User $ZbxUser -inPasswd $ZbxInPasswd
        [string]$saveConvertName = $ZbxGraphId
        $savePng = "/tmp/$(Get-Random)_$saveConvertName.png"
        Save-GraphZabixWEB -UrlWeb $ZbxUrlWWW -graphId_Item $ZbxGraphId -timeFrom "now-30m" -timeTo "now" -imgHeight 200 -imgWidth 600 -imgSave $savePng -WebSession $cookie

        #Telegram
        $uri = "https://api.telegram.org/bot$TgmToken/sendPhoto"
        $fileObject= get-item $savePng
        #$Text = "Test"
        $Form = @{
            chat_id = $TgmChatid
            photo   = $fileObject
            #caption = $Text
            #disable_notification = 'True'
        }
        #Sound Enable\Disable. Sound is always on by default is True.
        if($Sound){
            if($Sound -eq "False"){
               from.Add("disable_notification",'True')}
            if($Sound -eq "True"){
               from.Add("disable_notification",'False')}
        }
        #form
        $invokeRestMethodSplat = @{
                Uri         = $Uri
                ErrorAction = 'Stop'
                Form        = $Form
                Method      = 'Post'
        }
        $resultIRM = Invoke-RestMethod @invokeRestMethodSplat
        #Resultat
        if ( $resultIRM.ok -eq $true){
            #The message is gone
            Write-Host '1'
            #Write-Host "True" -ForegroundColor Green
        } else {
            #The message not gone
            Write-Host '2'
            #Write-Host "False" -ForegroundColor Red
        }
        Remove-Item $savePng -Force
    }
    catch{
        #Errror Run
        Write-Host '3'
        #Write-Host "False" -ForegroundColor Red
        $err = $error[0] | format-list -Force
        $err | Out-File /tmp/ZabbixImgToTelegram_Error.log -Append -Encoding utf8
    }
}

Invoke-ZabbixGraphToTelegram -ZbxUrlWWW $args[0] -ZbxUser $args[1] -ZbxInPasswd $args[2] -ZbxGraphId $args[3] -TgmToken $args[4] -TgmChatid $args[5]
