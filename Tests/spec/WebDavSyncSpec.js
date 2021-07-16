import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

describe('webdav sync', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const resource = `/SOGo/dav/${config.username}/Calendar/test-webdavsync/`

  beforeEach(async function() {
  })

  afterEach(async function() {
    await webdav_su.deleteObject(resource)
  })

  it("webdav sync", async function() {
    let results

    // missing tests:
    //   invalid tokens: negative, non-numeric, > current timestamp
    //   non-empty collections: token validity, status codes for added,
    //                          modified and removed elements

    results = await webdav.makeCalendar(resource)
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(201)

    // test queries:
    //   empty collection:
    //     without a token (query1)
    //     with a token (query2)
    //   (when done, non-empty collection:
    //     without a token (query3)
    //     with a token (query4))

    results = await webdav.syncQuery(resource, null, [ 'getetag' ])
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(207)
    // TODO: sync-token is not returned by the tsdav library -- grep raw

    // we make sure that any token is accepted when the collection is
    // empty, but that the returned token differs
    results = await webdav.syncQuery(resource, '1234', [ 'getetag' ])
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(207)
    // TODO: sync-token is not returned by the tsdav library -- grep raw?
  })
})