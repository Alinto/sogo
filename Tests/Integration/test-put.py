#!/usr/bin/python

from config import hostname, port, username, password, testput_nbrdays

import ev_generator
import sogotests
import unittest
import webdavlib

class HTTPUnparsedURLTest(unittest.TestCase):
    def __init__(self, arg):
        unittest.TestCase.__init__(self, arg)
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)

    def setUp(self):
        self.resource = '/SOGo/dav/%s/Calendar/test-dav-put/' % username
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)
        mkcol = webdavlib.WebDAVMKCOL(self.resource)
        self.client.execute(mkcol)
        self.assertEquals(mkcol.response["status"], 201,
                          "preparation: failure creating collection"
                          "(code = %d)" % mkcol.response["status"])
            
    def testPUT(self):
        gen = ev_generator.ev_generator(testput_nbrdays)
        counter = 1
        while gen.iter():
            event = gen.event
            url = self.resource + "event-%d.ics" % counter
            put = webdavlib.HTTPPUT(url, event)
            put.content_type = "text/calendar; charset=utf-8"
            self.client.execute(put)
            counter = counter + 1

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)

if __name__ == "__main__":
    sogotests.runTests()
