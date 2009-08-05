#!/usr/bin/python

from testconfig import hostname, port, username, password

import sys
import unittest
import webdavlib
import xml.xpath
import time

resource = '/SOGo/dav/%s/Calendar/test-webdavsync/' % username

class WebdavSyncTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(resource)
        self.client.execute(delete)

    def _xpath_query(self, query, top_node):
        xpath_context = xml.xpath.CreateContext(top_node)
        xpath_context.setNamespaces({ "D": "DAV:" })
        return xml.xpath.Evaluate(query, None, xpath_context)
        
    def test(self):
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
        #   non-empty collection:
        #     without a token (query3)
        #     with a token (query4)

        query1 = webdavlib.WebDAVSyncQuery(resource, None, [ "getetag" ])
        self.client.execute(query1)
        self.assertEquals(query1.response["status"], 207,
                          ("query1: invalid status code: %d (!= 207)"
                           % query1.response["status"]))
        token_node = self._xpath_query("/D:multistatus/D:sync-token",
                                       query1.response["document"])[0]
        # Implicit "assertion": we expect SOGo to return a token node, with a
        # non-empty numerical value. Anything else will trigger an exception
        token = int(token_node.childNodes[0].nodeValue)

        self.assertTrue(token > 0)
        self.assertTrue(token < int(query1.start))

        # we make sure that any token is invalid when the collection is empty
        query2 = webdavlib.WebDAVSyncQuery(resource, "1234", [ "getetag" ])
        self.client.execute(query2)
        self.assertEquals(query2.response["status"], 403)
        cond_nodes = self._xpath_query("/D:error/D:valid-sync-token",
                                       query2.response["document"])
        self.assertTrue(len(cond_nodes) > 0,
                        "expected 'valid-sync-token' condition error")

if __name__ == "__main__":
    unittest.main()
