#!/usr/bin/env python

import getopt
import imaplib
#import ldb
import plistlib
import os
import re
import shutil
import subprocess
import sys

imaphost = '127.0.0.1'
imapport = 143
sambaprivate = '/var/lib/samba/private'
mapistorefolder = "%s/mapistore" % (sambaprivate)
sogoDefaultsFile = "/home/sogo/GNUstep/Defaults/.GNUstepDefaults"

#  - takes a username and optionally its password
#  - removes the entry in samba's ldap tree via ldbedit (NOTYET)
#  - remove the user's directory under mapistore/ and mapistore/SOGo
#  - cleanup Junk Folders and Sync Issues imap folders
#  - Delete the socfs_ table for the username.

def usage():
  print """
%s [-i imaphost] ] [-p imapport] [-s sambaprivate] username [password]
    -i imaphost        IMAP host to connect to [%s]
    -p imappost        IMAP port to use	[%d]
    -s sambaprivate    samba private directory [%s]
""" % (os.path.basename(sys.argv[0]), imaphost, imapport, sambaprivate)

def main():
  global sambaprivate
  global mapistorefolder
  global imaphost
  global imapport
  try:
      opts, args = getopt.getopt(sys.argv[1:], "i:p:s:")
  except getopt.GetoptError, err:
      print str(err)
      usage()
      sys.exit(2)

  for o, a in opts:
      if o == "-i":
          imaphost = a
      elif o == "-p":
          imapport = a
      elif o == "-s":
          sambaprivate = a
          mapistorefolder = "%s/mapistore" % (sambaprivate)
      else:
          assert False, "unhandled option"

  argslen = len(args)
  if (argslen == 2):
    username = args[0]
    userpass = args[1]
  elif (argslen == 1):
    username = args[0]
    userpass = username
    print "Using username as password"
  else:
    usage()
    print "Specify a user (and optionally the password)"
    sys.exit(2)

  # cleanup starts here
  try:
      imapCleanup(imaphost, imapport, username, userpass)
  except Exception as e:
      print "Error during imapCleanup, continuing: %s" % str(e)

  try:
      mapistoreCleanup(mapistorefolder, username)
  except (shutil.Error, OSError) as e:
      print "Error during mapistoreCleanup, continuing: %s" % str(e)

#  try:
#    pass
#    #ldbCleanup(sambaprivate, username)
#  except ldb.LdbError as e:
#    print "Error during ldbCleanup, continuing: %s" % str(e)

  sqlCleanup(username)


def extractmb(si):
    inparen = False
    inquote = False
    part = []
    parts = []

    for char in si:
        if inparen:
            if char == ")":
                inparen = False
                parts.append("".join(part))
            else:
                part.append(char)
        elif inquote:
            if char == "\"":
                inquote = False
                parts.append("".join(part))
            else:
                part.append(char)
        else:
            if char == "(":
                inparen = True
            elif char == "\"":
                inquote = True
            elif char == " ":
                part = []
            else:
                part.append(char)

    return parts[-1]

def cleanupmb(mb, client):
    (code, data) = client.list("%s/" % mb, "%")
    if code == "OK":
        for si in data:
            if si is not None:
                submb = extractmb(si)
                cleanupmb(submb, client)
    else:
        raise Exception, "Failure while cleaning up '%s'" % mb
    client.unsubscribe(mb)
    (code, data) = client.delete(mb)
    if code == "OK":
        print "mailbox '%s' deleted" % mb
    else:
        print "mailbox '%s' coult NOT be deleted (code = '%s')" % (mb, code)
  
def imapCleanup(imaphost, imapport, username, userpass) :

    client = imaplib.IMAP4(imaphost, imapport)
    (code, data) = client.login(username, userpass)
    if code != "OK":
        raise Exception, "Login failure"

    print "Logged in as '%s'" % username

    for foldername in [ "Sync Issues", "Junk E-mail" ]:
        (code, data) = client.list(foldername, "%")
        if code == "OK":
            for si in data:
                if si is not None:
                    print si
                    continue
                    mb = extractmb(si)
                    cleanupmb(mb, client)
    client.logout()

def mapistoreCleanup(mapistorefolder, username):

    # delete the user's folder under the mapistore and under mapistore/SOGo
    shutil.rmtree("%s/%s" % (mapistorefolder, username), ignore_errors=True)
    shutil.rmtree("%s/SOGo/%s" % (mapistorefolder, username), ignore_errors=True)

# NOTYET
#def ldbCleanup(sambaprivate, username):
#  conn = ldb.Ldb("%s/openchange.ldb" % (sambaprivate))
####  entries = conn.search(None, expression="(|(cn=%s)(MAPIStoreURI=sogo://%s:*)(MAPIStoreURI=sogo://%s@*))" % (username,username,username),
#  entries = conn.search(None, expression="cn=%s" % (username),
#              scope=ldb.SCOPE_SUBTREE)
#  for entry in entries:
#    print "Deleting %s" % (entry.dn)
#    conn.delete(entry.dn)

def mysqlCleanup(dbhost, dbport, dbuser, dbpass, dbname, username):
  import MySQLdb

  conn= MySQLdb.connect(host=dbhost, port=int(dbport), user=dbuser, passwd=dbpass, db=dbname)
  c=conn.cursor()
  tablename="socfs_%s" % (username)
  c.execute("TRUNCATE TABLE %s" % tablename)
  print "Table %s emptied"


def postgresqlCleanup(dbhost, dbport, dbuser, dbpass, dbname, username):
  import pg           
  conn = pg.connect(host=dbhost, port=int(dbport), user=dbuser, passwd=dbpass, dbname=dbname) 
  tablename = "socfs_%s" % username
  conn.query("DELETE FROM %s" % tablename)
  print "table '%s' emptied" % tablename

def getOCSFolderInfoURL():
  global sogoDefaultsFile
  sogoDefaults = plistlib.readPlist(sogoDefaultsFile)
  try:
    OCSFolderInfoURL = sogoDefaults['sogod']['OCSFolderInfoURL']
  except KeyError:
    OCSFolderInfoURL = ""

  return OCSFolderInfoURL

def sqlCleanup(username):
  OCSFolderInfoURL = getOCSFolderInfoURL()
  if (OCSFolderInfoURL is None):
    raise Exception("Couldn't fetch OCSFolderInfoURL or it is not set. the socfs_%s table should be truncated manually" % (username))
    
  # postgresql://sogo:sogo@127.0.0.1:5432/sogo/sogo_folder_info
  m = re.search("(.+)://(.+):(.+)@(.+):(\d+)/(.+)/(.+)", OCSFolderInfoURL)

  proto = m.group(1)
  dbuser = m.group(2)
  dbpass = m.group(3)
  dbhost = m.group(4)
  dbport = m.group(5)
  dbname = m.group(6)
  # 7 is folderinfo table 

  if (proto == "postgresql"):
    postgresqlCleanup(dbhost, dbport, dbuser, dbpass, dbname, username)
  elif (proto == "mysql"):
    mysqlCleanup(dbhost, dbport, dbuser, dbpass, dbname, username)
  else:
    raise Exception("Unknown sql proto: " % (proto))


if __name__ == "__main__":
    main() 
