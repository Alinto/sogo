import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'
import ICAL from 'ical.js'

describe('CalDAV Scheduling', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdavAttendee1 = new WebDAV(config.attendee1_username, config.attendee1_password)
  const webdavAttendee1Delegate = new WebDAV(config.attendee1_delegate_username, config.attendee1_delegate_password)

  const utility = new TestUtility(webdav)

  const userCalendar = `/SOGo/dav/${config.username}/Calendar/personal/`
  const attendee1Calendar = `/SOGo/dav/${config.attendee1_username}/Calendar/personal/`
  const attendee1DelegateCalendar = `/SOGo/dav/${config.attendee1_delegate_username}/Calendar/personal/`
  const resourceNoOverbookCalendar = `/SOGo/dav/${config.resource_no_overbook}/Calendar/personal/`
  const resourceCanOverbookCalendar = `/SOGo/dav/${config.resource_can_overbook}/Calendar/personal/`

  let user
  let attendee1
  let attendee1Delegate
  let resourceNoOverbook
  let resourceCanOverbook

  let icsList = []

  const _getEvent = async function(client, calendarName, filename, expectedCode = 200) {
    const [{ status, raw }] = await client.getObject(calendarName, filename)
    expect(status).toBe(expectedCode)
    if (status <= 300)
      return new ICAL.Component(ICAL.parse(raw))
  }

  const _getAllEvents = async function(client, calendarName, expectedCode = 207) {
    const results = await client.propfindCollection(calendarName)
    const hrefs = results.filter(r => r.href).map(r => r.href)

    return hrefs
  }

  const _putEvent = async function(client, calendarName, filename, event, expectedCode = 201) {
    const response = await client.createCalendarObject(calendarName, filename, event.toString())
    expect(response.status)
      .withContext(`Event creation returns code ${expectedCode}`)
      .toBe(expectedCode)
    return response
  }

  const _postEvent = async function(client, outbox, vcalendar, originator, recipients, expectedCode = 200) {
    const response = await client.postCaldav(outbox, vcalendar, originator, recipients)
    expect(response.status)
      .withContext(`Event post returns code ${expectedCode}`)
      .toBe(expectedCode)
    return response
  }

  const _deleteEvent = async function(client, url, expectedCode) {
    const response = await client.deleteObject(url)
    if (expectedCode)
      expect(response.status).toBe(expectedCode)
    return response
  }

  const _deleteAllEvents = async function(client, calendarName, expectedCode = 204) {
    const hrefs = await _getAllEvents(client, calendarName)
    for (const href of hrefs) {
      await _deleteEvent(client, href) // ignore returned code
    }
    return hrefs
  }

  const _compareAttendees = function(vcalendar1, vcalendar2) {
    const vevent1 = vcalendar1.getFirstSubcomponent('vevent')
    const vevent2 = vcalendar2.getFirstSubcomponent('vevent')
    const attendeeToString = function(a) {
      const email = a.getFirstValue()
      const partstat = a.getParameter('partstat')
      const delegatedto = a.getParameter('delegated-to') || '(none)'
      const delegatedfrom = a.getParameter('delegated-from') || '(none)'
      return `${email}/${partstat}/${delegatedto}/${delegatedfrom}`
    }
    const attendees1 = vevent1.getAllProperties('attendee').map(attendeeToString)
    const attendees2 = vevent2.getAllProperties('attendee').map(attendeeToString)

    expect(attendees1.length)
      .withContext(`'vcalendar1' has attendees`)
      .toBeGreaterThan(0)
    expect(attendees2.length)
    .withContext(`'vcalendar2' has attendees`)
    .toBeGreaterThan(0)
    expect(attendees1.length)
    .withContext(`'vcalendar1' and 'vcalendar2' have the same number of attendees`)
    .toBe(attendees2.length)

    for (let attendee of attendees1) {
      expect(attendees2.indexOf(attendee))
        .withContext(`${attendee} from 'vcalendar1' is found in 'vcalendar2`)
        .toBeGreaterThanOrEqual(0)
    }
  }

  beforeAll(async function() {
    user = await utility.fetchUserInfo(config.username)
    attendee1 = await utility.fetchUserInfo(config.attendee1_username)
    attendee1Delegate = await utility.fetchUserInfo(config.attendee1_delegate_username)
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
    const icsName = 'test-add-attendee.ics'
    icsList.push(icsName)

    let vcalendar, vcalendarAttendee
    let vevent, veventAttendee, organizer, attendee

    // make sure the event doesn't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1. create an event in the organizer's calendar
    vcalendar = utility.createCalendar('Test add attendee', 'Test add attendee')
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
    await _putEvent(webdav, userCalendar, icsName, vcalendar, 204)

    // 3. verify that the attendee has the event
    vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)

    // 4. make sure the received event match the original one
    veventAttendee = vcalendarAttendee.getFirstSubcomponent('vevent')
    expect(veventAttendee.getFirstProperty('uid').getFirstValue())
      .withContext(`UID in organizer's calendar and attendees's calendar are identical`)
      .toBe(vevent.getFirstProperty('uid').getFirstValue())
  })

  it('Remove attendee after event creation', async function() {
    const icsName = 'test-remove-attendee.ics'
    icsList.push(icsName)

    let vcalendar, vcalendarNoAttendee, vcalendarAttendee
    let vevent, veventAttendee, organizer, attendee

    // make sure the event doesn't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1. create an event in the organizer's calendar
    vcalendar = utility.createCalendar('Test uninvite attendee', 'Test uninvite attendee')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // keep a copy around for updates without other attributes
    vcalendarNoAttendee = ICAL.Component.fromString(vcalendar.toString())

    // 2. add an attendee
    vcalendar.addPropertyWithValue('method', 'REQUEST')
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    vevent.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, vcalendar, 204)

    // 3. verify that the attendee has the event
    vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)

    // 4. make sure the received event match the original one
    veventAttendee = vcalendarAttendee.getFirstSubcomponent('vevent')
    expect(veventAttendee.getFirstProperty('uid').getFirstValue())
      .toBe(vevent.getFirstProperty('uid').getFirstValue())

    // 5. uninvite the attendee - put the event back without the attendee
    vevent = vcalendarNoAttendee.getFirstSubcomponent('vevent')
    vevent.addProperty(utility.createDateTimeProperty('last-modified'))
    await _putEvent(webdav, userCalendar, icsName, vcalendarNoAttendee, 204)

    // 6. verify that the attendee doesn't have the event anymore
    await _getEvent(webdavAttendee1, attendee1Calendar, icsName, 404)
  })

  it('try to overbook a resource', async function() {
    const icsName = 'test-no-overbook.ics'
    const obIcsName = 'test-no-overbook-overlap.ics'
    icsList.push(icsName, obIcsName)

    let vcalendar, vevent, organizer, attendee

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceNoOverbookCalendar)

    // make sure the events don't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, userCalendar + obIcsName)

    // 1. create an event in the organizer's calendar
    vcalendar = utility.createCalendar('Test no overbook', 'Test no overbook')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    vevent.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. create a second event overlapping the first one
    vcalendar = utility.createCalendar('Test no overbook - overlap', 'Test no overbook - overlap')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    vevent.addProperty(attendee)

    // put the event - should trigger a 409
    await _putEvent(webdav, userCalendar, obIcsName, vcalendar, 409)
  })

  it('try to overbook a resource - multiplebookings=0', async function() {
    const icsName = 'test-can-overbook.ics'
    const obIcsName = 'test-can-overbook-overlap.ics'
    icsList.push(icsName, obIcsName)

    let vcalendar, vevent, organizer, attendee

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceCanOverbookCalendar)

    // make sure the events don't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, userCalendar + obIcsName)

    // 1. create an event in the organizer's calendar
    vcalendar = utility.createCalendar('Test can overbook', 'Test can overbook')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceCanOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceCanOverbook.email)
    vevent.addProperty(attendee)
    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. create a second event overlapping the first one
    vcalendar = utility.createCalendar('Test can overbook - overlap', 'Test can overbook - overlap')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceCanOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceCanOverbook.email)
    vevent.addProperty(attendee)

    // put the event - should be fine since we can overbook this one
    await _putEvent(webdav, userCalendar, obIcsName, vcalendar)
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

    const icsName = 'test-res-overlap-detection.ics'
    const overlapIcsName = 'test-res-overlap-detection-overlap.ics'
    icsList.push(icsName, overlapIcsName)

    let vcalendar, vcalendarNoOverlap
    let vevent, organizer, attendee, rrule, recur, nstartdate, nenddate

    // make sure there are no events in the resource calendar
    await _deleteAllEvents(webdav_su, resourceNoOverbookCalendar)

    // make sure the event doesn't exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, attendee1Calendar + overlapIcsName)

    const noOverlapRecurringIcsName = 'test-res-overlap-detection-nooverlap.ics'
    icsList.push(noOverlapRecurringIcsName)
    await _deleteEvent(webdav, userCalendar + noOverlapRecurringIcsName)

    const overlapRecurringIcsName = 'test-res-overlap-detection-overlap-recurring.ics'
    icsList.push(overlapRecurringIcsName)
    await _deleteEvent(webdav, userCalendar + overlapRecurringIcsName)

    // 1. create recurring event with resource
    vcalendar = utility.createCalendar('Recurring event with resource', 'Recurring event with resource')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    rrule = new ICAL.Property('rrule')
    recur = new ICAL.Recur({ freq: 'DAILY', count: 5 })
    rrule.setValue(recur)
    vevent.addProperty(rrule)
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    vevent.addProperty(attendee)

    // keep a copy around for #3
    vcalendarNoOverlap = ICAL.Component.fromString(vcalendar.toString())

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. Create single event overlaping one instance for the previous event
    vcalendar = utility.createCalendar('Recurring event with resource - overlap', 'Recurring event with resource - overlap')
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', attendee1.displayname)
    organizer.setValue(attendee1.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', resourceNoOverbook.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(resourceNoOverbook.email)
    vevent.addProperty(attendee)

    // should fail
    await _putEvent(webdavAttendee1, attendee1Calendar, overlapIcsName, vcalendar, 409)

    // 3. Create recurring event which _doesn't_ overlap the first event
    //    (should be OK, used to fail pre1.3.17)
    // shift the start date to one hour after the original event end time
    vevent = vcalendarNoOverlap.getFirstSubcomponent('vevent')
    nstartdate = vevent.getFirstProperty('dtend').getFirstValue().toJSDate()
    nstartdate = new Date(nstartdate.getTime() + 1000*60*60)
    nenddate = new Date(nstartdate.getTime() + 1000*60*60)
    vevent.removeProperty('dtstart')
    vevent.removeProperty('dtend')
    vevent.addProperty(utility.createDateTimeProperty('dtstart', nstartdate))
    vevent.addProperty(utility.createDateTimeProperty('dtend', nenddate))
    vevent.updatePropertyWithValue('uid', 'recurring - nooverlap')
    await _putEvent(webdav, userCalendar, noOverlapRecurringIcsName, vcalendarNoOverlap)

    // 4. Create recurring event overlapping the previous recurring event
    //    should fail with a 409
    nstartdate = vevent.getFirstProperty('dtstart').getFirstValue().toJSDate()
    nstartdate = new Date(nstartdate.getTime() + 1000*60*5)
    nenddate = new Date(nstartdate.getTime() + 1000*60*60)
    vevent.removeProperty('dtstart')
    vevent.removeProperty('dtend')
    vevent.addProperty(utility.createDateTimeProperty('dtstart', nstartdate))
    vevent.addProperty(utility.createDateTimeProperty('dtend', nenddate))
    vevent.updatePropertyWithValue('uid', 'recurring - nooverlap')
    await _putEvent(webdav, userCalendar, overlapRecurringIcsName, vcalendarNoOverlap, 409)
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

    const icsName = 'test-rrule-exception-invitation-dance.ics'
    icsList.push(icsName)

    let vcalendar, vcalendarOrganizer, vcalendarAttendee, vevents, vevent, veventMaster, veventException
    let recurrenceId, summary, uid, organizer, attendees, attendee, rrule, recur, originalStartDate

    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, attendee1Calendar + icsName)

    // 1.  create a recurring event in the organizer's calendar
    summary = 'Test reccuring exception invite cancel'
    uid = 'Test-recurring-exception-invite-cancel'
    vcalendar = utility.createCalendar(summary, uid)
    vevent = vcalendar.getFirstSubcomponent('vevent')
    rrule = new ICAL.Property('rrule')
    recur = new ICAL.Recur({ freq: 'DAILY', count: 5 })
    rrule.setValue(recur)
    vevent.addProperty(rrule)

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // read the event back from the server
    vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)

    // 2. Add an exception to the master event and invite attendee1 to it
    vevent = vcalendarOrganizer.getFirstSubcomponent('vevent')
    vevent.removeProperty('last-modified')
    vevent.addProperty(utility.createDateTimeProperty('last-modified'))
    originalStartDate = vevent.getFirstPropertyValue('dtstart')

    veventException = new ICAL.Component('vevent')
    veventException.addProperty(utility.createDateTimeProperty('created'))
    veventException.addProperty(utility.createDateTimeProperty('last-modified'))
    veventException.addProperty(utility.createDateTimeProperty('dtstamp'))
    veventException.addPropertyWithValue('uid', uid)
    veventException.addPropertyWithValue('summary', summary)
    veventException.addPropertyWithValue('transp', 'OPAQUE')
    veventException.addPropertyWithValue('description', 'Exception')
    veventException.addPropertyWithValue('sequence', '1')
    veventException.addProperty(vevent.getFirstProperty('dtstart'))
    veventException.addProperty(vevent.getFirstProperty('dtend'))
    // out of laziness, add the exception for the first occurence of the event
    recurrenceId = new ICAL.Property('recurrence-id')
    recurrenceId.setParameter('tzid', originalStartDate.timezone)
    recurrenceId.setValue(originalStartDate)
    veventException.addProperty(recurrenceId)

    // 2.1 Add attendee1 and organizer to the exception
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setParameter('partstat', 'ACCEPTED')
    organizer.setValue(user.email)
    veventException.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('role', 'REQ-PARTICIPANT')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    veventException.addProperty(attendee)
    vcalendarOrganizer.addSubcomponent(veventException)

    await _putEvent(webdav, userCalendar, icsName, vcalendarOrganizer, 204)

    // 3. Make sure the attendee got the event
    vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    vevents = vcalendarAttendee.getAllSubcomponents('vevent')
    expect(vevents.length)
      .withContext('vEvents count in the calendar of the attendee')
      .toBe(1)
    vevent = vevents[0]
    expect(vevent.getFirstPropertyValue('recurrence-id'))
      .withContext(`The vEvent of the attendee has a RECURRENCE-ID`)
      .toBeTruthy()
    attendees = vevent.getAllProperties('attendee')
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

  it ('RRULE invitation delete exdate dance', async function() {
    // Workflow:
    //   Create an recurring event and invite Bob
    //   Add an exdate to the master event
    //   Verify that the exdate has propagated to Bob's calendar
    //   Add an exdate to bob's version of the event
    //   Verify that an exception has been created in the org's calendar and that bob is 'declined'

    const icsName = 'test-rrule-invitation-deleted-exdate-dance.ics'
    icsList.push(icsName)

    let summary, uid, rrule, recur, organizer, attendees, attendee, nstartdate, exdate, offset
    let vcalendar, vcalendarOrganizer, vcalendarAttendee, vevent, vevents, veventMaster, veventException

    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1. create a recurring event in the organizer's calendar
    summary = 'Test rrule invitation deleted exdate dance'
    uid = 'Test-rrule-invitation-deleted-exdate-dance'
    vcalendar = utility.createCalendar(summary, uid)
    vevent = vcalendar.getFirstSubcomponent('vevent')
    rrule = new ICAL.Property('rrule')
    recur = new ICAL.Recur({ freq: 'DAILY', count: 5 })
    rrule.setValue(recur)
    vevent.addProperty(rrule)
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setParameter('partstat', 'ACCEPTED')
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('role', 'REQ-PARTICIPANT')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    vevent.addProperty(attendee)

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. Make sure the attendee got it
    await _getEvent(webdavAttendee1, attendee1Calendar, icsName)

    // 3. Add exdate to master event
    vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)
    vevent = vcalendarOrganizer.getFirstSubcomponent('vevent')
    nstartdate = vevent.getFirstProperty('dtstart').getFirstValue().toJSDate()
    offset = nstartdate.getTimezoneOffset()
    exdate = new Date(nstartdate.getTime() - offset*60*1000)
    exdate = ICAL.Time.fromJSDate(exdate)
    exdate = exdate.convertToZone(ICAL.Timezone.utcTimezone)
    vevent.addPropertyWithValue('exdate', exdate)

    await _putEvent(webdav, userCalendar, icsName, vcalendarOrganizer, 204)

    // 4. make sure the attendee has the exdate
    vcalendarAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    vevent = vcalendarAttendee.getFirstSubcomponent('vevent')
    expect(vevent.getFirstProperty('exdate').getFirstValue().toICALString())
      .withContext(`Exdate is in attendee's calendar`)
      .toEqual(exdate.toICALString())

    // 5. Create an exdate in the attendee's calendar
    exdate = new Date(nstartdate.getTime() + offset*60*1000 + 1000*60*60*24*2)
    exdate = ICAL.Time.fromJSDate(exdate)
    exdate = exdate.convertToZone(ICAL.Timezone.utcTimezone)
    vevent.addPropertyWithValue('exdate', exdate)
    vevent.removeProperty('last-modified')
    vevent.addProperty(utility.createDateTimeProperty('last-modified'))

    await _putEvent(webdavAttendee1, attendee1Calendar, icsName, vcalendarAttendee, 204)

    // 6. Make sure the attendee is:
    //  needs-action in master event
    //  declined in the new exception created by the exdate above
    vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)
    vevents = vcalendarOrganizer.getAllSubcomponents('vevent')
    for (vevent of vevents) {
      if (vevent.getFirstPropertyValue('recurrence-id'))
        veventException = vevent
      else
        veventMaster = vevent
    }

    attendees = veventMaster.getAllProperties('attendee')
    expect(attendees.length)
      .withContext('Attendees count in the calendar of the master event')
      .toBe(1)
    attendee = attendees[0]
    expect(attendee.getParameter('partstat'))
      .withContext('Partstat of attendee is need-actions for the master event')
      .toBe('NEEDS-ACTION')

    expect(veventException)
    .withContext(`The vCalendar of the organizer has a vEvent with a recurrence-id: ${vcalendarOrganizer}`)
    .toBeTruthy()
    attendees = veventException.getAllProperties('attendee')
    expect(attendees.length)
      .withContext('Attendees count in the calendar of the exception event')
      .toBe(1)
    attendee = attendees[0]
    expect(attendee.getParameter('partstat'))
      .withContext('Partstat of attendee is declined for the exception')
      .toBe('DECLINED')
  })

  it('iCal organizer is attendee - bug #1839', async function() {
    const icsName = 'test-organizer-is-attendee.ics'
    icsList.push(icsName)

    let summary, uid
    let vcalendar, vcalendarOrganizer, vevent, organizer, attendee, attendees

    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)

    // 1.  create a recurring event in the organizer's calendar
    summary = 'Test organizer is attendee'
    uid = 'Test-organizer-is-attendee'
    vcalendar = utility.createCalendar(summary, uid)
    vevent = vcalendar.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setParameter('partstat', 'ACCEPTED')
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('role', 'REQ-PARTICIPANT')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    vevent.addProperty(attendee)

    // 1.1 add the organizer as an attendee
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', user.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('role', 'REQ-PARTICIPANT')
    attendee.setParameter('partstat', 'ACCEPTED')
    attendee.setValue(user.email)
    vevent.addProperty(attendee)
    // console.debug(`Test organizer is attendee =\n${vcalendar.toString()}`)

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // 2. Fetch the event and make sure the organizer is not in the attendee list anymore
    vcalendarOrganizer = await _getEvent(webdav, userCalendar, icsName)
    vevent = vcalendarOrganizer.getFirstSubcomponent('vevent')
    attendees = vevent.getAllProperties('attendee')
    for (attendee of attendees) {
      expect(attendee.getFirstValue())
        .withContext(`Organizer is not an attendee`)
        .not.toBe(user.email)
    }
  })

  it('PUT 2 events with the same UID - bug #1853', async function () {
    const icsName = 'test-same-uid.ics'
    const conflictIcsName = 'test-same-uid-conflict.ics'
    icsList.push(icsName, conflictIcsName)

    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdav, userCalendar + conflictIcsName)

    let summary, uid
    let vcalendar

    // 1. create simple event
    summary = 'Test same uid'
    uid = 'Test-same-uid'
    vcalendar = utility.createCalendar(summary, uid)

    await _putEvent(webdav, userCalendar, icsName, vcalendar)

    // PUT the same event with a new filename - should trigger a 409
    await _putEvent(webdav, userCalendar, conflictIcsName, vcalendar, 409)
  })

  it('invitation delegation', async function () {
    const icsName = 'test-delegation.ics'
    icsList.push(icsName)

    let vcalendarInvitation, vcalendarInvitationAttendee, vcalendarInvitationDelegate, vcalendarInvitationOrganizer, vcalendarCancellation
    let vevent, organizer, attendee, attendees, delegate

    // the invitation must not exist
    await _deleteEvent(webdav, userCalendar + icsName)
    await _deleteEvent(webdavAttendee1, attendee1Calendar + icsName)
    await _deleteEvent(webdavAttendee1Delegate, attendee1DelegateCalendar + icsName)

    // 1. org -> attendee => org: 1, attendee: 1 (pst=N-A), delegate: 0
    vcalendarInvitation = utility.createCalendar()
    vcalendarInvitation.addPropertyWithValue('method', 'REQUEST')
    vevent = vcalendarInvitation.getFirstSubcomponent('vevent')
    organizer = new ICAL.Property('organizer')
    organizer.setParameter('cn', user.displayname)
    organizer.setValue(user.email)
    vevent.addProperty(organizer)
    attendee = new ICAL.Property('attendee')
    attendee.setParameter('cn', attendee1.displayname)
    attendee.setParameter('rsvp', 'TRUE')
    attendee.setParameter('partstat', 'NEEDS-ACTION')
    attendee.setValue(attendee1.email)
    vevent.addProperty(attendee)

    await _postEvent(webdav, userCalendar, vcalendarInvitation, user.email, [attendee1.email])

    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdav, userCalendar, icsName, vcalendarInvitation)

    vcalendarInvitationAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    _compareAttendees(vcalendarInvitationAttendee, vcalendarInvitation)

    // 2. attendee delegates to delegate
    //    => org: 1 (updated), attendee: 1 (updated,pst=D),
    //       delegate: 1 (new,pst=N-A)
    vcalendarInvitation.addPropertyWithValue('method', 'REQUEST')
    attendee.setParameter('partstat', 'DELEGATED')
    attendee.setParameter('delegated-to', attendee1Delegate.email)
    delegate = new ICAL.Property('attendee')
    delegate.setParameter('delegated-from', attendee1.email)
    delegate.setParameter('cn', attendee1Delegate.displayname)
    delegate.setParameter('rsvp', 'TRUE')
    delegate.setParameter('partstat', 'NEEDS-ACTION')
    delegate.setValue(attendee1Delegate.email)
    vevent.addProperty(delegate)

    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarInvitation, attendee1.email, [attendee1Delegate.email])

    vcalendarInvitation.updatePropertyWithValue('method', 'REPLY')
    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarInvitation, attendee1.email, [user.email])

    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdavAttendee1, attendee1Calendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationDelegate = await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName)
    _compareAttendees(vcalendarInvitationDelegate, vcalendarInvitation)

    // 3. delegate accepts
    //    => org: 1 (updated), attendee: 1 (updated,pst=D),
    //       delegate: 1 (accepted,pst=A)
    vcalendarInvitation.updatePropertyWithValue('method', 'REQUEST')
    delegate.setParameter('partstat', 'ACCEPTED')
    await _postEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, vcalendarInvitation, attendee1Delegate.email, [user.email, attendee1.email])
    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationOrganizer = await _getEvent(webdav, userCalendar, icsName)
    _compareAttendees(vcalendarInvitationOrganizer, vcalendarInvitation)

    // 4. attendee accepts
    // => org: 1 (updated), attendee: 1 (updated,pst=A),
    //    delegate: 0 (cancelled, deleted)
    vcalendarCancellation = utility.createCalendar()
    vcalendarCancellation.addPropertyWithValue('method', 'CANCEL')
    attendees = vevent.getAllProperties('attendee')
    vevent = vcalendarCancellation.getFirstSubcomponent('vevent')
    vevent.updatePropertyWithValue('sequence', '1')
    vevent.addProperty(ICAL.Property.fromString(organizer.toICALString()))
    for (attendee of attendees) {
      vevent.addProperty(ICAL.Property.fromString(attendee.toICALString()))
    }
    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarCancellation, attendee1.email, [attendee1Delegate.email])

    vevent = vcalendarInvitation.getFirstSubcomponent('vevent')
    for (attendee of attendees) {
      if (attendee.getParameter('delegated-to')) {
        // console.debug(`delegated-to = ${attendee.toICALString()}`)
        attendee.removeParameter('delegated-to')
        attendee.setParameter('partstat', 'ACCEPTED')
      } else {
        // Remove delegate attendee
        vevent.removeProperty(attendee)
      }
    }
    vcalendarInvitation.addPropertyWithValue('method', 'REPLY')
    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarInvitation, attendee1.email, [user.email])

    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdavAttendee1, attendee1Calendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationOrganizer = await _getEvent(webdav, userCalendar, icsName)
    _compareAttendees(vcalendarInvitationOrganizer, vcalendarInvitation)

    // vcalendarInvitationDelegate = await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName, 404)

    // 5. org updates inv.
    //    => org: 1 (updated), attendee: 1 (updated), delegate: 0
    vcalendarInvitation.updatePropertyWithValue('method', 'REQUEST')
    vevent.updatePropertyWithValue('sequence', '1')
    vevent.updatePropertyWithValue('last-modified', utility.createDateTimeProperty('last-modified').getFirstValue())
    vevent.updatePropertyWithValue('dtstamp', utility.createDateTimeProperty('dtstamp').getFirstValue())
    attendee = vevent.getFirstProperty('attendee')
    attendee.setParameter('partstat', 'NEEDS-ACTION')

    await _postEvent(webdav, userCalendar, vcalendarInvitation, user.email, [attendee1.email])

    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdav, userCalendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    _compareAttendees(vcalendarInvitationAttendee, vcalendarInvitation)

    // 6. attendee delegates to delegate
    //    => org: 1 (updated), attendee: 1 (updated), delegate: 1 (new)
    vcalendarInvitation.updatePropertyWithValue('method', 'REQUEST')
    attendee.setParameter('partstat', 'DELEGATED')
    attendee.setParameter('delegated-to', attendee1Delegate.email)
    delegate = new ICAL.Property('attendee')
    delegate.setParameter('delegated-from', attendee1.email)
    delegate.setParameter('cn', attendee1Delegate.displayname)
    delegate.setParameter('rsvp', 'TRUE')
    delegate.setParameter('partstat', 'NEEDS-ACTION')
    delegate.setValue(attendee1Delegate.email)
    vevent.addProperty(delegate)

    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarInvitation, attendee1.email, [attendee1Delegate.email])
    vcalendarInvitation.updatePropertyWithValue('method', 'REPLY')
    await _postEvent(webdavAttendee1, attendee1Calendar, vcalendarInvitation, attendee1.email, [user.email])
    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdavAttendee1, attendee1Calendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationOrganizer = await _getEvent(webdav, userCalendar, icsName)
    _compareAttendees(vcalendarInvitationOrganizer, vcalendarInvitation)

    vcalendarInvitationDelegate = await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName)
    _compareAttendees(vcalendarInvitationDelegate, vcalendarInvitation)

    // 7. delegate accepts
    //    => org: 1 (updated), attendee: 1 (updated), delegate: 1 (accepted)
    vcalendarInvitation.updatePropertyWithValue('method', 'REPLY')
    delegate.setParameter('partstat', 'ACCEPTED')
    await _postEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, vcalendarInvitation, attendee1Delegate.email, [user.email, attendee1.email])
    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationOrganizer = await _getEvent(webdav, userCalendar, icsName)
    _compareAttendees(vcalendarInvitationOrganizer, vcalendarInvitation)
    vcalendarInvitationAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    _compareAttendees(vcalendarInvitationAttendee, vcalendarInvitation)

    // 8. org updates inv.
    //    => org: 1 (updated), attendee: 1 (updated,partstat unchanged),
    //       delegate: 1 (updated,partstat reset)
    vcalendarInvitation.updatePropertyWithValue('method', 'REQUEST')
    vevent.updatePropertyWithValue('sequence', '2')
    vevent.updatePropertyWithValue('last-modified', utility.createDateTimeProperty('last-modified').getFirstValue())
    vevent.updatePropertyWithValue('dtstamp', utility.createDateTimeProperty('dtstamp').getFirstValue())
    delegate.setParameter('partstat', 'NEEDS-ACTION')

    await _postEvent(webdav, userCalendar, vcalendarInvitation, user.email, [attendee1.email, attendee1DelegateCalendar.email])

    vcalendarInvitation.removeProperty('method')
    await _putEvent(webdav, userCalendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName)
    _compareAttendees(vcalendarInvitationAttendee, vcalendarInvitation)

    vcalendarInvitationDelegate = await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName)
    _compareAttendees(vcalendarInvitationDelegate, vcalendarInvitation)

    // 9. org cancels invitation
    //    => org: 1 (updated), attendee: 0 (cancelled, deleted),
    //       delegate: 0 (cancelled, deleted)
    vcalendarInvitation.updatePropertyWithValue('method', 'CANCEL')
    vevent.updatePropertyWithValue('sequence', '3')
    vevent.updatePropertyWithValue('last-modified', utility.createDateTimeProperty('last-modified').getFirstValue())
    vevent.updatePropertyWithValue('dtstamp', utility.createDateTimeProperty('dtstamp').getFirstValue())

    await _postEvent(webdav, userCalendar, vcalendarInvitation, user.email, [attendee1.email, attendee1DelegateCalendar.email])

    vcalendarInvitation.removeProperty('method')
    vevent.removeProperty(attendee)
    vevent.removeProperty(delegate)
    await _putEvent(webdav, userCalendar, icsName, vcalendarInvitation, 204)

    vcalendarInvitationAttendee = await _getEvent(webdavAttendee1, attendee1Calendar, icsName, 404)
    vcalendarInvitationDelegate = await _getEvent(webdavAttendee1Delegate, attendee1DelegateCalendar, icsName, 404)
  })
})