#!/usr/bin/python
from config import hostname, port, username, password, \
                   superuser, superuser_password, \
                   attendee1, attendee1_username, \
                   attendee1_password, \
                   attendee1_delegate, attendee1_delegate_username, \
                   attendee1_delegate_password, \
                   resource_no_overbook, resource_can_overbook, \
                   white_listed_attendee

import preferences
import simplejson
import sogotests
import unittest
import utilities
import datetime
import dateutil.tz
import vobject
import vobject.base
import vobject.icalendar
import webdavlib
import StringIO


class preventInvitationsTest(unittest.TestCase):
    def setUp(self):
      self.prefs = preferences.preferences(attendee1, attendee1_password)
      self.caldav = CalDAVSchedulingTest(self)

    def tearDown(self):
      self.prefs.set("autoReplyText", "")
      self.prefs.set('PreventInvitations', '0')
      self.prefs.set("whiteList", "")
      #- Manual Cleanup, not called because classs is not derived from unittest
      self.caldav.tearDown()

    def testDontPreventInvitation(self):
      """ Set/get the PreventInvitation pref"""
      #- First accept the invitation
      self.prefs.set('PreventInvitations', '0')
      notset = self.prefs.get_settings('')['Calendar']['PreventInvitations']
      self.assertEqual(notset, 0)
      self.caldav.AddAttendee()
      self.caldav.VerifyEvent()

    def testPreventInvitation(self):
      """ Set PreventInvitation and don't accept the Invitation"""
      #- Second, enable PreventInviation and refuse it
      self.prefs.set('enablePreventInvitations', '0')
      isset = self.prefs.get_settings('')['Calendar']['PreventInvitations']
      self.assertEqual(isset, 1)
      self.caldav.AddAttendee(409)
      self.caldav.VerifyEvent(404)

    def testPreventInvitationWhiteList(self):
      """ Set PreventInvitation add to WhiteList and accept the Invitation"""
      #- First, add the Organiser to the Attendee's whitelist
      self.prefs.set('enablePreventInvitations', '0')
      self.prefs.set("whiteList", white_listed_attendee)
      whitelist = self.prefs.get_settings('Calendar')['PreventInvitationsWhitelist']
      self.assertEqual(whitelist, white_listed_attendee)

      #- Second, try again to invite, it should work
      self.prefs.set('enablePreventInvitations', '0')
      isset = self.prefs.get_settings('')['Calendar']['PreventInvitations']
      self.assertEqual(isset, 1)
      self.caldav.AddAttendee()
      self.caldav.VerifyEvent()


class CalDAVSchedulingTest(object):
    def __init__(self, parent_self):
        self.test = parent_self # used for utilities
        self.setUp()

    def setUp(self):
        self.superuser_client = webdavlib.WebDAVClient(hostname, port,
                                             superuser, superuser_password)
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        self.attendee1_client = webdavlib.WebDAVClient(hostname, port,
                                             attendee1_username, attendee1_password)
        self.attendee1_delegate_client = webdavlib.WebDAVClient(hostname, port,
                                                                attendee1_delegate_username, attendee1_delegate_password)

        utility = utilities.TestUtility(self.test, self.client)
        (self.user_name, self.user_email) = utility.fetchUserInfo(username)
        (self.attendee1_name, self.attendee1_email) = utility.fetchUserInfo(attendee1)
        (self.attendee1_delegate_name, self.attendee1_delegate_email) = utility.fetchUserInfo(attendee1_delegate)

        self.user_calendar = "/SOGo/dav/%s/Calendar/personal/" % username
        self.attendee1_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1
        self.attendee1_delegate_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1_delegate

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
            self.test.assertEquals(put.response["status"], exp_status)

    def _getEvent(self, client, filename, exp_status = 200):
        get = webdavlib.HTTPGET(filename)
        client.execute(get)

        if exp_status is not None:
            self.test.assertEquals(get.response["status"], exp_status)

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
            self.test.assertEquals(delete.response["status"], exp_status)

    def AddAttendee(self, exp_status=204):
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
                       exp_status=exp_status)

        #- save event for VerifyEvent
        self.event = event
        self.ics_name = ics_name

    def VerifyEvent(self, exp_status=200):
        # 1. verify that the attendee has the event
        attendee_event = self._getEvent(self.attendee1_client, "%s%s" % (self.attendee1_calendar, self.ics_name), exp_status)

        # 2. make sure the received event match the original one
        if attendee_event:
            self.test.assertEquals(self.event.vevent.uid, attendee_event.vevent.uid)


if __name__ == "__main__":
    sogotests.runTests()
