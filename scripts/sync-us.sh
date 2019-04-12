#!/usr/bin/env bash

##################################
##   @Author  : wzdnzd          ##
##   @Time    : 2019-03-13      ##
##################################

ARGS="$@"

current=$(cd "$(dirname "$0")";pwd)

config_file="${current%/*}/conf/config.json"
status_file="${current%/*}/conf/status"
flag='us'

domain=`sort -u ${config_file} | egrep \"domain\" | egrep ${flag} | cut -d ':' -f 2 | sed 's/[\", ]//g'`

if [[ "${domain}" = "" ]]; then
    echo "can't found mycis ${flag} domain, please check it and try again."
    exit -1
fi

if [[ -f "$status_file" ]]; then
    now=`date +%s`
    change=`cat ${status_file} | grep "${domain}.change" | cut -d '=' -f 2 | sed 's/[\", ]//g'`
    finish=`cat ${status_file} | grep "${domain}.end" | cut -d '=' -f 2 | sed 's/[\", ]//g'`

    if [[ ${change} == 'true' ]] && [[ ${now} -lt $[finish] ]]; then
        echo "found dns has been changed, waiting..."
        exit -1
    fi
fi

address=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
result=$?
if [[ "${address}" = "" ]]; then
    echo "${domain}: Name or service not known"
    exit ${result}
fi

server=`sort -u ${config_file} | egrep \"hostname\" | cut -d ':' -f 2 | sed 's/[\", ]//g'`

if [[ "${server}" != "" ]] && [[ "${server}" != "localhost" ]]; then
    server=`ping ${server} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
else
    server=`hostname -i`
fi

address=`echo ${address} | cut -d '.' -f 1-2`
server=`echo ${server} | cut -d '.' -f 1-2`

if [[ "${address}" != "${server}" ]]; then
    echo "sync direction must be: master --> standby"
    exit 0
else
    /usr/bin/rsync ${ARGS}
    result=$?
    exit ${result}
fi
