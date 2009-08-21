#!/usr/bin/python

from config import hostname, port, username, password, subscriber_username, subscriber_password

import sys
import unittest
import webdavlib
import time

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

def fetchUserEmail(login):
    client = webdavlib.WebDAVClient(hostname, port,
                                    username, password)
    resource = '/SOGo/dav/%s/' % login
    propfind = webdavlib.WebDAVPROPFIND(resource,
                                        ["{urn:ietf:params:xml:ns:caldav}calendar-user-address-set"],
                                        0)
    propfind.xpath_namespace = { "D": "DAV:",
                                 "C": "urn:ietf:params:xml:ns:caldav" }
    client.execute(propfind)
    nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/C:calendar-user-address-set/D:href',
                                    None)

    return nodes[0].childNodes[0].nodeValue

class DAVAclTest(unittest.TestCase):
    resource = None

    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
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

    def rightsToSOGoRights(self, rights):
        self.fail("subclass must implement this method")

    def setupRights(self, rights):
        rights_str = "".join(["<%s/>" % x for x in self.rightsToSOGoRights(rights) ])
        aclQuery = """<acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
<set-roles user="%s">%s</set-roles>
</acl-query>""" % (subscriber_username, rights_str)

        post = webdavlib.HTTPPOST(self.resource, aclQuery, "application/xml")
        self.client.execute(post)
        self.assertEquals(post.response["status"], 204,
                          "rights modification: failure to set '%s' (status: %d)"
                          % (rights_str, post.response["status"]))

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

