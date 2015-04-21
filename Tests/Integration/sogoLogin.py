#!/usr/bin/python

from config import hostname, port, username, password
import sys, getopt
import webdavlib
import urllib
import urllib2
import base64
import simplejson
import cookielib

def getAuthCookie(hostname, port, username, password) :
	cjar = cookielib.CookieJar();
	opener = urllib2.build_opener(urllib2.HTTPCookieProcessor(cjar))
	urllib2.install_opener(opener)

	creds2 = simplejson.dumps({"userName":username, "password": password})
	req = urllib2.Request("http://%s:%s/SOGo/connect" % (hostname, port), creds2,
				{'Content-Type': 'application/json'})
	
	fd = urllib2.urlopen(req)
	
	for cookie in cjar :
	    if cookie.name == "0xHIGHFLYxSOGo":
	      authinfo = cookie.value
	      break

	return "0xHIGHFLYxSOGo="+authinfo

def usage() :
	msg ="""Usage:
%s [-h] [-H | --host=hostname] [-p|--passwd=password] \
[-P|--port=port] [-u|--user=username]\n""" % sys.argv[0]

	sys.stderr.write(msg);

if __name__ == "__main__" :
	try:
	    opts, args = getopt.getopt (sys.argv[1:], "hH:p:P:u:", \
	                            ("host=", "passwd=", "port=", "user="));
	except getopt.GetoptError:
	    usage()
	    exit(1)
	for o, v in opts :
	    if o == "-h" :
	        usage()
	        exit(1)
	    elif o == "-H" or o == "--host" :
	        hostname = v
	    elif o == "-p" or o == "--passwd" :
	        password = v
	    elif o == "-P" or o == "--port" :
	        port = v
	    elif o == "-u" or o == "--user" :
	        username = v

	print getAuthCookie(hostname, port, username, password)
