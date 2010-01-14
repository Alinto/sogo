#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username

import unittest
import webdavlib

class iCalTest(unittest.TestCase):
    def testPrincipalCollectionSet(self):
        """principal-collection-set: 'DAV' header must be returned with iCal 4"""
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        resource = '/SOGo/dav/%s/' % username

        # NOT iCal4
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        propfind.xpath_namespace = { "D": "DAV:" }
        client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        headers = propfind.response["headers"]
        self.assertFalse(headers.has_key("dav"),
                         "DAV header must not be returned when user-agent is NOT iCal 4")

        # iCal4
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}principal-collection-set"],
                                            0)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        propfind.xpath_namespace = { "D": "DAV:" }
        client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        headers = propfind.response["headers"]
        self.assertTrue(headers.has_key("dav"),
                        "DAV header must be returned when user-agent is iCal 4")

        expectedDAVClasses = ["1", "2", "access-control", "calendar-access",
                              "calendar-schedule", "calendar-proxy"]
        davClasses = [x.strip() for x in headers["dav"].split(",")]
        for davClass in expectedDAVClasses:
            self.assertTrue(davClass in davClasses,
                            "DAV class '%s' not found" % davClass)

    def _setMemberSet(self, owner, members, perm):
        resource = '/SOGo/dav/%s/calendar-proxy-%s/' % (owner, perm)
        membersHref = [ { "{DAV:}href": '/SOGo/dav/%s/' % x }
                        for x in members ]
        props = { "{DAV:}group-member-set": membersHref }
        proppatch = webdavlib.WebDAVPROPPATCH(resource, props)
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        proppatch.xpath_namespace = { "D": "DAV:" }
        client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 207,
                          "failure (%s) setting '%s' permission for '%s' on %s's calendars"
                          % (proppatch.response["status"], perm,
                             "', '".join(members), owner))

    def _getMembership(self, user):
        resource = '/SOGo/dav/%s/' % user
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                             ["{DAV:}group-membership"], 0)
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        propfind.xpath_namespace = { "D": "DAV:" }
        client.execute(propfind)

        hrefs = propfind.xpath_evaluate("/D:multistatus/D:response/D:propstat/D:prop/D:group-membership/D:href")
        members = [x.childNodes[0].nodeValue for x in hrefs]

        return members

    def _getProxyFor(self, user, perm):
        resource = '/SOGo/dav/%s/' % user
        prop = "{http://calendarserver.org/ns/}calendar-proxy-%s-for" % perm
        propfind = webdavlib.WebDAVPROPFIND(resource, [prop], 0)
        client = webdavlib.WebDAVClient(hostname, port, username, password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        propfind.xpath_namespace = { "D": "DAV:", "n1": "http://calendarserver.org/ns/" }
        client.execute(propfind)

        hrefs = propfind.xpath_evaluate("/D:multistatus/D:response/D:propstat/D:prop/n1:calendar-proxy-%s-for/D:href"
                                        % perm)
        members = [x.childNodes[0].nodeValue[len("/SOGo/dav/"):-1] for x in hrefs]
        
        return members

    def testCalendarProxy(self):
        self._setMemberSet(username, [], "read")
        self._setMemberSet(username, [], "write")
        self._setMemberSet(subscriber_username, [], "read")
        self._setMemberSet(subscriber_username, [], "write")
        self.assertEquals([], self._getMembership(username),
                          "'%s' must have no membership"
                          % username)
        self.assertEquals([], self._getMembership(subscriber_username),
                          "'%s' must have no membership"
                          % subscriber_username)
        self.assertEquals([], self._getProxyFor(username, "read"),
                          "'%s' must not be a proxy for anyone" % username)
        self.assertEquals([], self._getProxyFor(username, "write"),
                          "'%s' must not be a proxy for anyone" % username)
        self.assertEquals([], self._getProxyFor(subscriber_username, "read"),
                          "'%s' must not be a proxy for anyone" % subscriber_username)
        self.assertEquals([], self._getProxyFor(subscriber_username, "write"),
                          "'%s' must not be a proxy for anyone" % subscriber_username)

        for perm in ("read", "write"):
            for users in ((username, subscriber_username),
                          (subscriber_username, username)):
                self._setMemberSet(users[0], [users[1]], perm)
                membership = self._getMembership(users[1])
                self.assertEquals(['/SOGo/dav/%s/calendar-proxy-%s/'
                                   % (users[0], perm)],
                                  membership,
                                  "'%s' must have %s access to %s's calendars"
                                  % (users[1], perm, users[0]))
                proxyFor = self._getProxyFor(users[1], perm)
                self.assertEquals([users[0]], proxyFor,
                                  "'%s' expected to be %s proxy for %s: %s"
                                  % (users[1], perm, users[0], proxyFor))

if __name__ == "__main__":
    unittest.main()
