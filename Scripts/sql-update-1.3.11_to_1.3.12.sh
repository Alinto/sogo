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

tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_location, '/', 5) from $indextable;"`

for table in $tables;
do
  convVCtoText
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database
