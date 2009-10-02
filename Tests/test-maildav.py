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
         Tue, 17 Dec 2009 07:42:16 -0400
Received: from aloha.dev (localhost [127.0.0.1])
         by aloha.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 29 Sep 2009 07:42:16 -0400
Message-ID: <4AC1F29sept6.5060801@cyril.dev>
Date: Tue, 29 Sep 2009 07:42:14 -0400
From: Cyril <message1from@cyril.dev>
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
To: message1to@cyril.dev
CC: message1cc@cyril.dev, user10@cyril.dev
Subject: message1subject
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

-- 
Cyril <cyril@cyril.dev>
"""

message2 = """Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 09 Dec 2009 07:42:16 -0400
Message-ID: <410sepAC1F296.5060801a@cyril.dev>
Date: Tue, 10 Sep 2009 07:42:14 -0400
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
From: Cyril <message2from@cyril.dev>
To: message2to@cyril.dev
CC: message2cc@cyril.dev
Subject: message2subject
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
-- 
Cyril <cyril@cyril.dev>
"""

message3 = """Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 15 Dec 2009 07:42:16 -0400
Message-ID: <4AC1aF2dec96.5060801a@cyril.dev>
Date: Tue, 10 Dec 2009 07:42:14 -0400
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
From: Cyril <message3from@cyril.dev>
To: message3to@cyril.dev
CC: message3cc@cyril.dev
Subject: Hallo
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

