import config from '../lib/config'
import { default as WebDAV, DAVMailHeaderShort, DAVHttpMail, DAVMailHeader } from '../lib/WebDAV'
import TestUtility from '../lib/utilities'
import { fetch } from 'cross-fetch'
import { DAVNamespace, DAVNamespaceShorthandMap } from 'tsdav'

const message1 = `Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 17 Dec 2009 07:42:16 -0400
Received: from aloha.dev (localhost [127.0.0.1])
         by aloha.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 29 Sep 2009 07:42:16 -0400
Message-ID: <4AC1F29sept6.5060801@cyril.dev>
Date: Mon, 28 Sep 2009 07:42:14 -0400
From: Cyril <message1from@cyril.dev>
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
References: <4AC3BF1B.3010806@inverse.ca>
MIME-Version: 1.0
To: message1to@cyril.dev
CC: 2message1cc@cyril.dev, user10@cyril.dev
Subject: message1subject
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

--
Cyril <cyril@cyril.dev>
`
let msg1Size = 874
const message2 = `Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 09 Dec 2009 07:42:16 -0400
Message-ID: <410sepAC1F296.5060801a@cyril.dev>
Date: Tue, 10 Sep 2009 07:42:14 -0400
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
From: Cyril <message2from@cyril.dev>
To: message2to@cyril.dev
CC: 3message2cc@cyril.dev
Subject: message2subject
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
Stuff StuffStuffStuffStuff StuffStuffStuff StuffStuff
--
Cyril <cyril@cyril.dev>
`
let msg2Size = 4398
const message3 = `Return-Path: <cyril@cyril.dev>
Received: from cyril.dev (localhost [127.0.0.1])
         by cyril.dev (Cyrus v2.3.8-Debian-2.3.8-1) with LMTPA;
         Tue, 15 Dec 2009 07:42:16 -0400
Message-ID: <4AC1aF2dec96.5060801a@cyril.dev>
Date: Tue, 10 Dec 2009 07:42:14 -0400
User-Agent: Thunderbird 2.0.0.22 (Macintosh/20090605)
MIME-Version: 1.0
From: Cyril <message3from@cyril.dev>
To: message3to@cyril.dev
CC: 1message3cc@cyril.dev
Subject: Hallo
Content-Type: text/plain; charset=us-ascii; format=flowed
Content-Transfer-Encoding: 7bit
Reply-To: support@inverse.ca

Hello Jacques,

Can you read me?

This message is just a bit larger than message1 but smaller than message2
--
Cyril <cyril@cyril.dev>`
let msg3Size = 720

let webdav, utility
let user, resource, mailboxesList

// DAVMailCollectionTest

