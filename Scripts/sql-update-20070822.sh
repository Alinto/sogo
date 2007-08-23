#!/bin/bash

# this script only work with PostgreSQL

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

echo ""
echo "You will now be requested your password twice..."
echo "After that, a list of SQL operations will scroll."
echo ""

sqlscript=""

function addField() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ADD COLUMN c_deleted INTEGER;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_location, '/', 5) from $indextable where c_folder_type != 'Container';"`

for table in $tables;
do
  addField
done

sqlscript="$sqlscript;"
echo "$sqlscript" | psql -e -U $username -h $hostname $database
