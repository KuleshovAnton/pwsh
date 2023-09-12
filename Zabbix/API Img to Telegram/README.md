#Zabbix configure for ZabbixImgToTelegram.

#Create Item in Zabbix WEB.
Img to telegram
ImgToTelegram["{$ZBXURLWWW}","{$ZBXUSER}","{$ZBXINPASSWD}","{$ZBXGRAPHID}","{$TGMTOKEN}","{$TGMCHATID}"]


#Create user parameter on Zabbix agent.
ZabbixImgToTelegram.conf
UserParameter=ImgToTelegram[*], /etc/zabbix/zabbix_agentd.d/./ZabbixImgToTelegram_2.ps1 "$1" "$2" "$3" "$4" "$5" "$6"