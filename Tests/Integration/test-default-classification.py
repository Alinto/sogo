#!/usr/bin/python

import sogotests
import unittest
import webdavlib

from config import *

class HTTPDefaultClassificationTest(unittest.TestCase):
    def _setClassification(self, user, component, classification = ""):
        resource = '/SOGo/dav/%s/Calendar/' % user
        props = { "{urn:inverse:params:xml:ns:inverse-dav}%s-default-classification" % component: classification }
        proppatch = webdavlib.WebDAVPROPPATCH(resource, props)
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.execute(proppatch)

        return (proppatch.response["status"] == 207);

    def _getClassification(self, user, component):
        resource = '/SOGo/dav/%s/Calendar/' % user
        property_name = "{urn:inverse:params:xml:ns:inverse-dav}%s-default-classification" % component 
        propfind = webdavlib.WebDAVPROPFIND(resource, [ property_name ], "0")
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.execute(propfind)
        classification = None
        propstat_nodes = propfind.response["document"].findall("{DAV:}response/{DAV:}propstat")
        for propstat_node in propstat_nodes:
            status_nodes = propstat_node.findall("{DAV:}status")
            if status_nodes[0].text.lower() == "http/1.1 200 ok":
                property_nodes = propstat_node.findall("{DAV:}prop/%s" % property_name)
                if len(property_nodes) > 0:
                    classification = property_nodes[0].text

        return classification

    def test(self):
        self.assertFalse(self._setClassification(username, "123456", "PUBLIC"),
                         "expected failure when setting a classification with an invalid property")
        self.assertFalse(self._setClassification(username, "events", ""),
                         "expected failure when setting an empty classification")
        self.assertFalse(self._setClassification(username, "events", "pouet"),
                         "expected failure when setting an invalid classification")
        for component in [ "events", "tasks" ]:
            for classification in [ "PUBLIC", "PRIVATE", "CONFIDENTIAL" ]:
                self.assertTrue(self._setClassification(username, component, classification),
                                "error when setting classification to '%s'" % classification)
                fetched_class = self._getClassification(username, component)
                self.assertTrue(classification == fetched_class,
                                "set and fetched classifications do not match (%s != %s)" % (classification, fetched_class))

if __name__ == "__main__":
    sogotests.runTests()
