import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('public access', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_anon = new WebDAV()
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdav_subscriber = new WebDAV(config.subscriber_username, config.subscriber_password)
  const utility = new TestUtility(webdav)
  const utility_subscriber = new TestUtility(webdav_subscriber)
  let createdRsrc

  // DAVCalendarPublicAclTest

  afterEach(async function() {
    if (createdRsrc) {
      await webdav_su.deleteObject(createdRsrc)
    }
  })

  it("normal user access to (non-)shared resource from su", async function() {
    const parentColl = `/SOGo/dav/${config.username}/Calendar/`
    let results
    let href

    // 1. all rights removed
    createdRsrc = `${parentColl}test-dav-acl/`
    for (const rsrc of ['personal', 'test-dav-acl']) {
      const resource = `${parentColl}${rsrc}/`
      await webdav.makeCalendar(resource)
      await utility.setupRights(resource, 'anonymous', {})
      await utility.setupRights(resource, config.subscriber_username, {})
      await utility.setupRights(resource, '<default>', {})
    }

    results = await webdav_subscriber.propfindURL(parentColl)
    expect(results.length)
      .withContext(`Profind returns 1 href when subscriber user ${config.subscriber_username} has no right`)
      .toBe(1)
    href = results[0].href
    expect(href)
      .withContext(`Unique href must be the Calendar parent collection ${parentColl}`)
      .toBe(parentColl)

    // 2. creation right added
    await utility.setupCalendarRights(createdRsrc, config.subscriber_username, { c: true })

    results = await webdav_subscriber.propfindURL(parentColl)
    expect(results.length)
      .withContext(`Profind returns 4 href when subscriber user ${config.subscriber_username} has creation right`)
      .toBe(4)
    href = results[0].href
    expect(href)
      .withContext(`First href must be the Calendar parent collection ${parentColl}`)
      .toBe(parentColl)

    let resourceHrefs = {
      [createdRsrc]: false,
      [`${createdRsrc.slice(0, -1)}.xml`]: false,
      [`${createdRsrc.slice(0, -1)}.ics`]: false
    }
    for (href of results.map(r => r.href).slice(1)) {
      expect(Object.keys(resourceHrefs).includes(href))
        .withContext(`Propfind href ${href} is returned`)
        .toBeTrue()
      expect(resourceHrefs[href])
        .not.toBeTrue()
      resourceHrefs[href] = true
    }

    await utility.setupRights(createdRsrc, config.subscriber_username) // remove rights

    // 3. creation right added for "default user"
    //    subscriber_username expected to have access, but not "anonymous"
    await utility.setupCalendarRights(createdRsrc, '<default>', { c: true })

    results = await webdav_subscriber.propfindURL(parentColl)
    expect(results.length)
      .withContext('Profind returns 4 href when <default> user has creation right')
      .toBe(4)
    href = results[0].href
    expect(href)
      .withContext('First href must be the Calendar parent collection')
      .toBe(parentColl)

    resourceHrefs = {
      [createdRsrc]: false,
      [`${createdRsrc.slice(0, -1)}.xml`]: false,
      [`${createdRsrc.slice(0, -1)}.ics`]: false
    }
    for (href of results.map(r => r.href).slice(1)) {
      expect(Object.keys(resourceHrefs).includes(href))
        .withContext(`Propfind href ${href} is returned`)
        .toBeTrue()
      expect(resourceHrefs[href])
        .withContext(`Propfind href ${href} is returned only once`)
        .not.toBeTrue()
      resourceHrefs[href] = true
    }

    const anonParentColl = `/SOGo/dav/public/${config.username}/Calendar/`
    results = await webdav_anon.propfindURL(anonParentColl)
    expect(results.length)
      .withContext('Profind returns 1 href for anonymous user')
      .toBe(1)
    href = results[0].href
    expect(href)
      .withContext('Unique href must be the Calendar parent collection')
      .toBe(anonParentColl)

    await utility.setupRights(createdRsrc, '<default>', {})

    // 4. creation right added for "anonymous"
    //    "anonymous" expected to have access, but not subscriber_username

    await utility.setupCalendarRights(createdRsrc, 'anonymous', { c: true })

    results = await webdav_anon.propfindURL(anonParentColl)
    expect(results.length)
      .withContext('Profind returns 4 href when anonymous user has creation right')
      .toBe(4)
    href = results[0].href
    expect(href)
      .withContext('First href must be the Calendar parent collection')
      .toBe(anonParentColl)

    const anonRsrc = `${anonParentColl}test-dav-acl/`
    resourceHrefs = {
      [anonRsrc]: false,
      [`${anonRsrc.slice(0, -1)}.xml`]: false,
      [`${anonRsrc.slice(0, -1)}.ics`]: false
    }
    for (href of results.map(r => r.href).slice(1)) {
      expect(Object.keys(resourceHrefs).includes(href))
        .withContext(`Propfind href ${href} is returned`)
        .toBeTrue()
      expect(resourceHrefs[href])
        .withContext(`Propfind href ${href} is returned only once`)
        .not.toBeTrue()
      resourceHrefs[href] = true
    }

    results = await webdav_subscriber.propfindURL(parentColl)
    expect(results.length)
      .withContext('Profind returns 1 href when <default> user has no right')
      .toBe(1)
    href = results[0].href
    expect(href)
      .withContext('First href must be the Calendar parent collection')
      .toBe(parentColl)

  })

  it("user accessing (non-)shared Calendars", async function() {
    const parentColl = `/SOGo/dav/${config.subscriber_username}/Calendar/`
    let results

    createdRsrc = `${parentColl}test-dav-acl/`
    for (const rsrc of ['personal', 'test-dav-acl']) {
      const resource = `${parentColl}${rsrc}/`
      await webdav_su.makeCalendar(resource)
      await utility_subscriber.setupRights(resource, config.username, {})
    }

    results = await webdav_subscriber.propfindURL(parentColl)
    const hrefs = results.map(r => r.href).filter(h => {
      return h == `${parentColl}` ||
        h.indexOf(`${parentColl}personal`) == 0 ||
        h.indexOf(`${parentColl}test-dav-acl`) == 0
    })
    expect(hrefs.length)
      .withContext(`Profind returns at least 3 hrefs when user ${config.subscriber_username} is the owner`)
      .toBeGreaterThan(2)
    const [href] = hrefs
    expect(href)
      .withContext('Unique href must be the Calendar parent collection')
      .toBe(parentColl)
  })

})