#!/bin/pwsh

#v_1.0.0.3
#Accept and send a alertmanager_webhook.
#Shutdown listener port. Example: #curl http://localhost:8080/api/end

#Create listener port.
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:8080/api/')
$listener.Start()

#$userAuth = ''
#$userAuthPass = ''
#$urlVCS = ''

while($true){
    $context = $listener.GetContextAsync()

    #Shutdown listener #curl http://localhost:8080/api/end
    if($context.Result.Request.URL -match '/api/end$'){
        break
    }else{
        #Read incoming body from alertmanager.
        $requestBodyReader = New-Object System.IO.StreamReader $context.Result.Request.InputStream
        $js3 = $requestBodyReader.ReadToEnd() | ConvertFrom-Json

        #Create new body to msg all message.
        $arrFiring = @()
        if($js3.status -eq 'firing') {
            $firings = $js3.alerts | Where-Object { $_.status -eq "firing" -or $_.status -eq "resolved" }
            if( $firings.status -eq "firing" ){
                foreach ( $oneFiring in ($firings | Where-Object {$_.status -eq "firing"}) ){
                    $msg = ("
                    🔥AlertName : "+ $oneFiring.labels.alertname +"
                    Instance    : "+ $oneFiring.labels.instance +"
                    StartsAt    : "+ $oneFiring.startsAt +"
                    Summary     : "+ $oneFiring.annotations.summary +"
                    Description : "+ $oneFiring.annotations.description +"
                    ")
                    $arrFiring += $msg
                }
            }
            if( $firings.status -eq "resolved" ){
                foreach ( $oneFiring in ($firings | Where-Object {$_.status -eq "resolved"}) ){
                    $msg = ("
                    💧AlertName : "+ $oneFiring.labels.alertname +"
                    Instance    : "+ $oneFiring.labels.instance +"
                    EndsAt      : start "+ $oneFiring.startsAt +" end "+ $oneFiring.endsAt +"
                    ")
                    $arrFiring += $msg
                }
            }
        }
        if($js3.status -eq 'resolved'){
            $firings = $js3.alerts | Where-Object { $_.status -eq "resolved"}
            foreach ( $oneFiring in $firings ){
                $msg = ("
                AlertName   : "+ $oneFiring.labels.alertname +"
                Instance    : "+ $oneFiring.labels.instance +"
                EndsAt      : "+ $oneFiring.endsAt +"
                Summary     : "+ $oneFiring.annotations.summary +"
                Description : "+ $oneFiring.annotations.description +"
                ")
                $arrFiring += $msg
            }
        }

		#mark img status.
        if ($js3.status -eq 'firing') { $emg = "🔥"} else { $emg ="💧"}
		#message for send.
        $msgToIva  =(
		$emg +""+ $js3.status.ToUpper() +"
        Receiver    : "+$js3.receiver +"
        "+$arrFiring
        )
        ######################################################################################
        #Writer or send, past you code.
        $msgToIva | Out-File "/tmp/alertmanager_webhook.log" -Append -Encoding utf8 -ErrorAction Ignore
        ######################################################################################
        
        #Close session.
        $context.Result.Response.Close()
    }
}
$listener.Stop()

######################################################################################

#String RawUrl. example /api/2378234gyufyi-pqiuriuwh34-ijdhiuy4wi/
$rawUrl = ($context.Result.Request.RawUrl) -split "/"
#output chat ID
$chatId= $rawUrl[2]
#Run sendto IVA
function msgToChatIVA {
    param(
        [Parameter(Mandatory=$true,Position=0)][string]$userAuth,
        [Parameter(Mandatory=$true,Position=1)][string]$passAuth,
        [Parameter(Mandatory=$true,Position=2)][string]$urlAuth,
        [Parameter(Mandatory=$true,Position=3)][string]$chatId,
        [Parameter(Mandatory=$true,Position=4)][string]$chatUrl,
        [Parameter(Mandatory=$true,Position=5)]$msg
    )
    #url auth
    $authBody = @{"login"=$userAuth; "password"=$passAuth; "rememberMe"="false"}
    $authReq = @{
        body = ($authBody | ConvertTo-Json)
        uri  = ($urlAuth +"/api/rest/login")
        headers = @{"content-type" = "application/json"}
        method = "Post"
        }
    $resp = (Invoke-WebRequest @authReq | ConvertFrom-Json).sessionid

    #url cahat
    $apiChatIVA = ($chatUrl +"/api/rest/chats/"+ $chatId +"/send-message")
    #send msg to cahat
    $sendHeaders = @{"Session"=$resp; "Content-type" = "application/json"; "Local"="RU"}
    $sendBody1 = @{"message"=$msg} | ConvertTo-Json
    $sendBody2 = [System.Text.Encoding]::UTF8.GetBytes($sendBody1)
	try{
	    $msgto = Invoke-RestMethod -Method Post -Uri $apiChatIVA -Body $sendBody2 -Headers $sendHeaders
		[string]$timeAt = ($msgto.createdAt)
		$timeLength = $timeAt.Substring(0, 10)
		$timeResult = (([System.DateTimeOffset]::FromUnixTimeSeconds($timeLength)).DateTime.ToLocalTime()).ToString("s")
		( $timeResult +";Send;chatRoomID<"+ $msgto.chatRoomId +">") | Out-File "/tmp/alertmanager_webhook.log" -Append -Encoding utf8 -ErrorAction Ignore
	}catch{
		$StatusCode = $_.Exception.Response.StatusCode
		#$StatusDescription = $_.Exception.Response.StatusDescription
		$ErrorMessage = $_.ErrorDetails.Message
		( $(get-date -Format 'yyyy-MM-ddTHH:mm:ss')+";Error;"+ $([int]$StatusCode) +" "+ $($StatusCode) +" - "+ $($ErrorMessage) ) | Out-File "/tmp/alertmanager_webhook.log" -Append -Encoding utf8 -ErrorAction Ignore
	}
}
msgToChatIVA -userAuth $userAuth -passAuth $userAuthPass -urlAuth $urlVCS -chatUrl $urlVCS -chatId $chatId -msg $msgToIva

######################################################################################
#Create systemd services.
#nano /etc/systemd/system/alertmanager_webhook.service
[Unit]
Description=Alertmanager Webhook
After=network.target
[Service]
Type=simple
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager_webhook.ps1
[Install]
WantedBy=multi-user.target

######################################################################################
#msg example: 
#Create new body to msg only firing or resolved.
🔥FIRING
Receiver    : team-124

AlertName   : NodeExporter-Down
Instance    : 127.0.0.1:9100
StartsAt    : 08/08/2025 15:40:00
Summary     : Node exporter is DOWN
Description : Grafana discover - node exporter is DOWN

AlertName   : NodeExporter-Down
Instance    : 192.168.0.115:9100
StartsAt    : 08/08/2025 15:40:00
Summary     : Node exporter is DOWN
Description : Grafana discover - node exporter is DOWN

######################################################################################
#msg example:
#Create new body to msg all message.
🔥FIRING
Receiver    : team-124

🔥AlertName : NodeExporter-Down
Instance    : 127.0.0.1:9100
StartsAt    : 08/07/2025 21:39:00
Summary     : Instance 127.0.0.1:9100 down
Description : VMalert - 127.0.0.1:9100 of job=node-exporter-VictoriaMetrics has been down for more than 1 minute.

💧AlertName : NodeExporter-Down
Instance    : 192.168.0.115:9100
EndsAt      : start 08/07/2025 21:38:30 end 08/07/2025 21:42:20

######################################################################################

#Kill
#curl http://localhost:8080/api/end
