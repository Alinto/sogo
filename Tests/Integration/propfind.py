#!/usr/bin/python

from config import hostname, port, username, password

import webdavlib

import sys
import getopt
import xml.dom.ext

def parseArguments():
    arguments = {}

depth = "0"
quiet = False
(opts, args) = getopt.getopt(sys.argv[1:], "d:q", ["depth=", "quiet"])

for pair in opts:
    if (pair[0] == "-d" or pair[0] == "--depth"):
        depth = pair[1]
    elif (pair[0] == "-q" or pair[0] == "--quiet"):
        quiet = True

# print "depth: " + depth

nargs = len(args)
if (nargs > 0):
    resource = args[0]
    if (nargs > 1):
        properties = args[1:]
    else:
        properties = [ "allprop" ]
else:
    print "resource required"
    sys.exit(-1)

client = webdavlib.WebDAVClient(hostname, port, username, password)
propfind = webdavlib.WebDAVPROPFIND(resource, properties, depth)
client.execute(propfind)

sys.stderr.write("response:\n\n")
print propfind.response["body"]

if propfind.response.has_key("document"):
    sys.stderr.write("document tree:\n")
    xml.dom.ext.PrettyPrint(propfind.response["document"])
