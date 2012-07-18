#!/bin/bash

set -e

# This script only works with mysql
# updates c_cycleinfo to mediumtext
# http://www.sogo.nu/bugs/view.php?id=1848
# the field length was actually changed somewhere between 1.3.2 and 1.3.3
# but no one reported any breakage.

# this script only works with MySQL

defaultusername=$USER
defaulthostname=127.0.0.1
defaultdatabase=$USER
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
    part="`echo -e \"ALTER TABLE $table MODIFY c_cycleinfo mediumtext;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "This script will ask for the sql password twice" >&2
echo "Converting c_cycleinfo from VARCHAR(1000) to mediumtext in calendar quick tables" >&2
tables=`mysql -p -s -u $username -h $hostname $database -e "select SUBSTRING_INDEX(c_quick_location, '/', -1) from $indextable where c_path3 = 'Calendar';"`

for table in $tables;
do
  growVC
done

echo "$sqlscript" | mysql -p -s -u $username -h $hostname $database
