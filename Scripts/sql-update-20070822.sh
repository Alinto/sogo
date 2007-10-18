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

sqlscript="$sqlscript;update $indextable set c_path4 = 'personal', c_path = '/Users/' || c_path2 || '/Calendar/personal' where c_path3 = 'Calendar' and c_path4 is null;"

function updateCalendarLocation() {
    oldIFS="$IFS"
    IFS=" "
    user="`echo $table | cut -f 1 -d :`"
    tablename="`echo $table | cut -f 2 -d :`"
    newstart="/$user/Calendar/personal";
    part="update $tablename set c_object = replace(c_object, '/$user/Calendar', '$newstart') where c_object not like '$newstart%';";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

tables=`psql -t -U $username -h $hostname $database -c "select c_path2 || ':' || split_part(c_acl_location, '/', 5) from $indextable where c_folder_type = 'Appointment';"`
for table in $tables;
do
  updateCalendarLocation
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database > /dev/null

echo "Please ignore the errors above. They just mean that the migration was already done for the elements in question.";