#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username, subscriber_password

import sys
import unittest
import webdavlib
import xml.xpath
import time

# TODO:
# - we don't test "respond" yet
# - addressbook acls
# ? testcase for "calendar-query"
# - test rights validity:
#   - send invalid rights to SOGo and expect failures
#   - refetch the set of rights and make sure it matches what was set
#     originally

# rights:
#   v: view all
#   d: view date and time
#   m: modify
#   r: respond
# short rights notation: { "c": create,
#                          "d": delete,
#                          "pu": public,
#                          "pr": private,
#                          "co": confidential }

resource = '/SOGo/dav/%s/Calendar/test-dav-acl/' % username

event_template = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Inverse//Event Generator//EN
BEGIN:VEVENT
SEQUENCE:0
TRANSP:OPAQUE
UID:12345-%(class)s-%(filename)s
SUMMARY:%(class)s event (orig. title)
DTSTART:20090805T100000Z
DTEND:20090805T140000Z
CLASS:%(class)s
DESCRIPTION:%(class)s description
LOCATION:location
CREATED:20090805T100000Z
DTSTAMP:20090805T100000Z
END:VEVENT
END:VCALENDAR"""

class DAVAclTest(unittest.TestCase):
    def setUp(self):
        self.classToICSClass = { "pu": "PUBLIC",
                                 "pr": "PRIVATE",
                                 "co": "CONFIDENTIAL" }
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        delete = webdavlib.WebDAVDELETE(resource)
        self.client.execute(delete)
        mkcol = webdavlib.WebDAVMKCOL(resource)
        self.client.execute(mkcol)
        self.assertEquals(mkcol.response["status"], 201,
                          "preparation: failure creating collection"
                          "(code = %d)" % mkcol.response["status"])
        self._putEvent(self.client, "public.ics", "PUBLIC")
        self._putEvent(self.client, "private.ics", "PRIVATE")
        self._putEvent(self.client, "confidential.ics", "CONFIDENTIAL")
        self.subscriber_client = webdavlib.WebDAVClient(hostname, port,
                                                        subscriber_username,
                                                        subscriber_password)

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(resource)
        self.client.execute(delete)

    def testViewAllPublic(self):
        """'view all' on a specific class (PUBLIC)"""
        self._testRights({ "pu": "v" })

    def testModifyPublicViewAllPrivateViewDConfidential(self):
        """'modify' PUBLIC, 'view all' PRIVATE, 'view d&t' confidential"""
        self._testRights({ "pu": "m", "pr": "v", "co": "d" })

    def testCreateOnly(self):
        """'create' only"""
        self._testRights({ "c": True })

    def testDeleteOnly(self):
        """'delete' only"""
        self._testRights({ "d": True })

    def testCreateDeleteModifyPublicViewAllPrivateViewDConfidential(self):
        """'create', 'delete', 'view d&t' PUBLIC, 'modify' PRIVATE"""
        self._testRights({ "c": True, "d": True, "pu": "d", "pr": "m" })

    def testNothing(self):
        """no right given"""
        self._testRights({})

    def _xpath_query(self, query, top_node):
        xpath_context = xml.xpath.CreateContext(top_node)
        xpath_context.setNamespaces({ "D": "DAV:",
                                      "C": "urn:ietf:params:xml:ns:caldav" })
        return xml.xpath.Evaluate(query, None, xpath_context)

    def _putEvent(self, client, filename,
                  event_class = "PUBLIC", exp_status = 201):
        url = "%s%s" % (resource, filename)
        event = event_template % { "class": event_class,
                                   "filename": filename }
        put = webdavlib.HTTPPUT(url, event, "text/calendar; charset=utf-8")
        client.execute(put)
        self.assertEquals(put.response["status"], exp_status,
                          "%s: event creation/modification:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, put.response["status"]))

    def _deleteEvent(self, client, filename, exp_status = 204):
        url = "%s%s" % (resource, filename)
        delete = webdavlib.WebDAVDELETE(url)
        client.execute(delete)
        self.assertEquals(delete.response["status"], exp_status,
                          "%s: event deletion: expected status code '%d'"
                          " (received '%d')"
                          % (filename, exp_status, delete.response["status"]))

    def _testRights(self, rights):
        self._setupRights(rights)
        self._testCreate(rights)
        self._testEventRight("pu", rights)
        self._testEventRight("pr", rights)
        self._testEventRight("co", rights)
        self._testDelete(rights)

    def _rightsToSOGoRights(self, rights):
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

    def _setupRights(self, rights):
        rights_str = "".join(["<%s/>" % x for x in self._rightsToSOGoRights(rights) ])
        aclQuery = """<acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
