#!/bin/bash

set -e

# This script only works with MySQL - it does:
#
# 1- updates c_defaults and c_settings to longtext in the sogo_user_profile table
#    to avoid truncation of data at 64k
# 2- increase the c_mail column to text to contact quick table
# 3- add the c_hascertificate column to contact quick table

defaultusername=$USER
defaulthostname=127.0.0.1
defaultdatabase=sogo
indextable=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSFolderInfoURL =/  {print $2}' |  awk -F/ '{print $NF}')
if [ -z "$indextable" ]; then
  echo "Couldn't fetch OCSFolderInfoURL value, aborting" >&2
  exit 1
fi
storeurl=$(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSStoreURL =/  {print $2}' |  awk -F/ '{print $NF}')

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

function growUserProfile() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE sogo_user_profile MODIFY c_defaults LONGTEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    part="`echo -e \"ALTER TABLE sogo_user_profile MODIFY c_settings LONGTEXT;\\n\"`";
    sqlscript="$sqlscript$part"
    IFS="$oldIFS"
}

function growMailInContactsQuick() {
    oldIFS="$IFS"
    IFS=" "
    part="`echo -e \"ALTER TABLE $table MODIFY c_mail text;\\n\"`";
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
echo "Converting c_content from TEXT to LONGTEXT in the sogo_user_profile table" >&2
growUserProfile

echo "Converting c_mail from VARCHAR(255) to TEXT in Contacts quick tables" >&2
if [ -z "$storeurl" ]; then
    tables=`mysql -p -s -u $username -h $hostname $database -e "select SUBSTRING_INDEX(c_quick_location, '/', -1) from $indextable where c_path3 = 'Contacts';"`
else
    tables="sogo_quick_contact"
fi

for table in $tables;
do
    growMailInContactsQuick
    addCertificateInContactsQuick
done

echo "$sqlscript" | mysql -p -s -u $username -h $hostname $database
