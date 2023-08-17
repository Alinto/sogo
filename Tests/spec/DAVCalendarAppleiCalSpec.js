import { DAVNamespace } from 'tsdav'
import config from '../lib/config'
import { default as WebDAV, DAVInverse } from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

/**
 * NOTE
 *
 * To pass the following tests, make sure "username" and "subscriber_username" don't have
 * additional calendars.
 */

describe('Apple iCal', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const utility = new TestUtility(webdav_su)

  const iCal4UserAgent = 'DAVKit/4.0.1 (730); CalendarStore/4.0.1 (973); iCal/4.0.1 (1374); Mac OS X/10.6.2 (10C540)'

  const _setMemberSet = async function(owner, members, perm) {
    const resource = `/SOGo/dav/${owner}/calendar-proxy-${perm}`
    const headers = { 'User-Agent': iCal4UserAgent }
    const membersHref = members.map(m => {
      return `/SOGo/dav/${m}`
    })
    const properties = {
      'group-member-set': membersHref.length ? { href: membersHref } : ''
    }
    const results = await webdav_su.proppatchWebdav(resource, properties, DAVNamespace.DAV, headers)

    expect(results.length)
      .withContext(`Number of responses from PROPPATCH on group-member-set for ${owner}`)
      .toBe(1)
    expect(results[0].status)
      .withContext(`HTTP status code when setting group member on calendar-proxy-${perm} for ${owner}`)
      .toBe(207)
  }

  const _getMembership = async function(user) {
    const resource = `/SOGo/dav/${user}/`
    const headers = { 'User-Agent': iCal4UserAgent }
    const results = await webdav_su.propfindWebdav(resource, ['group-membership'], DAVNamespace.DAV, headers)

    expect(results.length)
      .withContext(`Number of responses from PROPFIND on group-membership for ${user}`)
      .toBe(1)
    expect(results[0].status)
      .withContext(`HTTP status code when getting group membership for ${user}`)
      .toBe(207)

    const { props: { groupMembership: { href = [] } = {} } = {} } = results[0]

    return Array.isArray(href) ? href : [href] // always return an array
  }

  const _getProxyFor = async function(user, perm) {
    const resource = `/SOGo/dav/${user}/`
    const headers = { 'User-Agent': iCal4UserAgent }
    const results = await webdav_su.propfindWebdav(resource, [`calendar-proxy-${perm}-for`], DAVNamespace.CALENDAR_SERVER, headers)

    expect(results.length)
      .withContext(`Number of responses from PROPFIND on group-membership for ${user}`)
      .toBe(1)
    expect(results[0].status)
      .withContext(`HTTP status code when getting group membership for ${user}`)
      .toBe(207)

    const { props = {} } = results[0]
    const users = props[`calendarProxy${perm.replace(/^\w/, (c) => c.toUpperCase())}For`]
    const { href = [] } = users

    return Array.isArray(href) ? href : [href] // always return an array
  }

  const _testMapping = async function(perm, resource, rights) {
    const results = await utility.setupCalendarRights(resource, config.subscriber_username, rights)
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(204)

    const membership = await _getMembership(config.subscriber_username)
    expect(membership)
      .withContext(`${perm.replace(/^\w/, (c) => c.toUpperCase())} access to /SOGo/dav/${config.subscriber_username}/`)
      .toContain(`/SOGo/dav/${config.username}/calendar-proxy-${perm}/`)

    const proxyFor = await _getProxyFor(config.subscriber_username, perm)
    expect(proxyFor)
      .withContext(`Proxy ${perm} on /SOGo/dav/${config.subscriber_username}/`)
      .toContain(`/SOGo/dav/${config.username}/`)
  }

  beforeEach(async function() {
    await _setMemberSet(config.username, [], 'read')
    await _setMemberSet(config.username, [], 'write')
    await _setMemberSet(config.subscriber_username, [], 'read')
    await _setMemberSet(config.subscriber_username, [], 'write')
    await _setMemberSet(config.superuser, [], 'read')
    await _setMemberSet(config.superuser, [], 'write')
  })

  // iCalTest

  it(`principal-collection-set: 'DAV' header must be returned with iCal 4`, async function() {
    const resource = `/SOGo/dav/${config.username}/`
    const expectedDAVClasses = ['1', '2', 'access-control', 'calendar-access', 'calendar-schedule', 'calendar-auto-schedule', 'calendar-proxy']

    let headers, response, davClasses, davClass
    headers = { Depth: new String(0) }

    // NOT iCal4
    response = await webdav.propfindWebdavRaw(resource, ['principal-collection-set'], headers)
    expect(response.status)
      .withContext(`HTTP status code when fetching principal-collection-set`)
      .toBe(207)
    expect(response.headers.get('dav'))
      .withContext(`DAV header must NOT be returned when user-agent is NOT iCal 4`)
      .toBeFalsy()

    // iCal4
    headers['User-Agent'] = iCal4UserAgent
    response = await webdav.propfindWebdavRaw(resource, ['principal-collection-set'], headers)
    expect(response.status)
      .withContext(`HTTP status code when fetching principal-collection-set`)
      .toBe(207)
    expect(response.headers.get('dav'))
      .withContext(`DAV header must be returned when user-agent is iCal 4`)
      .toBeTruthy()

    davClasses = response.headers.get('dav').split(', ')
    for (davClass of expectedDAVClasses) {
      expect(davClasses.includes(davClass))
        .withContext(`DAV header includes class ${davClass}`)
        .toBeTrue()
    }
  })

  it(`calendar-proxy as used from iCal`, async function() {
    let membership, perm, users, proxyFor

    membership = await _getMembership(config.username)
    expect(membership.length)
      .toBe(0)
    membership = await _getMembership(config.subscriber_username)
    expect(membership.length)
      .toBe(0)

    users = await _getProxyFor(config.username, 'read')
    expect(users.length)
      .withContext(`Proxy read for /SOGo/dav/${config.username}`)
      .toBe(0)
    users = await _getProxyFor(config.username, 'write')
    expect(users.length)
      .withContext(`Proxy write for /SOGo/dav/${config.username}`)
      .toBe(0)
    users = await _getProxyFor(config.subscriber_username, 'read')
    expect(users.length)
      .withContext(`Proxy read for /SOGo/dav/${config.subscriber_username}`)
      .toBe(0)
    users = await _getProxyFor(config.subscriber_username, 'write')
    expect(users.length)
      .withContext(`Proxy write for /SOGo/dav/${config.subscriber_username}`)
      .toBe(0)

    for (perm of ['read', 'write']) {
      for (users of [[config.username, config.subscriber_username], [config.subscriber_username, config.username]]) {
        const [owner, member] = users

        await _setMemberSet(owner, [member], perm)

        let [ membership ] = await _getMembership(member)
        expect(membership)
          .toBe(`/SOGo/dav/${owner}/calendar-proxy-${perm}/`)

        proxyFor = await _getProxyFor(member, perm)
        expect(proxyFor.length).toBe(1)
        expect(proxyFor).toContain(`/SOGo/dav/${owner}/`)
      }
    }
  })

  it('calendar-proxy as used from SOGo', async function() {
    const personalResource = `/SOGo/dav/${config.username}/Calendar/personal/`
    const otherResource = `/SOGo/dav/${config.username}/Calendar/test-calendar-proxy2/`

    let response, membership

    // Remove rights on personal calendar
    await utility.setupRights(personalResource, config.subscriber_username);
    [response] = await utility.subscribe(personalResource, [config.subscriber_username])
    expect(response.status)
      .toBe(200)

    await webdav_su.deleteObject(otherResource)
    await webdav_su.makeCalendar(otherResource)
    await utility.setupRights(otherResource, config.subscriber_username);
    [response] = await utility.subscribe(otherResource, [config.subscriber_username])
    expect(response.status)
      .toBe(200)

    // we test the rights mapping
    // write: write on 'personal', none on 'test-calendar-proxy2'
    await _testMapping('write', personalResource, { c: true, d: false, pu: 'v' })
    await _testMapping('write', personalResource, { c: false, d: true, pu: 'v' })
    await _testMapping('write', personalResource, { c: false, d: false, pu: 'm' })
    await _testMapping('write', personalResource, { c: false, d: false, pu: 'r' })

    // read: read on 'personal', none on 'test-calendar-proxy2'
    await _testMapping('read', personalResource, { c: false, d: false, pu: 'd' })
    await _testMapping('read', personalResource, { c: false, d: false, pu: 'v' })

    // write: read on 'personal', write on 'test-calendar-proxy2'
    await _testMapping('write', otherResource, { c: false, d: false, pu: 'r' });

    // we test the unsubscription
    // unsubscribed from personal, subscribed to 'test-calendar-proxy2'
    [response] = await utility.unsubscribe(personalResource, [config.subscriber_username])
    expect(response.status)
      .toBe(200)
    membership = await _getMembership(config.subscriber_username)
    expect(membership)
      .withContext(`Proxy write to /SOGo/dav/${config.subscriber_username}/`)
      .toContain(`/SOGo/dav/${config.username}/calendar-proxy-write/`);
    // unsubscribed from personal, unsubscribed from 'test-calendar-proxy2'
    [response] = await utility.unsubscribe(otherResource, [config.subscriber_username])
    expect(response.status)
      .toBe(200)
    membership = await _getMembership(config.subscriber_username)
    expect(membership.length)
      .withContext(`No more access to /SOGo/dav/${config.subscriber_username}/`)
      .toBe(0)

    await webdav_su.deleteObject(otherResource)
  }, 10000) // increase timeout for this long test
})