This message is just a big larger than message1 but smaller than message2
-- 
Cyril <cyril@cyril.dev>
"""
message1_received = """Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 17 Dec 2009 07:42:16 -0400"""

class DAVMailCollectionTest(unittest.TestCase):
  resource = '/SOGo/dav/%s/Mail/' % username
  user_email = None

  def setUp(self):
    self.client = webdavlib.WebDAVClient(hostname, port,
                                         username, password)
    if self.user_email is None:
      self.user_email = fetchUserEmail(username)
      if self.user_email.startswith("mailto:"):
        self.user_email = self.user_email[7:]

    self.resource = '/SOGo/dav/%s/Mail/%s_A_%s/' \
        % (username,
           username.replace("@", "_A_").replace(".", "_D_"),
           mailserver.replace(".", "_D_"))

  ## helper methods
  def _makeCollection(self, name, status = 201):
    url = "%s%s" % (self.resource, name)
    mkcol = webdavlib.WebDAVMKCOL(url)
    self.client.execute(mkcol)
    self.assertEquals(mkcol.response["status"], status,
              "failure creating collection"
              "(code = %d)" % mkcol.response["status"])

  def _deleteCollection(self, name, status = 204):
    url = "%sfolder%s" % (self.resource, name)
    delete = webdavlib.WebDAVDELETE(url)
    self.client.execute(delete)
    self.assertEquals(delete.response["status"], status,
              "failure deleting collection"
              "(code = %d)" % delete.response["status"])

  def _putMessage(self, client, folder, message,
                  exp_status = 201):
    url = "%sfolder%s" % (self.resource, folder)
    put = webdavlib.HTTPPUT(url, message)
    put.content_type = "message/rfc822"
    client.execute(put)
    if (exp_status is not None):
      self.assertEquals(put.response["status"], exp_status,
                        "message creation/modification:"
                        " expected status code '%d' (received '%d')"
                        % (exp_status, put.response["status"]))
    return put.response["headers"]["location"]

  def _testProperty (self, url, property, expected, isDate = 0):
      propfind = webdavlib.WebDAVPROPFIND(url, (property, ), 0)
      self.client.execute(propfind)
      key = property.replace("{urn:schemas:httpmail:}", "a:")
      key = key.replace("{urn:schemas:mailheader:}", "a:")
      tmp = propfind.xpath_evaluate("/D:multistatus/D:response/D:propstat/D:prop")
      prop = tmp[0].firstChild;
      result = None

      if prop:
          result = prop._get_firstChild()._get_nodeValue()
          #print key, result

      if isDate:
          tstruct = time.strptime (result, "%a, %d %b %Y %H:%M:%S %Z")
          result = int (time.mktime (tstruct))

      self.assertEquals(result, expected,
                      "failure in propfind"
                      "(%s != %s)" % (result, expected))

  def testMKCOL(self):
    """Folder creation"""
    self._makeCollection("test-dav-mail-%40-abc")
    self._deleteCollection("test-dav-mail-%40-abc")
    self._makeCollection("test-dav-mail-@-def")
    self._deleteCollection("test-dav-mail-@-def")
    self._makeCollection("test-dav-mail-%20-ghi")
    self._deleteCollection("test-dav-mail-%20-ghi")
    self._makeCollection("test-dav-mail-%25-jkl", 500)

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
    self._deleteCollection("test-dav-mail")
    self._makeCollection("test-dav-mail")

    # message creation on collection url
    url = "%s%s" % (self.resource, "foldertest-dav-mail/")
    put = webdavlib.HTTPPUT(url, message1)
    put.content_type = "message/rfc822"
    self.client.execute(put)
    self.assertEquals(put.response["status"], 201,
                      "failure putting message"
                      "(code = %d)" % put.response["status"])

    itemLocation = put.response["headers"]["location"]
    get = webdavlib.WebDAVGET(itemLocation)
    self.client.execute(get)
    self.assertEquals(get.response["status"], 200,
                      "failure getting item"
                      "(code = %d)" % get.response["status"])

    # message creation with explicit filename
    url = "%s%s" %(self.resource, "foldertest-dav-mail/blabla.eml")
    put = webdavlib.HTTPPUT(url, message1)
    put.content_type = "message/rfc822"
    self.client.execute(put)
    self.assertEquals(put.response["status"], 201,
                      "failure putting message"
                      "(code = %d)" % put.response["status"])
    
    itemLocation = put.response["headers"]["location"]
    get = webdavlib.WebDAVGET(itemLocation)
    self.client.execute(get)
    self.assertEquals(get.response["status"], 200,
                      "failure getting item"
                      "(code = %d)" % get.response["status"])

    self._deleteCollection("test-dav-mail")

  def _testFilters(self, filters):
    for filter in filters:
      self._testFilter(filter)

  def _testFilter(self, filter):
    expected_hrefs = {}
    expected_count = len(filter[1])
    for href in filter[1]:
      expected_hrefs[href] = True

    received_count = 0
    query = webdavlib.MailDAVMailQuery(self.resource, ["displayname"],
                                       filter[0])
    self.client.execute(query)
    self.assertEquals(query.response["status"], 207,
                      "filter %s:\n\tunexpected status: %d"
                      % (filter[0], query.response["status"]))
    query.xpath_namespace = { "D": "DAV:",
                              "I": "urn:inverse:params:xml:ns:inverse-dav" }
    response_nodes = query.xpath_evaluate("/D:multistatus/D:response")
    for response_node in response_nodes:
      href_node = query.xpath_evaluate("D:href", response_node)[0]
      href = href_node.childNodes[0].nodeValue
      received_count = received_count + 1
      self.assertTrue(expected_hrefs.has_key(href),
                      "filter %s:\n\tunexpected href: %s" % (filter[0], href))

    self.assertEquals(len(filter[1]), received_count,
                      "filter %s:\n\tunexpected amount of refs: %d"
                      % (filter[0], received_count))

  def testREPORTMailQuery(self):
    """mail-query"""
    self._deleteCollection("test-dav-mail")
    self._makeCollection("test-dav-mail")

    msg1Loc = self._putMessage(self.client, "test-dav-mail", message1)
    parsed = webdavlib.HTTPUnparsedURL(msg1Loc)
    msg1Path = parsed.path
    msg2Loc = self._putMessage(self.client, "test-dav-mail", message2)
    parsed = webdavlib.HTTPUnparsedURL(msg2Loc)
    msg2Path = parsed.path
    msg3Loc = self._putMessage(self.client, "test-dav-mail", message3)
    parsed = webdavlib.HTTPUnparsedURL(msg3Loc)
    msg3Path = parsed.path

    properties = ["{DAV:}displayname"]

    ## 1. test filter: receive-date
    #   SINCE, BEFORE, ON
    # q = MailDAVMailQuery(self.resource, properties, filters = None)

    filters = (({ "receive-date": { "from": "20091201T000000Z",
                                    "to": "20091208T000000Z" } },
                []),
               ({ "receive-date": { "from": "20091208T000000Z",
                                    "to": "20091213T134300Z" } },
                [ msg2Loc ]),
               ({ "receive-date": { "from": "20091208T000000Z",
                                    "to": "20091216T134300Z" } },
                [ msg2Loc, msg3Loc ]),
               ({ "receive-date": { "from": "20091216T000000Z",
                                    "to": "20091220T134300Z" } },
                [ msg1Loc ]),
               ({ "receive-date": { "from": "20091220T000000Z",
                                    "to": "20091229T134300Z" } },
                []))
    self._testFilters(filters)

    ## 1. test filter: date
    #   SENTSINCE, SENTBEFORE, SENTON

    filters = (({ "date": { "from": "20090101T000000Z",
                            "to": "20090201T000000Z" } },
                []),
               ({ "date": { "from": "20090912T000000Z",
                            "to": "20090929T134300Z" } },
                [ msg1Loc ]),
               ({ "date": { "from": "20090929T134300Z",
                            "to": "20091209T000000Z" } },
                []),
               ({ "date": { "from": "20090901T134300Z",
                            "to": "20091209T000000Z" } },
                [ msg1Loc, msg2Loc ]),
               ({ "date": { "from": "20091201T000000Z",
                            "to": "20091211T000000Z" } },
                [ msg3Loc ]),
               ({ "date": { "from": "20091211T000000Z",
                            "to": "20101211T000000Z" } },
                []),
               ({ "date": { "from": "20090101T000000Z",
                            "to": "20100101T000000Z" } },
                [ msg1Loc, msg2Loc, msg3Loc ]))
    self._testFilters(filters)

    ## 1. test filter: sequence
    #   x:y
    filters = (({ "sequence": { "from": "1" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "sequence": { "from": "5" }},
                []),
               ({ "sequence": { "to": "5" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "sequence": { "from": "1",
                                "to": "2" }},
                [ msg1Loc, msg2Loc ]))
    self._testFilters(filters)

    ## 1. test filter: uid
    #   UID
    filters = (({ "uid": { "from": "1" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "uid": { "from": "5" }},
                []),
               ({ "uid": { "to": "5" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "uid": { "from": "1",
                           "to": "2" }},
                [ msg1Loc, msg2Loc ]))
    self._testFilters(filters)

    ## 1. test filter: from
    #   FROM
    filters = (({ "from": { "match": "message" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "from": { "match": "Cyril" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "from": { "match": "cyril.dev" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "from": { "match": "message1from" }},
                [ msg1Loc ]),
               ({ "from": { "match": "message2from" }},
                [ msg2Loc ]),
               ({ "from": { "match": "message3from" }},
                [ msg3Loc ]))
    self._testFilters(filters)

    ## 1. test filter: to
    #   TO
    filters = (({ "to": { "match": "message" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "to": { "match": "Cyril" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "to": { "match": "cyril.dev" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "to": { "match": "message1to" }},
                [ msg1Loc ]),
               ({ "to": { "match": "message2to" }},
                [ msg2Loc ]),
               ({ "to": { "match": "message3to" }},
                [ msg3Loc ]))
    self._testFilters(filters)

    ## 1. test filter: cc
    #   CC
    filters = (({ "cc": { "match": "message" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "cc": { "match": "Cyril" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "cc": { "match": "cyril.dev" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "cc": { "match": "message1cc" }},
                [ msg1Loc ]),
               ({ "cc": { "match": "message2cc" }},
                [ msg2Loc ]),
               ({ "cc": { "match": "message3cc" }},
                [ msg3Loc ]))
    self._testFilters(filters)

    ## 1. test filter: bcc
    #   BCC
    ## TODO

    ## 1. test filter: body
    #   BODY
    filters = (({ "body": { "match": "Hello" }},
                [ msg1Loc, msg2Loc, msg3Loc ]),
               ({ "body": { "match": "Stuff" }},
                [ msg2Loc ]),
               ({ "body": { "match": "DOESNOT MATCH" }},
                []))
    self._testFilters(filters)

    ## 1. test filter: size
    #   LARGER, SMALLER
    ## 1. test filter: answered
    #   ANSWERED, UNANSWERED
    ## 1. test filter: draft
    #   DRAFT
    ## 1. test filter: flagged
    #   FLAGGED
    ## 1. test filter: recent
    #   RECENT
    ## 1. test filter: seen
    #   SEEN
    ## 1. test filter: deleted
    #   DELETED
    ## 1. test filter: keywords
    #   KEYWORD x

    # 1. test sort: (receive-date) ARRIVAL
    # 1. test sort: (date) DATE
    # 1. test sort: CC
    # 1. test sort: FROM
    # 1. test sort: SIZE
    # 1. test sort: SUBJECT
    # 1. test sort: TO

    self._deleteCollection("test-dav-mail")

  def testPROPFIND(self):
    """Message properties"""
    self._deleteCollection ("test-dav-mail")
    self._makeCollection ("test-dav-mail")

    url = "%s%s" % (self.resource, "foldertest-dav-mail/")
    put = webdavlib.HTTPPUT (url, message1)
    put.content_type = "message/rfc822"
    self.client.execute (put)
    self.assertEquals(put.response["status"], 201,
                      "failure putting message"
                      "(code = %d)" % put.response["status"])

    itemLocation = put.response["headers"]["location"]
    tests = (("{urn:schemas:httpmail:}date", 1254242534, 1),
             ("{urn:schemas:httpmail:}hasattachment", "0", 0),
             ("{urn:schemas:httpmail:}read", "0", 0),
             ("{urn:schemas:httpmail:}textdescription", 
               "<![CDATA[%s]]>" % message1, 0),
             ("{urn:schemas:httpmail:}unreadcount", None, 0),
             ("{urn:schemas:mailheader:}cc","message1cc@cyril.dev, user10@cyril.dev", 0),
             ("{urn:schemas:mailheader:}date", "Tue, 29 Sep 2009 11:42:14 GMT", 0),
             ("{urn:schemas:mailheader:}from", "Cyril <message1from@cyril.dev>", 0),
             ("{urn:schemas:mailheader:}in-reply-to", None, 0),
             ("{urn:schemas:mailheader:}message-id","<4AC1F29sept6.5060801@cyril.dev>", 0),
             ("{urn:schemas:mailheader:}received", message1_received, 0),
             ("{urn:schemas:mailheader:}references",
               "<4AC3BF1B.3010806@inverse.ca>", 0),
             ("{urn:schemas:mailheader:}subject", "Hallo", 0),
             ("{urn:schemas:mailheader:}to", "jacques@cyril.dev", 0))

    for test in tests:
        property, expected, isDate = test
        self._testProperty(itemLocation, property, expected, isDate)

    self._deleteCollection ("test-dav-mail")


if __name__ == "__main__":
  unittest.main()
