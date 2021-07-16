import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

describe('create, read, modify, delete tasks for regular user', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdav_subscriber = new WebDAV(config.subscriber_username, config.subscriber_password)
  const utility = new TestUtility(webdav)

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
    'old.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:Old;Carte
FN:Carte 'old'
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
END:VCARD`,
    'old-modified.vcf': `BEGIN:VCARD
VERSION:3.0
PRODID:-//Inverse//Card Generator//EN
UID:NEWTESTCARD
N:Old;Carte modifiee
FN:Carte modifiee 'old'
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

  const sogoRights = {
    c: 'ObjectCreator',
    d: 'ObjectEraser',
    v: 'ObjectViewer',
    e: 'ObjectEditor'
  }

  const resource = `/SOGo/dav/${config.username}/Contacts/test-dav-acl/`

  const _putCard = async function(client, filename, expectedCode, realCard) {
    const card = cards[realCard || filename]
    if (!card)
      throw new Error(`Card ${realCard || filename} is unknown`)
    const response = await client.createVCard(resource, filename, card)
    expect(response.status).toBe(expectedCode)
  }

  const _getCard = async function(client, filename, expectedCode) {
    const [{ status }] = await client.getCard(resource, filename)
    expect(status).toBe(expectedCode)
  }

  const _deleteCard = async function(client, filename, expectedCode = 204) {
    const response = await client.deleteObject(resource + filename)
    expect(response.status)
      .withContext('HTTP status code when deleting a card')
      .toBe(expectedCode)
  }

  const _testView = async function(rights) {
    let expectedCode = 403
    if (rights && (rights.v || rights.e)) {
      expectedCode = 200
    }
    await _getCard(webdav_subscriber, 'old.vcf', expectedCode)
  }

  const _testCreate = async function(rights) {
    let expectedCode
    if (rights && rights.c)
      expectedCode = 201
    else
      expectedCode = 403
    await _putCard(webdav_subscriber, 'new.vcf', expectedCode)
  }

  const _testModify = async function(rights) {
    let expectedCode
    if (rights && rights.e)
      expectedCode = 204
    else
      expectedCode = 403
    await _putCard(webdav_subscriber, 'old.vcf', expectedCode, 'old-modified.vcf')
  }

  const _testDelete = async function(rights) {
    let expectedCode = 403
    if (rights && rights.d) {
      expectedCode = 204
    }
    await _deleteCard(webdav_subscriber, 'old.vcf', expectedCode)
  }

  const _testRights = async function(rights) {
    const results = await utility.setupAddressBookRights(resource, config.subscriber_username, rights)
    expect(results.length).toBe(1)
    expect(results[0].status).toBe(204)
    await _testCreate(rights)
    await _testView(rights)
    await _testModify(rights)
    await _testDelete(rights)
  }

  beforeEach(async function() {
    await webdav.deleteObject(resource)
    await webdav.makeAddressBook(resource)
    await _putCard(webdav, 'old.vcf', 201)
  })

  afterEach(async function() {
    await webdav_su.deleteObject(resource)
  })

  // DAVAddressBookAclTest

  it("'view' only", async function() {
    await _testRights({ v: true })
  })

  it("'edit' only", async function() {
    await _testRights({ e: true })
  })

  it("'create' only", async function() {
    await _testRights({ c: true })
  })

  it("'delete' only", async function() {
    await _testRights({ d: true })
  })

  it("'create', 'delete'", async function() {
    await _testRights({ c: true, d: true })
  })

  it("'view', 'delete'", async function() {
    await _testRights({ v: true, d: true })
  })

  it("'edit', 'create'", async function() {
    await _testRights({ c: true, e: true })
  })

  it("'edit', 'delete'", async function() {
    await _testRights({ d: true, e: true })
  })
})