#!/usr/bin/python

import os, sys

HOST="localhost"
USER="agenor"
DB=""

for i in range(1, 10000):
    NEWUSER="agenor%i" % ( i, )
    res=os.system("createuser -A -D -h %s -U %s %s" % ( HOST, USER, NEWUSER ))
    print "%s res: %i" % ( NEWUSER, res )
