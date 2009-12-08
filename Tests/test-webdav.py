#!/usr/bin/python

from config import hostname, port, username, password

import unittest
import webdavlib

class WebDAVTest(unittest.TestCase):
    def testPrincipalCollectionSet(self):
        """property: principal-collection-set"""
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        resource = '/SOGo/dav/%s/' % username
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        propfind.xpath_namespace = { "D": "DAV:" }
        client.execute(propfind)
        assert(propfind.response["status"] == 207)
        nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/D:principal-collection-set/D:href',
                                        None)
        responseHref = nodes[0].childNodes[0].nodeValue
        if responseHref[0:4] == "http":
            self.assertEquals("http://%s%s" % (hostname, resource), responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, resource ))
        else:
            self.assertEquals(resource, responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, resource ))

    def testPrincipalCollectionSet2(self):
        """property: principal-collection-set"""
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        resource = '/SOGo/dav/%s/freebusy.ifb' % username
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        propfind.xpath_namespace = { "D": "DAV:" }
        client.execute(propfind)
        assert(propfind.response["status"] == 207)
        nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/D:principal-collection-set/D:href',
                                        None)
        responseHref = nodes[0].childNodes[0].nodeValue
        if responseHref[0:4] == "http":
            self.assertEquals("http://%s%s" % (hostname, resource), responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, resource ))
        else:
            self.assertEquals(resource, responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, resource ))

if __name__ == "__main__":
    unittest.main()
