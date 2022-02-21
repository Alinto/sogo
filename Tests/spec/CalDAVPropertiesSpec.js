import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

describe('read and set calendar properties', function() {
  const webdav = new WebDAV(config.username, config.password)
  const resource = `/SOGo/dav/${config.username}/Calendar/test-dav-properties/`

  beforeEach(async function() {
    await webdav.makeCalendar(resource)
  })

  afterEach(async function() {
    await webdav.deleteObject(resource)
  })

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
  })

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

  })
})