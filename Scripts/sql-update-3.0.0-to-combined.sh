#!/bin/bash

echo "
========================================================================
WARNING
========================================================================
This script modifies the SOGo database schema so that it complies to the
new optional 9-table model.  It is *not* part of a normal upgrade.

It is *strongly* recommended you backup your database before proceeding.

In other words, only run this if you absolutely know what you're doing.
"

while [[ -z "${GO_WITH_INSTALL}" ]]; do
    read -p "Do you really want to proceed (yes/no)? " GO_WITH_INSTALL
done

if [[ ${GO_WITH_INSTALL:0:1} != "Y" && ${GO_WITH_INSTALL:0:1} != "y" ]]; then
    echo "User-aborted."
    exit;
fi

STOREFIELDS="c_name, c_content, c_creationdate, c_lastmodified, c_version, c_deleted"
APPOINTMENTFIELDS="c_name, c_uid, c_startdate, c_enddate, c_cycleenddate, c_title, c_participants, c_isallday, c_iscycle, c_cycleinfo, \
c_classification, c_isopaque, c_status, c_priority, c_location, c_orgmail, c_partmails, c_partstates, c_category, c_sequence, c_component, c_nextalarm, c_description"
CONTACTFIELDS="c_name, c_givenname, c_cn, c_sn, c_screenname, c_l, c_mail, c_o, c_ou, c_telephonenumber, c_categories, c_component"

IFS=" "

