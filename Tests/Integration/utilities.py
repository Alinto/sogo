#!/usr/bin/python

import StringIO
import sys
import unittest
import vobject
import vobject.ics_diff
import webdavlib
import xml.sax.saxutils

class ics_compare():

    def __init__(self, event1, event2):
      self.event1 = event1
      self.event2 = event2
      self.diffs = None

    def _vcalendarComponent(self, event):
      event_component = None
      for item in vobject.readComponents(event):
        if item.name == "VCALENDAR":
          event_component = item
      return event_component

    def areEqual(self):
        s_event1 = StringIO.StringIO(self.event1)
        s_event2 = StringIO.StringIO(self.event2)

        event1_vcalendar = self._vcalendarComponent(s_event1)
        if event1_vcalendar is None:
            raise Exception("No VCALENDAR component in event1")

        event2_vcalendar = self._vcalendarComponent(s_event2)
        if event2_vcalendar is None:
            raise Exception("No VCALENDAR component in event2")

        self.diffs = vobject.ics_diff.diff(event1_vcalendar, event2_vcalendar)
        if not self.diffs:
            return True
        else:
            return False

    def textDiff(self):
        saved_stdout = sys.stdout
        out = StringIO.StringIO()
        sys.stdout = out
        try :
            if self.diffs is not None:
                for (left, right) in self.diffs:
                    left.prettyPrint()
                    right.prettyPrint()
        finally:
            sys.stdout = saved_stdout

        return out.getvalue().strip()


class TestUtility():
    def __init__(self, test, client, resource = None):
        self.test = test
        self.client = client
        self.userInfo = {}

    def fetchUserInfo(self, login):
        if not self.userInfo.has_key(login):
            resource = "/SOGo/dav/%s/" % login
            propfind = webdavlib.WebDAVPROPFIND(resource,
                                                ["displayname",
                                                 "{urn:ietf:params:xml:ns:caldav}calendar-user-address-set"],
                                                0)
            self.client.execute(propfind)
            self.test.assertEquals(propfind.response["status"], 207)
            common_tree = "{DAV:}response/{DAV:}propstat/{DAV:}prop"
            name_nodes = propfind.response["document"] \
                         .findall('%s/{DAV:}displayname' % common_tree)
            email_nodes = propfind.response["document"] \
                          .findall('%s/{urn:ietf:params:xml:ns:caldav}calendar-user-address-set/{DAV:}href'
                                   % common_tree)

            if len(name_nodes[0].text) > 0:
                displayName = name_nodes[0].text
            else:
                displayName = ""
            self.userInfo[login] = (displayName, email_nodes[0].text)

        return self.userInfo[login]

class TestACLUtility(TestUtility):
    def __init__(self, test, client, resource):
        TestUtility.__init__(self, test, client, resource)
        self.resource = resource

    def _subscriptionOperation(self, subscribers, operation):
        subscribeQuery = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                          + "<%s" % operation
                          + " xmlns=\"urn:inverse:params:xml:ns:inverse-dav\"")
        if (subscribers is not None):
            subscribeQuery = (subscribeQuery
                              + " users=\"%s\"" % ",".join(subscribers))
        subscribeQuery = subscribeQuery + "/>"
        post = webdavlib.HTTPPOST(self.resource, subscribeQuery)
        post.content_type = "application/xml; charset=\"utf-8\""
        self.client.execute(post)
        self.test.assertEquals(post.response["status"], 200,
                               "subscribtion failure to '%s' for '%s' (status: %d)"
                               % (self.resource, "', '".join(subscribers),
                                  post.response["status"]))

    def subscribe(self, subscribers=None):
        self._subscriptionOperation(subscribers, "subscribe")

    def unsubscribe(self, subscribers=None):
        self._subscriptionOperation(subscribers, "unsubscribe")

    def rightsToSOGoRights(self, rights):
        self.fail("subclass must implement this method")

    def setupRights(self, username, rights = None):
        if rights is not None:
            rights_str = "".join(["<%s/>"
                                  % x for x in self.rightsToSOGoRights(rights) ])
            aclQuery = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                        + "<acl-query"
                        + " xmlns=\"urn:inverse:params:xml:ns:inverse-dav\">"
                        + "<set-roles user=\"%s\">%s</set-roles>" % (xml.sax.saxutils.escape(username),
                                                                     rights_str)
                        + "</acl-query>")
        else:
            aclQuery = ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                        + "<acl-query"
                        + " xmlns=\"urn:inverse:params:xml:ns:inverse-dav\">"
                        + "<remove-user user=\"%s\"/>" % xml.sax.saxutils.escape(username)
                        + "</acl-query>")

        post = webdavlib.HTTPPOST(self.resource, aclQuery)
        post.content_type = "application/xml; charset=\"utf-8\""
        self.client.execute(post)

        if rights is None:
            err_msg = ("rights modification: failure to remove entry (status: %d)"
                       % post.response["status"])
        else:
            err_msg = ("rights modification: failure to set '%s' (status: %d)"
                       % (rights_str, post.response["status"]))
        self.test.assertEquals(post.response["status"], 204, err_msg)

# Calendar:
#   rights:
#     v: view all
#     d: view date and time
#     m: modify
#     r: respond
#   short rights notation: { "c": create,
#                            "d": delete,
#                            "pu": public,
#                            "pr": private,
#                            "co": confidential }
class TestCalendarACLUtility(TestACLUtility):
    def rightsToSOGoRights(self, rights):
        sogoRights = []
        if rights.has_key("c") and rights["c"]:
            sogoRights.append("ObjectCreator")
        if rights.has_key("d") and rights["d"]:
            sogoRights.append("ObjectEraser")

        classes = { "pu": "Public",
                    "pr": "Private",
                    "co": "Confidential" }
        rights_table = { "v": "Viewer",
                         "d": "DAndTViewer",
                         "m": "Modifier",
                         "r": "Responder" }
        for k in classes.keys():
            if rights.has_key(k):
                right = rights[k]
                sogo_right = "%s%s" % (classes[k], rights_table[right])
                sogoRights.append(sogo_right)

        return sogoRights

# Addressbook:
#   short rights notation: { "c": create,
#                            "d": delete,
#                            "e": edit,
#                            "v": view }
class TestAddressBookACLUtility(TestACLUtility):
    def rightsToSOGoRights(self, rights):
        sogoRightsTable = { "c": "ObjectCreator",
                            "d": "ObjectEraser",
                            "v": "ObjectViewer",
                            "e": "ObjectEditor" }

        sogoRights = []
        for k in rights.keys():
            sogoRights.append(sogoRightsTable[k])

        return sogoRights


