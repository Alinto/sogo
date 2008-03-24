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
    part="`echo -e \"ALTER TABLE $table ADD COLUMN c_component VARCHAR(10); UPDATE TABLE $table SET COLUMN c_component = 'vcard' WHERE c_component IS NULL; ALTER TABLE $table ALTER COLUMN c_component SET NOT NULL;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from $indextable where c_folder_type = 'Contact';"`

for table in $tables;
do
  addField
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database > /dev/null

echo "Please ignore the errors above. They just mean that the migration was already done for the elements in question.";
