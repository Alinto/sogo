#!/usr/bin/python

import os, sys

HOST="localhost"
USER="agenor"
DB="blah2"

for i in range(920, 10000):
    DB="agenor%i" % ( i, )
    res=os.system("createdb -h %s -U %s %s" % ( HOST, USER, DB ))
    print "%s res: %i" % ( DB, res )
