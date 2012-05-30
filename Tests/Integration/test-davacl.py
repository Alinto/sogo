#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username, subscriber_password, \
		   superuser, superuser_password

import sys
import unittest
import webdavlib
import time

import sogotests
import utilities

# TODO:
# - cal: complete test for "modify": "respond to" causes a 204 but no actual
#        modification should occur
# - ab: testcase for addressbook-query, webdav-sync (no "calendar-data"
#       equivalent)
# - cal: testcase for "calendar-query"
# - test rights validity:
#   - send invalid rights to SOGo and expect failures
#   - refetch the set of rights and make sure it matches what was set
#     originally
#   - test "current-user-acl-set"

class DAVCalendarSuperUserAclTest(unittest.TestCase):
    def __init__(self, arg):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             superuser, superuser_password)
        self.resource = "/SOGo/dav/%s/Calendar/test-dav-superuser-acl/" % subscriber_username
        self.filename = "suevent.ics"
        self.url = "%s%s" % (self.resource, self.filename)

        unittest.TestCase.__init__(self, arg)
        
    def setUp(self):
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)
        mkcol = webdavlib.WebDAVMKCOL(self.resource)
        self.client.execute(mkcol)
        self.assertEquals(mkcol.response["status"], 201,
                          "preparation: failure creating collection"
                          "(code = %d)" % mkcol.response["status"])

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)

    def _getEvent(self):
        get = webdavlib.HTTPGET(self.url)
        self.client.execute(get)

        if get.response["status"] == 200:
            event = get.response["body"]
        else:
            event = None

        return event

    def _calendarDataInMultistatus(self, query, response_tag = "{DAV:}response"):
        event = None

        # print "\n\n\n%s\n\n" % query.response["body"]
        # print "\n\n"
        response_nodes = query.response["document"].findall(response_tag)
        for response_node in response_nodes:
            href_node = response_node.find("{DAV:}href")
            href = href_node.text
            if href.endswith(self.filename):
                propstat_node = response_node.find("{DAV:}propstat")
                if propstat_node is not None:
                    status_node = propstat_node.find("{DAV:}status")
                    status = status_node.text
                    if status.endswith("200 OK"):
                        data_node = propstat_node.find("{DAV:}prop/{urn:ietf:params:xml:ns:caldav}calendar-data")
                        event = data_node.text
                    elif not (status.endswith("404 Resource Not Found")
                              or status.endswith("404 Not Found")):
                        self.fail("%s: unexpected status code: '%s'"
                                  % (self.filename, status))

        return event

    def _propfindEvent(self):
        propfind = webdavlib.WebDAVPROPFIND(self.resource,
                                            ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                            1)
        self.client.execute(propfind)
        if propfind.response["status"] != 404:
            event = self._calendarDataInMultistatus(propfind)

        return event
    
    def _multigetEvent(self):
        event = None

        multiget = webdavlib.CalDAVCalendarMultiget(self.resource,
                                                    ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                                    [ self.url ])
        self.client.execute(multiget)
        if multiget.response["status"] != 404:
            event = self._calendarDataInMultistatus(multiget)

        return event

    def _webdavSyncEvent(self):
        event = None

        sync_query = webdavlib.WebDAVSyncQuery(self.resource, None,
                                               ["{urn:ietf:params:xml:ns:caldav}calendar-data"])
        self.client.execute(sync_query)
        if sync_query.response["status"] != 404:
            event = self._calendarDataInMultistatus(sync_query, "{DAV:}sync-response")

        return event

    def testSUAccess(self):
        """create, read, modify, delete for superuser"""
        event = event_template % { "class": "PUBLIC",
                                   "filename": self.filename,
                                   "organizer_line": "",
                                   "attendee_line": "" }

        # 1. Create
        put = webdavlib.HTTPPUT(self.url, event)
        put.content_type = "text/calendar; charset=utf-8"
        self.client.execute(put)
        self.assertEquals(put.response["status"], 201,
                          "%s: event creation/modification:"
                          " expected status code '201' (received '%d')"
                          % (self.filename, put.response["status"]))

        # 2. Read
        readEvent = self._getEvent()
        self.assertEquals(readEvent, event,
                          "GET: returned event does not match")
        readEvent = self._propfindEvent()
        self.assertEquals(readEvent, event,
                          "PROPFIND: returned event does not match")
        readEvent = self._multigetEvent()
        self.assertEquals(readEvent, event,
                          "MULTIGET: returned event does not match")
        readEvent = self._webdavSyncEvent()
        self.assertEquals(readEvent, event,
                          "WEBDAV-SYNC: returned event does not match")
        
        # 3. Modify
        for eventClass in [ "CONFIDENTIAL", "PRIVATE", "PUBLIC" ]:
            event = event_template % { "class": eventClass,
                                       "filename": self.filename,
                                       "organizer_line": "",
                                       "attendee_line": "" }
            put = webdavlib.HTTPPUT(self.url, event)
            put.content_type = "text/calendar; charset=utf-8"
            self.client.execute(put)
            self.assertEquals(put.response["status"], 204,
                              "%s: event modification failed"
                              " expected status code '204' (received '%d')"
                              % (self.filename, put.response["status"]))
        
        # 4. Delete
        delete = webdavlib.WebDAVDELETE(self.url)
        self.client.execute(delete)
        self.assertEquals(delete.response["status"], 204,
                          "%s: event deletion failed"
                          " expected status code '204' (received '%d')"
                          % (self.filename, put.response["status"]))