describe('MailDAV', function() {

  const _deleteMailbox = async function (path, expectedCode = 204) {
    const folderPath = path.split('/').map(p => `folder${p}`).join('/')
    const response = await webdav.deleteObject(resource + folderPath)
    if (expectedCode) {
      expect(response.status)
        .withContext(`HTTP status code when deleting the mailbox ${path}`)
        .toBe(expectedCode)
    }
  }

  const _makeMailbox = async function (path, expectedCode = 201) {
    const [lastFolder, ...parents] = path.split('/').reverse()
    let mailPath = lastFolder
    if (parents.length) {
      // Prefix parent names with "folder"
      mailPath = parents.reverse().map(p => `folder${p}`).join('/') + '/' + lastFolder
    }
    const [response] = await webdav.makeCollection(resource + mailPath)
    if (mailboxesList.indexOf(path) < 0)
      mailboxesList.push(path)
    expect(response.status)
      .withContext(`HTTP status code when creating the mailbox ${path}`)
      .toBe(expectedCode)
  }

  const _putMessage = async function (path, message, expectedCode = 201) {
    const url = resource + `folder${path}`
    const localHeaders = {'Content-Type': 'message/rfc822'}
    const response = await fetch(webdav.serverUrl + url, {
      method: 'PUT',
      headers: { ...webdav.headers, ...localHeaders },
      body: message
    })
    if (expectedCode != null)
      expect(response.status)
        .withContext(`HTTP status code when putting a message`)
        .toBe(expectedCode)
    if (response.status >= 200)
      return response.headers.get('location');
  }

  const _testFilter = async function (filter) {
    const [filters, hrefs] = filter
    const url = `${resource}foldertest-dav-mail`
    const results = await webdav.mailQueryMaildav(url, ['displayname', 'getcontentlength'], filters)
    let messages = {}

    let received_count = 0
    for (let response of results) {
      expect(response.status)
      .withContext(`HTTP status code when performing a mail query`)
      .toBe(207)
      if (response.href) {
        expect(hrefs.includes(response.href))
        .withContext(`${response.href} is returned (filter: ${JSON.stringify(filters)}, expected results: ${hrefs.join(', ')})`)
        .toBeTrue()
        messages[response.href] = response.props
        received_count++
      }
    }
    expect(received_count)
    .withContext(`Expected number of results from mail query ${JSON.stringify(filters)}`)
    .toEqual(hrefs.length)

    return messages
  }

  const _testSort = async function (sortAttribute, expectedHrefs, ascending = true) {
    const url = `${resource}foldertest-dav-mail`
    const results = await webdav.mailQueryMaildav(url, ['displayname'], null, sortAttribute, ascending)

    let received_count = 0
    for (let i = 0; i < results.length; i++) {
      let response = results[i]
      expect(response.status)
      .withContext(`HTTP status code when performing a mail sorting query`)
      .toBe(207)
      if (response.href) {
        expect(response.href)
        .withContext(`Sort result at position ${i} on attribute ${sortAttribute}`)
        .toEqual(expectedHrefs[i])
        received_count++
      }
    }
    expect(received_count)
    .withContext(`Expected number of results from mail sorting query by ${sortAttribute}`)
    .toEqual(expectedHrefs.length)
  }

  const _testProperty = async function (url, namespace, property, expected) {
    const [result] = await webdav.propfindWebdav(url, [property], namespace)
    const { props: { [utility.camelCase(property)]: objectProperty }} = result

    if (['from', 'to', 'cc'].includes(property)) {
      const addresses = objectProperty.split(/, /).map(s => s.replace(/.*<(.+)>.*/, "$1"))
      for (let address of expected) {
        expect(addresses).toContain(address)
      }
    }
    else {
      expect(objectProperty)
      .withContext(`Property ${utility.camelCase(property)} of ${url}`)
      .toEqual(expected)
    }
  }

  beforeAll(async function() {
    webdav = new WebDAV(config.username, config.password)
    utility = new TestUtility(webdav)
    user = await utility.fetchUserInfo(config.username)
    resource = `/SOGo/dav/${config.username}/Mail/0/`
  })

  beforeEach(function() {
    mailboxesList = []
  })

  afterEach(async function() {
    for (let path of mailboxesList.reverse()) {
      await _deleteMailbox(path, null)
    }
  })

  it(`Folder creation`, async function() {
    await _makeMailbox('test-dav-mail-%40-abc')
    await _makeMailbox('test-dav-mail-@-def')
    await _makeMailbox('test-dav-mail-%20-ghi')
    await _makeMailbox('test-dav-mail-%20-ghi', 500)
    await _makeMailbox('test-dav-mail')
    await _makeMailbox('test-dav-mail/test-dav-mail')
  })

  it(`Message creation`, async function() {
    const mailbox = 'test-dav-mail'
    let itemLocation, url, response

    await _makeMailbox(mailbox)

    // message creation on collection url
    itemLocation = await _putMessage(mailbox, message1);
    [response] = await webdav.getObject(itemLocation)
    expect(response.status)
      .withContext(`HTTP status code when fetching a message`)
      .toBe(200)

    // message creation with explicit filename
    itemLocation = await _putMessage(`${mailbox}/blabla.eml`, message1);
    [response] = await webdav.getObject(itemLocation)
    expect(response.status)
      .withContext(`HTTP status code when fetching a message`)
      .toBe(200)
  })

  it(`mail-query filters`, async function() {
    const mailbox = 'test-dav-mail'
    const url = `${resource}folder${mailbox}`
    let msg1Loc, msg2Loc, msg3Loc
    let msgs, filter, filters

    await _makeMailbox(mailbox)
    msg1Loc = await _putMessage(mailbox, message1);
    msg2Loc = await _putMessage(mailbox, message2);
    msg3Loc = await _putMessage(mailbox, message3);

    // Fetch messages sizes
    msgs = await _testFilter([{}, [msg1Loc, msg2Loc, msg3Loc]])
    msg1Size = msgs[msg1Loc].getcontentlength
    msg2Size = msgs[msg2Loc].getcontentlength
    msg3Size = msgs[msg3Loc].getcontentlength

    // 1. test filter: sent-date
    //   SENTSINCE, SENTBEFORE, SENTON
    filters = [
      [
        {
          'sent-date': {
            from: '20091201T000000Z',
            to: '20091208T000000Z'
          }
        },
        []
      ],
      [
        {
          'sent-date': {
            from: '20090908T000000Z',
            to: '20090913T134300Z'
          }
        },
        [ msg2Loc ]
      ],
      [
        {
          'sent-date': {
            from: '20090908T000000Z',
            to: '20091016T134300Z'
          }
        },
        [ msg1Loc, msg2Loc ]
      ],
      [
        {
          'sent-date': {
            from: '20091210T000000Z',
            to: '20091220T134300Z'
          }
        },
        [ msg3Loc ]
      ],
      [
        {
          'sent-date': {
            from: '20091220T000000',
            to: '20091229T134300Z'
          }
        },
        []
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 2. test filter: uid
    filters = [
      [
        { uid: { from: '1' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { uid: { to: '5' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { uid: { from: '1', to: '2' }},
        [ msg1Loc, msg2Loc ]
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 3. test filter: from
    //   FROM
    filters = [
      [
        { from: { match: 'message' } },
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { from: { match: 'Cyril' } },
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { from: { match: 'cyril.dev' } },
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { from: { match: 'message1from' } },
        [ msg1Loc ]
      ],
      [
        { from: { match: 'message2from' } },
        [ msg2Loc ]
      ],
      [
        { from: { match:  'message3from' } },
        [ msg3Loc ]
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 4. test filter: to
    //   TO
    filters = [
      [
        { to: { match: 'message' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { to: { match: 'Cyril' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { to: { match: 'message1to' }},
        [ msg1Loc ]
      ],
      [
        { to: { match: 'message2to' }},
        [ msg2Loc ]
      ],
      [
        { to: { match: 'message3to' }},
        [ msg3Loc ]
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 5. test filter: cc
    //   CC
    filters = [
      [
        { cc: { match: 'message' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { cc: { match: 'Cyril' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { cc: { match: 'cyril.dev' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { cc: { match: 'message1cc' }},
        [ msg1Loc ]
      ],
      [
        { cc: { match: 'message2cc' }},
        [ msg2Loc ]
      ],
      [
        { cc: { match: 'message3cc' }},
        [ msg3Loc ]
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 6. test filter: body
    //   BODY
    filters = [
      [
        { body: { match: 'Hello' }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { body: { match: 'Stuff' }},
        [ msg2Loc ]
      ],
      [
        { body: { match: 'DOESNOT MATCH' }},
        []
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 7. test filter: size
    //   LARGER, SMALLER
    filters = [
      [
        { size: { min: msg1Size, max: msg1Size }},
        []
      ],
      [
        { size: { min: msg1Size -1, max: msg1Size +1 }},
        [ msg1Loc ]
      ],
      [
        { size: { min: msg3Size -1, max: msg2Size +1 }},
        [ msg1Loc, msg2Loc, msg3Loc ]
      ],
      [
        { size: { min: msg1Size -1, max: msg2Size +1 }},
        [ msg1Loc, msg2Loc ]
      ],
      [
        { size: { min: msg3Size -1, max: msg1Size +1 }},
        [ msg1Loc, msg3Loc ]
      ],
      [
        [
          { size: { min: msg3Size -1, max: msg2Size +1 } },
          { size: { max: msg1Size +1, not: "true" } }
        ],
        [ msg2Loc ]
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

    // 8. test filter: multiple combinations
    filters = [
      [
        {
          body: { match: "Hello" },
          cc: { match: "message1cc" }
        },
          [ msg1Loc ]
      ],
      [
        {
          to: { match: "message" },
          uid: { from: "1", to: "2" }
        },
        [ msg1Loc, msg2Loc ]
      ],
      [
        {
          to: { match: "message" },
          uid: { from: "1", to: "2" },
          cc: { match: "message3cc" }
        },
        []
      ]
    ]

    for (filter of filters) {
      await _testFilter(filter)
    }

  }, 30000) // increase timeout for this long test

  it(`mail-query sort`, async function() {
    const mailbox = 'test-dav-mail'
    const url = `${resource}folder${mailbox}`
    let msg1Loc, msg2Loc, msg3Loc
    let filter, filters

    await _makeMailbox(mailbox)
    msg1Loc = await _putMessage(mailbox, message1);
    msg2Loc = await _putMessage(mailbox, message2);
    msg3Loc = await _putMessage(mailbox, message3);

    await _testSort(`${DAVMailHeaderShort}:received`, [msg1Loc, msg2Loc, msg3Loc])
    await _testSort(`${DAVMailHeaderShort}:date`, [ msg2Loc, msg1Loc, msg3Loc ])
    await _testSort(`${DAVMailHeaderShort}:from`, [ msg1Loc, msg2Loc, msg3Loc ])
    await _testSort(`${DAVMailHeaderShort}:to`, [ msg1Loc, msg2Loc, msg3Loc ])
    await _testSort(`${DAVMailHeaderShort}:cc`, [ msg3Loc, msg1Loc, msg2Loc ])
    await _testSort(`${DAVMailHeaderShort}:subject`, [ msg3Loc, msg1Loc, msg2Loc ])
    await _testSort(`${DAVNamespaceShorthandMap[DAVNamespace.DAV]}:getcontentlength`, [ msg3Loc, msg1Loc, msg2Loc ])
    await _testSort(`${DAVMailHeaderShort}:cc`, [ msg2Loc, msg1Loc, msg3Loc ], false)

  }, 30000) // increase timeout for this long test

  it(`message properties`, async function() {
    const mailbox = 'test-dav-mail'
    await _makeMailbox(mailbox)
    const msg1Loc = await _putMessage(mailbox, message1);

    await _testProperty(msg1Loc, DAVHttpMail, 'date', 'Mon, 28 Sep 2009 11:42:14 GMT')
    await _testProperty(msg1Loc, DAVHttpMail, 'hasattachment', 0)
    await _testProperty(msg1Loc, DAVHttpMail, 'read', 0)
    await _testProperty(msg1Loc, DAVHttpMail, 'textdescription', `<![CDATA[${message1}]]>`)
    await _testProperty(msg1Loc, DAVHttpMail, 'unreadcount', {})
    await _testProperty(msg1Loc, DAVMailHeader, 'cc', ['2message1cc@cyril.dev', 'user10@cyril.dev'])
    await _testProperty(msg1Loc, DAVMailHeader, 'date', 'Mon, 28 Sep 2009 11:42:14 GMT')
    await _testProperty(msg1Loc, DAVMailHeader, 'from', ['message1from@cyril.dev'])
    await _testProperty(msg1Loc, DAVMailHeader, 'in-reply-to', {})
    await _testProperty(msg1Loc, DAVMailHeader, 'message-id', '<4AC1F29sept6.5060801@cyril.dev>')
    await _testProperty(msg1Loc, DAVMailHeader, 'references', '<4AC3BF1B.3010806@inverse.ca>')
    await _testProperty(msg1Loc, DAVMailHeader, 'subject', 'message1subject')
    await _testProperty(msg1Loc, DAVMailHeader, 'to', ['message1to@cyril.dev'])
  }, 30000) // increase timeout for this long test
})