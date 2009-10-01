#!/usr/bin/python

from config import hostname, port, username, password, mailserver, subscriber_username, subscriber_password

import sys
import unittest
import webdavlib
import time

def fetchUserEmail(login):
  client = webdavlib.WebDAVClient(hostname, port,
                                  username, password)
  resource = '/SOGo/dav/%s/' % login
  propfind = webdavlib.WebDAVPROPFIND(resource,
                                      ["{urn:ietf:params:xml:ns:caldav}calendar-user-address-set"],
                                      0)
  propfind.xpath_namespace = { "D": "DAV:",
                               "C": "urn:ietf:params:xml:ns:caldav" }
  client.execute(propfind)
  nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/C:calendar-user-address-set/D:href',
                                  None)

  return nodes[0].childNodes[0].nodeValue

message1 = """Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 29 Sep 2009 07:42:16 -0400
X-Virus-Scanned: Debian amavisd-new at inverse.ca
Message-ID: <4AC1F296.5060801@cyril.dev>
Date: Tue, 29 Sep 2009 07:42:14 -0400
From: Cyril <cyril@cyril.dev>
Organization: Inverse inc.
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
To: jacques@cyril.dev
CC: support@inverse.ca
Subject: Hallo
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca,Cyril <cyril@cyril.dev>

Hello Jacques,

Can you read me?

-- 
Cyril <cyril@cyril.dev>
"""

class DAVMailCollectionTest(unittest.TestCase):
  resource = '/SOGo/dav/%s/Mail/' % username
  user_email = None

  def setUp(self):
    self.client = webdavlib.WebDAVClient(hostname, port,
                                         username, password)
    if self.user_email is None:
      self.user_email = fetchUserEmail(username)
      if self.user_email.startswith ("mailto:"):
        self.user_email = self.user_email[7:]

    self.resource = '/SOGo/dav/%s/Mail/%s_A_%s/' \
        % (username,
           username.replace("@", "_A_").replace (".", "_D_"),
           mailserver.replace (".", "_D_"))

  ## helper methods
  def _makeCollection (self, name, status = 201):
    url = "%s%s" % (self.resource, name)
    mkcol = webdavlib.WebDAVMKCOL(url)
    self.client.execute(mkcol)
    self.assertEquals(mkcol.response["status"], status,
              "failure creating collection"
              "(code = %d)" % mkcol.response["status"])

  def _deleteCollection (self, name, status = 204):
    url = "%sfolder%s" % (self.resource, name)
    delete = webdavlib.WebDAVDELETE(url)
    self.client.execute(delete)
    self.assertEquals(delete.response["status"], status,
              "failure deleting collection"
              "(code = %d)" % delete.response["status"])

  def _putMessage(self, client, filename,
                  exp_status = 201):
    url = "%s%s" % (self.resource, filename)
    put = webdavlib.HTTPPUT(url, message)
    put.content_type = "message/rfc822"
    client.execute(put)
    self.assertEquals(put.response["status"], exp_status,
                      "%s: event creation/modification:"
                      " expected status code '%d' (received '%d')"
                      % (filename, exp_status, put.response["status"]))

  def testMKCOL(self):
    """Folder creation"""
    self._makeCollection ("test-dav-mail-%40-abc")
    self._deleteCollection ("test-dav-mail-%40-abc")
    self._makeCollection ("test-dav-mail-@-def")
    self._deleteCollection ("test-dav-mail-@-def")
    self._makeCollection ("test-dav-mail-%20-ghi")
    self._deleteCollection ("test-dav-mail-%20-ghi")
    self._makeCollection ("test-dav-mail-%25-jkl", 500)

    # Test MOVE
#    self._makeCollection ("test-dav-mail-movable")
#    url = "%sfolder%s" % (self.resource, "test-dav-mail-movable")
#    move = webdavlib.WebDAVMOVE (url)
#    move.destination = "http://cyril.dev%s%s2" % (self.resource, "test-dav-mail-movable")
#    move.host = "cyril.dev"
#    self.client.execute (move)
#    self.assertEquals(move.response["status"], 204,
#              "failure creating collection"
#              "(code = %d)" % move.response["status"])

  def testPUT(self):
    """Message creation"""
    self._deleteCollection ("test-dav-mail")
    self._makeCollection ("test-dav-mail")

    # message creation on collection url
    url = "%s%s" % (self.resource, "foldertest-dav-mail/")
    put = webdavlib.HTTPPUT (url, message1)
    put.content_type = "message/rfc822; charset=utf-8"
    self.client.execute (put)
    self.assertEquals(put.response["status"], 201,
                      "failure putting message"
                      "(code = %d)" % put.response["status"])

    itemLocation = put.response["headers"]["location"]
    get = webdavlib.WebDAVGET (itemLocation)
    self.client.execute (get)
    self.assertEquals(get.response["status"], 200,
                      "failure getting item"
                      "(code = %d)" % get.response["status"])

    # message creation with explicit filename
    url = "%s%s" % (self.resource, "foldertest-dav-mail/blabla.eml")
    put = webdavlib.HTTPPUT (url, message1)
    put.content_type = "message/rfc822; charset=utf-8"
    self.client.execute (put)
    self.assertEquals(put.response["status"], 201,
                      "failure putting message"
                      "(code = %d)" % put.response["status"])
    
    itemLocation = put.response["headers"]["location"]
    get = webdavlib.WebDAVGET (itemLocation)
    self.client.execute (get)
    self.assertEquals(get.response["status"], 200,
                      "failure getting item"
                      "(code = %d)" % get.response["status"])

    self._deleteCollection ("test-dav-mail")

if __name__ == "__main__":
  unittest.main()