class DAVAclTest(unittest.TestCase):
    resource = None

    def __init__(self, arg):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        unittest.TestCase.__init__(self, arg)

    def setUp(self):
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)
        mkcol = webdavlib.WebDAVMKCOL(self.resource)
        self.client.execute(mkcol)
        self.assertEquals(mkcol.response["status"], 201,
                          "preparation: failure creating collection"
                          "(code = %d)" % mkcol.response["status"])
        self.subscriber_client = webdavlib.WebDAVClient(hostname, port,
                                                        subscriber_username,
                                                        subscriber_password)

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(self.resource)
        self.client.execute(delete)

    def _versitLine(self, line):
        key, value = line.split(":")
        semicolon = key.find(";")
        if semicolon > -1:
            key = key[:semicolon]

        return (key, value)

    def versitDict(self, event):
        versitStruct = {}
        for line in event.splitlines():
            (key, value) = self._versitLine(line)
            if not (key == "BEGIN" or key == "END"):
                versitStruct[key] = value

        return versitStruct

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
%(organizer_line)s%(attendee_line)sCREATED:20090805T100000Z
DTSTAMP:20090805T100000Z
END:VEVENT
END:VCALENDAR"""

task_template = """BEGIN:VCALENDAR
PRODID:-//Inverse//Event Generator//EN
VERSION:2.0
BEGIN:VTODO
CREATED:20100122T201440Z
LAST-MODIFIED:20100201T175246Z
DTSTAMP:20100201T175246Z
UID:12345-%(class)s-%(filename)s
SUMMARY:%(class)s event (orig. title)
CLASS:%(class)s
DESCRIPTION:%(class)s description
STATUS:IN-PROCESS
PERCENT-COMPLETE:0
END:VTODO
END:VCALENDAR"""

class DAVCalendarAclTest(DAVAclTest):
    resource = '/SOGo/dav/%s/Calendar/test-dav-acl/' % username
    user_email = None

    def __init__(self, arg):
        DAVAclTest.__init__(self, arg)
        self.acl_utility = utilities.TestCalendarACLUtility(self,
                                                            self.client,
                                                            self.resource)

    def setUp(self):
        DAVAclTest.setUp(self)
        self.user_email = self.acl_utility.fetchUserInfo(username)[1]
        self.classToICSClass = { "pu": "PUBLIC",
                                 "pr": "PRIVATE",
                                 "co": "CONFIDENTIAL" }
        self._putEvent(self.client, "public-event.ics", "PUBLIC")
        self._putEvent(self.client, "private-event.ics", "PRIVATE")
        self._putEvent(self.client, "confidential-event.ics", "CONFIDENTIAL")
        self._putTask(self.client, "public-task.ics", "PUBLIC")
        self._putTask(self.client, "private-task.ics", "PRIVATE")
        self._putTask(self.client, "confidential-task.ics", "CONFIDENTIAL")

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

    def testCreateRespondToPublic(self):
        """'create', 'respond to' PUBLIC"""
        self._testRights({ "c": True, "pu": "r" })

    def testNothing(self):
        """no right given"""
        self._testRights({})

    def _putEvent(self, client, filename,
                  event_class = "PUBLIC",
                  exp_status = 201,
                  organizer = None, attendee = None,
                  partstat = "NEEDS-ACTION"):
        url = "%s%s" % (self.resource, filename)
        if organizer is not None:
            organizer_line = "ORGANIZER:%s\n" % organizer
        else:
            organizer_line = ""
        if attendee is not None:
            attendee_line = "ATTENDEE;PARTSTAT=%s:%s\n" % (partstat, attendee)
        else:
            attendee_line = ""
        event = event_template % { "class": event_class,
                                   "filename": filename,
                                   "organizer_line": organizer_line,
                                   "attendee_line": attendee_line }
        put = webdavlib.HTTPPUT(url, event)
        put.content_type = "text/calendar; charset=utf-8"
        client.execute(put)
        self.assertEquals(put.response["status"], exp_status,
                          "%s: event creation/modification:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, put.response["status"]))

    def _putTask(self, client, filename,
                 task_class = "PUBLIC",
                 exp_status = 201):
        url = "%s%s" % (self.resource, filename)
        task = task_template % { "class": task_class,
                                 "filename": filename }
        put = webdavlib.HTTPPUT(url, task)
        put.content_type = "text/calendar; charset=utf-8"
        client.execute(put)
        self.assertEquals(put.response["status"], exp_status,
                          "%s: task creation/modification:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, put.response["status"]))

    def _deleteEvent(self, client, filename, exp_status = 204):
        url = "%s%s" % (self.resource, filename)
        delete = webdavlib.WebDAVDELETE(url)
        client.execute(delete)
        self.assertEquals(delete.response["status"], exp_status,
                          "%s: event deletion: expected status code '%d'"
                          " (received '%d')"
                          % (filename, exp_status, delete.response["status"]))

    def _currentUserPrivilegeSet(self, resource, expStatus = 207):
        propfind = webdavlib.WebDAVPROPFIND(resource,
                                            ["{DAV:}current-user-privilege-set"],
                                            0)
        self.subscriber_client.execute(propfind)
        self.assertEquals(propfind.response["status"], expStatus,
                          "unexected status code when reading privileges:"
                          + " %s instead of %d"
                          % (propfind.response["status"], expStatus))

        privileges = []
        if expStatus < 300:
            response_nodes = propfind.response["document"].findall("{DAV:}response/{DAV:}propstat/{DAV:}prop/{DAV:}current-user-privilege-set/{DAV:}privilege")
            for node in response_nodes:
                privileges.extend([x.tag for x in node.getchildren()])

        return privileges

    def _comparePrivilegeSets(self, expectedPrivileges, privileges):
        testHash = dict(map(lambda x: (x, True), privileges))
        for privilege in expectedPrivileges:
            self.assertTrue(testHash.has_key(privilege),
                            "expected privilege '%s' not found" % privilege)
        testHash = dict(map(lambda x: (x, True), expectedPrivileges))
        for privilege in privileges:
            self.assertTrue(testHash.has_key(privilege),
                            "excessive privilege '%s' found" % privilege)

    def _testCollectionDAVAcl(self, rights):
        if len(rights) > 0:
            expectedPrivileges = ['{DAV:}read',
                                  '{DAV:}read-current-user-privilege-set',
                                  '{urn:ietf:params:xml:ns:caldav}read-free-busy']
        else:
            expectedPrivileges = []
        if rights.has_key("c"):
            extraPrivileges = ["{DAV:}bind",
                               "{DAV:}write-content",
                               '{urn:ietf:params:xml:ns:caldav}schedule',
                               '{urn:ietf:params:xml:ns:caldav}schedule-post',
                               '{urn:ietf:params:xml:ns:caldav}schedule-post-vevent',
                               '{urn:ietf:params:xml:ns:caldav}schedule-post-vtodo',
                               '{urn:ietf:params:xml:ns:caldav}schedule-post-vjournal',
                               '{urn:ietf:params:xml:ns:caldav}schedule-post-vfreebusy',
                               '{urn:ietf:params:xml:ns:caldav}schedule-deliver',
                               '{urn:ietf:params:xml:ns:caldav}schedule-deliver-vevent',
                               '{urn:ietf:params:xml:ns:caldav}schedule-deliver-vtodo',
                               '{urn:ietf:params:xml:ns:caldav}schedule-deliver-vjournal',
                               '{urn:ietf:params:xml:ns:caldav}schedule-deliver-vfreebusy',
                               '{urn:ietf:params:xml:ns:caldav}schedule-respond',
                               '{urn:ietf:params:xml:ns:caldav}schedule-respond-vevent',
                               '{urn:ietf:params:xml:ns:caldav}schedule-respond-vtodo']
            expectedPrivileges.extend(extraPrivileges)
        if rights.has_key("d"):
            expectedPrivileges.append("{DAV:}unbind")
        if len(expectedPrivileges) == 0:
            expStatus = 404
        else:
            expStatus = 207
        privileges = self._currentUserPrivilegeSet(self.resource, expStatus)
        self._comparePrivilegeSets(expectedPrivileges, privileges)

    def _testEventDAVAcl(self, event_class, right, error_code):
        icsClass = self.classToICSClass[event_class].lower()
        for suffix in [ "event", "task" ]:
            url = "%s%s-%s.ics" % (self.resource, icsClass, suffix)

            if right is None:
                expStatus = error_code
                expectedPrivileges = None
            else:
                expStatus = 207
                expectedPrivileges = ['{DAV:}read-current-user-privilege-set',
                                      '{urn:inverse:params:xml:ns:inverse-dav}view-date-and-time',
                                      '{DAV:}read']
                if right != "d":
                    extraPrivilege = '{urn:inverse:params:xml:ns:inverse-dav}view-whole-component'
                    expectedPrivileges.append(extraPrivilege)
                    if right != "v":
                        extraPrivileges = ['{urn:inverse:params:xml:ns:inverse-dav}respond-to-component',
                                           '{DAV:}write-content']
                        expectedPrivileges.extend(extraPrivileges)
                        if right != "r":
                            extraPrivileges = ['{DAV:}write-properties',
                                               '{DAV:}write']
                            expectedPrivileges.extend(extraPrivileges)

            privileges = self._currentUserPrivilegeSet(url, expStatus)
            if expStatus != error_code:
                self._comparePrivilegeSets(expectedPrivileges, privileges)

    def _testRights(self, rights):
        self.acl_utility.setupRights(subscriber_username, rights)
        self._testCreate(rights)
        self._testCollectionDAVAcl(rights)
        self._testEventRight("pu", rights)
        self._testEventRight("pr", rights)
        self._testEventRight("co", rights)
        self._testDelete(rights)

    def _testCreate(self, rights):
        if rights.has_key("c") and rights["c"]:
            exp_code = 201
        elif len(rights) == 0:
            exp_code = 404
        else:
            exp_code = 403
        self._putEvent(self.subscriber_client, "creation-test.ics", "PUBLIC",
                       exp_code)

    def _testDelete(self, rights):
        if rights.has_key("d") and rights["d"]:
            exp_code = 204
        elif len(rights) == 0:
            exp_code = 404
        else:
            exp_code = 403
        self._deleteEvent(self.subscriber_client, "public-event.ics",
                          exp_code)
        self._deleteEvent(self.subscriber_client, "private-event.ics",
                          exp_code)
        self._deleteEvent(self.subscriber_client, "confidential-event.ics",
                          exp_code)

    def _testEventRight(self, event_class, rights):
        if rights.has_key(event_class):
            right = rights[event_class]
        else:
            right = None

        event = self._getEvent(event_class)
        self._checkViewEventRight("GET", event, event_class, right)
        event = self._propfindEvent(event_class)
        self._checkViewEventRight("PROPFIND", event, event_class, right)
        event = self._multigetEvent(event_class)
        self._checkViewEventRight("multiget", event, event_class, right)
        event = self._webdavSyncEvent(event_class)
        self._checkViewEventRight("webdav-sync", event, event_class, right)

        if len(rights) > 0:
            error_code = 403
        else:
            error_code = 404
        self._testModify(event_class, right, error_code)
        self._testRespondTo(event_class, right, error_code)
        self._testEventDAVAcl(event_class, right, error_code)

    def _getEvent(self, event_class, is_invitation = False):
        icsClass = self.classToICSClass[event_class]
        if is_invitation:
            filename = "invitation-%s" % icsClass.lower()
        else:
            filename = "%s" % icsClass.lower()
        url = "%s%s-event.ics" % (self.resource, filename)
        get = webdavlib.HTTPGET(url)
        self.subscriber_client.execute(get)

        if get.response["status"] == 200:
            event = get.response["body"]
        else:
            event = None

        return event

    def _getTask(self, task_class):
        filename = "%s" % self.classToICSClass[task_class].lower()
        url = "%s%s-task.ics" % (self.resource, filename)
        get = webdavlib.HTTPGET(url)
        self.subscriber_client.execute(get)

        if get.response["status"] == 200:
            task = get.response["body"]
        else:
            task = None

        return task

    def _calendarDataInMultistatus(self, query, filename,
                                   response_tag = "{DAV:}response"):
        event = None

        # print "\n\n\n%s\n\n" % query.response["body"]
        # print "\n\n"
        response_nodes = query.response["document"].findall("%s" % response_tag)
        for response_node in response_nodes:
            href_node = response_node.find("{DAV:}href")
            href = href_node.text
            if href.endswith(filename):
                propstat_node = response_node.find("{DAV:}propstat")
                if propstat_node is not None:
                    status_node = propstat_node.find("{DAV:}status")
                    status = status_node.text
                    if status.endswith("200 OK"):
                        data_node = propstat_node.find("{DAV:}prop/{urn:ietf:params:xml:ns:caldav}calendar-data")
                        event = data_node.text
                    elif not (status.endswith("404 Resource Not Found")
                              or status.endswith("404 Not Found")):
                        self.fail("%s: unexpected status code: '%s'"
                                  % (filename, status))

        return event

    def _propfindEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        filename = "%s-event.ics" % icsClass.lower()
        propfind = webdavlib.WebDAVPROPFIND(self.resource,
                                            ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                            1)
        self.subscriber_client.execute(propfind)
        if propfind.response["status"] != 404:
            event = self._calendarDataInMultistatus(propfind, filename)

        return event
    
    def _multigetEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s-event.ics" % (self.resource, icsClass.lower())
        multiget = webdavlib.CalDAVCalendarMultiget(self.resource,
                                                    ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                                    [ url ])
        self.subscriber_client.execute(multiget)
        if multiget.response["status"] != 404:
            event = self._calendarDataInMultistatus(multiget, url)

        return event

    def _webdavSyncEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s-event.ics" % (self.resource, icsClass.lower())
        sync_query = webdavlib.WebDAVSyncQuery(self.resource, None,
                                               ["{urn:ietf:params:xml:ns:caldav}calendar-data"])
        self.subscriber_client.execute(sync_query)
        if sync_query.response["status"] != 404:
            event = self._calendarDataInMultistatus(sync_query, url,
                                                    "{DAV:}sync-response")

        return event

    def _checkViewEventRight(self, operation, event, event_class, right):
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
                                                     "filename": "%s-event.ics" % icsClass.lower(),
                                                     "organizer_line": "",
                                                     "attendee_line": ""})
                self.assertTrue(event.strip() == complete_event.strip(),
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
                          "UID": "12345-%s-%s-event.ics" % (icsClass,
                                                      icsClass.lower()),
                          "SUMMARY": "(%s event)" % icsClass.capitalize(),
                          "DTSTART": "20090805T100000Z",
                          "DTEND": "20090805T140000Z",
                          "CLASS": icsClass,
                          "CREATED": "20090805T100000Z",
                          "DTSTAMP": "20090805T100000Z",
                          "X-SOGO-SECURE": "YES" }
        event_dict = self.versitDict(event)
        for key in event_dict.keys():
            self.assertTrue(expected_dict.has_key(key),
                            "key '%s' of secure event not expected" % key)
            self.assertTrue(expected_dict[key] == event_dict[key]
                            or key == "SUMMARY",
                            "value for key '%s' of secure does not match"
                            " (exp: '%s', obtained: '%s'"
                            % (key, expected_dict[key], event_dict[key] ))

        for key in expected_dict.keys():
            self.assertTrue(event_dict.has_key(key),
                            "expected key '%s' not found in secure event"
                            % key)

    def _testModify(self, event_class, right, error_code):
        if right == "m" or right == "r":
            exp_code = 204
        else:
            exp_code = error_code
        icsClass = self.classToICSClass[event_class]
        filename = "%s-event.ics" % icsClass.lower()
        self._putEvent(self.subscriber_client, filename, icsClass,
                       exp_code)

    def _testRespondTo(self, event_class, right, error_code):
        icsClass = self.classToICSClass[event_class]
        filename = "invitation-%s-event.ics" % icsClass.lower()
        self._putEvent(self.client, filename, icsClass,
                       201,
                       "mailto:nobody@somewhere.com", self.user_email,
                       "NEEDS-ACTION")

        if right == "m" or right == "r":
            exp_code = 204
        else:
            exp_code = error_code

        # here we only do 'passive' validation: if a user has a "respond to"
        # right, only the attendee entry will me modified. The change of
        # organizer must thus be silently ignored below.
        self._putEvent(self.subscriber_client, filename, icsClass,
                       exp_code, "mailto:someone@nowhere.com", self.user_email,
                       "ACCEPTED")
        if exp_code == 204:
            att_line = "ATTENDEE;PARTSTAT=ACCEPTED:%s\n" % self.user_email
            if right == "r":
                exp_event = event_template % {"class": icsClass,
                                              "filename": filename,
                                              "organizer_line": "ORGANIZER:mailto:nobody@somewhere.com\n",
                                              "attendee_line": att_line}
            else:
                exp_event = event_template % {"class": icsClass,
                                              "filename": filename,
                                              "organizer_line": "ORGANIZER:mailto:someone@nowhere.com\n",
                                              "attendee_line": att_line}
            event = self._getEvent(event_class, True).replace("\r", "")
            self.assertEquals(exp_event.strip(), event.strip(),
                              "'respond to' event does not match:\nreceived:\n"
                              "/%s/\nexpected:\n/%s/" % (event, exp_event))

class DAVAddressBookAclTest(DAVAclTest):
    resource = '/SOGo/dav/%s/Contacts/test-dav-acl/' % username
    cards = { "new.vcf": """BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:New;Carte
