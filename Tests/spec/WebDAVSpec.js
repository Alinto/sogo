import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

describe('WebDAV', function() {
  var webdav
  var utility

  beforeEach(function() {
    webdav = new WebDAV(config.username, config.password)
    utility = new TestUtility(webdav)
  })

  it("property: 'principal-collection-set' on collection object", async function() {
    const resource = `/SOGo/dav/${config.username}/`
    const results = await webdav.principalCollectionSet(resource)
    expect(results.length).toBe(1)
    results.forEach(o => {
      expect(o.ok).toBe(true)
      expect(o.status).toBe(207)
      expect(resource).toBe(o.href)
    })
  })

  it("property: 'principal-collection-set' on non-collection object", function() {
    const resource = `/SOGo/dav/${config.username}/freebusy.ifb`
    return webdav.principalCollectionSet(resource).then(function(results) {
      expect(results.length).toBe(1)
      results.forEach(o => {
        expect(o.ok).toBe(true)
        expect(o.status).toBe(207)
      })
    })
  })

  it("propfind: ensure various NSURL work-arounds", async function() {
    const resultsNoSlash = await webdav.propfindURL(`/SOGo/dav/${config.username}`)
    resultsNoSlash.forEach(o => {
      // Expect no trailing slash nowhere
      expect(o.href.slice(-1)).toMatch(/[^\/]$/)
    })
    const resultsWithSlash = await webdav.propfindURL(`/SOGo/dav/${config.username}/`)
    resultsWithSlash.forEach(o => {
      // Expect a trailing slash for collections only
      if (o.props.resourcetype.collection) {
        expect(o.href.slice(-1)).toMatch(/\/$/)
      }
      else {
        expect(o.href.slice(-1)).toMatch(/[^\/]$/)
      }
    })
    const resultsNoColl = await webdav.propfindURL(`/SOGo/dav/${config.username}/freebusy.ifb`)
    resultsNoColl.forEach(o => {
      // Expect no collection
      expect(o.props.resourcetype.collection).toBeFalsy()
    })
  })

  // REPORT
  it("principal-property-search", async function() {
    const resource = `/SOGo/dav/${config.username}/Calendar`
    const user = await utility.fetchUserInfo(config.username)
    const results = await webdav.principalPropertySearch(resource)
    expect(results.length).toBe(1)
    results.forEach(o => {
      expect(o.props.displayname).toBe(user.displayname)
    })
  })

  // http://tools.ietf.org/html/rfc3253.html#section-3.8
  it("expand-property", async function () {
    const resource = `/SOGo/dav/${config.username}/`
    const user = await utility.fetchUserInfo(config.username)
    const properties = [
      {
        _attributes: {
          name: 'owner'
        },
        property: { _attributes: { name: 'displayname' } }
      },
      {
        _attributes: {
          name: 'principal-collection-set'
        },
        property: { _attributes: { name: 'displayname' } }
      }
    ]
    const outcomes = {
      owner: {
        href: resource,
        displayname: user.displayname
      },
      principalCollectionSet: {
        href: '/SOGo/dav/',
        displayname: 'SOGo'
      }
    }
    const results = await webdav.expendProperty(resource, properties)
    expect(results.length).toBe(1)
    results.forEach(o => {
      const { props = {} } = o
      expect(o.status)
        .withContext(`HTTP status code when expanding properties`)
        .toBe(207)
      Object.keys(outcomes).forEach(p => {
        const { response: { href, propstat: { prop: { displayname }} }} = props[p]
        expect(href)
          .withContext(`Result of expand-property for href`)
          .toBe(outcomes[p].href)
        expect(displayname)
          .withContext(`Result of expand-property for displayname`)
          .toBe(outcomes[p].displayname)
      })
    })
  })
})