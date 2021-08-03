#!/bin/bash

sudo /etc/init.d/ssh start

bash -c /initial-configure.sh 
source /home/gpadmin/.profile

export STATUS=0
i=0
echo "STARTING... (about 30 sec)"
while [[ $STATUS -eq 0 ]] || [[ $i -lt 30 ]]; do
	sleep 1
	i=$((i+1))
	STATUS=$(grep -r -i "Database successfully started" /home/gpadmin/gpAdminLogs/*.log | wc -l)
done

echo "STARTED"


#trap
while [ "$END" == '' ]; do
			sleep 1
			trap "MASTER_DATA_DIRECTORY=/data/master/$SEG_PREFIX-1/ gpstop -M immediate && END=1" INT TERM
done
