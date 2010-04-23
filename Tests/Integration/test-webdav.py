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
        self.dav_utility = utilities.TestUtility(self.client)

    def testPrincipalCollectionSet(self):
        """property: 'principal-collection-set' on collection object"""
        resource = '/SOGo/dav/%s/' % username
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        propfind.xpath_namespace = { "D": "DAV:" }
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/D:principal-collection-set/D:href',
                                        None)
        responseHref = nodes[0].childNodes[0].nodeValue
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
        propfind.xpath_namespace = { "D": "DAV:" }
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/D:principal-collection-set/D:href',
                                        None)
        responseHref = nodes[0].childNodes[0].nodeValue
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
        propfind.xpath_namespace = { "D": "DAV:" }
        self.client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)

        nodes = propfind.xpath_evaluate('/D:multistatus/D:response',
                                        None)
        for node in nodes:
            responseHref = propfind.xpath_evaluate('D:href', node)[0].childNodes[0].nodeValue
            hasSlash = responseHref[-1] == '/'
            resourcetypes = \
                propfind.xpath_evaluate('D:propstat/D:prop/D:resourcetype',
                                        node)[0].childNodes
            isCollection = len(resourcetypes) > 0
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
        query = webdavlib.WebDAVPrincipalPropertySearch(resource, matches,
                                                        ["displayname"])
        self.client.execute(query)
        self.assertEquals(query.response["status"], 207)
        response = query.xpath_evaluate('/D:multistatus/D:response')[0]
        href = query.xpath_evaluate('D:href', response)[0]
        self.assertEquals("/SOGo/dav/%s/" % username,
                          href.childNodes[0].nodeValue)
        displayname = query.xpath_evaluate('/D:multistatus/D:response' \
                                               + '/D:propstat/D:prop' \
                                               + '/D:displayname')[0]
        value = displayname.nodeValue
        if value is None:
            value = ""
        self.assertEquals(userInfo[0], value)
        
    # http://tools.ietf.org/html/rfc3253.html#section-3.8
    def testExpandProperty(self):
        """expand-property"""
        resource = '/SOGo/dav/%s/' % username
        userInfo = self.dav_utility.fetchUserInfo(username)

        query_props = {"owner": { "href": resource,
                                  "displayname": userInfo[0]},
                       "principal-collection-set": { "href": "/SOGo/dav/",
                                                     "displayname": "SOGo"}}
        query = webdavlib.WebDAVExpandProperty(resource, query_props.keys(),
                                               ["displayname"])
        self.client.execute(query)
        self.assertEquals(query.response["status"], 207)

        topResponse = query.xpath_evaluate('/D:multistatus/D:response')[0]
        topHref = query.xpath_evaluate('D:href', topResponse)[0]
        self.assertEquals(resource, topHref.childNodes[0].nodeValue)
        for query_prop in query_props.keys():
            propResponse = query.xpath_evaluate('D:propstat/D:prop/D:%s'
                                                % query_prop, topResponse)[0]


# <?xml version="1.0" encoding="utf-8"?>
# <D:multistatus xmlns:D="DAV:">
#   <D:response>
#     <D:href>/SOGo/dav/wsourdeau/</D:href>
#     <D:propstat>
#       <D:prop>
#         <D:owner>
#           <D:response>
#             <D:href>/SOGo/dav/wsourdeau/</D:href>
#             <D:propstat>
#               <D:prop>
#                 <D:displayname>Wolfgang Sourdeau</D:displayname>
#               </D:prop>
#               <D:status>HTTP/1.1 200 OK</D:status>
#             </D:propstat>
#           </D:response>
#         </D:owner>
            propHref = query.xpath_evaluate('D:response/D:href',
                                            propResponse)[0]
            self.assertEquals(query_props[query_prop]["href"],
                              propHref.childNodes[0].nodeValue,
                              "'%s', href mismatch: exp. '%s', got '%s'"
                              % (query_prop,
                                 query_props[query_prop]["href"],
                                 propHref.childNodes[0].nodeValue))
            propDisplayname = query.xpath_evaluate('D:response/D:propstat/D:prop/D:displayname',
                                                   propResponse)[0]
            if len(propDisplayname.childNodes) > 0:
                displayName = propDisplayname.childNodes[0].nodeValue
            else:
                displayName = ""
            self.assertEquals(query_props[query_prop]["displayname"],
                              displayName,
                              "'%s', displayname mismatch: exp. '%s', got '%s'"
                              % (query_prop,
                                 query_props[query_prop]["displayname"],
                                 propDisplayname.nodeValue))

if __name__ == "__main__":
    unittest.main()
