#!/bin/bash

set -e
# This script only works with PostgreSQL
# updates c_mail to text in Contacts quick table
# http://www.sogo.nu/bugs/view.php?id=4322

defaultusername=$USER
defaulthostname=localhost
defaultdatabase=sogo
indextable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSFolderInfoURL =/  {print $2}' |  awk -F/ '{print $NF}')
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

function growContactsQuick() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ALTER COLUMN c_mail TYPE TEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "This script will ask for the database password twice" >&2
echo "Converting c_mail from VARCHAR(255) to TEXT in Contacts quick tables" >&2
tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from $indextable where c_path3 = 'Contacts';"`

for table in $tables;
do
  growContactsQuick
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database
