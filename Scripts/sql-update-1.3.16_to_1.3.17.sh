#!/bin/bash

set -e 
# This script only works with PostgreSQL
# updates c_cycleinfo to varchar(1000000).
# http://www.sogo.nu/bugs/view.php?id=1848
# the field length was actually changed somewhere between 1.3.2 and 1.3.3
# but no one reported any breakage.

defaultusername=$USER
defaulthostname=localhost
defaultdatabase=$USER
#indextable=sogo_folder_info
indextable=$(su - sogo -c "defaults read sogod OCSFolderInfoURL" | awk -F/ '{print $NF}')
if [ -z "$indextable" ]; then
  echo "Couldn't fetch OCSFolderInfoURL value, aborting" >&2
  exit 1
fi

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

function growVC() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ALTER COLUMN c_cycleinfo TYPE VARCHAR(1000000);\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "Converting c_cycleinfo from VARCHAR(1000) to VARCHAR(1000000) in calendar quick tables" >&2
tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from $indextable where c_path3 = 'Calendar';"`

for table in $tables;
do
  growVC
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database
