#!/usr/bin/env bash

##################################
##   @Author  : wzdnzd          ##
##   @Time    : 2019-03-13      ##
##################################

current=$(cd "$(dirname "$0")";pwd)
config_file="${current%/*}/conf/bisync.conf.lua"

startCmd="lsyncd -log Exec $current"
statusCmd="ps -ef | egrep 'lsyncd -log Exec.*conf.lua' | grep -v 'grep'"
currStatus=`eval ${statusCmd}`

function start() {
	if [[ "${currStatus}" == "" ]];then
		${startCmd}
		currStatus=`eval ${statusCmd}`
		if [[  "${currStatus}" != ""  ]];then
			echo "lsyncd service start.......OK"
		else
		    echo "lsyncd service start.......Failed"
		    exit 1
		fi
	else
		echo "lsyncd service is running !"
	fi

	exit 0
}

function stop() {
	if [[ "${currStatus}" != "" ]];then
		pkill -9 lsyncd
		currStatus=`eval ${statusCmd}`
		if [[ "${currStatus}" == "" ]];then
			echo "lsyncd service stop.......OK"
		else
		    echo "lsyncd service stop.......Failed"
		    exit 1
		fi
	else
		echo "lsyncd service is not running !"
	fi
}

function status() {
	if [[ "${currStatus}" != "" ]];then
		echo "lsyncd service is running !"
	else
		echo "lsyncd service is not running !"
	fi

	exit 0
}

function restart() {
	if [[ "${currStatus}" == "" ]];then
		echo "lsyncd service is not running, starting..."
		start
	else
		stop
		start
	fi
}

case $1 in
"start")
start
;;
"stop")
stop
;;
"status")
status
;;
"restart")
restart
;;
*)
echo
echo  "Usage: $0 start|stop|restart|status"
echo
esac