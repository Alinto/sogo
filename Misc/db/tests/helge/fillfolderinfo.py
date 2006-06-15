#!/usr/bin/python

import pg

USER="agenor"
HOST="localhost"
DB="agenor_fldinfodb"
TABLE="SOGo_folder_info"

db = pg.DB(DB, HOST, 5432, "", "", USER);
print "connection:", db

for i in range(110001, 250000):
    SQL=("INSERT INTO %s ( c_foldername, c_tablename, c_dbname ) " + \
         "VALUES ( 'privcal_%i', 'agenor_tab_%i', 'agenortabledb' );") % \
         ( TABLE, i, i, )
    if i % 1000 == 0:
        print "%i: %s" % ( i, SQL )
    db.query(SQL)
