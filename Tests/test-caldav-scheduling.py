#!/usr/bin/python

# setup: username must be super-user or have read-access to PUBLIC events in
#        both attendee and delegate's personal calendar

from config import hostname, port, username, password, attendee1, attendee1_delegate

import datetime
import sys
import time
import unittest
import vobject
import vobject.base
import vobject.icalendar
import webdavlib
import StringIO

def fetchUserInfo(login):
    client = webdavlib.WebDAVClient(hostname, port, username, password)
    resource = "/SOGo/dav/%s/" % login
    propfind = webdavlib.WebDAVPROPFIND(resource,
                                        ["displayname",
                                         "{urn:ietf:params:xml:ns:caldav}calendar-user-address-set"],
                                        0)
    propfind.xpath_namespace = { "D": "DAV:",
                                 "C": "urn:ietf:params:xml:ns:caldav" }
    client.execute(propfind)
    assert(propfind.response["status"] == 207)
    name_nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/D:displayname',
                                          None)
    email_nodes = propfind.xpath_evaluate('/D:multistatus/D:response/D:propstat/D:prop/C:calendar-user-address-set/D:href',
                                          None)

    return (name_nodes[0].childNodes[0].nodeValue, email_nodes[0].childNodes[0].nodeValue)

class CalDAVITIPDelegationTest(unittest.TestCase):
    def setUp(self):
        self.client = webdavlib.WebDAVClient(hostname, port,
                                             username, password)
        (self.user_name, self.user_email) = fetchUserInfo(username)
        (self.attendee1_name, self.attendee1_email) = fetchUserInfo(attendee1)
        (self.attendee1_delegate_name, self.attendee1_delegate_email) = fetchUserInfo(attendee1_delegate)

        self.user_calendar = "/SOGo/dav/%s/Calendar/personal/" % username
        self.attendee1_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1
        self.attendee1_delegate_calendar = "/SOGo/dav/%s/Calendar/personal/" % attendee1_delegate

    def _newEvent(self):
        newCal = vobject.iCalendar()
        vevent = newCal.add('vevent')
        vevent.add('summary').value = "test event"
        vevent.add('transp').value = "OPAQUE"

        now = datetime.datetime.now()
        startdate = vevent.add('dtstart')
        startdate.value = now
        enddate = vevent.add('dtend')
        enddate.value = now + datetime.timedelta(0, 3600)
        vevent.add('uid').value = "test-delegation"
        vevent.add('dtstamp').value = now
        vevent.add('last-modified').value = now
        vevent.add('created').value = now
        
        vevent.add('sequence').value = "0"

        return newCal

    def tearDown(self):
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.user_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_calendar, None)
        self._deleteEvent(self.client,
                          "%stest-delegation.ics" % self.attendee1_delegate_calendar,
                          None)

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
                                 "%stest-delegation.ics" % self.attendee1_calendar, 404)

if __name__ == "__main__":
    unittest.main()
