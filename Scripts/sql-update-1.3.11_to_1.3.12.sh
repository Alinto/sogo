#!/bin/bash

# This script only works with PostgreSQL

defaultusername=$USER
defaulthostname=localhost
defaultdatabase=$USER
indextable=sogo_folder_info

read -p "Username ($defaultusername): " username
read -p "Hostname ($defaulthostname): " hostname
read -p "Database ($defaultdatabase): " database

if [ -z "$username" ]
then
  username=$defaultusername
fi
if [ -z "$hostname" ]
then
  hostname=$defaulthostname
fi
if [ -z "$database" ]
then
  database=$defaultdatabase
fi

sqlscript=""

function convVCtoText() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ALTER COLUMN c_content TYPE TEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "Step 1 - Converting c_content from VARCHAR to TEXT in table sogo_folder_info" >&2
tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_location, '/', 5) from $indextable;"`

for table in $tables;
do
  convVCtoText
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database

echo "Step 2 - Fix primary key for the sogo_sessions table" >&2
SESSIONTBL=$(su - sogo -c "defaults read sogod OCSSessionsFolderURL" | awk -F/ '{print $NF}')
if [ -z "$SESSIONTBL" ]; then
  echo "Failed to obtain session table name" >&2
  exit 1
fi

psql -e -U $username -h $hostname $database -c "ALTER TABLE $SESSIONTBL ADD PRIMARY KEY (c_id);"

