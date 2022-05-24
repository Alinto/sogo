import cookie from 'cookie'
import {
  DAVNamespace,
  DAVNamespaceShorthandMap,

  davRequest,
  deleteObject,
  formatProps,
  getBasicAuthHeaders,
  getDAVAttribute,
  propfind,

  calendarMultiGet,
  calendarQuery,
  createCalendarObject,
  makeCalendar,

  createVCard
} from 'tsdav'
import convert from 'xml-js'
import { fetch } from 'cross-fetch'
import config from './config'

const DAVInverse = 'urn:inverse:params:xml:ns:inverse-dav'
const DAVInverseShort = 'i'
const DAVMailHeader = 'urn:schemas:mailheader:'
const DAVMailHeaderShort = 'mh'
const DAVHttpMail = 'urn:schemas:httpmail:'
const DAVHttpMailShort = 'hm'
const DAVnsShortMap = {
  [DAVInverse]: DAVInverseShort,
  [DAVMailHeader]: DAVMailHeaderShort,
  [DAVHttpMail]: DAVHttpMailShort,
  ...DAVNamespaceShorthandMap
}

export {
  DAVInverse, DAVInverseShort,
  DAVMailHeader, DAVMailHeaderShort,
  DAVHttpMail, DAVHttpMailShort
}

class WebDAV {
  constructor(un, pw) {
    this.serverUrl = `http://${config.hostname}:${config.port}`
    this.cookie = null
    if (un && pw) {
      this.username = un
      this.password = pw
      this.headers = getBasicAuthHeaders({
        username: un,
        password: pw
      })
    }
    else {
      this.headers = {}
    }
  }

  // Generic operations

