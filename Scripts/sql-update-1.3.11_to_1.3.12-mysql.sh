#!/bin/bash
# converting c_content to text is not needed on mysql as it is already big enough (mediumtext)

# this script only works with MySQL

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

SESSIONTBL=$(su - sogo -c "defaults read sogod OCSSessionsFolderURL" | awk -F/ '{print $NF}')
if [ -z "$SESSIONTBL" ]; then
  echo "Failed to obtain session table name" >&2
  exit 1
fi

echo "Fix primary key for the sogo_sessions table"
mysql -p -s -u $username -h $hostname $database -e "ALTER TABLE $SESSIONTBL ADD PRIMARY KEY (c_id);"
