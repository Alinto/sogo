#!/usr/bin/env python

"""
README!!!

Check the table names in
CREATE_QUICK + CREATE_BLOB -> are the table names correct?
"""

import pg
import sys
import random


# the default database. this is where folder_info lives
DEFAULT_DB="test"
USER="OGo"
PASSWORD="OGo"
HOST="agenor-db"
PORT="5432"

DEFAULT_CONNECTION = "%s:%s@%s:%s" % (USER, PASSWORD, HOST, PORT)

# insert more names if you want to test with multiple db's!
dbConnectionMap = { DEFAULT_DB : DEFAULT_CONNECTION }


# lookup table for db connections
connectionPool = {}


#
# TEMPLATES
#

CREATE_QUICK="""CREATE TABLE SOGo_%(user)s_privcal_quick (
  c_name       VARCHAR(256)    NOT NULL PRIMARY KEY,
  uid          VARCHAR(256)    NOT NULL,
  startdate    INT NOT NULL,
  enddate      INT NOT NULL,
  title        VARCHAR(1000)   NOT NULL,
  participants VARCHAR(100000) NOT NULL
)"""

CREATE_BLOB="""CREATE TABLE SOGo_%(user)s_privcal (
  c_name         VARCHAR(256)    NOT NULL PRIMARY KEY,
  c_content      VARCHAR(100000) NOT NULL,
  c_creationdate INT             NOT NULL,
  c_lastmodified INT             NOT NULL,
  c_version      INT             NOT NULL
)"""

INSERT_FOLDERINFO_USER="""INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/%(user)s', 
    'Users',
    '%(user)s',
    NULL,
    NULL,
    '%(user)s', 
    'http://%(connection)s/%(db)s/SOGo_user_folder', 
    'http://%(connection)s/%(db)s/SOGo_user_folder_quick', 
    'Container'
)"""

INSERT_FOLDERINFO_USER_PRIVCAL="""INSERT INTO SOGo_folder_info 
  ( c_path, c_path1, c_path2, c_path3, c_path4, c_foldername, 
    c_location, c_quick_location, c_folder_type ) 
VALUES 
  ( '/Users/%(user)s/Calendar', 
    'Users',
    '%(user)s',
    'Calendar',
     NULL,
    'Calendar', 
    'http://%(connection)s/%(db)s/SOGo_%(user)s_privcal', 
    'http://%(connection)s/%(db)s/SOGo_%(user)s_privcal_quick', 
    'Appointment'
)"""


#
# HELPERS
#

def usage():
  sys.stderr.write("""create_user_tables.py <filename>
  
  filename is plain text, platform encoding. Each line has a username. Simple.
  """)
  sys.exit(1)

def splitConnectionString(connectionString):
  res = []
  for t in connectionString.split("@"):
    for r in t.split(":"):
      res.append(r)
  return res
  
#
# MAIN
#

def run():
  global dbConnectionMap, connectionPool

  # check arguments
  try:
    filename = sys.argv[1]
  except IndexError:
    usage()

  # check filename
  try:
    f = open (filename, "r");
  except IOError:
    sys.stderr.write("%s\n" % (sys.exc_value))
    sys.exit(1)

  # setup connection pools
  dbs = dbConnectionMap.keys()
  dbsCount = len(dbs)
  for db in dbs:
    conString = dbConnectionMap[db]
    c = splitConnectionString(conString)
    #pg.DB(dbname, host, port, opt, tty, user, passwd)
    con = pg.DB(db, c[2], int(c[3]), None, None, c[0], c[1])
    connectionPool[db] = con

  # get the default connection
  db = DEFAULT_DB
  defcon = connectionPool[db]
  con = defcon

  # read list of users
  users = f.readlines()
  for user in users:
    user = user.strip()
    
    # pick a random database if dbsCount > 1
    if dbsCount > 1:
      idx = random.randrange(0, dbsCount)
      db = dbs[idx]
      con = connectionPool[db]
  
    map = { "user"       : user,
            "db"         : db,
            "connection" : dbConnectionMap[db],
          }
   
    con.query(CREATE_QUICK % map)
    con.query(CREATE_BLOB % map)
    defcon.query(INSERT_FOLDERINFO_USER % map)
    defcon.query(INSERT_FOLDERINFO_USER_PRIVCAL % map)


# let the games begin ...
if __name__ == "__main__":
    run()