# Parse postgres connection string from OCSFolderInfoURL in sogo.conf
set $(sogo-tool dump-defaults -f /etc/sogo/sogo.conf | awk -F\" '/ OCSFolderInfoURL =/  {print $2}' \
	| sed -n 's/\([^:]\+\):\/\/\([^:]\+\):\([^@]\+\)@\([^:]\+\):\([^/]\+\)\/\([^/]\+\)\/\([^/]\+\)/\1 \2 \3 \4 \5 \6 \7/p')
PROTOCOL=$1
USER=$2
PWD=$3
HOST=$4
PORT=$5
DB=$6
TABLE=$7

if [ -z "$PROTOCOL" ] || [ -z "$USER" ] || [ -z "$HOST" ] || [ -z "$PORT" ] || [ -z "$DB" ] || [ -z "$TABLE" ]; then
    echo "ERROR: Failed to parse value of OCSFolderInfoURL in /etc/sogo/sogo.conf" 1>&2
    exit 1
fi

if ! [ "$PROTOCOL" = "postgresql" ]; then
    echo "ERROR: Unsupported protocol $PROTOCOL. Use this script for migrating postgresql databases." 1>&2
    exit 1
fi

# Create temporary files
export PGPASSFILE=$(mktemp)
TABLEFILE=$(mktemp)
SQLFILE=$(mktemp)
trap "rm -rf $TABLEFILE $PGPASSFILE $SQLFILE" EXIT

# Save password for subsequent batch-mode calls of psql 
echo "*:*:*:$USER:$PWD" > $PGPASSFILE


#########################
# Create new tables

# Check if table sogo_store exists
CHECK=$(psql -A -F " " -w -t -U $USER -h $HOST $DB -c "SELECT TRUE FROM  information_schema.tables WHERE table_name='sogo_store'")
RET=$?

if [ $RET -ne 0 ]; then 
    echo "ERROR: postgresql returned error $RET" 1>&2
    exit 1    
fi

if [ "$CHECK" != "t" ]; then
   cat >> $SQLFILE <<HERE
ALTER TABLE $TABLE ALTER COLUMN c_location DROP NOT NULL;

CREATE TABLE sogo_store
(
  c_folder_id integer NOT NULL,
  c_name character varying(255) NOT NULL,
  c_content text NOT NULL,
  c_creationdate integer NOT NULL,
  c_lastmodified integer NOT NULL,
  c_version integer NOT NULL,
  c_deleted integer,
  CONSTRAINT sogo_store_pkey PRIMARY KEY (c_folder_id, c_name)
);

CREATE TABLE sogo_acl
(
  c_folder_id integer NOT NULL,
  c_object character varying(255) NOT NULL,
  c_uid character varying(255) NOT NULL,
  c_role character varying(80) NOT NULL
);

CREATE INDEX sogo_acl_c_folder_id_idx ON sogo_acl(c_folder_id);
CREATE INDEX sogo_acl_c_uid_idx ON sogo_acl(c_uid);

CREATE TABLE sogo_quick_appointment
(
  c_folder_id integer NOT NULL,
  c_name character varying(255) NOT NULL,
  c_uid character varying(255) NOT NULL,
  c_startdate integer,
  c_enddate integer,
  c_cycleenddate integer,
  c_title character varying(1000) NOT NULL,
  c_participants text,
  c_isallday integer,
  c_iscycle integer,
  c_cycleinfo text,
  c_classification integer NOT NULL,
  c_isopaque integer NOT NULL,
  c_status integer NOT NULL,
  c_priority integer,
  c_location character varying(255),
  c_orgmail character varying(255),
  c_partmails text,
  c_partstates text,
  c_category character varying(255),
  c_sequence integer,
  c_component character varying(10) NOT NULL,
  c_nextalarm integer,
  c_description text,
  CONSTRAINT sogo_quick_appointment_pkey PRIMARY KEY (c_folder_id, c_name)
);

CREATE TABLE sogo_quick_contact
(
  c_folder_id integer NOT NULL,
  c_name character varying(255) NOT NULL,
  c_givenname character varying(255),
  c_cn character varying(255),
  c_sn character varying(255),
  c_screenname character varying(255),
  c_l character varying(255),
  c_mail character varying(255),
  c_o character varying(255),
  c_ou character varying(255),
  c_telephonenumber character varying(255),
  c_categories character varying(255),
  c_component character varying(10) NOT NULL,
  CONSTRAINT sogo_quick_contact_pkey PRIMARY KEY (c_folder_id, c_name)
);


HERE
fi

#########################
# Merge per-folder tables


# Retrieve folder infos
psql -A -F " " -w -t -U $USER -h $HOST $DB -c "SELECT c_path, c_folder_id, c_folder_type, split_part(c_quick_location, '/', 5), \
	split_part(c_location, '/', 5), split_part(c_acl_location, '/', 5) FROM \"$TABLE\" WHERE c_location IS NOT NULL" > $TABLEFILE 
RET=$?

if [ $RET -ne 0 ]; then 
    echo "ERROR: postgresql returned error $RET" 1>&2
    exit 1    
fi

while read LINE
do           
    set $LINE
    FOLDERID=$2
    FOLDERTYPE=$3
    QUICKTABLE=$4
    STORETABLE=$5
    ACLTABLE=$6
    
    if [ "$FOLDERTYPE" != "Appointment" ] && [ "$FOLDERTYPE" != "Contact" ]; then
    	echo "ERROR: Unknown folder type $FOLDERTYPE, folder id $FOLDERID" 1>&2
    	exit 1
    fi

    # Merge content and acl
    echo "INSERT INTO sogo_store(c_folder_id, $STOREFIELDS) SELECT $FOLDERID, $STOREFIELDS FROM $STORETABLE;" >> $SQLFILE
    echo "INSERT INTO sogo_acl(c_folder_id, c_object, c_uid, c_role) SELECT $FOLDERID, c_object, c_uid, c_role FROM $ACLTABLE;" >> $SQLFILE
        
    # Merge quick table
    if [ "$FOLDERTYPE" = "Appointment" ]; then
    	echo "INSERT INTO sogo_quick_appointment(c_folder_id, $APPOINTMENTFIELDS) SELECT $FOLDERID, $APPOINTMENTFIELDS FROM $QUICKTABLE;" >> $SQLFILE
    else
	    echo "INSERT INTO sogo_quick_contact(c_folder_id, $CONTACTFIELDS) SELECT $FOLDERID, $CONTACTFIELDS FROM $QUICKTABLE;" >> $SQLFILE
    fi
    
    # Drop migrated tables and update folder info        
    echo "DROP TABLE $QUICKTABLE;" >> $SQLFILE
    echo "DROP TABLE $STORETABLE;" >> $SQLFILE
    echo "DROP TABLE $ACLTABLE;" >> $SQLFILE
    echo "UPDATE sogo_folder_info SET c_location = NULL, c_quick_location = NULL, c_acl_location = NULL WHERE c_folder_id = $FOLDERID;" >> $SQLFILE      
    echo >> $SQLFILE
done < $TABLEFILE

echo "Merging tables...."
psql -v ON_ERROR_STOP=1 -w -U $USER -h $HOST $DB < $SQLFILE
RET=$?

if [ $RET -ne 0 ]; then 
    echo "ERROR: postgresql returned error $RET" 1>&2
    exit 1    
fi
        

#########################
# Patch sogo.conf

if ! (grep -q "OCSStoreURL" /etc/sogo/sogo.conf); then
    echo "Patching /etc/sogo/sogo.conf...."
    # Generate properties OCSStoreURL and OCSAclURL
    sed "s/\(.*\)OCSFolderInfoURL.*$/\0\n\1OCSStoreURL = \"postgresql:\/\/$USER:$PASSWORD@$HOST:$PORT\/$DB\/sogo_store\";\
\n\1OCSAclURL = \"postgresql:\/\/$USER:$PASSWORD@$HOST:$PORT\/$DB\/sogo_acl\";/g" -i /etc/sogo/sogo.conf
fi


