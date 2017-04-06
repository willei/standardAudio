#!/bin/sh
NGINX=/opt/chivox/openresty/nginx/sbin
NGINX_EXE=$NGINX/nginx
CONF="/opt/chivox/standardAudio/conf/nginx.conf"
PREFIX=/opt/chivox/standardAudio/
PIDFILE=/log/standardAudio/nginx.pid
LD_LIBRARY_PATH=/opt/chivox/standardAudio/lualib:

cd $PREFIX

case "$1" in
    start )
        if [ -f $PIDFILE ]
        then
            echo "$PIDFILE exists, standardAudio is already running or crashed"
        else
            echo "Starting standardAudio..."
            export LD_LIBRARY_PATH
            if [ ! -d /log ]
            then
                mkdir /log
            fi
            if [ ! -d /log/standardAudio ]
            then
                mkdir /log/standardAudio
            fi
            if [ ! -d ./logs ]
            then
                mkdir ./logs
            fi
            #export PATH=$NGINX
            $NGINX_EXE -p $PREFIX -c $CONF
            sleep 0.3
            PID=$(cat $PIDFILE)
            echo "standardAudio "$PID" is runnning"
        fi
        ;;
    quit )
        if [ ! -f $PIDFILE ]
        then
            echo "$PIDFILE does not exist, process is not running"
        else
            PID=$(cat $PIDFILE)
            #export PATH=$NGINX
            $NGINX_EXE -p $PREFIX -c $CONF -s quit
            while [ -x /proc/${PID} ]
            do
                echo "Waiting for standardAudio to quit ..."
                sleep 1
            done
            echo "standardAudio quit"
        fi
        ;;
    stop )
        if [ ! -f $PIDFILE ]
        then
            echo "$PIDFILE does not exist, process is not running"
        else
            PID=$(cat $PIDFILE)
            #export PATH=$NGINX
            $NGINX_EXE -p $PREFIX -c $CONF -s stop
            while [ -x /proc/${PID} ]
            do
                echo "Waiting for standardAudio to stop ..."
                sleep 1
            done
            echo "standardAudio stopped"
        fi
        ;;
    reload )
        #export PATH=$NGINX
        echo "reloading standardAudio..."
        $NGINX_EXE -p $PREFIX -c $CONF -s reload
        ;;
    status )
        if [ -f $PIDFILE ]
        then
            PID=$(cat $PIDFILE)
            echo "standardAudio "$PID" is runnning"
        else
            echo "$PIDFILE does not exist, standardAudio process is not running"
        fi
        ;;
    * )
        echo "Usage: start|quit|stop|reload|status as first argument"
esac
