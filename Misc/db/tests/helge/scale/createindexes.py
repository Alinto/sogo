#!/usr/bin/python

import os, sys

HOST="localhost"
USER="postgres"
DB="ogo"

today11="1088672400"
LOGINPREFIX="Utilisateur-"

DATERANGEIDX="""
CREATE INDEX user_%i_daterange_idx
  ON user_%i_quick
  USING BTREE ( startdate, enddate );
"""

NAMEIDX="""
CREATE INDEX user_%i_blob_name_idx
  ON user_%i_blob
  USING HASH ( c_name );
"""

for i in range(1,200):
    print "-- USER: %i %s%i" %  (i, LOGINPREFIX, i )
    print DATERANGEIDX % ( i, i, )
    print NAMEIDX      % ( i, i, )
    print ""
    print ""
