#!/bin/bash
#
# Usage: generate-folderinfo-sql-for-users user1 [user2] [user3] [...]
#

DB_USER="sogo"
DB_PASS="sogo"
DB_HOST="192.168.0.4"
DB_PORT="5432"
DB_NAME="sogo"
TIMEZONE="Canada/Eastern"


while [ "$1" != "" ]; do
USER_ID=$1
USER_TABLE=`echo $USER_ID | tr -s [:punct:] _`
cat << EOF
--
-- (C) 2004 SKYRIX Software AG
--
-- TODO:
--   add a unique constraints on path

UPDATE SOGo_folder_info
  SET c_acl_location = 'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_acl'
  WHERE c_folder_type = 'Container'
  AND c_path2 = '${USER_ID}';
UPDATE SOGo_folder_info
  SET c_acl_location = 'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_acl'
  WHERE c_folder_type = 'Contact'
  AND c_path2 = '${USER_ID}';
UPDATE SOGo_folder_info
  SET c_acl_location = 'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_privcal_acl'
  WHERE c_folder_type = 'Appointment'
  AND c_path2 = '${USER_ID}';

DROP TABLE SOGo_${USER_TABLE}_acls;
DROP TABLE SOGo_${USER_TABLE}_privcal_acls;
DROP TABLE SOGo_${USER_TABLE}_contacts_acls;

DROP TABLE SOGo_${USER_TABLE}_acl;
DROP TABLE SOGo_${USER_TABLE}_privcal_acl;
DROP TABLE SOGo_${USER_TABLE}_contacts_acl;

CREATE TABLE SOGo_${USER_TABLE}_acl (
  c_uid          VARCHAR(256)    NOT NULL,
  c_object       VARCHAR(256)    NOT NULL,
  c_role         VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_privcal_acl (
  c_uid          VARCHAR(256)    NOT NULL,
  c_object       VARCHAR(256)    NOT NULL,
  c_role         VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_contacts_acl (
  c_uid          VARCHAR(256)    NOT NULL,
  c_object       VARCHAR(256)    NOT NULL,
  c_role         VARCHAR(80)     NOT NULL
);

EOF
shift
done
