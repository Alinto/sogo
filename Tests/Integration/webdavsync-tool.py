#!/usr/bin/python

import getopt
import sys
import urlparse
import webdavlib
import xml.dom.minidom

def usage() :
	msg ="""Usage:
  %s [-h] [-s sync-token] -u uri\n""" % sys.argv[0]

	sys.stderr.write(msg);

def getAllCollections(client, uri):
  collections = []
  depth = 1

  propfind = webdavlib.WebDAVPROPFIND(uri, ["allprop"], depth)
  client.execute(propfind)
  client.conn.close()
  doc = propfind.response["document"]
  for response in doc.iter("{DAV:}response"):
    propstat = response.find("{DAV:}propstat")
    if propstat is not None:
      prop = propstat.find("{DAV:}prop")
      if prop is not None:
        resourcetype = prop.find("{DAV:}resourcetype")
        if resourcetype.find("{DAV:}collection") is not None:
          href = prop.find("{DAV:}href")
          if href is not None and href.text != uri:
            collections.append(href.text)
  return collections

def changedItemsFromCollection(client, collection, synctoken=None):
  # get all changed hrefs since synctoken
  hrefs = []
  syncquery = webdavlib.WebDAVSyncQuery(collection, synctoken, [ "getcontenttype", "getetag" ])
  client.execute(syncquery)
  client.conn.close()
  if (syncquery.response["status"] != 207):
    raise Exception("Bad http response code: %d" % syncquery.response["status"])
  doc = syncquery.response["document"]

  # extract all hrefs
  for syncResponse in doc.iter("{DAV:}response"):
    href = syncResponse.find("{DAV:}href")
    if href is not None:
      hrefs.append(href.text)

  return hrefs
  

def main():
  depth = 1
  synctoken = "1"
  url = None

  try:
   opts, args = getopt.getopt (sys.argv[1:], "hs:u:", \
                               ("sync-token=", "url="));
  except getopt.GetoptError:
    usage()
    exit(1)

  for o, v in opts :
    if o == "-h" :
      usage()
      exit(1)
    elif o == "-s" or o == "--sync-token" :
      synctoken = v
    elif o == "-u" or o == "--url" :
      url = v

  if url is None:
    usage()
    exit(1)

  o = urlparse.urlparse(url)
  hostname = o.hostname
  port = o.port
  username = o.username
  password = o.password
  uri = o.path

  client = webdavlib.WebDAVClient(hostname, port, username, password)

  collections = getAllCollections(client, uri)
  if len(collections) == 0:
    print "No collections found!"
    sys.exit(1)

  for collection in collections:
    changedItems = changedItemsFromCollection(client, collection) 
    # fetch the href data
    if len(changedItems) > 0:
      multiget = webdavlib.CalDAVCalendarMultiget(collection,
                                                  ["getetag", "{%s}calendar-data" % webdavlib.xmlns_caldav],
                                                  changedItems, depth)
      client.execute(multiget)
      client.conn.close()
      if (multiget.response["status"] != 207):
        raise Exception("Bad http response code: %d" % multiget.response["status"])

if __name__ == "__main__":
  main()
