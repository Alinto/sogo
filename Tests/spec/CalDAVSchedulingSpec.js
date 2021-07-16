import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'
import ICAL from 'ical.js'

describe('create, read, modify, delete tasks for regular user', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdavAttendee1 = new WebDAV(config.attendee1, config.attendee1_password)
  const webdavAttendee1Delegate = new WebDAV(config.attendee1_delegate_username, config.attendee1_delegate_password)

  const utility = new TestUtility(webdav)

  const userCalendar = `/SOGo/dav/${config.username}/Calendar/personal/`
  const attendee1Calendar = `/SOGo/dav/${config.attendee1}/Calendar/personal/`
  const attendee1DelegateCalendar = `/SOGo/dav/${config.attendee1_delegate}/Calendar/personal/`
  const resourceNoOverbookCalendar = `/SOGo/dav/${config.resource_no_overbook}/Calendar/personal/`
  const resourceCanOverbookCalendar = `/SOGo/dav/${config.resource_can_overbook}/Calendar/personal/`

  let user
  let attendee1
  let attendee1Delegate
  let resourceNoOverbook
  let resourceCanOverbook

  let icsList = []

  const _getEvent = async function(client, calendar, filename, expectedCode = 200) {
    const [{ status, raw }] = await client.getEvent(calendar, filename)
    expect(status).toBe(expectedCode)
    if (status <= 300)
      return new ICAL.Component(ICAL.parse(raw))
  }

  const _getAllEvents = async function(client, calendar, expectedCode = 207) {
    const results = await client.propfindCollection(calendar)
    const hrefs = results.filter(r => r.href).map(r => r.href)

    return hrefs
  }

  const _newDateTimeProperty = function(propertyName, dateObject = new Date()) {
    let property = new ICAL.Property(propertyName)
    property.setParameter('tzid', 'America/Montreal')
    property.setValue(ICAL.Time.fromJSDate(dateObject))

    return property
  }

  const _newEvent = function(summary = 'test event', uid = 'test', transp = 'OPAQUE') {
    const vcalendar = new ICAL.Component('vcalendar')
    const vevent = new ICAL.Component('vevent')
    const now = new Date()
    const later = new Date(now.getTime() + 1000*60*60)

    vcalendar.addSubcomponent(vevent)
    vevent.addPropertyWithValue('uid', uid)
    vevent.addPropertyWithValue('summary', summary)
    vevent.addPropertyWithValue('transp', transp)
    vevent.addProperty(_newDateTimeProperty('dtstart', now))
    vevent.addProperty(_newDateTimeProperty('dtend', later))
    vevent.addProperty(_newDateTimeProperty('dtstamp', now))
    vevent.addProperty(_newDateTimeProperty('last-modified', now))
    vevent.addProperty(_newDateTimeProperty('created', now))
    vevent.addPropertyWithValue('class', 'PUBLIC')
    vevent.addPropertyWithValue('sequence', '0')

    return vcalendar
  }

  const _putEvent = async function(client, calendar, filename, event, expectedCode = 201) {
    const response = await client.createCalendarObject(calendar, filename, event.toString())
    expect(response.status)
      .withContext(`Event creation returns code ${expectedCode}`)
      .toBe(expectedCode)
    return response
  }

  const _deleteEvent = async function(client, url, expectedCode) {
    const response = await client.deleteObject(url)
    if (expectedCode)
      expect(response.status).toBe(expectedCode)
    return response
  }

  const _deleteAllEvents = async function(client, calendar, expectedCode = 204) {
    const hrefs = await _getAllEvents(client, calendar)
    for (const href of hrefs) {
      await _deleteEvent(client, href) // ignore returned code
    }
    return hrefs
  }

  beforeAll(async function() {
    user = await utility.fetchUserInfo(config.username)
    attendee1 = await utility.fetchUserInfo(config.attendee1)
    attendee1Delegate = await utility.fetchUserInfo(config.attendee1_delegate)
    resourceNoOverbook = await utility.fetchUserInfo(config.resource_no_overbook)
    resourceCanOverbook = await utility.fetchUserInfo(config.resource_can_overbook)

    // fetch non existing event to let sogo create the calendars in the db
    await _getEvent(webdav, userCalendar, 'nonexistent', 404)
    await _getEvent(webdavAttendee1, attendee1Calendar, 'nonexistent', 404)
    await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, 'nonexistent', 404)
  })

  afterEach(async function() {
    for (const ics of icsList) {
      await _deleteEvent(webdav_su, userCalendar + ics)
      await _deleteEvent(webdav_su, attendee1Calendar + ics)
      await _deleteEvent(webdav_su, attendee1DelegateCalendar + ics)
      await _deleteEvent(webdav_su, resourceCanOverbookCalendar + ics)
      await _deleteEvent(webdav_su, resourceNoOverbookCalendar + ics)
    }
  })

  // CalDAVSchedulingTest

  it('add attendee after event creation', async function() {
    // make sure the event doesn't exist
    const icsName = 'test-add-attendee.ics'
    icsList.push(icsName)
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1. create an event in the organiser's calendar
    let calendar = _newEvent('Test add attendee', 'Test add attendee')
    let event = calendar.getFirstSubcomponent('vevent')
    let organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    await _putEvent(webdav, userCalendar, icsName, calendar)

    // 2. add an attendee
    calendar.addPropertyWithValue('method', 'REQUEST')
    let attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    event.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, calendar, 204)

    // 3. verify that the attendee has the event
    let attendeeCalendar = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)

    // 4. make sure the received event match the original one
    let attendeeEvent = attendeeCalendar.getFirstSubcomponent('vevent')
    expect(attendeeEvent.getFirstProperty('uid').getFirstValue())
      .toBe(event.getFirstProperty('uid').getFirstValue())
  })

  it('Remove attendee after event creation', async function() {
    const icsName = 'test-remove-attendee.ics'
    icsList.push(icsName)

    // make sure the event doesn't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1. create an event in the organiser's calendar
    let calendar = _newEvent('Test uninvite attendee', 'Test uninvite attendee')
    let event = calendar.getFirstSubcomponent('vevent')
    let organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    await _putEvent(webdav, userCalendar, icsName, calendar)

    // keep a copy around for updates without other attributes
    let noAttendeeEvent = ICAL.Component.fromString(calendar.toString())

    // 2. add an attendee
    calendar.addPropertyWithValue('method', 'REQUEST')
    let attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    event.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, calendar, 204)

    // 3. verify that the attendee has the event
    let attendeeCalendar = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)

    // 4. make sure the received event match the original one
    let attendeeEvent = attendeeCalendar.getFirstSubcomponent('vevent')
    expect(attendeeEvent.getFirstProperty('uid').getFirstValue())
      .toBe(event.getFirstProperty('uid').getFirstValue())

    // 5. uninvite the attendee - put the event back without the attendee
    event = noAttendeeEvent.getFirstSubcomponent('vevent')
    event.addProperty(_newDateTimeProperty('last-modified'))
    await _putEvent(webdav, userCalendar, icsName, noAttendeeEvent, 204)

    // 6. verify that the attendee doesn't have the event anymore
    await _getEvent(webdavAttendee1, attendee1Calendar, icsName, 404)
  })

  it('try to overbook a resource', async function() {
    let calendar, event, organizer, attendee

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceNoOverbookCalendar)

    // make sure the events don't exist
    const icsName = 'test-no-overbook.ics'
    icsList.push(icsName)
    await _deleteEvent(webdav, userCalendar + icsName)

    const obIcsName = 'test-no-overbook-overlap.ics'
    icsList.push(obIcsName)
    await _deleteEvent(webdav, userCalendar + obIcsName)

    // 1. create an event in the organiser's calendar
    calendar = _newEvent('Test no overbook', 'Test no overbook')
    event = calendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    event.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, calendar)

    // 2. create a second event overlapping the first one
    calendar = _newEvent('Test no overbook - overlap', 'Test no overbook - overlap')
    event = calendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    event.addProperty(attendee)

    // put the event - should trigger a 409
    await _putEvent(webdav, userCalendar, obIcsName, calendar, 409)
  })

  it('try to overbook a resource - multiplebookings=0', async function() {
    let calendar, event, organizer, attendee

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceCanOverbookCalendar)

    // make sure the events don't exist
    const icsName = 'test-can-overbook.ics'
    icsList.push(icsName)
    await _deleteEvent(webdav, userCalendar + icsName)

    const obIcsName = 'test-can-overbook-overlap.ics'
    icsList.push(obIcsName)
    await _deleteEvent(webdav, userCalendar + obIcsName)

    // 1. create an event in the organiser's calendar
    calendar = _newEvent('Test can overbook', 'Test can overbook')
    event = calendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceCanOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceCanOverbook.email)
    event.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, calendar)

    // 2. create a second event overlapping the first one
    calendar = _newEvent('Test can overbook - overlap', 'Test can overbook - overlap')
    event = calendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceCanOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceCanOverbook.email)
    event.addProperty(attendee)

    // put the event - should be fine since we can overbook this one
    await _putEvent(webdav, userCalendar, obIcsName, calendar)
  })

  it('Resource booking overlap detection - bug #1837', async function() {
    // There used to be some problems with recurring events and resources booking
    // This test implements these edge cases

    // 1. Create recurring event (with resource)
    // 2. Create single event overlaping one instance for the previous event
    //    (should fail)
    // 3. Create recurring event which _doesn't_ overlap the first event
    //    (should be OK, used to fail pre1.3.17)
    // 4. Create recurring event overlapping the previous recurring event
    //    (should fail)

    let calendar, event, organizer, attendee, rrule, recur
    let noOverlapCalendar, nstartdate, nenddate

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceNoOverbookCalendar)

    // make sure the event doesn't exist
    const icsName = 'test-res-overlap-detection.ics'
    icsList.push(icsName)
    await _deleteEvent(webdav, userCalendar + icsName)

    const overlapIcsName = 'test-res-overlap-detection-overlap.ics'
    icsList.push(overlapIcsName)
    await _deleteEvent(webdav, attendee1Calendar + overlapIcsName) // TODO: validate calendar

    const noOverlapRecurringIcsName = 'test-res-overlap-detection-nooverlap.ics'
    icsList.push(noOverlapRecurringIcsName)
    await _deleteEvent(webdav, userCalendar + noOverlapRecurringIcsName)

    const overlapRecurringIcsName = 'test-res-overlap-detection-overlap-recurring.ics'
    icsList.push(overlapRecurringIcsName)
    await _deleteEvent(webdav, userCalendar + overlapRecurringIcsName)

    // 1. create recurring event with resource
    calendar = _newEvent('Recurring event with resource', 'Recurring event with resource')
    event = calendar.getFirstSubcomponent('vevent')
    rrule = new ICAL.Property('rrule')
    recur = new ICAL.Recur({ freq: 'DAILY', count: 5 })
    rrule.setValue(recur)
    event.addProperty(rrule)
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    event.addProperty(attendee)

    // keep a copy around for #3
    noOverlapCalendar = ICAL.Component.fromString(calendar.toString())

    await _putEvent(webdav, userCalendar, icsName, calendar)

    // 2. Create single event overlaping one instance for the previous event
    calendar = _newEvent('Recurring event with resource - overlap', 'Recurring event with resource - overlap')
    event = calendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', attendee1.displayname)
    organizer.setValue(attendee1.email)
    event.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    event.addProperty(attendee)

    // should fail
    await _putEvent(webdavAttendee1, attendee1Calendar, overlapIcsName, calendar, 409)

    // 3. Create recurring event which _doesn't_ overlap the first event
    //    (should be OK, used to fail pre1.3.17)
    // shift the start date to one hour after the original event end time
    event = noOverlapCalendar.getFirstSubcomponent('vevent')
    nstartdate = event.getFirstProperty('dtend').getFirstValue().toJSDate()
    nstartdate = new Date(nstartdate.getTime() + 1000*60*60)
    nenddate = new Date(nstartdate.getTime() + 1000*60*60)
    event.removeProperty('dtstart')
    event.removeProperty('dtend')
    event.addProperty(_newDateTimeProperty('dtstart', nstartdate))
    event.addProperty(_newDateTimeProperty('dtend', nenddate))
    event.updatePropertyWithValue('uid', 'recurring - nooverlap')
    await _putEvent(webdav, userCalendar, noOverlapRecurringIcsName, noOverlapCalendar)

    // 4. Create recurring event overlapping the previous recurring event
    //    should fail with a 409
    nstartdate = event.getFirstProperty('dtstart').getFirstValue().toJSDate()
    nstartdate = new Date(nstartdate.getTime() + 1000*60*5)
    nenddate = new Date(nstartdate.getTime() + 1000*60*60)
    event.removeProperty('dtstart')
    event.removeProperty('dtend')
    event.addProperty(_newDateTimeProperty('dtstart', nstartdate))
    event.addProperty(_newDateTimeProperty('dtend', nenddate))
    event.updatePropertyWithValue('uid', 'recurring - nooverlap')
    await _putEvent(webdav, userCalendar, overlapRecurringIcsName, noOverlapCalendar, 409)
  })

  it('RRULE exception invitation dance', async function() {
    // This workflow is based on what lightning 1.2.1 does
    //  create a reccurring event
    //  add an exception
    //  invite bob to the exception:
    //    bob is declined in the master event
    //    bob needs-action in the exception
    //  bob accepts
    //    bob is declined in the master event
    //    bob is accepted in the exception
    //  the organizer 'uninvites' bob
    //    the event disappears from bob's calendar
    //    bob isn't in the master+exception event

    let vcalendar, vevent, summary, uid, rrule, recur
    let originalStartDate, originalEndDate

    const icsName = 'test-rrule-exception-invitation-dance.ics'
    icsList.push(icsName)

    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, attendee1Calendar + icsName)

    summary = 'Test reccuring exception invite cancel'
    uid = 'Test-recurring-exception-invite-cancel'
    vcalendar = _newEvent(summary, uid)
    vevent = vcalendar.getFirstSubcomponent('vevent')
    rrule = new ICAL.Property('rrule')
    recur = new ICAL.Recur({ freq: 'DAILY', count: 5 })
    rrule.setValue(recur)
    vevent.addProperty(rrule)

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // read the event back from the server
    let vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)

    // 2. Add an exception to the master event and invite attendee1 to it
    vevent = vcalendarOrganizer.getFirstSubcomponent('vevent')
    vevent.removeProperty('last-modified')
    vevent.addProperty(_newDateTimeProperty('last-modified'))
    originalStartDate = vevent.getFirstPropertyValue('dtstart')
    originalEndDate = vevent.getFirstPropertyValue('dtend')

    let veventEx = new ICAL.Component('vevent')
    veventEx.addProperty(_newDateTimeProperty('created'))
    veventEx.addProperty(_newDateTimeProperty('last-modified'))
    veventEx.addProperty(_newDateTimeProperty('dtstamp'))
    veventEx.addPropertyWithValue('uid', uid)
    veventEx.addPropertyWithValue('summary', summary)
    veventEx.addPropertyWithValue('transp', 'OPAQUE')
    veventEx.addPropertyWithValue('description', 'Exception')
    veventEx.addPropertyWithValue('sequence', '1')
    veventEx.addProperty(vevent.getFirstProperty('dtstart'))
    veventEx.addProperty(vevent.getFirstProperty('dtend'))
    // out of laziness, add the exception for the first occurence of the event
    let recurrenceId = new ICAL.Property('recurrence-id')
    recurrenceId.setParameter('tzid', originalStartDate.timezone)
    recurrenceId.setValue(originalStartDate)
    veventEx.addProperty(recurrenceId)

    // 2.1 Add attendee1 and organizer to the exception
    let organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setParameter('partstat', 'ACCEPTED')
    organizer.setValue(user.email)
    veventEx.addProperty(organizer)
    let attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('role', 'REQ-PARTICIPANT')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    veventEx.addProperty(attendee)
    vcalendarOrganizer.addSubcomponent(veventEx)

    await _putEvent(webdav, userCalendar, icsName, vcalendarOrganizer, 204)

    // 3. Make sure the attendee got the event
    let vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    let vevents = vcalendarAttendee.getAllSubcomponents('vevent')
    expect(vevents.length)
      .withContext('vEvents count in the calendar of the attendee')
      .toBe(1)
    vevent = vevents[0]
    expect(vevent.getFirstPropertyValue('recurrence-id'))
      .withContext('The vEvent of the attendee has a RECURRENCE-ID')
      .toBeTruthy()
    let attendees = vevent.getAllProperties('attendee')
    expect(attendees.length)
      .withContext('Attendees count in the calendar of the attendee')
      .toBe(1)
    attendee = attendees[0]
    expect(attendee.getParameter('partstat'))
      .withContext('Partstat of attendee in calendar of the attendee')
      .toBe('NEEDS-ACTION')

    // 4. attendee accepts invitation
    attendee.setParameter('partstat', 'ACCEPTED')
    await _putEvent(webdavAttendee1, attendee1Calendar, icsName, vcalendarAttendee, 204)

    // fetch the organizer's event
    vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)
    vevents = vcalendarOrganizer.getAllSubcomponents('vevent')
    expect(vevents.length)
      .withContext('vEvents count in the calendar of the organizer')
      .toBe(2)
    let veventMaster, veventException
    for (vevent of vevents) {
      if (vevent.getFirstPropertyValue('recurrence-id')) {
        veventException = vevent
      } else {
        veventMaster = vevent
      }
    }

    // make sure sogo doesn't duplicate attendees
    expect(veventMaster.getAllProperties('attendee').length).toBe(0)
    expect(veventException.getAllProperties('attendee').length).toBe(1)

    // 5. Make sure organizer got the accept for the exception and
	  // that the attendee is still declined in the master
    attendee = veventException.getAllProperties('attendee')[0]
    expect(attendee.getParameter('partstat'))
      .withContext('Partstat of attendee in the calendar of the organizer')
      .toBe('ACCEPTED')

    // 6. delete the attendee from the organizer event (uninvite)
	  //    The event should be deleted from the attendee's calendar
    vcalendarOrganizer.removeSubcomponent(veventException)
    await _putEvent(webdav, userCalendar, icsName, vcalendarOrganizer, 204)
    await _getEvent(webdavAttendee1, attendee1Calendar, icsName, 404)
  })
})