FN:Carte 'new'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD""",
              "old.vcf": """BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:Old;Carte
FN:Carte 'old'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD""",
              "new-modified.vcf": """BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:New;Carte modifiee
FN:Carte modifiee 'new'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD""",
              "old-modified.vcf": """BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:Old;Carte modifiee
FN:Carte modifiee 'old'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD""" }

    def __init__(self, arg):
        DAVAclTest.__init__(self, arg)
        self.acl_utility = utilities.TestAddressBookACLUtility(self,
                                                               self.client,
                                                               self.resource)

    def setUp(self):
        DAVAclTest.setUp(self)
        self._putCard(self.client, "old.vcf", 201)

    def testView(self):
        """'view' only"""
        self._testRights({ "v": True })

    def testEdit(self):
        """'edit' only"""
        self._testRights({ "e": True })

    def testCreateOnly(self):
        """'create' only"""
        self._testRights({ "c": True })

    def testDeleteOnly(self):
        """'delete' only"""
        self._testRights({ "d": True })

    def testCreateDelete(self):
        """'create', 'delete'"""
        self._testRights({ "c": True, "d": True })

    def testViewCreate(self):
        """'view' and 'create'"""
        self._testRights({ "c": True, "v": True })

    def testViewDelete(self):
        """'view' and 'delete'"""
        self._testRights({ "d": True, "v": True })

    def testEditCreate(self):
        """'edit' and 'create'"""
        self._testRights({ "c": True, "e": True })

    def testEditDelete(self):
        """'edit' and 'delete'"""
        self._testRights({ "d": True, "e": True })

    def _testRights(self, rights):
        self.acl_utility.setupRights(subscriber_username, rights)
        self._testCreate(rights)
        self._testView(rights)
        self._testEdit(rights)
        self._testDelete(rights)

    def _putCard(self, client, filename, exp_status, real_card = None):
        url = "%s%s" % (self.resource, filename)
        if real_card is None:
            real_card = filename
        card = self.cards[real_card]
        put = webdavlib.HTTPPUT(url, card)
        put.content_type = "text/x-vcard; charset=utf-8"
        client.execute(put)
        self.assertEquals(put.response["status"], exp_status,
                          "%s: card creation/modification:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, put.response["status"]))

    def _getCard(self, client, filename, exp_status):
        url = "%s%s" % (self.resource, filename)
        get = webdavlib.HTTPGET(url)
        client.execute(get)
        self.assertEquals(get.response["status"], exp_status,
                          "%s: card get:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, get.response["status"]))

    def _deleteCard(self, client, filename, exp_status):
        url = "%s%s" % (self.resource, filename)
        delete = webdavlib.WebDAVDELETE(url)
        client.execute(delete)
        self.assertEquals(delete.response["status"], exp_status,
                          "%s: card deletion:"
                          " expected status code '%d' (received '%d')"
                          % (filename, exp_status, delete.response["status"]))

    def _testCreate(self, rights):
        if rights.has_key("c") and rights["c"]:
            exp_code = 201
        else:
            exp_code = 403
        self._putCard(self.subscriber_client, "new.vcf", exp_code)

    def _testView(self, rights):
        if ((rights.has_key("v") and rights["v"])
            or (rights.has_key("e") and rights["e"])):
            exp_code = 200
        else:
            exp_code = 403
        self._getCard(self.subscriber_client, "old.vcf", exp_code)

    def _testEdit(self, rights):
        if rights.has_key("e") and rights["e"]:
            exp_code = 204
        else:
            exp_code = 403
        self._putCard(self.subscriber_client, "old.vcf", exp_code, "old-modified.vcf")

    def _testDelete(self, rights):
        if rights.has_key("d") and rights["d"]:
            exp_code = 204
        else:
            exp_code = 403
        self._deleteCard(self.subscriber_client, "old.vcf", exp_code)

class DAVPublicAccessTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port)
        self.anon_client = webdavlib.WebDAVClient(hostname, port)
        self.dav_utility = utilities.TestUtility(self, self.client)

    def testPublicAccess(self):
        resource = '/SOGo/so/public'
        options = webdavlib.HTTPOPTIONS(resource)
        self.anon_client.execute(options)
        self.assertEquals(options.response["status"], 404,
                          "/SOGo/so/public is unexpectedly available")

        resource = '/SOGo/public'
        options = webdavlib.HTTPOPTIONS(resource)
        self.anon_client.execute(options)
        self.assertEquals(options.response["status"], 404,
                          "/SOGo/public is unexpectedly available")

        resource = '/SOGo/dav/%s' % username
        options = webdavlib.HTTPOPTIONS(resource)
        self.anon_client.execute(options)
        self.assertEquals(options.response["status"], 401,
                          "Non-public resources should request authentication")

        resource = '/SOGo/dav/public'
        options = webdavlib.HTTPOPTIONS(resource)
        self.anon_client.execute(options)
        self.assertNotEquals(options.response["status"], 401,
                             "Non-public resources must NOT request authentication")
        self.assertEquals(options.response["status"], 200,
                          "/SOGo/dav/public is not available, check user defaults")


class DAVCalendarPublicAclTest(unittest.TestCase):
    def setUp(self):
        self.createdRsrc = None
        self.superuser_client = webdavlib.WebDAVClient(hostname, port,
                                             superuser, superuser_password)
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        self.subscriber_client = webdavlib.WebDAVClient(hostname, port,
                                                        subscriber_username,
                                                        subscriber_password)
        self.anon_client = webdavlib.WebDAVClient(hostname, port)

    def tearDown(self):
        if self.createdRsrc is not None:
            delete = webdavlib.WebDAVDELETE(self.createdRsrc)
            self.superuser_client.execute(delete)

    def testCollectionAccessNormalUser(self):
        """normal user access to (non-)shared resource from su"""

        # 1. all rights removed
        parentColl = '/SOGo/dav/%s/Calendar/' % username
        self.createdRsrc = '%stest-dav-acl/' % parentColl
        for rsrc in [ 'personal', 'test-dav-acl' ]:
            resource = '%s%s/' % (parentColl, rsrc)
            mkcol = webdavlib.WebDAVMKCOL(resource)
            self.client.execute(mkcol)
            acl_utility = utilities.TestCalendarACLUtility(self,
                                                           self.client,
                                                           resource)
            acl_utility.setupRights("anonymous", {})
            acl_utility.setupRights(subscriber_username, {})
            acl_utility.setupRights("<default>", {})

        propfind = webdavlib.WebDAVPROPFIND(parentColl, [ "displayname" ], 1)
        self.subscriber_client.execute(propfind)
        hrefs = propfind.response["document"] \
                .findall("{DAV:}response/{DAV:}href")

        self.assertEquals(len(hrefs), 1,
                          "expected 1 href in response instead of %d" % len(hrefs))
        self.assertEquals(hrefs[0].text, parentColl,
                          "the href must be the 'Calendar' parent coll.")

        acl_utility = utilities.TestCalendarACLUtility(self,
                                                       self.client,
                                                       self.createdRsrc)

        # 2. creation right added
        acl_utility.setupRights(subscriber_username, { "c": True })

        self.subscriber_client.execute(propfind)
        hrefs = propfind.response["document"].findall("{DAV:}response/{DAV:}href")
        self.assertEquals(len(hrefs), 4,
                          "expected 4 hrefs in response, got %d: %s"
                          % (len(hrefs), ", ".join([ x.text for x in hrefs ])))
        self.assertEquals(hrefs[0].text, parentColl,
                          "the first href is not a 'Calendar' parent coll.")

        resourceHrefs = { resource: False,
                          "%s.xml" % resource[:-1]: False,
                          "%s.ics" % resource[:-1]: False }
        for href in hrefs[1:]:
            self.assertTrue(resourceHrefs.has_key(href.text),
                            "received unexpected href: %s" % href.text)
            self.assertFalse(resourceHrefs[href.text],
                            "href was returned more than once: %s" % href.text)
            resourceHrefs[href.text] = True

        acl_utility.setupRights(subscriber_username)

        # 3. creation right added for "default user"
        #    subscriber_username expected to have access, but not "anonymous"
        acl_utility.setupRights("<default>", { "c": True })
        
        self.subscriber_client.execute(propfind)
        hrefs = propfind.response["document"] \
                .findall("{DAV:}response/{DAV:}href")

        self.assertEquals(len(hrefs), 4,
                          "expected 4 hrefs in response, got %d: %s"
                          % (len(hrefs), ", ".join([ x.text for x in hrefs ])))
        self.assertEquals(hrefs[0].text, parentColl,
                          "the first href is not a 'Calendar' parent coll.")
        resourceHrefs = { resource: False,
                          "%s.xml" % resource[:-1]: False,
                          "%s.ics" % resource[:-1]: False }
        for href in hrefs[1:]:
            self.assertTrue(resourceHrefs.has_key(href.text),
                            "received unexpected href: %s" % href.text)
            self.assertFalse(resourceHrefs[href.text],
                            "href was returned more than once: %s" % href.text)
            resourceHrefs[href.text] = True

        anonParentColl = '/SOGo/dav/public/%s/Calendar/' % username
        anon_propfind = webdavlib.WebDAVPROPFIND(anonParentColl,
                                                 [ "displayname" ], 1)

        self.anon_client.execute(anon_propfind)
        hrefs = anon_propfind.response["document"] \
                .findall("{DAV:}response/{DAV:}href")
        self.assertEquals(len(hrefs), 1, "expected only 1 href in response")
        self.assertEquals(hrefs[0].text, anonParentColl,
                          "the first href is not a 'Calendar' parent coll.")

        acl_utility.setupRights("<default>", {})

        # 4. creation right added for "anonymous"
        #    "anonymous" expected to have access, but not subscriber_username
        acl_utility.setupRights("anonymous", { "c": True })

        self.anon_client.execute(anon_propfind)
        hrefs = anon_propfind.response["document"] \
                .findall("{DAV:}response/{DAV:}href")


        self.assertEquals(len(hrefs), 4,
                          "expected 4 hrefs in response, got %d: %s"
                          % (len(hrefs), ", ".join([ x.text for x in hrefs ])))
        self.assertEquals(hrefs[0].text, anonParentColl,
                          "the first href is not a 'Calendar' parent coll.")
        anonResource = '%stest-dav-acl/' % anonParentColl
        resourceHrefs = { anonResource: False,
                          "%s.xml" % anonResource[:-1]: False,
                          "%s.ics" % anonResource[:-1]: False }
        for href in hrefs[1:]:
            self.assertTrue(resourceHrefs.has_key(href.text),
                            "received unexpected href: %s" % href.text)
            self.assertFalse(resourceHrefs[href.text],
                            "href was returned more than once: %s" % href.text)
            resourceHrefs[href.text] = True

        self.subscriber_client.execute(propfind)
        hrefs = propfind.response["document"] \
                .findall("{DAV:}response/{DAV:}href")
        self.assertEquals(len(hrefs), 1, "expected only 1 href in response")
        self.assertEquals(hrefs[0].text, parentColl,
                          "the first href is not a 'Calendar' parent coll.")

    def testCollectionAccessSuperUser(self):
        # super user accessing (non-)shared res from nu

        parentColl = '/SOGo/dav/%s/Calendar/' % subscriber_username
        self.createdRsrc = '%stest-dav-acl/' % parentColl
        for rsrc in [ 'personal', 'test-dav-acl' ]:
            resource = '%s%s/' % (parentColl, rsrc)
            mkcol = webdavlib.WebDAVMKCOL(resource)
            self.superuser_client.execute(mkcol)
            acl_utility = utilities.TestCalendarACLUtility(self,
                                                           self.subscriber_client,
                                                           resource)
            acl_utility.setupRights(username, {})

        propfind = webdavlib.WebDAVPROPFIND(parentColl, [ "displayname" ], 1)
        self.subscriber_client.execute(propfind)
        hrefs = [x.text \
                 for x in propfind.response["document"] \
                 .findall("{DAV:}response/{DAV:}href")]
        self.assertTrue(len(hrefs) > 2,
                        "expected at least 3 hrefs in response")
        self.assertEquals(hrefs[0], parentColl,
                          "the href must be the 'Calendar' parent coll.")
        for rsrc in [ 'personal', 'test-dav-acl' ]:
            resource = '%s%s/' % (parentColl, rsrc)
            self.assertTrue(hrefs.index(resource) > -1,
                            "resource '%s' not returned" % resource)

if __name__ == "__main__":
    sogotests.runTests()
