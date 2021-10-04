import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

import {
  DAVNamespace,
  DAVNamespaceShorthandMap,
  davRequest
} from 'tsdav'
import { formatProps, getDAVAttribute } from 'tsdav/dist/util/requestHelpers';

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
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
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
TEL;TYPE=work:+1 514 123-3372
TEL;TYPE=home:tel dom
TEL;TYPE=cell:portable
TEL;TYPE=fax:fax
TEL;TYPE=pager:pager
X-MOZILLA-HTML:FALSE
EMAIL;TYPE=work:address.email@domaine.ca
EMAIL;TYPE=home:address.email@domaine2.com
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

  // https://datatracker.ietf.org/doc/html/rfc6352#section-8.7
  fit("supports for addressbook-multiget", async function() {
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
  })
})