<set-roles user="%s">%s</set-roles>
</acl-query>""" % (subscriber_username, rights_str)

        post = webdavlib.HTTPPOST(resource, aclQuery, "application/xml")
        self.client.execute(post)
        self.assertEquals(post.response["status"], 204,
                          "rights modification: failure to set '%s' (status: %d)"
                          % (rights_str, post.response["status"]))

    def _testCreate(self, rights):
        if rights.has_key("c") and rights["c"]:
            exp_code = 201
        else:
            exp_code = 403
        self._putEvent(self.subscriber_client, "creation-test.ics", "PUBLIC",
                       exp_code)

    def _testDelete(self, rights):
        if rights.has_key("d") and rights["d"]:
            exp_code = 204
        else:
            exp_code = 403
        self._deleteEvent(self.subscriber_client, "public.ics", exp_code)
        self._deleteEvent(self.subscriber_client, "private.ics", exp_code)
        self._deleteEvent(self.subscriber_client, "confidential.ics",
                          exp_code)

    def _testEventRight(self, event_class, rights):
        if rights.has_key(event_class):
            right = rights[event_class]
        else:
            right = None

        event = self._getEvent(event_class)
        self._checkEventRight("GET", event, event_class, right)
        event = self._propfindEvent(event_class)
        self._checkEventRight("PROPFIND", event, event_class, right)
        event = self._multigetEvent(event_class)
        self._checkEventRight("multiget", event, event_class, right)
        event = self._webdavSyncEvent(event_class)
        self._checkEventRight("webdav-sync", event, event_class, right)

        self._testModify(event_class, right)

    def _getEvent(self, event_class):
        icsClass = self.classToICSClass[event_class]
        url = "%s%s.ics" % (resource, icsClass.lower())
        get = webdavlib.HTTPGET(url)
        self.subscriber_client.execute(get)

        if get.response["status"] == 200:
            event = get.response["body"]
        else:
            event = None

        return event

    def _calendarDataInMultistatus(self, top_node, filename,
                                   response_tag = "D:response"):
        event = None

        response_nodes = self._xpath_query("/D:multistatus/%s" % response_tag,
                                           top_node)
        for response_node in response_nodes:
            href_node = self._xpath_query("D:href", response_node)[0]
            href = href_node.childNodes[0].nodeValue
            if href.endswith(filename):
                propstat_nodes = self._xpath_query("D:propstat", response_node)
                for propstat_node in propstat_nodes:
                    status_node = self._xpath_query("D:status",
                                                    propstat_node)[0]
                    status = status_node.childNodes[0].nodeValue
                    data_nodes = self._xpath_query("D:prop/C:calendar-data",
                                                   propstat_node)
                    if status.endswith("200 OK"):
                        if (len(data_nodes) > 0
                            and len(data_nodes[0].childNodes) > 0):
                            event = data_nodes[0].childNodes[0].nodeValue
                    else:
                        if not (status.endswith("404 Resource Not Found")
                                or status.endswith("404 Not Found")):
                            self.fail("%s: unexpected status code: '%s'"
                                      % (filename, status))

        return event

    def _propfindEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        filename = "%s.ics" % icsClass.lower()
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                            1)
        self.subscriber_client.execute(propfind)
        if propfind.response["status"] != 403:
            event = self._calendarDataInMultistatus(propfind.response["document"],
                                                    filename)

        return event

    def _multigetEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s.ics" % (resource, icsClass.lower())
        multiget = webdavlib.WebDAVCalendarMultiget(resource,
                                                    ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                                    [ url ])
        self.subscriber_client.execute(multiget)
        if multiget.response["status"] != 403:
            event = self._calendarDataInMultistatus(multiget.response["document"],
                                                    url)

        return event

    def _webdavSyncEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s.ics" % (resource, icsClass.lower())
        sync_query = webdavlib.WebDAVSyncQuery(resource, None,
                                               ["{urn:ietf:params:xml:ns:caldav}calendar-data"])
        self.subscriber_client.execute(sync_query)
        if sync_query.response["status"] != 403:
            event = self._calendarDataInMultistatus(sync_query.response["document"],
                                                    url, "D:sync-response")

        return event

    def _checkEventRight(self, operation, event, event_class, right):
        if right is None:
            self.assertEquals(event, None,
                              "None right expecting event invisibility for"
                              " operation '%s'" % operation)
        else:
            self.assertTrue(event is not None,
                            "no event returned during operation '%s'"
                            " (right: %s)" % (operation, right))
            if right == "v" or right == "r" or right == "m":
                icsClass = self.classToICSClass[event_class]
                complete_event = (event_template % { "class": icsClass,
                                                     "filename": "%s.ics" % icsClass.lower() })
                self.assertTrue(event == complete_event,
                                "Right '%s' should return complete event"
                                " during operation '%s'"
                                % (right, operation))
            elif right == "d":
                self._testEventIsSecureVersion(event_class, event)
            else:
                self.fail("Right '%s' is not supported" % right)

    def _testEventIsSecureVersion(self, event_class, event):
        icsClass = self.classToICSClass[event_class]
        expected_dict = { "VERSION": "2.0",
                          "PRODID": "-//Inverse//Event Generator//EN",
                          "SEQUENCE": "0",
                          "TRANSP": "OPAQUE",
                          "UID": "12345-%s-%s.ics" % (icsClass,
                                                      icsClass.lower()),
                          "SUMMARY": "(%s event)" % icsClass.capitalize(),
                          "DTSTART": "20090805T100000Z",
                          "DTEND": "20090805T140000Z",
                          "CLASS": icsClass,
                          "CREATED": "20090805T100000Z",
                          "DTSTAMP": "20090805T100000Z",
                          "X-SOGO-SECURE": "YES" }
        event_dict = self._versitDict(event)
        for key in event_dict.keys():
            self.assertTrue(expected_dict.has_key(key),
                            "key '%s' of secure event not expected" % key)
            self.assertTrue(expected_dict[key] == event_dict[key],
                            "value for key '%s' of secure does not match"
                            " (exp: '%s', obtained: '%s'"
                            % (key, expected_dict[key], event_dict[key] ))

        for key in expected_dict.keys():
            self.assertTrue(event_dict.has_key(key),
                            "expected key '%s' not found in secure event"
                            % key)

    def _versitLine(self, line):
        key, value = line.split(":")
        semicolon = key.find(";")
        if semicolon > -1:
            key = key[:semicolon]

        return (key, value)

    def _versitDict(self, event):
        versitDict = {}
        for line in event.splitlines():
            (key, value) = self._versitLine(line)
            if not (key == "BEGIN" or key == "END"):
                versitDict[key] = value

        return versitDict

    def _testModify(self, event_class, right):
        if right == "m":
            exp_code = 204
        else:
            exp_code = 403
        icsClass = self.classToICSClass[event_class]
        filename = "%s.ics" % icsClass.lower()
        self._putEvent(self.subscriber_client, filename, icsClass,
                       exp_code)

if __name__ == "__main__":
    unittest.main()
