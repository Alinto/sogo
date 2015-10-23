#!/bin/bash

# this script only works with MySQL

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

function addField() {
  oldIFS="$IFS"
  IFS=" "
  part="`echo -e \"ALTER TABLE $table ADD COLUMN c_categories VARCHAR(255);\\n\"`";
  sqlscript="$sqlscript$part"
  IFS="$oldIFS"
}

tables=`mysql -p -N -B -u $username -h $hostname $database -e "select SUBSTRING_INDEX(c_quick_location, '/', -1) from $indextable where c_folder_type = 'Contact';"`

for table in $tables;
do
  addField
done
echo "$sqlscript" | mysql -p -s -u $username -h $hostname $database > /dev/null
