#!/usr/bin/python

import os, sys

HOST="localhost"
USER="postgres"
DB="ogo"

today11="1088672400"
LOGINPREFIX="Utilisateur-"

QUICK_TEMPLATE="""
DROP TABLE user_%i_quick;
CREATE TABLE user_%i_quick (
  c_name       VARCHAR(256)    NOT NULL PRIMARY KEY,
  uid          VARCHAR(256)    NOT NULL,
  startdate    INT NOT NULL,
  enddate      INT NOT NULL,
  title        VARCHAR(1000)   NOT NULL,
  participants VARCHAR(100000) NOT NULL
);
"""

CONTENT_TEMPLATE="""
DROP TABLE user_%i_blob;
CREATE TABLE user_%i_blob (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY,
  c_content      VARCHAR(100000) NOT NULL,
  c_creationdate INT             NOT NULL,
  c_lastmodified INT             NOT NULL,
  c_version      INT             NOT NULL
);
"""

# parameters: LOGINPREFIX, i, LOGINPREFIX, i, DB, i, DB, i
FOLDERINFO_TEMPLATE="""
DELETE FROM SOGo_folder_info WHERE c_path2='%s%i';
INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/%s%i/Calendar', 
    'Users',
    '%s%i',
    'Calendar',
     NULL,
    'Calendar', 
    'http://postgres:test@localhost:5432/%s/user_%i_blob',
    'http://postgres:test@localhost:5432/%s/user_%i_quick',
    'Appointment' );
"""

for i in range(1,1000):
    print "-- USER: %i %s%i" %  (i, LOGINPREFIX, i )
    print QUICK_TEMPLATE      % ( i, i, )
    print CONTENT_TEMPLATE    % ( i, i, )
    print FOLDERINFO_TEMPLATE % ( LOGINPREFIX, i,
                                  LOGINPREFIX, i, LOGINPREFIX, i,
                                  DB, i, DB, i )
    print ""
    print ""

