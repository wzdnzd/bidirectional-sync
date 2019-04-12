#!/usr/bin/env bash

##################################
##   @Author  : wzdnzd          ##
##   @Time    : 2019-03-13      ##
##################################

pidFile="/var/run/rsync.pid"
startCmd="rsync --daemon --config=/etc/rsync/rsync.conf"
statusCmd="ps -ef | egrep 'rsync --daemon.*rsync.conf' | grep -v 'grep'"
currStatus=`eval ${statusCmd}`

function start() {
	if [[ "${currStatus}" == "" ]];then
		rm -f ${pidFile}
		${startCmd}
		currStatus=`eval ${statusCmd}`
		if [[  "${currStatus}" != ""  ]];then
			echo "rsync service start.......OK"
		else
		    echo "rsync service start.......Failed"
		    exit 1
		fi
	else
		echo "rsync service is running !"
	fi

	exit 0
}

function stop() {
	if [[ "${currStatus}" != "" ]];then
		kill -9 $(cat ${pidFile})
		currStatus=`eval ${statusCmd}`
		if [[ "${currStatus}" == "" ]];then
			echo "rsync service stop.......OK"
		else
		    echo "rsync service stop.......Failed"
		    exit 1
		fi
	else
		echo "rsync service is not running !"
	fi
}

function status() {
	if [[ "${currStatus}" != "" ]];then
		echo "rsync service is running !"
	else
		echo "rsync service is not running !"
	fi

	exit 0
}

function restart() {
	if [[ "${currStatus}" == "" ]];then
		echo "rsync service is not running, starting..."
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