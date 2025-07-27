#Zabbix configure for ZabbixImgToTelegram.

#Add the PowerShell module to the operating system where the Zabbix server is installed.
manageZabbixWithAPI.psm1 and manageZabbixWithAPI.psd1

#Add the execution script ZabbixImgToTelegram.psq to /etc/zabbix/zabbix_agentd.d/./

#Create user parameter on Zabbix agent.
nano ZabbixImgToTelegram.conf
#Add string.
UserParameter=ImgToTelegram[*], /etc/zabbix/zabbix_agentd.d/./ZabbixImgToTelegram.ps1 "$1" "$2" "$3" "$4" "$5" "$6"

#Create Item in Zabbix WEB.
Name: Img to telegram
Type: Zabbix agent
Key : ImgToTelegram["{$ZBXURLWWW}","{$ZBXUSER}","{$ZBXINPASSWD}","{$ZBXGRAPHID}","{$TGMTOKEN}","{$TGMCHATID}"]
Type of information: Numeric
Update interval: 0
Custom intervals: interval 3h, Period 1-7,09:00-18:00
Tags: Telegram



#Change the macro parameters at the host level
{$TGMCHATID}    - Telegram chat id.
{$TGMTOKEN}     - Telegram token.
{$ZBXGRAPHID}   - Graph ID from Zabbix, you can find it out as follows: open the Graphs of the host in Zabbix and look at the graph ID in the url,
                - or use the Get-GraphZabbixAPI command from the manageZabbixWithAPI module.
{$ZBXINPASSWD}  - A user with access to the web zabbix.
{$ZBXURLWWW}    - Url zabbix server example: https://zabbix/zabbix
{$ZBXUSER}      - A user with access to the web zabbix.