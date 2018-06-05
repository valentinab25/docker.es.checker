#!/bin/sh


if [ -z "$ES_URL" ]; then 
   echo "No ElasticSearch received, exiting"
   exit 1;
fi

if [[ "$@" != "check" ]]; then
  exec "$@"
fi

PORT=${PORT:-12345}
CHECK_PERIOD=${CHECK_PERIOD:-10}
YELLOW_WAIT=${YELLOW_WAIT:-60}
CLIENT_WAIT=${CLIENT_WAIT:-30}

#remove trailing slash
ES_URL=$(echo $ES_URL | sed 's/\/$//')


if [ -n "$ES_USER" ] && [ -n "$ES_PASSWORD" ]; then
   CHECK_URL=$(  echo $ES_URL/_cluster/health | awk -F "://" -v user="$ES_USER" -v pass="$ES_PASSWORD"  '{print $1"://"user":"pass"@"$2 }' )
else
    CHECK_URL=$ES_URL/_cluster/health
fi

state="GREEN"

start_port()
{

    if [ $( ps -ef | grep "nc -l $PORT" | grep -v grep | wc -l ) -eq 0 ]; then
        echo "Start port $PORT"
        nohup nc -l $PORT  > /dev/null 2>&1&
    fi
}



health_check()
{
  curl -i -s  $CHECK_URL > temp

#check HTTP status

  if [ $(grep -c -i "HTTP/1.1 200 OK" temp ) -eq 1 ]; then
     
   # Client responding, checking health status "
   if [ $(grep -c '"status":"green"' temp) -eq 1 ]; then
       state="GREEN"
       echo "Received status $state from healthcheck"
   else
  
     if [ $(grep -c '"status":"yellow"' temp) -eq 1 ]; then
        state="YELLOW"
     else
        state="RED"
     fi

    echo "Received status $state from healthcheck"
   fi
  else

   echo "Did not receive a HTTP 200 status from client"
  
   if [ $( cat temp | wc -l ) -eq 0 ]; then
      state="CLIENT_DOWN"
      echo "No responce received, URL is down"
   else
      cat temp
      echo ""
      state="CLIENT_NOK"
   fi
  fi
}

kill_port()
{
 if [ $( ps -ef | grep "nc -l $PORT" | grep -v grep | wc -l ) -eq 1 ]; then
  echo "Killing port $PORT"
  ps -ef | grep "nc -l $PORT"   | grep -v grep | awk '{print $1}' | xargs kill 
 fi
}

first_yellow=0
first_client_down=0
start_port

while true
do 
  health_check
  if [[ "$state" == "GREEN" ]]; then
    first_yellow=0
    first_client_down=0
    start_port
  else
 
    if [[ "$state" == "YELLOW" ]] && [ $first_yellow -eq 0  ]; then
        echo "Wait $YELLOW_WAIT for cluster to fix itself"
        sleep  $YELLOW_WAIT
        first_yellow=1
        continue
    fi
   
    if [[ "$state" == "CLIENT_DOWN" ]] && [ $first_client_down -eq 0  ]; then
        echo "Wait $CLIENT_WAIT  for cluster to fix itself"
        sleep  $CLIENT_WAIT
        first_client_down=1
        continue
    fi

    kill_port

  fi

 sleep $CHECK_PERIOD
done
    


