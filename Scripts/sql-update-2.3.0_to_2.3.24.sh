#!/bin/bash

set -e

# This script only works with PostgreSQL - it does:
#
# 1- increase the c_mail column to text to contact quick table
# 2- add the c_hascertificate column to contact quick table

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

function growMailInContactsQuick() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ALTER COLUMN c_mail TYPE TEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

function addCertificateInContactsQuick() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table ADD c_hascertificate INT4 DEFAULT 0;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

echo "This script will ask for the database password twice" >&2
echo "Converting c_mail from VARCHAR(255) to TEXT and add c_hascertificate in Contacts quick tables" >&2
tables=`psql -t -U $username -h $hostname $database -c "select split_part(c_quick_location, '/', 5) from $indextable where c_path3 = 'Contacts';"`

for table in $tables;
do
    growMailInContactsQuick
    addCertificateInContactsQuick
done

echo "$sqlscript" | psql -q -e -U $username -h $hostname $database
