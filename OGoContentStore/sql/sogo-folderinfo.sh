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

DELETE FROM SOGo_folder_info WHERE c_path2 = '${USER_ID}';

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}', 
    'Users',
    '${USER_ID}',
    NULL,
    NULL,
    '${USER_ID}', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_user_folder', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_user_folder_quick', 
    'Container' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Calendar', 
    'Users',
    '${USER_ID}',
    'Calendar',
     NULL,
    'Calendar', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_privcal', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_privcal_quick', 
    'Appointment' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Contacts/personal', 
    'Users',
    '${USER_ID}',
    'Contacts',
    'personal',
    'Contacts', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_${USER_TABLE}_contacts_quick', 
    'Contact' );

EOF
shift
done
