#!/bin/bash
#
# Usage: generate-folderinfo-sql-for-users user1 [user2] [user3] [...]
#

DB="/tmp/sogo-registry.sqlite"

while [ "$1" != "" ]; do
USER_ID=$1
USER_TABLE=`echo $USER_ID | tr -s [:punct:] _`

cat << EOF
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
    'sqlite://localhost${DB}/SOGo_user_folder_blob', 
    'sqlite://localhost${DB}/SOGo_user_folder_quick', 
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
    'sqlite://localhost${DB}/SOGo_${USER_TABLE}_privcal', 
    'sqlite://localhost${DB}/SOGo_${USER_TABLE}_privcal', 
    'Appointment' );

INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/${USER_ID}/Contacts', 
    'Users',
    '${USER_ID}',
    'Contacts',
     NULL,
    'Contacts', 
    'sqlite://localhost${DB}/SOGo_${USER_TABLE}_contacts', 
    'sqlite://localhost${DB}/SOGo_${USER_TABLE}_contacts', 
    'Contact' );


DROP   TABLE SOGo_${USER_TABLE}_privcal;
CREATE TABLE SOGo_${USER_TABLE}_privcal (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY, /* the filename */
  c_content      VARCHAR(100000) NOT NULL, /* the BLOB */
  c_creationdate INT             NOT NULL, /* creation date */
  c_lastmodified INT             NOT NULL, /* last modification (UPDATE) */
  c_version      INT             NOT NULL, /* version counter */

  /* quick fields */
  uid          VARCHAR(256)    NOT NULL,
  startdate    INT             NOT NULL,
  enddate      INT             NOT NULL,
  cycleenddate INT             NULL,     /* enddate for cyclic events */
  title        VARCHAR(1000)   NOT NULL,
  cycleinfo    VARCHAR(1000)   NULL,     /* property list with cycle infos */
  participants VARCHAR(100000) NOT NULL, /* the CNs of the participants */
  isallday     INT             NULL,
  iscycle      INT             NULL,     /* client needs to fetch to resolve */
  ispublic     INT             NOT NULL,
  status       INT             NOT NULL,
  priority     INT             NOT NULL, -- for marking high prio apts
  isopaque     INT             NULL,
  location     VARCHAR(256)    NULL,
  orgmail      VARCHAR(256)    NULL,
  partmails    VARCHAR(100000) NOT NULL, /* the emails of the participants */
  partstates   VARCHAR(256)    NOT NULL, /* the status of each participant */
  sequence     INT             NULL      /* the iCal sequence */
);


DROP   TABLE SOGo_${USER_TABLE}_contacts;
CREATE TABLE SOGo_${USER_TABLE}_contacts (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY, /* the filename */
  c_content      VARCHAR(100000) NOT NULL, /* the BLOB */
  c_creationdate INT             NOT NULL, /* creation date */
  c_lastmodified INT             NOT NULL, /* last modification (UPDATE) */
  c_version      INT             NOT NULL, /* version counter */

  /* quick fields */
  givenname       VARCHAR(256),
  cn              VARCHAR(256),
  sn              VARCHAR(256),
  l               VARCHAR(256),
  mail            VARCHAR(256),
  o               VARCHAR(256),
  ou              VARCHAR(256),
  telephonenumber VARCHAR(256)
);

EOF
shift
done
