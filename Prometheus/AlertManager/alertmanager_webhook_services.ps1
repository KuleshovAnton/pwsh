#!/bin/pwsh

#v_1.0.0.3
#Accept and send a alertmanager_webhook.
#Shutdown listener port. Example: #curl http://localhost:8080/api/end
#Create listener port.
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://localhost:8080/api/')
$listener.Start()

while($true){
    #Shutdown listener #curl http://localhost:8080/api/end
    if($request.URL -match '/api/end$'){
        break
    }else{
        $context = $listener.GetContext()
        $request = $context.Request
        #Read incoming body from alertmanager.
        $requestBodyReader = New-Object System.IO.StreamReader $context.Request.InputStream
        $js3 = $requestBodyReader.ReadToEnd() | ConvertFrom-Json
        #Create new body to msg.
        if($js3.status -eq 'firing') {
            $firings = $js3.alerts | Where-Object { $_.status -eq "firing"}
        }else{
            $firings = $js3.alerts | Where-Object { $_.status -eq "resolved"}
        }
        $arrFiring = @()
        foreach ( $oneFiring in $firings){
			
			if($oneFiring.status -eq 'firing'){
				$time = ("StartsAt    : "+ $oneFiring.startsAt)
			}
			if($oneFiring.status -eq 'resolved'){
				$time = ("EndsAt      : "+ $oneFiring.endsAt)
			}
			
            $msg = ("
            AlertName   : "+ $oneFiring.labels.alertname +"
            Instance    : "+ $oneFiring.labels.instance +"
            "+ $time +"
            Summary     : "+ $oneFiring.annotations.summary +"
            Description : "+ $oneFiring.annotations.description +"
			"
            )
            $arrFiring += $msg
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
        $context.Response.Close()
    }
}
$listener.Stop()

######################################################################################

#String RawUrl. example /api/2378234gyufyi-pqiuriuwh34-ijdhiuy4wi/
$rawUrl = ($context.Request.RawUrl) -split "/"
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
Receiver    : team-124
Status      : 🔥firing

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
<#
HasEntityBody:      возвращает true, если в запросе кроме заголовоков переданы какие-нибудь данные (тело запроса).
HttpMethod:         возвращает метод HTTP, использованный для отправки запроса клиентом.
IsAuthenticated:    возвращает значение bool, которое указывает, аутентифицирован ли клиент, отправивший этот запрос.
IsLocal:            возвращает значение bool, которое указывает, был ли запрос отправлен с локального компьютера.
KeepAlive:          возвращает значение bool, которое указывает, требует ли клиент постоянного подключения.
RemoteEndPoint:     возвращает IP-адрес клиента, который отправил запрос.
#>

#Kill
#curl http://localhost:8080/api/end
