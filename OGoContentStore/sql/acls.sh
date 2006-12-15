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

DELETE FROM SOGo_folder_info WHERE c_path2 = '${USER_ID}' AND c_folder_type = 'Acls';

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/acls', 
    'Users',
    '${USER_ID}',
    'acls',
    NULL,
    'acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_acls', 
    'Acls' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Calendar/acls', 
    'Users',
    '${USER_ID}',
    'Calendar',
    'acls',
    'acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_privcal_acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_privcal_acls', 
    'Acls' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Contacts/acls', 
    'Users',
    '${USER_ID}',
    'Contacts',
    'acls',
    'acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_acls', 
    'Acls' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Contacts/personal/acls', 
    'Users',
    '${USER_ID}',
    'Contacts',
    'personal',
    'acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_acls', 
    'Acls' );

DROP TABLE SOGo_${USER_TABLE}_acls;
DROP TABLE SOGo_${USER_TABLE}_privcal_acls;
DROP TABLE SOGo_${USER_TABLE}_contacts_acls;

CREATE TABLE SOGo_${USER_TABLE}_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_privcal_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_contacts_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

EOF
shift
done
