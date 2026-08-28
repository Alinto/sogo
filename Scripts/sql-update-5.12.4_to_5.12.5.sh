#!/bin/bash

set -euo pipefail

sessiontype=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | awk -F: '{ print $1 }')

if [ -z "$sessiontype" ]; then
    echo "Failed to obtain session table type" >&2
    exit 1
fi

if [[ "$sessiontype" == "postgresql" ]]; then
    sessionurl=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | cut -d / -f1-4)
    sessiontable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSSessionsFolderURL =/  {print $2}' | awk -F/ '{print $NF}')
    openidinput=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSIAMOpenIDSupport = YES/ {found=1} / OCIOpenIDSupport = YES/ {found=1} / OCSIdPoolURL =/ {if(found) print; found=0}')
    if [ -n "$openidinput" ]; then
        openidurl=$(echo "$openidinput" | awk -F\" '/ OCSIdPoolURL =/  {print $2}' | cut -d / -f1-4)
        openidtable=$(echo "$openidinput" | awk -F\" '/ OCSIdPoolURL =/  {print $2}' | awk -F/ '{print $NF}')
    fi

    if [ -n "$sessiontable" ]; then
        echo "Converting c_value from VARCHAR(4096) to TEXT in sessions table ($sessiontable)"
        psql $sessionurl -c "ALTER TABLE $sessiontable ALTER COLUMN c_value TYPE TEXT;"
    fi
    if [ -n "$openidtable" ]; then
        echo "Converting columns from VARCHAR(4096) to TEXT in openid table ($openidtable)"
        psql $openidurl -c "ALTER TABLE $openidtable ALTER COLUMN c_user_session TYPE TEXT;"
        psql $openidurl -c "ALTER TABLE $openidtable ALTER COLUMN c_old_session TYPE TEXT;"
        psql $openidurl -c "ALTER TABLE $openidtable ALTER COLUMN c_refresh_token TYPE TEXT;"
    fi
else
    echo "This script only supports PostgreSQL, detected: $sessiontype" >&2
    exit 1
fi

exit 0