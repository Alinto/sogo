#!/usr/bin/python

import os, sys

HOST="localhost"
USER="agenor"
DB="agenortabledb"

for i in range(10000, 60000):
    NEWTABLE="agenor_tab_%i" % ( i, )
    
    TABLECREATE="""CREATE TABLE %s
    ( pkey INT PRIMARY KEY,
      startdate    INT NOT NULL,
      endate       INT NOT NULL,
      title        VARCHAR(1000) NOT NULL,
      participants VARCHAR(100000) NOT NULL);""" % ( NEWTABLE, )
    
    CALL="echo '%s' | psql -h %s %s %s" % ( TABLECREATE, HOST, DB, USER )
    res=os.system(CALL)
    #res = 1
    #print "CALL:", CALL
    print "%s res: %i" % ( NEWTABLE, res )
