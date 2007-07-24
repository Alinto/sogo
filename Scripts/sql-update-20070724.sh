#!/bin/bash

# this script only work with PostgreSQL, which at this time is the only
# database really supported by SOGo/SOPE

defaultusername=$USER
defaulthostname=localhost
defaultdatabase=$USER

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
echo "You will now be requested your password thrice..."
echo "After that, a list of SQL operations will scroll."
echo ""

sqlscript=""

function renameFields() {
    oldIFS="$IFS"
    IFS=" "
    set $fields
    for field in $@
    do
	part="`echo -e \"ALTER TABLE $table RENAME $field TO c_${field};\\n\"`";
	sqlscript="$sqlscript$part"
    done
    IFS="$oldIFS"
}

table=sogo_user_profile
fields="uid defaults settings"
renameFields

fields="uid startdate enddate cycleenddate title cycleinfo participants isallday iscycle classification status priority isopaque location orgmail partmails partstates sequence component"
tables=`psql -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from sogo_folder_info where c_folder_type ilike 'Appointment';" | grep _quick`
for table in $tables;
do
  renameFields
done

fields="givenname cn sn l mail o ou telephonenumber screenname"
tables=`psql -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from sogo_folder_info where c_folder_type ilike 'Contact';" | grep _quick`
for table in $tables;
do
  renameFields
done

sqlscript="$sqlscript;"
echo "$sqlscript" | psql -e -U $username -h $hostname $database
