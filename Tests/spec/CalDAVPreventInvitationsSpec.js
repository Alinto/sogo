import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'
import Preferences from '../lib/Preferences'
import ICAL from 'ical.js'

// preventInvitationsTest
// CalDAVSchedulingTest

let prefs
let webdav, webdav_su, webdavAttendee1, webdavAttendee1Delegate
let utility, user, attendee1, attendee1Delegate
let userCalendar, attendee1Calendar, attendee1DelegateCalendar
let icsName, icsList, vcalendar

describe('PreventInvitationsWhitelist user setting', function() {

  const _getEvent = async function(client, calendarName, filename, expectedCode = 200) {
    const [{ status, headers, raw }] = await client.getObject(calendarName, filename)
    expect(status).toBe(expectedCode)
    if (status <= 300)
      return new ICAL.Component(ICAL.parse(raw))
    return false
  }

  const _putEvent = async function(client, calendarName, filename, event, expectedCode = 201) {
    const response = await client.createCalendarObject(calendarName, filename, event.toString())
    expect(response.status)
      .withContext(`Create event ${calendarName}${filename}`)
      .toBe(expectedCode)
    return response
  }

  const _addAttendee = async function(expectedCode = 204) {
    let vevent, organizer, attendee

    // add attendee after event creation
    icsName = 'test-add-attendee.ics'
    icsList.push(icsName)

    await webdav.deleteObject(userCalendar + icsName)
    await webdavAttendee1.deleteObject(attendee1Calendar + icsName)

    // 1. create an event in the organiser's calendar
    vcalendar = utility.createCalendar('Test add attendee', 'test-add-attendee')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. add an attendee
    vcalendar.addPropertyWithValue('method', 'REQUEST')
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    vevent.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, vcalendar, expectedCode)

    // NOTE: vcalendar and icsName are global for _verifyEvent
  }

  const _verifyEvent = async function(expectedCode = 200) {
    // 1. verify that the attendee has the event
    const vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName, expectedCode)

    // 2. make sure the received event match the original one
    if (vcalendarAttendee) {
      const veventAttendee = vcalendarAttendee.getFirstSubcomponent('vevent')
      const vevent = vcalendar.getFirstSubcomponent('vevent')
      const uidAttendee = veventAttendee.getFirstProperty('uid').getFirstValue()
      const uid = vevent.getFirstProperty('uid').getFirstValue()
      expect(uidAttendee)
        .toEqual(uid)
    }
  }

  beforeAll(async function() {
    prefs = new Preferences(config.attendee1_username, config.attendee1_password)
    const calendarPrefs = prefs.get('Calendar')
    if (!calendarPrefs.PreventInvitationsWhitelist)
      calendarPrefs.PreventInvitationsWhitelist = {}
    await prefs.set('PreventInvitationsWhitelist', {})
    if (!calendarPrefs.PreventInvitations)
      calendarPrefs.PreventInvitations = 0
    await prefs.set('PreventInvitations', 0)

    webdav = new WebDAV(config.username, config.password)
    webdav_su = new WebDAV(config.superuser, config.superuser_password)
    webdavAttendee1 = new WebDAV(config.attendee1, config.attendee1_password)
    webdavAttendee1Delegate = new WebDAV(config.attendee1_delegate_username, config.attendee1_delegate_password)

    utility = new TestUtility(webdav)
    user = await utility.fetchUserInfo(config.username)
    attendee1 = await utility.fetchUserInfo(config.attendee1)
    attendee1Delegate = await utility.fetchUserInfo(config.attendee1_delegate)

    userCalendar = `/SOGo/dav/${config.username}/Calendar/personal/`
    attendee1Calendar = `/SOGo/dav/${config.attendee1}/Calendar/personal/`
    attendee1DelegateCalendar = `/SOGo/dav/${config.attendee1_delegate}/Calendar/personal/`

    // fetch non existing event to let sogo create the calendars in the db
    await _getEvent(webdav, userCalendar, 'nonexistent', 404)
    await _getEvent(webdavAttendee1, attendee1Calendar, 'nonexistent', 404)
    await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, 'nonexistent', 404)

    // list of ics used by the test.
    // afterAll will loop over this and wipe them in all users' calendar
    icsList = []
  })

  afterAll(async function() {
    await prefs.set('PreventInvitationsWhitelist', {})
    await prefs.set('PreventInvitations', 0)
    // delete all created  events from all users' calendar
    for (const ics of icsList) {
      await webdav_su.deleteObject(userCalendar + ics)
      await webdav_su.deleteObject(attendee1Calendar + ics)
      await webdav_su.deleteObject(attendee1DelegateCalendar + ics)
    }
  })

  it(`Set/get the PreventInvitation pref`, async function() {
    // First accept the invitation
    await prefs.set('PreventInvitations', 0)
    const settings = await prefs.getSettings()
    const { Calendar: { PreventInvitations } = {} } = settings
    expect(PreventInvitations)
      .withContext(`Don't prevent invitations`)
      .toBe(0)
    await _addAttendee()
    await _verifyEvent()
  })

  it(`Set PreventInvitation and don't accept the Invitation`, async function() {
    // Second, enable PreventInviation and refuse it
    await prefs.set('PreventInvitations', 1)
    const settings = await prefs.getSettings()
    const { Calendar: { PreventInvitations } = {} } = settings
    expect(PreventInvitations)
      .withContext(`Prevent invitations is enabled`)
      .toBe(1)
    await _addAttendee(409)
    await _verifyEvent(404)
  })

  it(`Set PreventInvitation add to WhiteList and accept the Invitation`, async function() {
    // First, add the Organiser to the Attendee's whitelist
    await prefs.set('PreventInvitations', 1)
    await prefs.set('PreventInvitationsWhitelist', config.white_listed_attendee)
    const settings = await prefs.getSettings()
    const { Calendar: { PreventInvitations, PreventInvitationsWhitelist } = {} } = settings
    expect(PreventInvitations)
      .withContext(`Prevent invitations is enabled`)
      .toBe(1)
    expect(PreventInvitationsWhitelist)
      .withContext(`Prevent invitations is enabled, one user is whitelisted`)
      .toEqual(config.white_listed_attendee)
    // Second, try again to invite, it should work
    await _addAttendee()
    await _verifyEvent()
  })
})