#!/usr/bin/python

# setup: 4 users are needed: username, attendee1_username,
#        attendee1_delegate_username and superuser.
# when writing new tests, avoid using superuser when not absolutely needed

# TODO
#   - Individual tests should set the ACLs themselves on Resources tests

from config import hostname, port, username, password, \
		   superuser, superuser_password, \
                   attendee1, attendee1_username, \
		   attendee1_password, \
		   attendee1_delegate, attendee1_delegate_username, \
		   attendee1_delegate_password, \
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
        self.assertTrue(xml.etree.ElementTree.iselement(value))
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

class CalDAVSchedulingTest(unittest.TestCase):
    def setUp(self):
        self.superuser_client = webdavlib.WebDAVClient(hostname, port,
                                             superuser, superuser_password)
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        self.attendee1_client = webdavlib.WebDAVClient(hostname, port,
                                             attendee1_username, attendee1_password)
        self.attendee1_delegate_client = webdavlib.WebDAVClient(hostname, port,
                                                                attendee1_delegate_username, attendee1_delegate_password)

        utility = utilities.TestUtility(self, self.client)
        (self.user_name, self.user_email) = utility.fetchUserInfo(username)
        (self.attendee1_name, self.attendee1_email) = utility.fetchUserInfo(attendee1)
        (self.attendee1_delegate_name, self.attendee1_delegate_email) = utility.fetchUserInfo(attendee1_delegate)
        (self.res_no_ob_name, self.res_no_ob_email) = utility.fetchUserInfo(resource_no_overbook)
        (self.res_can_ob_name, self.res_can_ob_email) = utility.fetchUserInfo(resource_can_overbook)

        self.user_calendar = "/SOGo/dav/%s/Calendar/personal/" % username
        self.attendee1_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1
        self.attendee1_delegate_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1_delegate
        self.res_calendar = "/SOGo/dav/%s/Calendar/personal/" % resource_no_overbook
        self.res_ob_calendar = "/SOGo/dav/%s/Calendar/personal/" % resource_can_overbook

        # fetch non existing event to let sogo create the calendars in the db
        self._getEvent(self.client, "%snonexistent" % self.user_calendar, exp_status=404)
        self._getEvent(self.attendee1_client, "%snonexistent" % self.attendee1_calendar, exp_status=404)
        self._getEvent(self.attendee1_delegate_client, "%snonexistent" %
                        self.attendee1_delegate_calendar, exp_status=404)

        # list of ics used by the test.
        # tearDown will loop over this and wipe them in all users' calendar
        self.ics_list = []


    def tearDown(self):
        # delete all created  events from all users' calendar
        for ics in self.ics_list:
          self._deleteEvent(self.superuser_client,
                          "%s%s" % (self.user_calendar, ics), None)
          self._deleteEvent(self.superuser_client,
                          "%s%s" % (self.attendee1_calendar, ics), None)
          self._deleteEvent(self.superuser_client,
                          "%s%s" % (self.attendee1_delegate_calendar, ics), None)
          self._deleteEvent(self.superuser_client,
                          "%s%s" % (self.res_calendar, ics), None)
          self._deleteEvent(self.superuser_client,
                          "%s%s" % (self.res_ob_calendar, ics), None)

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
        vevent.add('class').value = "PUBLIC"
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

    def _getAllEvents(self, client, collection, exp_status = 207):
        propfind = webdavlib.WebDAVPROPFIND(collection, None)
        client.execute(propfind)
        if exp_status is not None:
            self.assertEquals(propfind.response["status"], exp_status)

        content = []
        nodes = propfind.response["document"].findall('{DAV:}response')
        for node in nodes:
          responseHref = node.find('{DAV:}href').text
          content += [responseHref]

        return content

    def _deleteAllEvents(self, client, collection, exp_status = 204):
        content = self._getAllEvents(client, collection)
        for item in content:
          self._deleteEvent(client, item)

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
        self.ics_list += [ics_name]

        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)
        self._deleteEvent(self.attendee1_client,
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
        attendee_event = self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name))

	# 4. make sure the received event match the original one
	# XXX is this enough?
	self.assertEquals(event.vevent.uid, attendee_event.vevent.uid)
	
    def testUninviteAttendee(self):
        """ Remove attendee after event creation """

        # make sure the event doesn't exist
        ics_name = "test-remove-attendee.ics"
        self.ics_list += [ics_name]

        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)
        self._deleteEvent(self.attendee1_client,
                          "%s%s" % (self.attendee1_calendar,ics_name), None)

        # 1. create an event in the organiser's calendar
        event = self._newEvent(summary="Test uninvite attendee", uid="Test uninvite attendee")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email

        self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

        # keep a copy around for updates without other attributes
        noAttendeeEvent = vobject.iCalendar()
        noAttendeeEvent.copy(event)

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
        attendee_event = self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name))

        # 4. make sure the received event match the original one
        self.assertEquals(event.vevent.uid, attendee_event.vevent.uid)

        # 5. uninvite the attendee - put the event back without the attendee 
        now = datetime.datetime.now(dateutil.tz.gettz("America/Montreal"))
        noAttendeeEvent.vevent.last_modified.value = now
        self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), noAttendeeEvent,
                        exp_status=204)

        # 6. verify that the attendee doesn't have the event anymore
        attendee_event = self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name), 404)

    def testResourceNoOverbook(self):
        """ try to overbook a resource """

        # make sure there are no events in the resource calendar
        self._deleteAllEvents(self.superuser_client, self.res_calendar)

        # make sure the event doesn't exist
        ics_name = "test-no-overbook.ics"
        self.ics_list += [ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

        ob_ics_name = "test-no-overbook-overlap.ics"
        self.ics_list += [ob_ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ob_ics_name), None)

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

        # make sure there are no events in the resource calendar
        self._deleteAllEvents(self.superuser_client, self.res_ob_calendar)

        # make sure the event doesn't exist
        ics_name = "test-can-overbook.ics"
        self.ics_list += [ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

        ob_ics_name = "test-can-overbook-overlap.ics"
        self.ics_list += [ob_ics_name]
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

    def testResourceBookingOverlapDetection(self):
        """ Resource booking overlap detection - bug #1837"""
        
        # There used to be some problems with recurring events and resources booking
        # This test implements these edge cases

        # 1. Create recurring event (with resource)
        # 2. Create single event overlaping one instance for the previous event
        #    (should fail)
        # 3. Create recurring event which _doesn't_ overlap the first event
        #    (should be OK, used to fail pre1.3.17)
        # 4. Create recurring event overlapping the previous recurring event
        #    (should fail)

        # make sure there are no events in the resource calendar
        self._deleteAllEvents(self.superuser_client, self.res_calendar)

        # make sure the event doesn't exist
        ics_name = "test-res-overlap-detection.ics"
        self.ics_list += [ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,ics_name), None)

        overlap_ics_name = "test-res-overlap-detection-overlap.ics"
        self.ics_list += [overlap_ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.attendee1_calendar,overlap_ics_name), None)

        nooverlap_recurring_ics_name = "test-res-overlap-detection-nooverlap.ics"
        self.ics_list += [nooverlap_recurring_ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,nooverlap_recurring_ics_name), None)

        overlap_recurring_ics_name = "test-res-overlap-detection-overlap-recurring.ics"
        self.ics_list += [overlap_recurring_ics_name]
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar,overlap_recurring_ics_name), None)

        # 1. create recurring event with resource
        event = self._newEvent(summary="recurring event with resource",
                                uid="recurring event w resource")
        event.vevent.add('rrule').value = "FREQ=DAILY;COUNT=5"
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.user_name
        organizer.value = self.user_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_no_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_no_ob_email

        # keep a copy around for #3
        nooverlap_event = vobject.iCalendar()
        nooverlap_event.copy(event)

        self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

        # 2. Create single event overlaping one instance for the previous event 
        event = self._newEvent(summary="recurring event with resource",
                                uid="recurring event w resource - overlap")
        organizer = event.vevent.add('organizer')
        organizer.cn_param = self.attendee1_name
        organizer.value = self.attendee1_email
        attendee = event.vevent.add('attendee')
        attendee.cn_param = self.res_no_ob_name
        attendee.rsvp_param = "TRUE"
        attendee.partstat_param = "NEEDS-ACTION"
        attendee.value = self.res_no_ob_email
        # should fail
        self._putEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, overlap_ics_name), event, exp_status=403)

        # 3. Create recurring event which _doesn't_ overlap the first event
        #    (should be OK, used to fail pre1.3.17)
        # shift the start date to one hour after the original event end time
        nstartdate = nooverlap_event.vevent.dtend.value + datetime.timedelta(0, 3600)
        nooverlap_event.vevent.dtstart.value = nstartdate
        nooverlap_event.vevent.dtend.value = nstartdate + datetime.timedelta(0, 3600)
        nooverlap_event.vevent.uid.value = "recurring - nooverlap"

        self._putEvent(self.client, "%s%s" % (self.user_calendar, nooverlap_recurring_ics_name), nooverlap_event)

        # 4. Create recurring event overlapping the previous recurring event
        #    should fail
        nstartdate = nooverlap_event.vevent.dtstart.value + datetime.timedelta(0, 300)
        nooverlap_event.vevent.dtstart.value = nstartdate
        nooverlap_event.vevent.dtend.value = nstartdate + datetime.timedelta(0, 3600)
        nooverlap_event.vevent.uid.value = "recurring - overlap"
        self._putEvent(self.client, "%s%s" % (self.user_calendar, overlap_recurring_ics_name), nooverlap_event, exp_status=403)


    def testRruleExceptionInvitationDance(self):
	""" RRULE exception invitation dance """

	# This workflow is based on what lightning 1.2.1 does
	#  create a reccurring event
	#  add an exception
	#  invite bob to the exception:
	#    bob is declined in the master event
	#    bob needs-action in the exception
	#  bob accepts
	#    bob is declined in the master event
	#    bob is accepted in the exception
	#  the organizer 'uninvites' bob
	#    the event disappears from bob's calendar 
	#    bob isn't in the master+exception event

	ics_name = "test-rrule-exception-invitation-dance.ics"
        self.ics_list += [ics_name]

	self._deleteEvent(self.client,
			  "%s%s" % (self.user_calendar, ics_name), None)
	self._deleteEvent(self.attendee1_client,
			  "%s%s" % (self.attendee1_calendar, ics_name), None)

	# 1.  create a recurring event in the organiser's calendar
	summary="Test reccuring exception invite cancel"
	uid="Test-recurring-exception-invite-cancel"
	event = self._newEvent(summary, uid)
	event.vevent.add('rrule').value = "FREQ=DAILY;COUNT=5"

	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

	# read the event back from the server
	org_ev = self._getEvent(self.client, "%s%s" % (self.user_calendar, ics_name))

	# 2. Add an exception to the master event and invite attendee1 to it
	now = datetime.datetime.now(dateutil.tz.gettz("America/Montreal"))
	org_ev.vevent.last_modified.value = now
	orig_dtstart = org_ev.vevent.dtstart.value
	orig_dtend = org_ev.vevent.dtend.value

	ev_exception = org_ev.add("vevent")
	ev_exception.add('created').value = now
	ev_exception.add('last-modified').value = now
	ev_exception.add('dtstamp').value = now
	ev_exception.add('uid').value = uid
	ev_exception.add('summary').value = summary
	# out of laziness, add the exception for the first occurence of the event
	recurrence_id = orig_dtstart
	ev_exception.add('recurrence-id').value = recurrence_id

	ev_exception.add('transp').value = "OPAQUE"
	ev_exception.add('description').value = "Exception"
	ev_exception.add('sequence').value = "1"
	ev_exception.add('dtstart').value = orig_dtstart
	ev_exception.add('dtend').value = orig_dtend

	# 2.1 Add attendee1 and organizer to the exception
	organizer = ev_exception.add('organizer')
	organizer.cn_param = self.user_name
	organizer.partstat_param = "ACCEPTED"
	organizer.value = self.user_email
	attendee = ev_exception.add('attendee')
	attendee.cn_param = self.attendee1_name
	attendee.rsvp_param = "TRUE"
	attendee.role_param = "REQ-PARTICIPANT"
	attendee.partstat_param = "NEEDS-ACTION"
	attendee.value = self.attendee1_email

	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), org_ev,
			exp_status=204)

	# 3. Make sure the attendee got the event
        attendee_ev = self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name))

	for ev in attendee_ev.vevent_list:
	  try:
	    if (ev.recurrence_id.value):
	      attendee_ev_exception = ev
	  except:
	    attendee_ev_master = ev
	
	# make sure sogo doesn't duplicate attendees - yes, we've seen that
	self.assertEquals(len(attendee_ev_master.attendee_list), 1)
	self.assertEquals(len(attendee_ev_exception.attendee_list), 1)

	# 4. The master event must contain the invitation, declined
	self.assertEquals(attendee_ev_master.attendee.partstat_param, "DECLINED")

	# 5. The exception event contain the invitation, NEEDS-ACTION
	self.assertEquals(attendee_ev_exception.attendee.partstat_param, "NEEDS-ACTION")

	# 6. attendee accepts invitation
	attendee_ev_exception.attendee.partstat_param = "ACCEPTED"
	self._putEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name), 
			attendee_ev, exp_status=204)
	
	# fetch the organizer's event
	org_ev = self._getEvent(self.client, "%s%s" % (self.user_calendar, ics_name))
	for ev in org_ev.vevent_list:
	  try:
	    if (ev.recurrence_id.value):
	      org_ev_exception = ev
	  except:
	    org_ev_master = ev

	# make sure sogo doesn't duplicate attendees
	self.assertEquals(len(org_ev_master.attendee_list), 1)
	self.assertEquals(len(org_ev_exception.attendee_list), 1)

	# 7. Make sure organizer got the accept for the exception and
	# that the attendee is still declined in the master
	self.assertEquals(org_ev_exception.attendee.partstat_param, "ACCEPTED")
	self.assertEquals(org_ev_master.attendee.partstat_param, "DECLINED")

	# 8. delete the attendee from the master event (uninvite)
	#    The event should be deleted from the attendee's calendar
	del org_ev_exception.attendee
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), 
			org_ev, exp_status=204)
	del org_ev_master.attendee
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), 
			org_ev, exp_status=204)

	self._getEvent(self.client, "%s%s" % (self.attendee1_calendar, ics_name),
			exp_status=404)

	# now be happy

    def testRruleInvitationDeleteExdate(self):
	"""RRULE invitation delete exdate dance"""

	# Workflow:
	# Create an recurring event and invite Bob
	# Add an exdate to the master event
	# Verify that the exdate has propagated to Bob's calendar
	# Add an exdate to bob's version of the event
	# Verify that an exception has been created in the org's calendar
	#  and that bob is 'declined'

	ics_name = "test-rrule-invitation-deleted-exdate-dance.ics"
        self.ics_list += [ics_name]

	self._deleteEvent(self.client,
			  "%s%s" % (self.user_calendar, ics_name), None)
	self._deleteEvent(self.attendee1_client,
			  "%s%s" % (self.attendee1_calendar, ics_name), None)

	# 1.  create a recurring event in the organiser's calendar
	summary="Test-rrule-invitation-deleted-exdate-dance"
	uid=summary
	event = self._newEvent(summary, uid)
	event.vevent.add('rrule').value = "FREQ=DAILY;COUNT=5"
	organizer = event.vevent.add('organizer')
	organizer.cn_param = self.user_name
	organizer.partstat_param = "ACCEPTED"
	organizer.value = self.user_email
	attendee = event.vevent.add('attendee')
	attendee.cn_param = self.attendee1_name
	attendee.rsvp_param = "TRUE"
	attendee.role_param = "REQ-PARTICIPANT"
	attendee.partstat_param = "NEEDS-ACTION"
	attendee.value = self.attendee1_email

	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

	# 2. Make sure the attendee got it
	self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name))

	# 3. Add exdate to master event
	org_ev=self._getEvent(self.client, "%s%s" % (self.user_calendar, ics_name))
	orig_dtstart = org_ev.vevent.dtstart.value
	# exdate is a list in vobject.icalendar
	org_exdate = [orig_dtstart.astimezone(dateutil.tz.gettz("UTC"))]
	org_ev.vevent.add('exdate').value = org_exdate
	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), org_ev, exp_status=204)

	# 4. make sure the attendee has the exdate
	attendee_ev = self._getEvent(self.attendee1_client, "%s%s" %
			(self.attendee1_calendar, ics_name))
	self.assertEqual(org_exdate, attendee_ev.vevent.exdate.value)

	# 5. Create an exdate in the attendee's calendar
	new_exdate = orig_dtstart + datetime.timedelta(days=2)
	attendee_exdate = [new_exdate.astimezone(dateutil.tz.gettz("UTC"))]
	attendee_ev.vevent.add('exdate').value = attendee_exdate
        now = datetime.datetime.now(dateutil.tz.gettz("America/Montreal"))
        attendee_ev.vevent.last_modified.value =  now
	self._putEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, ics_name),
			attendee_ev, exp_status=204)

	# 6. Make sure the attendee is:
	#  needs-action in master event
	#  declined in the new exception created by the exdate above
	org_ev=self._getEvent(self.client, "%s%s" % (self.user_calendar, ics_name))
	for ev in org_ev.vevent_list:
	  try:
	    if (ev.recurrence_id.value == attendee_exdate[0]):
	      org_ev_exception = ev
	  except:
	    org_ev_master = ev
	
	self.assertTrue(org_ev_exception)
	# make sure sogo doesn't duplicate attendees
	self.assertEquals(len(org_ev_master.attendee_list), 1)
	self.assertEquals(len(org_ev_exception.attendee_list), 1)

	self.assertEqual(org_ev_master.attendee.partstat_param, "NEEDS-ACTION");
	self.assertEqual(org_ev_exception.attendee.partstat_param, "DECLINED");
	
    def testOrganizerIsAttendee(self):
        """ iCal organizer is attendee - bug #1839 """

        # This tries to have the same behavior as iCal
        #   1. create an event, add an attendee and add the organizer as an attendee
        #   2. SOGo should remove the organizer from the attendee list
	ics_name = "test-organizer-is-attendee.ics"
        self.ics_list += [ics_name]

	self._deleteEvent(self.client,
			  "%s%s" % (self.user_calendar, ics_name), None)
	self._deleteEvent(self.attendee1_client,
			  "%s%s" % (self.attendee1_calendar, ics_name), None)

	# 1.  create a recurring event in the organiser's calendar
	summary="org is attendee"
	uid=summary
	event = self._newEvent(summary, uid)
	organizer = event.vevent.add('organizer')
	organizer.cn_param = self.user_name
	organizer.partstat_param = "ACCEPTED"
	organizer.value = self.user_email
	attendee = event.vevent.add('attendee')
	attendee.cn_param = self.attendee1_name
	attendee.rsvp_param = "TRUE"
	attendee.role_param = "REQ-PARTICIPANT"
	attendee.partstat_param = "NEEDS-ACTION"
	attendee.value = self.attendee1_email

        # 1.1 add the organizer as an attendee
	attendee = event.vevent.add('attendee')
	attendee.cn_param = self.user_name
	attendee.rsvp_param = "TRUE"
	attendee.role_param = "REQ-PARTICIPANT"
	attendee.partstat_param = "ACCEPTED"
	attendee.value = self.user_email

	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

	# 2. Fetch the event and make sure the organizer is not in the attendee list anymore
	org_ev = self._getEvent(self.client, "%s%s" % (self.user_calendar, ics_name))

        for attendee in org_ev.vevent.attendee_list:
          self.assertNotEqual(self.user_email, attendee.value)

    def testEventsWithSameUID(self):
        """ PUT 2 events with the same UID - bug #1853 """

	ics_name = "test-same-uid.ics"
        self.ics_list += [ics_name]

	self._deleteEvent(self.client,
			  "%s%s" % (self.user_calendar, ics_name), None)

	conflict_ics_name = "test-same-uid-conflict.ics"
        self.ics_list += [ics_name]

	self._deleteEvent(self.client,
			  "%s%s" % (self.user_calendar, conflict_ics_name), None)

	# 1.  create simple event
	summary="same uid"
	uid=summary
	event = self._newEvent(summary, uid)

	self._putEvent(self.client, "%s%s" % (self.user_calendar, ics_name), event)

        # PUT the same event with a new filename - should trigger a 403
	self._putEvent(self.client, "%s%s" % (self.user_calendar, conflict_ics_name), event, exp_status=403)

    def testInvitationDelegation(self):
        """ invitation delegation """

	ics_name = "test-delegation.ics"
        self.ics_list += [ics_name]

        # the invitation must not exist
        self._deleteEvent(self.client,
                          "%s%s" % (self.user_calendar, ics_name), None)
        self._deleteEvent(self.attendee1_client,
                          "%s%s" % (self.attendee1_calendar, ics_name), None)
        self._deleteEvent(self.attendee1_delegate_client,
                          "%s%s" % (self.attendee1_delegate_calendar, ics_name), None)

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

        att_inv = self._getEvent(self.attendee1_client,
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

        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.attendee1_delegate_email])
        invitation.method.value = "REPLY"
        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])
        del invitation.method
        self._putEvent(self.attendee1_client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        del_inv = self._getEvent(self.attendee1_delegate_client,
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
        self._postEvent(self.attendee1_delegate_client,
                        self.attendee1_delegate_calendar, invitation,
                        self.attendee1_delegate_email, [self.user_email, self.attendee1_email])
        del invitation.method
        self._putEvent(self.attendee1_delegate_client,
                       "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        att_inv = self._getEvent(self.attendee1_client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)

        # 4. attendee accepts
        # => org: 1 (updated), attendee: 1 (updated,pst=A),
        #    delegate: 0 (cancelled, deleted)

        cancellation = vobject.iCalendar()
        cancellation.copy(invitation)
        cancellation.add("method").value = "CANCEL"
        cancellation.vevent.sequence.value = "1"
        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, cancellation,
                        self.attendee1_email, [self.attendee1_delegate_email])

        attendee1 = invitation.vevent.attendee
        attendee1.partstat_param = "ACCEPTED"
        del attendee1.delegated_to_param
        invitation.add("method").value = "REPLY"
        invitation.vevent.remove(delegate)
        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])

        del invitation.method
        self._putEvent(self.attendee1_client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)

        del_inv = self._getEvent(self.attendee1_delegate_client,
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

        att_inv = self._getEvent(self.attendee1_client,
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

        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.attendee1_delegate_email])
        invitation.method.value = "REPLY"
        self._postEvent(self.attendee1_client,
                        self.attendee1_calendar, invitation,
                        self.attendee1_email, [self.user_email])
        del invitation.method
        self._putEvent(self.attendee1_client,
                       "%stest-delegation.ics" % self.attendee1_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        del_inv = self._getEvent(self.attendee1_delegate_client,
                                 "%stest-delegation.ics"
                                 % self.attendee1_delegate_calendar)
        self._compareAttendees(del_inv, invitation)

        # 7. delegate accepts
        #    => org: 1 (updated), attendee: 1 (updated), delegate: 1 (accepted)

        invitation.add("method").value = "REPLY"
        delegate.partstat_param = "ACCEPTED"
        self._postEvent(self.attendee1_delegate_client,
                        self.attendee1_delegate_calendar, invitation,
                        self.attendee1_delegate_email, [self.user_email,
                                                        self.attendee1_email])
        del invitation.method
        self._putEvent(self.attendee1_delegate_client,
                       "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                       invitation, 204)

        org_inv = self._getEvent(self.client,
                                 "%stest-delegation.ics" % self.user_calendar)
        self._compareAttendees(org_inv, invitation)
        att_inv = self._getEvent(self.attendee1_client,
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

        att_inv = self._getEvent(self.attendee1_client,
                                 "%stest-delegation.ics" % self.attendee1_calendar)
        self._compareAttendees(att_inv, invitation)
        del_inv = self._getEvent(self.attendee1_client,
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

        att_inv = self._getEvent(self.attendee1_client,
                                 "%stest-delegation.ics" % self.attendee1_calendar, 404)
        del_inv = self._getEvent(self.attendee1_delegate_client,
                                 "%stest-delegation.ics" % self.attendee1_delegate_calendar, 404)

if __name__ == "__main__":
    sogotests.runTests()
