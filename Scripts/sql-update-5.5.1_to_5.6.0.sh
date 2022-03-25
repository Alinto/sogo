#!/bin/bash

set -euo pipefail

# This script only works with PostgreSQL and MySQL - it does:
#
# - increase the c_value column of sessions table to varchar(4096)

sessiontype=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | awk -F: '{ print $1 }')

if [ -z "$sessiontype" ]; then
    echo "Failed to obtain session table type" >&2
    exit 1
fi

if [[ "$sessiontype" == "postgresql" ]]; then
    sessionurl=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | cut -d \/ -f1-4)
    sessiontable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | awk -F/ '{print $NF}')
    echo "Converting c_value from VARCHAR(255) to VARCHAR(4096) in sessions table ($sessiontable)"
    psql $sessionurl -c "ALTER TABLE $sessiontable ALTER COLUMN c_value TYPE VARCHAR(4096);"
elif [[ "$sessiontype" == "mysql" ]]; then
    sessiontable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | awk -F/ '{print $NF}')
    mysqlargs=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | sed 's/mysql:\/\/\([^:]\+\):\([^@]\+\)@\([^\:]\+\):\([^\/]\+\)\/\([^\/]\+\).\+/-h \3 -P \4 -u \1 -p\2 \5/')
    echo "Converting c_value from VARCHAR(255) to VARCHAR(4096) in sessions table ($sessiontable)"
    mysql -v $mysqlargs -e "ALTER TABLE $sessiontable MODIFY c_value VARCHAR(4096);"
else
    echo "Unsupported database type $sessiontype"
    exit 1
fi

exit 0
