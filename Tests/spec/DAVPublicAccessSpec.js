import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

describe('public access', function() {
  const webdav_anon = new WebDAV()

  // DAVPublicAccessTest

  it("access to /SOGo/so/public", async function() {
    const [{ status }] = await webdav_anon.options('/SOGo/so/public')
    expect(status)
      .withContext('/SOGo/so/public must not be accessible')
      .toBe(404)
  }, config.timeout || 10000)

  it("access to /SOGo/public", async function() {
    const [{ status }] = await webdav_anon.options('/SOGo/public')
    expect(status)
      .withContext('/SOGo/public must not be accessible')
      .toBe(404)
  }, config.timeout || 10000)

  it("access to non-public resource", async function() {
    const [{ status }] = await webdav_anon.options(`/SOGo/dav/${config.username}`)
    expect(status)
      .withContext('DAV non-public resources should request authentication')
      .toBe(401)
  }, config.timeout || 10000)

  it("access to public resource", async function() {
    const [{ status }] = await webdav_anon.options('/SOGo/dav/public')
    expect(status)
      .withContext('DAV public resources must not request authentication')
      .not.toBe(401)
    expect(status)
      .withContext('DAV public resources must be accessible')
      .toBe(200)
  }, config.timeout || 10000)
})