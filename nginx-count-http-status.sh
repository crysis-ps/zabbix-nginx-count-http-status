#!/bin/bash
#
# crontab -u zabbix -e
#* * * * * zabbix bash /etc/zabbix/nginx_count_http_status.sh

zbx_conf="/etc/zabbix/zabbix_agentd.conf"
key_name="response_num"
discovery_key="nginx.discovery.http_code"
log="/var/log/nginx/4lapy.access.log"
log_pos="9"
status_code="200 301 302 400 403 404 499 500 502 503 504"

zbx_host="$(sed -nr 's/^\s*Hostname=+(.+)\s*$/\1/p' $zbx_conf)"
tempfile=$(mktemp /tmp/nginx-count-http-status.XXXXXXXX)

# Timestamp for 1 minute ago
#
curr_ts="$(date '+%d/%b/%Y:%H:%M')"
ts="$(date '+%d/%b/%Y:%H:%M' -d "1 min ago")"

for st in $status_code; do
    access_responses_num=$(grep "${ts}" ${log} | awk '{ print $9 }' | grep "${st}" | wc -l)
    echo ${zbx_host}' nginx['$key_name','$st'] '$access_responses_num >> $tempfile
done

# Send values to server
#
/usr/bin/zabbix_sender --config $zbx_conf -i $tempfile

# If wrong then send discovery items
#
if [ $? -eq 2 ]
    then
	tempdiscovery=$(mktemp /tmp/nginx-count-http-status-discovery.XXXXXXXX)

	for st in $status_code; do
	    #/usr/bin/zabbix_sender --config ${zabbix_conf} -s $zbx_host -k $discovery_key -o {\"data\":[{\"{#CODE}\":\"$st\"}]}
	    echo ${zbx_host} $discovery_key '{"data":[{"{#CODE}":"'${st}'"}]}' >> $tempdiscovery
	    #echo error
	done
        /usr/bin/zabbix_sender --config $zbx_conf -i $tempdiscovery
        rm -f $tempdiscovery
fi

rm -f $tempfile

#
#zabbix_sender --config ${zabbix_conf} -s $zbx_host -k nginx.discovery.http_code -o '{"data":[{"{#CODE}":"500"}]}'
#

exit 0
