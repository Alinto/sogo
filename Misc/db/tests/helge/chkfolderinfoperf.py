#!/usr/bin/python

import pg, time

USER="agenor"
HOST="localhost"
DB="agenor_fldinfodb"
TABLE="SOGo_folder_info"

db = pg.DB(DB, HOST, 5432, "", "", USER);
print "connection:", db

def timeSelect(SELECT, WHERE=None):
    SQL="SELECT %s FROM %s" % ( SELECT, TABLE )
    if not WHERE is None: SQL="%s WHERE %s" % ( SQL, WHERE )
    starttime=time.time()
    res = db.query(SQL)
    endtime=time.time()
    print "perf '%s', %s: %.2fms" % ( SELECT, WHERE, (endtime-starttime)*1000)

timeSelect("COUNT(*)")
timeSelect("c_tablename, c_dbname")
timeSelect("c_tablename, c_dbname", "c_foldername='privcal_99827'")
