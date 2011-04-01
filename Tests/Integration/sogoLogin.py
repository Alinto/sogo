#!/usr/bin/python

from config import hostname, port, username, password
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

	creds = urllib.urlencode([("userName",username), ("password", password)])
	req = urllib2.Request("http://%s/SOGo/connect" % hostname, creds)
	
	fd = urllib2.urlopen(req)
	#print fd.info()
	
	for cookie in cjar :
	    if cookie.name == "0xHIGHFLYxSOGo":
	      authinfo = cookie.value
	      break

	return "0xHIGHFLYxSOGo="+authinfo
if __name__ == "__main__" :
	getAuthCookie()
