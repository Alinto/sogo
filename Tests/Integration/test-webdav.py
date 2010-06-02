#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username

import unittest
import utilities
import webdavlib

class WebDAVTest(unittest.TestCase):
    def __init__(self, arg):
        unittest.TestCase.__init__(self, arg)
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        self.dav_utility = utilities.TestUtility(self, self.client)

    def testPrincipalCollectionSet(self):
        """property: 'principal-collection-set' on collection object"""
        resource = '/SOGo/dav/%s/' % username
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        nodes = propfind.response["document"] \
                .findall('{DAV:}response/{DAV:}propstat/{DAV:}prop/{DAV:}principal-collection-set/{DAV:}href')
        responseHref = nodes[0].text
        if responseHref[0:4] == "http":
            self.assertEquals("http://%s/SOGo/dav/" % hostname, responseHref,
                              "{DAV:}principal-collection-set returned %s instead of 'http../SOGo/dav/'"
                              % ( responseHref, resource ))
        else:
            self.assertEquals("/SOGo/dav/", responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '/SOGo/dav/'"
                              % responseHref)

    def testPrincipalCollectionSet2(self):
        """property: 'principal-collection-set' on non-collection object"""
        resource = '/SOGo/dav/%s/freebusy.ifb' % username
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        node = propfind.response["document"] \
               .find('{DAV:}response/{DAV:}propstat/{DAV:}prop/{DAV:}principal-collection-set/{DAV:}href')
        responseHref = node.text
        expectedHref = '/SOGo/dav/'
        if responseHref[0:4] == "http":
            self.assertEquals("http://%s%s" % (hostname, expectedHref), responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, expectedHref ))
        else:
            self.assertEquals(expectedHref, responseHref,
                              "{DAV:}principal-collection-set returned %s instead of '%s'"
                              % ( responseHref, expectedHref ))

    def _testPropfindURL(self, resource):
        resourceWithSlash = resource[-1] == '/'
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}displayname", "{DAV:}resourcetype"],
                                            1)
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)

        nodes = propfind.response["document"].findall('{DAV:}response')
        for node in nodes:
            responseHref = node.find('{DAV:}href').text
            hasSlash = responseHref[-1] == '/'
            resourcetype = node.find('{DAV:}propstat/{DAV:}prop/{DAV:}resourcetype')
            isCollection = len(resourcetype.getchildren()) > 0
            if isCollection:
                self.assertEquals(hasSlash, resourceWithSlash,
                                  "failure with href '%s' while querying '%s'"
                                  % (responseHref, resource))
            else:
                self.assertEquals(hasSlash, False,
                                  "failure with href '%s' while querying '%s'"
                                  % (responseHref, resource))
    
    def testPropfindURL(self):
        """propfind: ensure various NSURL work-arounds"""
        # a collection without /
        self._testPropfindURL('/SOGo/dav/%s' % username)
        # a collection with /
        self._testPropfindURL('/SOGo/dav/%s/' % username)
        # a non-collection
        self._testPropfindURL('/SOGo/dav/%s/freebusy.ifb' % username)

    ## REPORT
    def testPrincipalPropertySearch(self):
        """principal-property-search"""
        resource = '/SOGo/dav'
        userInfo = self.dav_utility.fetchUserInfo(username)
        # subscriber_userInfo = self.dav_utility.fetchUserInfo(subscriber_username)
        matches = [["{urn:ietf:params:xml:ns:caldav}calendar-home-set",
                    "/SOGo/dav/%s/Calendar" % username]]
        ## the SOGo implementation does not support more than one
        ## property-search at a time:
        # ["{urn:ietf:params:xml:ns:caldav}calendar-home-set",
        #            "/SOGo/dav/%s/Calendar" % subscriber_username]]
        query = webdavlib.WebDAVPrincipalPropertySearch(resource,
                                                        ["displayname"], matches)
        self.client.execute(query)
        self.assertEquals(query.response["status"], 207)
        response = query.response["document"].findall('{DAV:}response')[0]
        href = response.find('{DAV:}href').text
        self.assertEquals("/SOGo/dav/%s/" % username, href)
        displayname = response.find('{DAV:}propstat/{DAV:}prop/{DAV:}displayname')
        value = displayname.text
        if value is None:
            value = ""
        self.assertEquals(userInfo[0], value)
        
    # http://tools.ietf.org/html/rfc3253.html#section-3.8
    def testExpandProperty(self):
        """expand-property"""
        resource = '/SOGo/dav/%s/' % username
        userInfo = self.dav_utility.fetchUserInfo(username)

        query_props = {"{DAV:}owner": { "{DAV:}href": resource,
                                        "{DAV:}displayname": userInfo[0]},
                       "{DAV:}principal-collection-set": { "{DAV:}href": "/SOGo/dav/",
                                                           "{DAV:}displayname": "SOGo"}}
        query = webdavlib.WebDAVExpandProperty(resource, query_props.keys(),
                                               ["displayname"])
        self.client.execute(query)
        self.assertEquals(query.response["status"], 207)

        topResponse = query.response["document"].find('{DAV:}response')
        topHref = topResponse.find('{DAV:}href')
        self.assertEquals(resource, topHref.text)
        for query_prop in query_props.keys():
            propResponse = topResponse.find('{DAV:}propstat/{DAV:}prop/%s'
                                            % query_prop)
            propHref = propResponse.find('{DAV:}response/{DAV:}href')
            self.assertEquals(query_props[query_prop]["{DAV:}href"],
                              propHref.text,
                              "'%s', href mismatch: exp. '%s', got '%s'"
                              % (query_prop,
                                 query_props[query_prop]["{DAV:}href"],
                                 propHref.text))
            propDisplayname = propResponse.find('{DAV:}response/{DAV:}propstat/{DAV:}prop/{DAV:}displayname')
            displayName = propDisplayname.text
            if displayName is None:
                displayName = ""
            self.assertEquals(query_props[query_prop]["{DAV:}displayname"],
                              displayName,
                              "'%s', displayname mismatch: exp. '%s', got '%s'"
                              % (query_prop,
                                 query_props[query_prop]["{DAV:}displayname"],
                                 propDisplayname))

if __name__ == "__main__":
    unittest.main()
