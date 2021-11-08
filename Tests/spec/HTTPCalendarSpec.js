import config from '../lib/config'
import WebDAV from '../lib/WebDAV'

let webdav, resource

describe('HTTP Calendar', function() {

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    resource = `/SOGo/so/${config.username}/Calendar`
  })

  it('Add Web Calendar', async function() {
    const data = { url: config.webCalendarURL }
    let url, response, body

    url = `${resource}/addWebCalendar`
    response = await webdav.postHttp(url, 'application/json', JSON.stringify(data))
    expect(response.status)
    .withContext(`HTTP status code when subscribing to a Web calendar`)
    .toBe(200)

    body = await response.json()
    expect(Object.keys(body))
    .withContext(`JSON payload when subscribing to a Web calendar`)
    .toContain('id')

    const calID = body.id
    url = `${resource}/${calID}/reload`
    response = await webdav.getHttp(url)
    expect(response.status)
    .withContext(`HTTP status code when reloading a Web calendar`)
    .toBe(200)

    expect(response.headers.get('content-type'))
    .withContext(`Content type of response when reloading a Web calendar`)
    .toBe('application/json')
    body = await response.json()
    expect(Object.keys(body))
    .withContext(`JSON payload when reloading a Web calendar`)
    .toContain('imported')

    url = `${resource}/${calID}/delete`
    response = await webdav.postHttp(url, 'application/json')
    expect(response.status)
    .withContext(`HTTP status code when unsubscribing to a Web calendar`)
    .toBe(204)
  })

})