class DAVCalendarAclTest(DAVAclTest):
    resource = '/SOGo/dav/%s/Calendar/test-dav-acl/' % username
    user_email = None

    def setUp(self):
        if self.user_email is None:
            self.user_email = fetchUserEmail(username)
        DAVAclTest.setUp(self)
        self.classToICSClass = { "pu": "PUBLIC",
                                 "pr": "PRIVATE",
                                 "co": "CONFIDENTIAL" }
        self._putEvent(self.client, "public.ics", "PUBLIC")
        self._putEvent(self.client, "private.ics", "PRIVATE")
        self._putEvent(self.client, "confidential.ics", "CONFIDENTIAL")

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
        put = webdavlib.HTTPPUT(url, event, "text/calendar; charset=utf-8")
        client.execute(put)
        self.assertEquals(put.response["status"], exp_status,
                          "%s: event creation/modification:"
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

    def _testRights(self, rights):
        self.setupRights(rights)
        self._testCreate(rights)
        self._testEventRight("pu", rights)
        self._testEventRight("pr", rights)
        self._testEventRight("co", rights)
        self._testDelete(rights)

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
        self._checkViewEventRight("GET", event, event_class, right)
        event = self._propfindEvent(event_class)
        self._checkViewEventRight("PROPFIND", event, event_class, right)
        event = self._multigetEvent(event_class)
        self._checkViewEventRight("multiget", event, event_class, right)
        event = self._webdavSyncEvent(event_class)
        self._checkViewEventRight("webdav-sync", event, event_class, right)

        self._testModify(event_class, right)
        self._testRespondTo(event_class, right)

    def _getEvent(self, event_class, is_invitation = False):
        icsClass = self.classToICSClass[event_class]
        if is_invitation:
            filename = "invitation-%s" % icsClass.lower()
        else:
            filename = "%s" % icsClass.lower()
        url = "%s%s.ics" % (self.resource, filename)
        get = webdavlib.HTTPGET(url)
        self.subscriber_client.execute(get)

        if get.response["status"] == 200:
            event = get.response["body"]
        else:
            event = None

        return event

    def _calendarDataInMultistatus(self, query, filename,
                                   response_tag = "D:response"):
        event = None

        query.xpath_namespace = { "D": "DAV:",
                                  "C": "urn:ietf:params:xml:ns:caldav" }
        response_nodes = query.xpath_evaluate("/D:multistatus/%s" % response_tag)
        for response_node in response_nodes:
            href_node = query.xpath_evaluate("D:href", response_node)[0]
            href = href_node.childNodes[0].nodeValue
            if href.endswith(filename):
                propstat_nodes = query.xpath_evaluate("D:propstat", response_node)
                for propstat_node in propstat_nodes:
                    status_node = query.xpath_evaluate("D:status",
                                                       propstat_node)[0]
                    status = status_node.childNodes[0].nodeValue
                    data_nodes = query.xpath_evaluate("D:prop/C:calendar-data",
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
        propfind = webdavlib.WebDAVPROPFIND(self.resource,
                                            ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                            1)
        self.subscriber_client.execute(propfind)
        if propfind.response["status"] != 403:
            event = self._calendarDataInMultistatus(propfind, filename)

        return event

    def _multigetEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s.ics" % (self.resource, icsClass.lower())
        multiget = webdavlib.WebDAVCalendarMultiget(self.resource,
                                                    ["{urn:ietf:params:xml:ns:caldav}calendar-data"],
                                                    [ url ])
        self.subscriber_client.execute(multiget)
        if multiget.response["status"] != 403:
            event = self._calendarDataInMultistatus(multiget, url)

        return event

    def _webdavSyncEvent(self, event_class):
        event = None

        icsClass = self.classToICSClass[event_class]
        url = "%s%s.ics" % (self.resource, icsClass.lower())
        sync_query = webdavlib.WebDAVSyncQuery(self.resource, None,
                                               ["{urn:ietf:params:xml:ns:caldav}calendar-data"])
        self.subscriber_client.execute(sync_query)
        if sync_query.response["status"] != 403:
            event = self._calendarDataInMultistatus(sync_query, url,
                                                    "D:sync-response")

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
                                                     "filename": "%s.ics" % icsClass.lower(),
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
                          "UID": "12345-%s-%s.ics" % (icsClass,
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
            self.assertTrue(expected_dict[key] == event_dict[key],
                            "value for key '%s' of secure does not match"
                            " (exp: '%s', obtained: '%s'"
                            % (key, expected_dict[key], event_dict[key] ))

        for key in expected_dict.keys():
            self.assertTrue(event_dict.has_key(key),
                            "expected key '%s' not found in secure event"
                            % key)

    def _testModify(self, event_class, right):
        if right == "m" or right == "r":
            exp_code = 204
        else:
            exp_code = 403
        icsClass = self.classToICSClass[event_class]
        filename = "%s.ics" % icsClass.lower()
        self._putEvent(self.subscriber_client, filename, icsClass,
                       exp_code)

    def _testRespondTo(self, event_class, right):
        icsClass = self.classToICSClass[event_class]
        filename = "invitation-%s.ics" % icsClass.lower()
        self._putEvent(self.client, filename, icsClass,
                       201,
                       "mailto:nobody@somewhere.com", self.user_email,
                       "NEEDS-ACTION")

        if right == "m" or right == "r":
            exp_code = 204
        else:
            exp_code = 403

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
                              "%s\nexpected:\n%s" % (event, exp_event))

# Addressbook:
#   short rights notation: { "c": create,
#                            "d": delete,
#                            "e": edit,
#                            "v": view }

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
        """'create' only"""
        self._testRights({ "c": True,
                           "d": True })

    def testViewCreate(self):
        """'view' and 'create'"""
        self._testRights({ "c": True,
                           "v": True })

    def testViewDelete(self):
        """'view' and 'delete'"""
        self._testRights({ "d": True,
                           "v": True })

    def testEditCreate(self):
        """'edit' and 'create'"""
        self._testRights({ "c": True,
                           "e": True })

    def testEditDelete(self):
        """'edit' and 'delete'"""
        self._testRights({ "d": True,
                           "e": True })

    def rightsToSOGoRights(self, rights):
        sogoRightsTable = { "c": "ObjectCreator",
                            "d": "ObjectEraser",
                            "v": "ObjectViewer",
                            "e": "ObjectEditor" }

        sogoRights = []
        for k in rights.keys():
            sogoRights.append(sogoRightsTable[k])

        return sogoRights

    def _testRights(self, rights):
        self.setupRights(rights)
        self._testCreate(rights)
        self._testView(rights)
        self._testEdit(rights)
        self._testDelete(rights)

    def _putCard(self, client, filename, exp_status, real_card = None):
        url = "%s%s" % (self.resource, filename)
        if real_card is None:
            real_card = filename
        card = self.cards[real_card]
        put = webdavlib.HTTPPUT(url, card, "text/x-vcard; charset=utf-8")
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

if __name__ == "__main__":
    unittest.main()

