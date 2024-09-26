import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

import ICAL from 'ical.js'
import {
  DAVNamespace,
  DAVNamespaceShorthandMap,
  davRequest,
  formatProps,
  getDAVAttribute
} from 'tsdav'

const cards = {
  'new.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:New;Carte
FN:Carte 'new'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email1@domaine.ca
EMAIL;TYPE=home:address.email1@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD`,
  'new-modified.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:New;Carte modifiee
FN:Carte modifiee 'new'
ORG:societe;service
NICKNAME:surnom
ADR;TYPE=work:adr2 societe;;adr societe;ville societe;etat soc;code soc;pays soc
ADR;TYPE=home:rue perso 2;;rue perso;ville perso;etat perso;code post perso;pays perso
TEL;TYPE=work:+1 555 222-2222
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email2@domaine.ca
EMAIL;TYPE=home:address.email2@domaine2.com
URL;TYPE=home:web perso
TITLE:fonction
URL;TYPE=work:page soc
CUSTOM1:divers1
CUSTOM2:divers2
CUSTOM3:divers3
CUSTOM4:divers4
NOTE:Remarque
X-AIM:pseudo aim
END:VCARD`
}

beforeAll(function () {
  jasmine.DEFAULT_TIMEOUT_INTERVAL = config.timeout || 10000;
});

describe('CardDAV extensions', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const utility = new TestUtility(webdav)

  const resource = `/SOGo/dav/${config.username}/Contacts/test-carddav/`

  const _putCard = async function(client, filename, expectedCode, realCard) {
    const card = cards[realCard || filename]
    if (!card)
      throw new Error(`Card ${realCard || filename} is unknown`)
    const response = await client.createVCard(resource, filename, card)
    expect(response.status).toBe(expectedCode)
  }

  beforeAll(async function() {
    await webdav.deleteObject(resource)
    await webdav.makeCollection(resource)
    for (let key of Object.keys(cards)) {
      await _putCard(webdav, key, 201)
    }
  })

  afterAll(async function() {
    await webdav_su.deleteObject(resource)
  })

  it("addressbook already exists", async function() {
    const response = await webdav.makeCollection(resource)
    expect(response[0].status)
      .withContext(`HTTP status code of MKCOL`)
      .toEqual(405)
  }, config.timeout || 10000)

  // CARDDAV:addressbook-query Report
  // https://datatracker.ietf.org/doc/html/rfc6352#section-8.6
  it("supports for addressbook-query on GCS folder", async function() {
    const name = Object.keys(cards)[1]
    const ns = DAVNamespaceShorthandMap[DAVNamespace.CARDDAV]
    const response = await davRequest({
      url: webdav.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: ns,
        headers: { ...webdav.headers, depth: '1' },
        body: {
          'addressbook-query': {
            _attributes: getDAVAttribute([
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'address-data', namespace: DAVNamespace.CARDDAV }]),
            filter: {
              _attributes: { test: 'anyof' },
              'prop-filter': [
                {
                  _attributes: { name: 'FN', test: 'anyof' },
                  'text-match': [
                    {
                      _attributes: { collation: 'i;unicasemap', 'match-type': 'starts-with' },
                      _text: 'Carte modifiee' // should match the second card
                    },
                    {
                      _attributes: { collation: 'i;unicasemap', 'match-type': 'contains' },
                      _text: 'No match' // should not match any card
                    }
                  ]
                },
                {
                  _attributes: { name: 'EMAIL', test: 'allof' },
                  'text-match': {
                    _attributes: { collation: 'i;unicasemap', 'match-type': 'starts-with' },
                    _text: 'email2' // should match the second card
                  }
                }
                ]
            }
          }
        },
        elementNameFn: (name) => {
          if (!/^.+:.+/.test(name)) {
            return `${ns}:${name}`
          }
          return name
        }
      }
    })
    expect(response.length)
      .withContext(`Number of results from addressbook-query`)
      .toBe(1)
    expect(response[0].status)
      .withContext(`HTTP status code of addressbook-query`)
      .toEqual(207)
    expect(utility.componentsAreEqual(response[0].props.addressData, cards[name]))
      .withContext(`Returned vCard matches ${name}`)
      .toBe(true)
  }, config.timeout || 10000)

  // CARDDAV:addressbook-query Report
  // https://datatracker.ietf.org/doc/html/rfc6352#section-8.6
  xit("supports for addressbook-query on source folder", async function() {
    let vcard, emails
    const ns = DAVNamespaceShorthandMap[DAVNamespace.CARDDAV]
    const response = await davRequest({
      url: webdav.serverUrl + `/SOGo/dav/${config.username}/Contacts/public/`,
      init: {
        method: 'REPORT',
        namespace: ns,
        headers: { ...webdav.headers, depth: '1' },
        body: {
          'addressbook-query': {
            _attributes: getDAVAttribute([
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'address-data', namespace: DAVNamespace.CARDDAV }]),
            filter: {
              _attributes: { test: 'anyof' },
              'prop-filter': [
                {
                  _attributes: { name: 'FN', test: 'allof' },
                  'text-match': [
                    {
                      _attributes: { collation: 'i;unicasemap', 'match-type': 'contains' },
                      _text: 'No match' // should not match any card
                    }
                  ]
                },
                {
                  _attributes: { name: 'EMAIL', test: 'allof' },
                  'text-match': {
                    _attributes: { collation: 'i;unicasemap', 'match-type': 'starts-with' },
                    _text: `${config.attendee1}`
                  }
                }
                ]
            }
          }
        },
        elementNameFn: (name) => {
          if (!/^.+:.+/.test(name)) {
            return `${ns}:${name}`
          }
          return name
        }
      }
    })
    expect(response.length)
      .withContext(`Number of results from addressbook-query`)
      .toBe(1)
    expect(response[0].status)
      .withContext(`HTTP status code of addressbook-query`)
      .toEqual(207)

    vcard = ICAL.Component.fromString(response[0].props.addressData.toString())
    emails = []
    for (const prop of vcard.getAllProperties('email')) {
      emails.push(prop.getFirstValue())
    }
    expect(emails)
      .withContext(`Returned vCard has email of ${config.attendee1_username} (${config.attendee1})`)
      .toContain(config.attendee1)
  }, config.timeout || 10000) // increase timeout for this long test

  // CARDDAV:addressbook-multiget Report
  // https://datatracker.ietf.org/doc/html/rfc6352#section-8.7
  it("supports for addressbook-multiget", async function() {
    const hrefs = Object.keys(cards).map(c => `${resource}${c}`)
    const response = await davRequest({
      url: webdav.serverUrl + resource,
      init: {
        method: 'REPORT',
        namespace: DAVNamespaceShorthandMap[DAVNamespace.CARDDAV],
        headers: { ...webdav.headers, depth: '0' },
        body: {
          'addressbook-multiget': {
            _attributes: getDAVAttribute([
              DAVNamespace.CARDDAV,
              DAVNamespace.DAV
            ]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:prop`]: formatProps([{ name: 'address-data', namespace: DAVNamespace.CARDDAV }]),
            [`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:href`]: hrefs
          }
        }
      },
    })
    expect(response.length).toBe(2)
    for (let r of response) {
      const [name, ...rest] = r.href.split('/').reverse()
      expect(r.status)
        .withContext(`HTTP status code of addressbook-multiget`)
        .toEqual(207)
      expect(utility.componentsAreEqual(r.props.addressData, cards[name]))
        .withContext(`Cards returned in addressbook-multiget`)
        .toBe(true)
    }
  }, config.timeout || 10000)
})