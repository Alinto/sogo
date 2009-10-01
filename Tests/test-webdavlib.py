#!/usr/bin/python

import unittest

from webdavlib import *

class HTTPUnparsedURLTest(unittest.TestCase):
    def testURLParse(self):
        fullURL = "http://username:password@hostname:123/folder/folder/object?param1=value1&param2=value2"
        testURL = HTTPUnparsedURL(fullURL)
        self.assertEquals(testURL.protocol, "http")
        self.assertEquals(testURL.username, "username")
        self.assertEquals(testURL.password, "password")
        self.assertEquals(testURL.hostname, "hostname")
        self.assertEquals(testURL.port, "123")
        self.assertEquals(testURL.path, "/folder/folder/object")

        exp_params = { "param1": "value1",
                       "param2": "value2" }
        self.assertEquals(exp_params, testURL.parameters)

        pathURL = "/folder/folder/simplereference"
        testURL = HTTPUnparsedURL(pathURL)
        self.assertEquals(testURL.protocol, None)
        self.assertEquals(testURL.username, None)
        self.assertEquals(testURL.password, None)
        self.assertEquals(testURL.hostname, None)
        self.assertEquals(testURL.port, None)
        self.assertEquals(testURL.path, "/folder/folder/simplereference")

if __name__ == "__main__":
    unittest.main()
