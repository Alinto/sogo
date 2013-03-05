#!/bin/bash

set -e

# This script only works with mysql
# updates c_content to longtext in SOGo/OpenChange cache tables
# to avoid truncation of data at 64k


defaultusername=$USER
defaulthostname=127.0.0.1
defaultdatabase=sogo

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

function growContent() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table MODIFY c_content LONGTEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "This script will ask for the sql password twice" >&2
echo "Converting c_content from TEXT to LONGTEXT in SOGo/OpenChange cache tables" >&2
tables=`mysql -p -s -u $username -h $hostname $database -e "show tables like 'socfs_%';"`

for table in $tables;
do
  growContent
done

echo "$sqlscript" | mysql -p -s -u $username -h $hostname $database
