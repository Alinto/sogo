#!/usr/bin/python

# setup: username must be super-user or have read-access to PUBLIC events in
#        both attendee and delegate's personal calendar

from config import hostname, port, username, password, \
                   attendee1, attendee1_delegate,      \
		   resource_no_overbook, resource_can_overbook

import datetime
import dateutil.tz
import sogotests
import sys
import time
import unittest
import utilities
import vobject
import vobject.base
import vobject.icalendar
import webdavlib
import StringIO
import xml.etree.ElementTree

class CalDAVPropertiesTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        self.test_calendar \
            = "/SOGo/dav/%s/Calendar/test-dav-properties/" % username
        mkcol = webdavlib.WebDAVMKCOL(self.test_calendar)
        self.client.execute(mkcol)

    def tearDown(self):
        delete = webdavlib.WebDAVDELETE(self.test_calendar)
        self.client.execute(delete)

    def testDavScheduleCalendarTransparency(self):
        """{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp"""

        ## PROPFIND
        propfind = webdavlib.WebDAVPROPFIND(self.test_calendar,
                                            ["{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp"],
                                            0)
        self.client.execute(propfind)
        response = propfind.response["document"].find('{DAV:}response')
        propstat = response.find('{DAV:}propstat')
        status = propstat.find('{DAV:}status').text[9:12]

        self.assertEquals(status, "200",
                          "schedule-calendar-transp marked as 'Not Found' in response")
        transp = propstat.find('{DAV:}prop/{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp')
        values = transp.getchildren()
        self.assertEquals(len(values), 1, "one and only one element expected")
        value = values[0]
        self.assertTrue(isinstance(value, xml.etree.ElementTree._ElementInterface),
                          "schedule-calendar-transp must be an instance of" \
                              " %s, not %s"
                          % ("_ElementInterface", transp.__class__.__name__))
        ns = value.tag[0:31]
        tag = value.tag[31:]
        self.assertTrue(ns == "{urn:ietf:params:xml:ns:caldav}",
                        "schedule-calendar-transp must have a value in"\
                        " namespace '%s', not '%s'"
                        % ("urn:ietf:params:xml:ns:caldav", ns))
        self.assertTrue(tag == "opaque",
                        "schedule-calendar-transp must be 'opaque' on new" \
                        " collections, not '%s'" % tag)

        ## PROPPATCH
        newValueNode = "{urn:ietf:params:xml:ns:caldav}thisvaluedoesnotexist"
        proppatch = webdavlib.WebDAVPROPPATCH(self.test_calendar,
                                              {"{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp": \
                                                   { newValueNode: True }})
        self.client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 400,
                          "expecting failure when setting transparency to" \
                              " an invalid value")

        newValueNode = "{urn:ietf:params:xml:ns:caldav}transparent"
        proppatch = webdavlib.WebDAVPROPPATCH(self.test_calendar,
                                              {"{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp": \
                                                   { newValueNode: True }})
        self.client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 207,
                          "failure (%s) setting transparency to" \
                              " 'transparent': '%s'"
                          % (proppatch.response["status"],
                             proppatch.response["body"]))

        newValueNode = "{urn:ietf:params:xml:ns:caldav}opaque"
        proppatch = webdavlib.WebDAVPROPPATCH(self.test_calendar,
                                              {"{urn:ietf:params:xml:ns:caldav}schedule-calendar-transp": \
                                                   { newValueNode: True }})
        self.client.execute(proppatch)
        self.assertEquals(proppatch.response["status"], 207,
                          "failure (%s) setting transparency to" \
                              " 'transparent': '%s'"
                          % (proppatch.response["status"],
                             proppatch.response["body"]))

class CalDAVITIPDelegationTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        utility = utilities.TestUtility(self, self.client)
        (self.user_name, self.user_email) = utility.fetchUserInfo(username)
        (self.attendee1_name, self.attendee1_email) = utility.fetchUserInfo(attendee1)
        (self.attendee1_delegate_name, self.attendee1_delegate_email) = utility.fetchUserInfo(attendee1_delegate)
        (self.res_no_ob_name, self.res_no_ob_email) = utility.fetchUserInfo(resource_no_overbook)
        (self.res_can_ob_name, self.res_can_ob_email) = utility.fetchUserInfo(resource_can_overbook)

        self.user_calendar = "/SOGo/dav/%s/Calendar/personal/" % username
        self.attendee1_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1
        self.attendee1_delegate_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1_delegate


    def tearDown(self):
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                          None)
        self._deleteEvent(self.client,
                          "%stest-add-attendee.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-add-attendee.ics" % self.attendee1_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-no-overbook.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-no-overbook-overlap.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-can-overbook.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-can-overbook-overlap.ics" % self.user_calendar, None)

    def _newEvent(self, summary="test event", uid="test", transp=0):
        transparency = ("OPAQUE", "TRANSPARENT")

        newCal = vobject.iCalendar()
        vevent = newCal.add('vevent')
        vevent.add('summary').value = summary
        vevent.add('transp').value = transparency[transp]

        now = datetime.datetime.now(dateutil.tz.gettz("America/Montreal"))
        startdate = vevent.add('dtstart')
        startdate.value = now
        enddate = vevent.add('dtend')
        enddate.value = now + datetime.timedelta(0, 3600)
        vevent.add('uid').value = uid
        vevent.add('dtstamp').value = now
        vevent.add('last-modified').value = now
        vevent.add('created').value = now
        
        vevent.add('sequence').value = "0"

        return newCal

    def _putEvent(self, client, filename, event, exp_status = 201):
        put = webdavlib.HTTPPUT(filename, event.serialize())
        put.content_type = "text/calendar; charset=utf-8"
        client.execute(put)
        if exp_status is not None:
            self.assertEquals(put.response["status"], exp_status)

    def _postEvent(self, client, outbox, event, originator, recipients,
                   exp_status = 200):
        post = webdavlib.CalDAVPOST(outbox, event.serialize(),
                                    originator, recipients)
        client.execute(post)
        if exp_status is not None:
            self.assertEquals(post.response["status"], exp_status)

    def _getEvent(self, client, filename, exp_status = 200):
        get = webdavlib.HTTPGET(filename)
        client.execute(get)

        if exp_status is not None:
            self.assertEquals(get.response["status"], exp_status)

        if get.response["headers"]["content-type"].startswith("text/calendar"):
            stream = StringIO.StringIO(get.response["body"])
            event = vobject.base.readComponents(stream).next()
        else:
            event = None

        return event

    def _deleteEvent(self, client, filename, exp_status = 204):
        delete = webdavlib.WebDAVDELETE(filename)
        client.execute(delete)
        if exp_status is not None:
            self.assertEquals(delete.response["status"], exp_status)

    def _eventAttendees(self, event):
        attendees = {}

        event_component = event.vevent
        for child in event_component.getChildren():
            if child.name == "ATTENDEE":
                try:
                    delegated_to = child.delegated_to_param
                except:
                    delegated_to = "(none)"
                try:
                    delegated_from = child.delegated_from_param
                except:
                    delegated_from = "(none)"
                attendees[child.value] = ("%s/%s/%s"
                                          % (child.partstat_param,
                                             delegated_to,
                                             delegated_from))

        return attendees

    def _compareAttendees(self, compared_event, event):
        compared_attendees = self._eventAttendees(compared_event)
        compared_emails = compared_attendees.keys()
        self.assertTrue(len(compared_emails) > 0,
                        "no attendee found")
        compared_emails.sort()

        attendees = self._eventAttendees(event)
        emails = attendees.keys()
        emails.sort()

        self.assertEquals(len(compared_emails), len(emails),
                          "number of attendees is not equal"
                          + " (actual: %d, exp: %d)"
                          % (len(compared_emails), len(emails)))

        for email in emails:
            self.assertEquals(compared_attendees[email],
                              attendees[email],
                              "partstat for attendee '%s' does not match"
                              " (actual: '%s', expected: '%s')"
                              % (email,
                                 compared_attendees[email], attendees[email]))

    def testAddAttendee(self):
	""" add attendee after event creation """

	# make sure the event doesn't exist
	ics_name = "test-add-attendee.ics"
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)
        self._deleteEvent(self.client,
                          "%s%s" % (self.attendee1_calendar,ics_name), None)

        # 1. create an event in the organiser's calendar
	event = self._newEvent(summary="Test add attendee", uid="Test add attendee")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

	# 2. add an attendee
        event.add("method").value = "REQUEST"
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.attendee1_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.attendee1_email
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event,
			exp_status=204)


	# 3. verify that the attendee has the event
        attendee_event = self._getEvent(self.client, "%s%s" % (self.attendee1_calendar, ics_name))

	# 4. make sure the received event match the original one
	# XXX is this enough?
	self.assertEquals(event.vevent.uid, attendee_event.vevent.uid)

    def testResourceNoOverbook(self):
	""" try to overbook a resource """

	# make sure the event doesn't exist
	ics_name = "test-no-overbook.ics"
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

	ob_ics_name = "test-no-overbook-overlap.ics"
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

        # 1. create an event in the organiser's calendar
	event = self._newEvent(summary="Test no overbook", uid="test no overbook")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_no_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_no_ob_email
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

        # 2. create a second event overlapping the first one
	event = self._newEvent(summary="Test no overbook - overlap", uid="test no overbook - overlap")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_no_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_no_ob_email

	# put the event - should trigger a 403
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ob_ics_name), event, exp_status=403)

    def testResourceCanOverbook(self):
	""" try to overbook a resource - multiplebookings=0"""

	# make sure the event doesn't exist
	ics_name = "test-can-overbook.ics"
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

	ob_ics_name = "test-can-overbook-overlap.ics"
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ob_ics_name), None)

        # 1. create an event in the organiser's calendar
	event = self._newEvent(summary="Test can overbook", uid="test can overbook")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_can_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_can_ob_email
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

        # 2. create a second event overlapping the first one
	event = self._newEvent(summary="Test can overbook - overlap", uid="test can overbook - overlap")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_can_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_can_ob_email

	# put the event - should be fine since we can overbook this one
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ob_ics_name), event)


    def testInvitationDelegation(self):
        """ invitation delegation """

        # the invitation must not exist
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                          None)

        # 1. org -> attendee => org: 1, attendee: 1 (pst=N-A), delegate: 0

        invitation = self._newEvent()
        invitation.add("method").value = "REQUEST"
        organizer = invitation.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = invitation.vevent.add('attendee')
        attendee.cn_param = self.attendee1_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.attendee1_email

        self._postEvent(self.client, self.user_calendar, invitation,
                        self.user_email, [self.attendee1_email])
        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.user_calendar,
                       invitation)

        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics"
                                 % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)

        # 2. attendee delegates to delegate
        #    => org: 1 (updated), attendee: 1 (updated,pst=D),
        #       delegate: 1 (new,pst=N-A)

        invitation.add("method").value = "REQUEST"
        attendee1 = invitation.vevent.attendee
        attendee1.partstat_param = "DELEGATED"
        attendee1.delegated_to_param = self.attendee1_delegate_email
        delegate = invitation.vevent.add('attendee')
        delegate.delegated_from_param = self.attendee1_email
        delegate.cn_param = self.attendee1_delegate_name
        delegate.rsvp_param = "TRUE"
        delegate.partstat_param = "NEEDS-ACTION"
        delegate.value = self.attendee1_delegate_email

        self._postEvent(self.client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.attendee1_delegate_email])
        invitation.method.value = "REPLY"
        self._postEvent(self.client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])
        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        del_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics"
                                 % self.attendee1_delegate_calendar)
        self._compareAttendees(del_inv, invitation)
        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)

        # 3. delegate accepts
        #    => org: 1 (updated), attendee: 1 (updated,pst=D),
        #       delegate: 1 (accepted,pst=A)

        invitation.add("method").value = "REPLY"
        delegate.partstat_param = "ACCEPTED"
        self._postEvent(self.client,
                        self.attendee1_delegate_calendar, invitation,
                        self.attendee1_delegate_email, [self.user_email, self.attendee1_email])
        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)

        # 4. attendee accepts
        # => org: 1 (updated), attendee: 1 (updated,pst=A),
        #    delegate: 0 (cancelled, deleted)

        cancellation = vobject.iCalendar()
        cancellation.copy(invitation)
        cancellation.add("method").value = "CANCEL"
        cancellation.vevent.sequence.value = "1"
        self._postEvent(self.client,
                        self.attendee1_calendar, cancellation,
                        self.attendee1_email, [self.attendee1_delegate_email])

        attendee1 = invitation.vevent.attendee
        attendee1.partstat_param = "ACCEPTED"
        del attendee1.delegated_to_param
        invitation.add("method").value = "REPLY"
        invitation.vevent.remove(delegate)
        self._postEvent(self.client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])

        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)

        del_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_delegate_calendar, 404)

        # 5. org updates inv.
        #    => org: 1 (updated), attendee: 1 (updated), delegate: 0

        invitation.add("method").value = "REQUEST"
        invitation.vevent.summary.value = "Updated invitation"
        invitation.vevent.sequence.value = "1"
        attendee.partstat_param = "NEEDS-ACTION"
        now = datetime.datetime.now()
        invitation.vevent.last_modified.value = now
        invitation.vevent.dtstamp.value = now

        self._postEvent(self.client, self.user_calendar, invitation,
                        self.user_email, [self.attendee1_email])

        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.user_calendar,
                       invitation, 204)

        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)

        # 6. attendee delegates to delegate
        #    => org: 1 (updated), attendee: 1 (updated), delegate: 1 (new)

        invitation.add("method").value = "REQUEST"
        attendee1.partstat_param = "DELEGATED"
        attendee1.delegated_to_param = self.attendee1_delegate_email

        delegate = invitation.vevent.add('attendee')
        delegate.delegated_from_param = self.attendee1_email
        delegate.cn_param = self.attendee1_delegate_name
        delegate.rsvp_param = "TRUE"
        delegate.partstat_param = "NEEDS-ACTION"
        delegate.value = self.attendee1_delegate_email

        self._postEvent(self.client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.attendee1_delegate_email])
        invitation.method.value = "REPLY"
        self._postEvent(self.client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])
        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        del_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics"
                                 % self.attendee1_delegate_calendar)
        self._compareAttendees(del_inv, invitation)

        # 7. delegate accepts
        #    => org: 1 (updated), attendee: 1 (updated), delegate: 1 (accepted)

        invitation.add("method").value = "REPLY"
        delegate.partstat_param = "ACCEPTED"
        self._postEvent(self.client,
                        self.attendee1_delegate_calendar, invitation,
                        self.attendee1_delegate_email, [self.user_email,
                                                        self.attendee1_email])
        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)

        # 8. org updates inv.
        #    => org: 1 (updated), attendee: 1 (updated,partstat unchanged),
        #       delegate: 1 (updated,partstat reset)

        invitation.add("method").value = "REQUEST"
        now = datetime.datetime.now()
        invitation.vevent.last_modified.value = now
        invitation.vevent.dtstamp.value = now
        invitation.vevent.summary.value = "Updated invitation (again)"
        invitation.vevent.sequence.value = "2"
        delegate.partstat_param = "NEEDS-ACTION"

        self._postEvent(self.client, self.user_calendar, invitation,
                        self.user_email, [self.attendee1_email, self.attendee1_delegate_email])

        del invitation.method
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.user_calendar,
                       invitation, 204)

        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)
        del_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(del_inv, invitation)

        # 9. org cancels invitation
        #    => org: 1 (updated), attendee: 0 (cancelled, deleted),
        #       delegate: 0 (cancelled, deleted)

        invitation.add("method").value = "CANCEL"
        now = datetime.datetime.now()
        invitation.vevent.last_modified.value = now
        invitation.vevent.dtstamp.value = now
        invitation.vevent.summary.value = "Cancelled invitation (again)"
        invitation.vevent.sequence.value = "3"

        self._postEvent(self.client, self.user_calendar, invitation,
                        self.user_email, [self.attendee1_email, self.attendee1_delegate_email])

        del invitation.method
        invitation.vevent.remove(attendee)
        invitation.vevent.remove(delegate)
        self._putEvent(self.client,
                       "%stest-delegation.ics" % self.user_calendar,
                       invitation, 204)

        att_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_calendar, 404)
        del_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.attendee1_delegate_calendar, 404)

if __name__ == "__main__":
    sogotests.runTests()
