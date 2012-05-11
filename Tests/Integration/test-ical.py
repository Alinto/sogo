#!/usr/bin/python

# FIXME: we should avoid using superuser if possible

from config import hostname, port, username, password, subscriber_username, \
		   superuser, superuser_password

import unittest
import sogotests
import utilities
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
        client.execute(propfind)
        self.assertEquals(propfind.response["status"], 207)
        headers = propfind.response["headers"]
        self.assertTrue(headers.has_key("dav"),
                        "DAV header must be returned when user-agent is iCal 4")

        expectedDAVClasses = ["1", "2", "access-control", "calendar-access",
                              "calendar-schedule", "calendar-auto-schedule",
                              "calendar-proxy"]
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
        client = webdavlib.WebDAVClient(hostname, port, superuser, superuser_password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 207,
                          "failure (%s) setting '%s' permission for '%s' on %s's calendars"
                          % (proppatch.response["status"], perm,
                             "', '".join(members), owner))

    def _getMembership(self, user):
        resource = '/SOGo/dav/%s/' % user
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                             ["{DAV:}group-membership"], 0)
        client = webdavlib.WebDAVClient(hostname, port, superuser, superuser_password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        client.execute(propfind)

        hrefs = propfind.response["document"].findall("{DAV:}response/{DAV:}propstat/{DAV:}prop/{DAV:}group-membership/{DAV:}href")
        members = [x.text for x in hrefs]

        return members

    def _getProxyFor(self, user, perm):
        resource = '/SOGo/dav/%s/' % user
        prop = "{http://calendarserver.org/ns/}calendar-proxy-%s-for" % perm
        propfind = webdavlib.WebDAVPROPFIND(resource, [prop], 0)
        client = webdavlib.WebDAVClient(hostname, port, superuser, superuser_password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        client.execute(propfind)

        hrefs = propfind.response["document"].findall("{DAV:}response/{DAV:}propstat/{DAV:}prop/{http://calendarserver.org/ns/}calendar-proxy-%s-for/{DAV:}href"
                                        % perm)
        members = [x.text[len("/SOGo/dav/"):-1] for x in hrefs]
        
        return members

    def testCalendarProxy(self):
        """calendar-proxy as used from iCal"""
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

    def _testMapping(self, client, perm, resource, rights):
        dav_utility = utilities.TestCalendarACLUtility(self, client, resource)
        dav_utility.setupRights(subscriber_username, rights)

        membership = self._getMembership(subscriber_username)
        self.assertEquals(['/SOGo/dav/%s/calendar-proxy-%s/'
                           % (username, perm)],
                          membership,
                          "'%s' must have %s access to %s's calendars:\n%s"
                          % (subscriber_username, perm, username, membership))
        proxyFor = self._getProxyFor(subscriber_username, perm)
        self.assertEquals([username], proxyFor,
                          "'%s' expected to be %s proxy for %s: %s"
                          % (subscriber_username, perm, username, proxyFor))

    def testCalendarProxy2(self):
        """calendar-proxy as used from SOGo"""
        client = webdavlib.WebDAVClient(hostname, port, superuser, superuser_password)
        client.user_agent = "DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)"
        personal_resource = "/SOGo/dav/%s/Calendar/personal/" % username
        dav_utility = utilities.TestCalendarACLUtility(self,
                                                       client,
                                                       personal_resource)
        dav_utility.setupRights(subscriber_username, {})
        dav_utility.subscribe([subscriber_username])

        other_resource = ("/SOGo/dav/%s/Calendar/test-calendar-proxy2/"
                          % username)
        delete = webdavlib.WebDAVDELETE(other_resource)
        client.execute(delete)
        mkcol = webdavlib.WebDAVMKCOL(other_resource)
        client.execute(mkcol)
        dav_utility = utilities.TestCalendarACLUtility(self,
                                                       client,
                                                       other_resource)
        dav_utility.setupRights(subscriber_username, {})
        dav_utility.subscribe([subscriber_username])

        ## we test the rights mapping
        # write: write on 'personal', none on 'test-calendar-proxy2'
        self._testMapping(client, "write", personal_resource,
                          { "c": True, "d": False, "pu": "v" })
        self._testMapping(client, "write", personal_resource,
                          { "c": False, "d": True, "pu": "v" })
        self._testMapping(client, "write", personal_resource,
                          { "c": False, "d": False, "pu": "m" })
        self._testMapping(client, "write", personal_resource,
                          { "c": False, "d": False, "pu": "r" })

        # read: read on 'personal', none on 'test-calendar-proxy2'
        self._testMapping(client, "read", personal_resource,
                          { "c": False, "d": False, "pu": "d" })
        self._testMapping(client, "read", personal_resource,
                          { "c": False, "d": False, "pu": "v" })
        
        # write: read on 'personal', write on 'test-calendar-proxy2'
        self._testMapping(client, "write", other_resource,
                          { "c": False, "d": False, "pu": "r" })

        ## we test the unsubscription
        # unsubscribed from personal, subscribed to 'test-calendar-proxy2'
        dav_utility = utilities.TestCalendarACLUtility(self, client,
                                                       personal_resource)
        dav_utility.unsubscribe([subscriber_username])
        membership = self._getMembership(subscriber_username)
        self.assertEquals(['/SOGo/dav/%s/calendar-proxy-write/' % username],
                          membership,
                          "'%s' must have write access to %s's calendars"
                          % (subscriber_username, username))
        # unsubscribed from personal, unsubscribed from 'test-calendar-proxy2'
        dav_utility = utilities.TestCalendarACLUtility(self, client,
                                                       other_resource)
        dav_utility.unsubscribe([subscriber_username])
        membership = self._getMembership(subscriber_username)
        self.assertEquals([],
                          membership,
                          "'%s' must have no access to %s's calendars"
                          % (subscriber_username, username))

        delete = webdavlib.WebDAVDELETE(other_resource)
        client.execute(delete)

if __name__ == "__main__":
    sogotests.runTests()
