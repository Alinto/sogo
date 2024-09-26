import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

describe('read and set calendar properties', function() {
  const webdav = new WebDAV(config.username, config.password)
  const utility = new TestUtility(webdav)
  const resource = `/SOGo/dav/${config.username}/Calendar/test-dav-properties/`

  beforeEach(async function() {
    await webdav.makeCalendar(resource)
  })

  afterEach(async function() {
    await webdav.deleteObject(resource)
  })

  it("calendar already exists", async function() {
    const response = await webdav.makeCalendar(resource)
    expect(response[0].status)
      .withContext(`HTTP status code of MKCALENDAR`)
      .toEqual(405)
  }, config.timeout || 10000)

  // CalDAVPropertiesTest

  it("propfind", async function() {
    const [result] = await webdav.propfindCaldav(resource, ['schedule-calendar-transp'])
    const { raw: { multistatus: { response: { propstat: { status, prop }}}}} = result
    expect(status)
      .withContext('schedule-calendar-transp profind is successful')
      .toBe('HTTP/1.1 200 OK')
    expect(Object.keys(prop).length)
      .withContext('schedule-calendar-transp has one element only')
      .toBe(1)
      expect(Object.keys(prop.scheduleCalendarTransp).includes('opaque'))
      .withContext('schedule-calendar-transp is "opaque" on new')
      .toBeTrue()
  }, config.timeout || 10000)

  it("proppatch", async function() {
    let newValueNode
    let results

    newValueNode = { 'thisvaluedoesnotexist': {} }
    results = await webdav.proppatchCaldav(resource, {'schedule-calendar-transp': newValueNode})
    expect(results.length)
      .toBe(1)
    expect(results[0].status)
    .withContext('Setting an invalid transparency is refused')
    .toBe(400)

    newValueNode = { 'transparent': {} }
    results = await webdav.proppatchCaldav(resource, {'schedule-calendar-transp': newValueNode})
    expect(results.length)
      .toBe(1)
    expect(results[0].status)
    .withContext(`Setting transparency to ${newValueNode} is successful`)
    .toBe(207)

    newValueNode = { 'opaque': {} }
    results = await webdav.proppatchCaldav(resource, {'schedule-calendar-transp': newValueNode})
    expect(results.length)
      .toBe(1)
    expect(results[0].status)
    .withContext(`Setting transparency to ${newValueNode} is successful`)
    .toBe(207)
  }, config.timeout || 10000)

  it("calendar-query", async function() {
    const filename = `new.ics`
    const event = `BEGIN:VCALENDAR
PRODID:-//Inverse//Event Generator//EN
VERSION:2.0
BEGIN:VEVENT
SEQUENCE:0
TRANSP:OPAQUE
UID:1234567890
SUMMARY:Visit to the museum of fine arts
DTSTART:20090805T100000Z
DTEND:20090805T140000Z
CLASS:PUBLIC
DESCRIPTION:description
LOCATION:location
DTSTAMP:20090805T100000Z
END:VEVENT
END:VCALENDAR`

    let response = await webdav.createCalendarObject(resource, filename, event)
    expect(response.status).toBe(201)

    response = await webdav.calendarQuery(
      resource,
      [
        {
          type: 'comp-filter',
          attributes: { name: 'VCALENDAR' },
          children: [
            {
              type: 'comp-filter',
              attributes: { name: 'VEVENT' },
              children: [
                {
                  type: 'prop-filter',
                  attributes: { name: 'TITLE' },
                  children: [
                    {
                      type: 'text-match',
                      value: 'museum'
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    )
    expect(response.length)
      .withContext(`Number of results from calendar-query`)
      .toBe(1)
    expect(response[0].status)
      .withContext(`HTTP status code of calendar-query`)
      .toEqual(207)
    expect(utility.componentsAreEqual(response[0].props.calendarData, event))
      .withContext(`Returned vCalendar matches ${filename}`)
      .toBe(true)
  }, config.timeout || 10000)
})