import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

describe('DAVCalendarSuperUserAcl', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const utility = new TestUtility(webdav)

  const event_template = `BEGIN:VCALENDAR
PRODID:-//Inverse//Event Generator//EN
VERSION:2.0
BEGIN:VEVENT
SEQUENCE:0
TRANSP:OPAQUE
UID:12345-%(class)-%(filename)
SUMMARY:%(class) event (orig. title)
DTSTART:20090805T100000Z
DTEND:20090805T140000Z
CLASS:%(class)
DESCRIPTION:%(class) description
LOCATION:location
%(organizer_line)%(attendee_line)CREATED:20090805T100000Z
DTSTAMP:20090805T100000Z
END:VEVENT
END:VCALENDAR`

  const resource = `/SOGo/dav/${config.subscriber_username}/Calendar/test-dav-superuser-acl/`
  const filename = 'suevent.ics'

  const event = utility.formatTemplate(event_template, {
    'class': 'PUBLIC',
    'filename': filename
  })

  beforeAll(async function() {
    await webdav_su.deleteObject(resource)
    await webdav_su.makeCalendar(resource)
  })

  afterAll(async function() {
    await webdav_su.deleteObject(resource)
  })

  // DAVCalendarSuperUserAclTest.testSUAccess
  it("create, read, modify, delete for superuser", async function() {
    let result, results

    // 1. Create

    result = await webdav_su.createCalendarObject(resource, filename, event)
    expect(result.status)
      .withContext('Event creation returns status code 201')
      .toBe(201)

    // 2. Read - GET

    results = await webdav_su.getObject(resource, filename)
    expect(results.length).toBe(1)
    expect(results[0].raw.replace(/\r\n/g,'\n')).toBe(event)

    // 2. Read - PROPFIND calendar-data

    results = await webdav_su.propfindEvent(resource + filename)
    expect(results.length).toBe(2) // suevent.ics + suevent.ics/master
    expect(results.find(o => {
      if (o.href == resource + filename) {
        expect(o.props.calendarData.replace(/\r\n/g,'\n')).toBe(event)
        return true
      }
      return false
    })).toBeTruthy()

    // 2. Read - REPORT calendar-multiget

    results = await webdav_su.calendarMultiGet(resource, filename)
    expect(results.length).toBe(1)
    expect(results.find(o => {
      if (o.href == resource + filename) {
        expect(o.props.calendarData.replace(/\r\n/g,'\n')).toBe(event)
        return true
      }
      return false
    })).toBeTruthy()

    // 2. Read - webdav-sync

    results = await webdav_su.syncCollection(resource)
    expect(results.length).toBe(1)
    expect(results.find(o => {
      expect(o.status).toBe(207)
      if (o.href == resource + filename) {
        expect(o.props.calendarData.replace(/\r\n/g,'\n')).toBe(event)
        return true
      }
      return false
    })).toBeTruthy()

    // 3. Modify

    const classes = ['CONFIDENTIAL', 'PRIVATE', 'PUBLIC']
    for (const c of classes) {
      const event = utility.formatTemplate(event_template, {
        'class': c,
        'filename': filename
      })
      const response = await webdav_su.createCalendarObject(resource, filename, event)
      expect(response.status).toBe(204)
    }

    // 4. Delete
    const response = await webdav_su.deleteObject(resource)
    expect(response.status).toBe(204)
  }, config.timeout || 10000)

})