#!/bin/bash

set -euo pipefail

# This script only works with PostgreSQL and MySQL - it does:
#
# - increase the c_defaults column of user profile table to medium text

profiletype=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ SOGoProfileURL =/  {print $2}' | awk -F: '{ print $1 }')

if [ -z "$profiletype" ]; then
    echo "Failed to obtain session table type" >&2
    exit 1
fi

if [[ "$profiletype" == "mysql" ]]; then
    profiletable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ SOGoProfileURL =/  {print $2}' | awk -F/ '{print $NF}')
    mysqlargs=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ SOGoProfileURL =/  {print $2}' | sed 's/mysql:\/\/\([^:]\+\):\([^@]\+\)@\([^\:]\+\):\([^\/]\+\)\/\([^\/]\+\).\+/-h \3 -P \4 -u \1 -p\2 \5/')
    echo "Converting c_defaults from TEXT to MEDIUMTEXT in sessions table ($profiletable)"
    mysql -v $mysqlargs -e "ALTER TABLE $profiletable MODIFY c_defaults MEDIUMTEXT;"
else
    echo "Unsupported database type $profiletype"
    exit 1
fi

exit 0
