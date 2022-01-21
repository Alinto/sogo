import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import { DAVNamespace, DAVNamespaceShorthandMap } from 'tsdav'
import convert from 'xml-js'

describe('webdav sync', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const resource = `/SOGo/dav/${config.username}/Calendar/test-webdavsync/`

  afterEach(async function() {
    await webdav_su.deleteObject(resource)
  })

  it('webdav sync', async function() {
    const nsShort = DAVNamespaceShorthandMap[DAVNamespace.DAV].toUpperCase()
    let response, xml, token

    // missing tests:
    //   invalid tokens: negative, non-numeric, > current timestamp
    //   non-empty collections: token validity, status codes for added,
    //                          modified and removed elements

    response = await webdav.makeCalendar(resource)
    expect(response.length).toBe(1)
    expect(response[0].status)
    .withContext(`HTTP status code when creating a Calendar`)
    .toBe(201)

    // test queries:
    //   empty collection:
    //     without a token (query1)
    //     with a token (query2)
    //   (when done, non-empty collection:
    //     without a token (query3)
    //     with a token (query4))

    response = await webdav.syncCollectionRaw(resource, null, [ 'getetag' ])
    xml = await response.text();
    ({ [`${nsShort}:multistatus`]: { [`${nsShort}:sync-token`]: { _text: token } } } = convert.xml2js(xml, {compact: true, nativeType: true}))
    expect(response.status)
    .withContext(`HTTP status code when performing sync-query without a token`)
    .toBe(207)
    expect(token)
    .withContext(`Sync query returns valid token`)
    .toBeGreaterThanOrEqual(0)

    // we make sure that any token is accepted when the collection is
    // empty, but that the returned token differs
    response = await webdav.syncCollectionRaw(resource, '1234', [ 'getetag' ])
    xml = await response.text();
    ({ [`${nsShort}:multistatus`]: { [`${nsShort}:sync-token`]: { _text: token } } } = convert.xml2js(xml, {compact: true, nativeType: true}))
    expect(response.status)
    .withContext(`HTTP status code when performing sync-query with a token`)
    .toBe(207)
    expect(token)
    .withContext(`Sync query returns valid token`)
    .toBeGreaterThanOrEqual(0)
  })
})