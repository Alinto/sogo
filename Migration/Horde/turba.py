#!/usr/bin/python

import sys
import MySQLdb

import TurbaConverter

from config import webdavConfig, dbConfig

if __name__ == "__main__":
    if len(sys.argv) > 1:
        user = sys.argv[1]
    else:
        raise Exception, "<user> argument must be specified" \
            " (use 'ALL' for everyone)"

    conn = MySQLdb.connect(host = dbConfig["hostname"],
                           user = dbConfig["username"],
                           passwd = dbConfig["password"],
                           db = dbConfig["database"],
                           use_unicode = True)
    cnv = TurbaConverter.TurbaConverter(user, webdavConfig)
    cnv.start(conn)
    conn.close()
