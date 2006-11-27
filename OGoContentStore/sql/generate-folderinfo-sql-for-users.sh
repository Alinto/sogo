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
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_user_acls', 
    'http://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}/SOGo_user_acls', 
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

DROP TABLE SOGo_${USER_TABLE}_acls;

CREATE TABLE SOGo_${USER_TABLE}_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

DROP TABLE SOGo_${USER_TABLE}_privcal_acls;
DROP TABLE SOGo_${USER_TABLE}_privcal_quick;
DROP TABLE SOGo_${USER_TABLE}_privcal;

CREATE TABLE SOGo_${USER_TABLE}_privcal_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_privcal_quick (
  c_name       VARCHAR(256)    NOT NULL PRIMARY KEY, -- the filename
  uid          VARCHAR(256)    NOT NULL,
  startdate    INT             NULL,
  enddate      INT             NULL,
  cycleenddate INT             NULL,     -- enddate for cyclic events
  title        VARCHAR(1000)   NOT NULL,
  cycleinfo    VARCHAR(1000)   NULL,     -- property list with cycle infos
  participants VARCHAR(100000) NULL, -- the CNs of the participants
  isallday     INT             NULL,
  iscycle      INT             NULL,     -- client needs to fetch to resolve
  ispublic     INT             NOT NULL,
  status       INT             NOT NULL,
  priority     INT             NOT NULL, -- for marking high prio apts
  isopaque     INT             NULL,
  location     VARCHAR(256)    NULL,
  orgmail      VARCHAR(256)    NULL,
  partmails    VARCHAR(100000) NULL, -- the emails of the participants
  partstates   VARCHAR(256)    NOT NULL, -- the status of each participant
  sequence     INT             NULL,      -- the iCal sequence
  component    VARCHAR(10)     NOT NULL -- the type of component (vevent/vtodo) in the vcalendar
);

CREATE TABLE SOGo_${USER_TABLE}_privcal (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY, -- the filename
  c_content      VARCHAR(100000) NOT NULL, -- the BLOB
  c_creationdate INT             NOT NULL, -- creation date
  c_lastmodified INT             NOT NULL, -- last modification (UPDATE)
  c_version      INT             NOT NULL  -- version counter
);

DROP TABLE SOGo_${USER_TABLE}_contacts_acls;
DROP TABLE SOGo_${USER_TABLE}_contacts_quick;
DROP TABLE SOGo_${USER_TABLE}_contacts;

CREATE TABLE SOGo_${USER_TABLE}_contacts_acls (
  uid          VARCHAR(256)    NOT NULL,
  object        VARCHAR(256)    NOT NULL,
  role          VARCHAR(80)     NOT NULL
);

CREATE TABLE SOGo_${USER_TABLE}_contacts_quick (
  c_name          VARCHAR(256)    NOT NULL PRIMARY KEY, -- the filename
  givenname       VARCHAR(256),
  cn              VARCHAR(256),
  sn              VARCHAR(256),
  l               VARCHAR(256),
  mail            VARCHAR(256),
  o               VARCHAR(256),
  ou              VARCHAR(256),
  telephonenumber VARCHAR(256)
);

CREATE TABLE SOGo_${USER_TABLE}_contacts (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY, -- the filename
  c_content      VARCHAR(100000) NOT NULL, -- the BLOB
  c_creationdate INT             NOT NULL, -- creation date
  c_lastmodified INT             NOT NULL, -- last modification (UPDATE)
  c_version      INT             NOT NULL  -- version counter
);

DELETE FROM SOGo_user_profile WHERE uid = '${USER_ID}';

INSERT INTO SOGo_user_profile ( 
  uid,
  allowinternet,
  timezonename,
  calendaruids
)
VALUES (
    '${USER_ID}', 1, '${TIMEZONE}', '${USER_ID}'
);

EOF
shift
done