  async getAuthCookie() {
    if (!this.cookie) {
      const resource = `/SOGo/connect`
      const response = await fetch(this.serverUrl + resource, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({userName: this.username, password: this.password})
      })
      const values = response.headers.get('set-cookie').split(/, /)
      let authCookies = []
      for (let v of values) {
        let c = cookie.parse(v)
        for (let authCookie of ['0xHIGHFLYxSOGo', 'XSRF-TOKEN']) {
          if (Object.keys(c).includes('0xHIGHFLYxSOGo')) {
            authCookies.push(cookie.serialize(authCookie, c[authCookie]))
          }
        }
      }
      this.cookie = authCookies.join('; ')
    }
    return this.cookie
  }

  async getHttp(resource) {
    const authCookie = await this.getAuthCookie()
    const localHeaders = { Cookie: authCookie }

    return await fetch(this.serverUrl + resource, {
      method: 'GET',
      headers: localHeaders
    })
  }

  async postHttp(resource, contentType = 'application/json', data = '') {
    const authCookie = await this.getAuthCookie()
    const localHeaders = { 'Content-Type': contentType, Cookie: authCookie }

    return await fetch(this.serverUrl + resource, {
      method: 'POST',
      body: data,
      headers: localHeaders
    })
  }

  //  WebDAV operations

  deleteObject(resource) {
    return deleteObject({
      url: this.serverUrl + resource,
      headers: this.headers
    })
  }

  getObject(resource, filename) {
    let url
    if (resource.match(/^http/))
      url = resource
    else
      url = this.serverUrl + resource
    if (filename)
      url += filename
    return davRequest({
      url,
      init: {
        method: 'GET',
        headers: this.headers,
        body: null
      },
      convertIncoming: false
    })
  }

  makeCollection(resource) {
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'MKCOL',
        headers: this.headers,
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV]
      }
    })
  }

  propfindWebdav(resource, properties, namespace = DAVNamespace.DAV, headers = {}) {
    const nsShort = DAVnsShortMap[namespace] || DAVInverseShort
    const formattedProperties = properties.map(p => {
      return { [`${nsShort}:${p}`]: '' }
    })
    let url
    if (resource.match(/^http/))
      url = resource
    else
      url = this.serverUrl + resource
    if (typeof headers.depth == 'undefined') {
      headers.depth = new String(0)
    }
    return davRequest({
      url,
      init: {
        method: 'PROPFIND',
        headers: { ...this.headers, ...headers },
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        body: {
          propfind: {
            _attributes: {
              ...getDAVAttribute([
                DAVNamespace.CALDAV,
                DAVNamespace.CALDAV_APPLE,
                DAVNamespace.CALENDAR_SERVER,
                DAVNamespace.CARDDAV,
                DAVNamespace.DAV
              ]),
              [`xmlns:${nsShort}`]: namespace
            },
            prop: formattedProperties
          }
        }
      }
    })
  }

  propfindWebdavRaw(resource, properties, headers = {}) {
    const namespace = DAVNamespaceShorthandMap[DAVNamespace.DAV]
    const formattedProperties = properties.map(prop => {
      return { [`${namespace}:${prop}`]: '' }
    })

    let xmlBody = convert.js2xml(
      {
        propfind: {
          _attributes: getDAVAttribute([DAVNamespace.DAV]),
          prop: formattedProperties
        }
      },
      {
        compact: true,
        spaces: 2,
        elementNameFn: (name) => {
          // add namespace to all keys without namespace
          if (!/^.+:.+/.test(name)) {
            return `${namespace}:${name}`;
          }
          return name;
        },
      }
    )

    return fetch(this.serverUrl + resource, {
      headers: {
        'Content-Type': 'application/xml; charset="utf-8"',
        ...headers,
        ...this.headers
      },
      method: 'PROPFIND',
      body: xmlBody
    })
  }

  propfindURL(resource = '/SOGo/dav') {
    return propfind({
      url: this.serverUrl + resource,
      depth: '1',
      props: [
        { name: 'displayname', namespace: DAVNamespace.DAV },
        { name: 'resourcetype', namespace: DAVNamespace.DAV }
      ],
      headers: this.headers
    })
  }

  propfindCollection(resource) {
    return propfind({
      url: this.serverUrl + resource,
      headers: this.headers
    })
  }

  // http://tools.ietf.org/html/rfc3253.html#section-3.8
  expendProperty(resource, properties) {
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        headers: this.headers,
        body: {
          'expand-property': {
            _attributes: getDAVAttribute([
              DAVNamespace.DAV,
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:property`]: properties
          }
        }
      },
    })
  }

  proppatchWebdav(resource, properties, namespace = DAVNamespace.DAV, headers = {}) {
    const nsShort = DAVNamespaceShorthandMap[namespace] || DAVInverseShort
    const formattedProperties = Object.keys(properties).map(p => {
      if (Array.isArray(properties[p])) {
        return { [`${nsShort}:${p}`]: properties[p].map(pp => {
          const [ key ] = Object.keys(pp)
          return { [`${nsShort}:${key}`]: pp[key] || '' }
        })}
      }
      return { [`${nsShort}:${p}`]: properties[p] || '' }
    })
    if (typeof headers.depth == 'undefined') {
      headers.depth = new String(0)
    }
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'PROPPATCH',
        headers: { ...this.headers, ...headers },
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        body: {
          propertyupdate: {
            _attributes: {
              ...getDAVAttribute([
                DAVNamespace.CALDAV,
                DAVNamespace.CALDAV_APPLE,
                DAVNamespace.CALENDAR_SERVER,
                DAVNamespace.CARDDAV,
                DAVNamespace.DAV
              ]),
              [`xmlns:${nsShort}`]: namespace
            },
            set: {
              prop: formattedProperties
            }
          }
        }
      }
    })
  }

  currentUserPrivilegeSet(resource) {
    return propfind({
      url: this.serverUrl + resource,
      depth: '0',
      props: [
        { name: 'current-user-privilege-set', namespace: DAVNamespace.DAV }
      ],
      headers: this.headers
    })
  }

  options(resource) {
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'OPTIONS',
        headers: this.headers,
        body: null
      },
      convertIncoming: false
    })
  }

  principalCollectionSet(resource = '/SOGo/dav') {
    return propfind({
      url: this.serverUrl + resource,
      depth: '0',
      props: [{ name: 'principal-collection-set', namespace: DAVNamespace.DAV }],
      headers: this.headers
    })
  }

  // https://datatracker.ietf.org/doc/html/rfc6578#section-3.2
  syncCollectionRaw(resource, token = '', properties) {
    const formattedProperties = properties.map((p) => {
      return { [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:${p}`]: '' }
    });
    let xmlBody = convert.js2xml(
      {
        'sync-collection': {
          _attributes: getDAVAttribute([DAVNamespace.DAV]),
          'sync-level': 1,
          'sync-token': token,
          prop: formattedProperties
        }
      },
      {
        compact: true,
        spaces: 2,
        elementNameFn: (name) => {
          // add namespace to all keys without namespace
          if (!/^.+:.+/.test(name)) {
            return `${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:${name}`
          }
          return name
        }
      }
    )
    return fetch(this.serverUrl + resource, {
      headers: {
        'Content-Type': 'application/xml; charset="utf-8"',
        ...this.headers
      },
      method: 'REPORT',
      body: xmlBody
    })
  }

  // CalDAV operations

  makeCalendar(resource) {
    return makeCalendar({
      url: this.serverUrl + resource,
      headers: this.headers
    })
  }

  createCalendarObject(resource, filename, calendar) {
    return createCalendarObject({
      headers: this.headers,
      calendar: { url: this.serverUrl + resource }, // DAVCalendar
      filename: filename,
      iCalString: calendar
    })
  }

  postCaldav(resource, vcalendar, originator, recipients) {
    let localHeaders = { 'content-type': 'text/calendar; charset=utf-8'}

    if (originator)
      localHeaders.originator = originator
    if (recipients && recipients.length > 0)
      localHeaders.recipients = recipients.join(',')

    return fetch(this.serverUrl + resource, {
      method: 'POST',
      body: vcalendar,
      headers: { ...this.headers, ...localHeaders }
    })
  }

  propfindEvent(resource) {
    return propfind({
      url: this.serverUrl + resource,
      headers: this.headers,
      depth: '1',
      props: [
        { name: 'calendar-data', namespace: DAVNamespace.CALDAV }
      ]
    })
  }

  calendarQuery(resource, filters) {
    return calendarQuery({
      url: this.serverUrl + resource,
      headers: this.headers,
      depth: '1',
      props: [
        { name: 'getetag', namespace: DAVNamespace.DAV },
        { name: 'calendar-data', namespace: DAVNamespace.CALDAV },
      ],
      filters,
    })
  }

  calendarMultiGet(resource, filename) {
    return calendarMultiGet({
      url: this.serverUrl + resource,
      headers: this.headers,
      props: [
        { name: 'calendar-data', namespace: DAVNamespace.CALDAV },
      ],
      objectUrls: [ this.serverUrl + resource + filename ]
    })
  }

  principalPropertySearch(resource) {
    return davRequest({
      url: `${this.serverUrl}/SOGo/dav`,
      init: {
        method: 'REPORT',
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        headers: this.headers,
        body: {
          'principal-property-search': {
            _attributes: getDAVAttribute([
              DAVNamespace.CALDAV,
              DAVNamespace.DAV,
            ]),
            'property-search': [
              {
                [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'calendar-home-set', namespace: DAVNamespace.CALDAV }]),
                'match': resource
              }
            ],
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'displayname', namespace: DAVNamespace.DAV }])
          }
        }
      },
    })
  }

  syncCollection(resource) {
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        headers: this.headers,
        body: {
          'sync-collection': {
            _attributes: getDAVAttribute([
              DAVNamespace.CALDAV,
              DAVNamespace.DAV
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'calendar-data', namespace: DAVNamespace.CALDAV }]),
          }
        }
      },
    })
  }

  propfindCaldav(resource, properties, depth = 0) {
    return this.propfindWebdav(resource, properties, DAVNamespace.CALDAV, { depth: new String(depth) })
  }

  proppatchCaldav(resource, properties, headers = {}) {
    return this.proppatchWebdav(resource, properties, DAVNamespace.CALDAV, headers)
  }

  // CardDAV operations

  getCard(resource, filename) {
    return davRequest({
      url: this.serverUrl + resource + filename,
      init: {
        method: 'GET',
        headers: this.headers,
        body: null
      },
      convertIncoming: false
    })
  }

  createVCard(resource, filename, card) {
    return createVCard({
      headers: this.headers,
      addressBook: { url: this.serverUrl + resource }, // DAVAddressBook
      filename,
      vCardString: card
    })
  }

  // MailDAV operations

  mailQueryMaildav(resource, properties, filters = {}, sort, ascending = true) {
    let formattedFilters = {}
    if (filters) {
      if (filters.constructor.toString().includes('Array')) {
        filters.map(f => {
          Object.keys(f).map(p => {
            const pName = `${DAVInverseShort}:${p}`
            if (!formattedFilters[pName])
              formattedFilters[pName] = []
            formattedFilters[pName].push({ _attributes: f[p] })
          })
        })
      }
      else {
        Object.keys(filters).map(p => {
          const pName = `${DAVInverseShort}:${p}`
          if (!formattedFilters[pName])
            formattedFilters[pName] = []
          formattedFilters[pName].push({ _attributes: filters[p] })
        })
      }
      if (Object.keys(formattedFilters).length) {
        formattedFilters = {[`${DAVInverseShort}:mail-filters`]: formattedFilters}
      }
    }
    let formattedSort = {}
    if (sort) {
      formattedSort = {[`${DAVInverseShort}:sort`]: {
        _attributes: { order: ascending ? 'ascending' : 'descending' },
        [sort]: {}
      }}
    }
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        headers: this.headers,
        body: {
          [`${DAVInverseShort}:mail-query`]: {
            _attributes: {
              ...getDAVAttribute([DAVNamespace.DAV]),
              [`xmlns:${DAVInverseShort}`]: DAVInverse,
              [`xmlns:${DAVMailHeaderShort}`]: DAVMailHeader
            },
            prop: formatProps(properties.map(p => { return { name: p } })),
            ...formattedFilters,
            ...formattedSort
          }
        }
      }
    })
  }

}

export default WebDAV