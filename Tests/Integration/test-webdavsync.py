#!/usr/bin/python

from config import hostname, port, username, password

import math
import sys
import sogotests
import time
import unittest
import webdavlib

resource = '/SOGo/dav/%s/Calendar/test-webdavsync/' % username

class WebdavSyncTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(resource)
        self.client.execute(delete)

    def test(self):
        """webdav sync"""
        # missing tests:
        #   invalid tokens: negative, non-numeric, > current timestamp
        #   non-empty collections: token validity, status codes for added,
        #                          modified and removed elements

        # preparation
        mkcol = webdavlib.WebDAVMKCOL(resource)
        self.client.execute(mkcol)
        self.assertEquals(mkcol.response["status"], 201,
                          "preparation: failure creating collection (code != 201)")

        # test queries:
        #   empty collection:
        #     without a token (query1)
        #     with a token (query2)
        #   (when done, non-empty collection:
        #     without a token (query3)
        #     with a token (query4))

        query1 = webdavlib.WebDAVSyncQuery(resource, None, [ "getetag" ])
        self.client.execute(query1)
        self.assertEquals(query1.response["status"], 207,
                          ("query1: invalid status code: %d (!= 207)"
                           % query1.response["status"]))
        token_node = query1.response["document"].find("{DAV:}sync-token")
        # Implicit "assertion": we expect SOGo to return a token node, with a
        # non-empty numerical value. Anything else will trigger an exception
        token = int(token_node.text)

        self.assertTrue(token > 0)
        query1EndTime = int(math.ceil(query1.start + query1.duration))
        self.assertTrue(token <= query1EndTime, 
                        "token = %d > query1EndTime = %d" % (token, query1EndTime))

        # we make sure that any token is accepted when the collection is
        # empty, but that the returned token differs
        query2 = webdavlib.WebDAVSyncQuery(resource, "1234", [ "getetag" ])
        self.client.execute(query2)
        self.assertEquals(query2.response["status"], 207)
        token_node = query2.response["document"].find("{DAV:}sync-token")
        self.assertTrue(token_node is not None,
                        "expected 'sync-token' tag")
        token = int(token_node.text)
        self.assertTrue(token > 0)

if __name__ == "__main__":
    sogotests.runTests()
