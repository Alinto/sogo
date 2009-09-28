#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username, subscriber_password

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

class DAVMailTest(unittest.TestCase):
  resource = None

  def setUp(self):
    self.client = webdavlib.WebDAVClient(hostname, port,
                       username, password)
    #delete = webdavlib.WebDAVDELETE(self.davResource)
    #self.client.execute(delete)
    #mkcol = webdavlib.WebDAVMKCOL(self.resource)
    #self.client.execute(mkcol)
    #self.assertEquals(mkcol.response["status"], 201,
    #          "preparation: failure creating collection"
    #          "(code = %d)" % mkcol.response["status"])
    #self.subscriber_client = webdavlib.WebDAVClient(hostname, port,
    #                        subscriber_username,
    #                        subscriber_password)

#  def tearDown(self):
    #delete = webdavlib.WebDAVDELETE(self.davResource)
    #self.client.execute(delete)


class DAVMailCollectionTest(DAVMailTest):
  resource = '/SOGo/dav/%s/Mail/' % username
  user_email = None

  def setUp(self):
    if self.user_email is None:
      self.user_email = fetchUserEmail(username)
      if self.user_email.startswith ("mailto:"):
        self.user_email = self.user_email[7:]

    self.resource = '/SOGo/dav/%s/Mail/%s/' \
        % (username, self.user_email)

    DAVMailTest.setUp(self)

  def testGeneric(self):
    """Test folder creation / listing"""
    self._makeCollection ("test-dav-mail-%40-abc")
    self._deleteCollection ("test-dav-mail-%40-abc")
    self._makeCollection ("test-dav-mail-@-def")
    self._deleteCollection ("test-dav-mail-@-def")
    self._makeCollection ("test-dav-mail-%20-ghi")
    self._deleteCollection ("test-dav-mail-%20-ghi")
    self._makeCollection ("test-dav-mail-%25-jkl", 500)

#    self._makeCollection ("test-dav-mail-movable")
#    url = "%sfolder%s" % (self.resource, "test-dav-mail-movable")
#    move = webdavlib.WebDAVMOVE (url)
#    move.destination = "http://cyril.dev%s%s2" % (self.resource, "test-dav-mail-movable")
#    move.host = "cyril.dev"
#    self.client.execute (move)
#    self.assertEquals(move.response["status"], 204,
#              "failure creating collection"
#              "(code = %d)" % move.response["status"])

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
    put.content_type = "text/plain; charset=utf-8"
    client.execute(put)
    self.assertEquals(put.response["status"], exp_status,
              "%s: event creation/modification:"
              " expected status code '%d' (received '%d')"
              % (filename, exp_status, put.response["status"]))

if __name__ == "__main__":
  unittest.main()

