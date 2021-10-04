import {
  DAVNamespace,
  DAVNamespaceShorthandMap,

  davRequest,
  deleteObject,
  getBasicAuthHeaders,
  propfind,
  syncCollection,

  calendarMultiGet,
  createCalendarObject,
  makeCalendar,

  createVCard
} from 'tsdav'
import { formatProps, getDAVAttribute } from 'tsdav/dist/util/requestHelpers';
import { makeCollection } from 'tsdav/dist/collection';
import convert from 'xml-js'
import { fetch } from 'cross-fetch'
import config from './config'

const DAVInverse = 'urn:inverse:params:xml:ns:inverse-dav'
const DAVInverseShort = 'i'

export { DAVInverse, DAVInverseShort }

class WebDAV {
  constructor(un, pw) {
    this.serverUrl = `http://${config.hostname}:${config.port}`
    if (un && pw) {
      this.headers = getBasicAuthHeaders({
        username: un,
        password: pw
      })
    }
    else {
      this.headers = {}
    }
  }

  deleteObject(resource) {
    return deleteObject({
      url: this.serverUrl + resource,
      headers: this.headers
    })
  }

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

  propfindWebdav(resource, properties, namespace = DAVNamespace.DAV, headers = {}) {
    const nsShort = DAVNamespaceShorthandMap[namespace] || DAVInverseShort
    const formattedProperties = properties.map(p => {
      return { [`${nsShort}:${p}`]: '' }
    })
    if (typeof headers.depth == 'undefined') {
      headers.depth = new String(0)
    }
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'PROPFIND',
        headers: { ...this.headers, ...headers },
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        body: {
          propfind: {
            _attributes: {
              ...getDAVAttribute([DAVNamespace.DAV]),
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

  principalCollectionSet(resource = '/SOGo/dav') {
    return propfind({
      url: this.serverUrl + resource,
      depth: '0',
      props: [{ name: 'principal-collection-set', namespace: DAVNamespace.DAV }],
      headers: this.headers
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

  syncColletion(resource) {
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

  syncQuery(resource, token = '', properties) {
    const formattedProperties = properties.map(p => { return { name: p, namespace: DAVNamespace.DAV } })
    return syncCollection({
      url: this.serverUrl + resource,
      props: formattedProperties,
      syncLevel: 1,
      syncToken: token,
      headers: this.headers
    })
  }

  propfindCaldav(resource, properties, depth = 0, parseOutgoing = true) {
    const formattedProperties = properties.map(p => { return { name: p, namespace: DAVNamespace.CALDAV } })
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'PROPFIND',
        headers: { ...this.headers, depth: new String(depth) },
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        body: {
          propfind: {
            _attributes: getDAVAttribute([
              DAVNamespace.CALDAV,
              DAVNamespace.CALDAV_APPLE,
              DAVNamespace.CALENDAR_SERVER,
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            prop: formattedProperties.length ? formatProps(formattedProperties) : null,
          }
        }
      },
      parseOutgoing
    })
  }

  proppatchCaldav(resource, properties, headers = {}) {
    const formattedProperties = Object.keys(properties).map(p => {
      return { name: p, namespace: DAVNamespace.CALDAV, value: properties[p] }
    })
    return davRequest({
      url: this.serverUrl + resource,
      init: {
        method: 'PROPPATCH',
        headers: { ...this.headers, ...headers },
        namespace: DAVNamespaceShorthandMap[DAVNamespace.DAV],
        body: {
          propertyupdate: {
            _attributes: getDAVAttribute([
              DAVNamespace.CALDAV,
              DAVNamespace.CALDAV_APPLE,
              DAVNamespace.CALENDAR_SERVER,
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            set: {
              prop: formatProps(formattedProperties)
            }
          }
        }
      }
      // parseOutgoing
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
              ...getDAVAttribute([DAVNamespace.DAV]),
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

  makeCollection(resource) {
    return makeCollection({
      url: this.serverUrl + resource,
      headers: this.headers
    });
  }

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

}

export default WebDAV