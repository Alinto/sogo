import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'

describe('create, read, modify, delete events for regular user', function() {
  const webdav = new WebDAV(config.username, config.password)
  const webdav_su = new WebDAV(config.superuser, config.superuser_password)
  const webdav_subscriber = new WebDAV(config.subscriber_username, config.subscriber_password)
  const utility = new TestUtility(webdav)

  const event_template = `BEGIN:VCALENDAR
PRODID:-//Inverse//Event Generator//EN
VERSION:2.0
BEGIN:VEVENT
SEQUENCE:0
TRANSP:OPAQUE
UID:12345-%(class)-%(filename)
SUMMARY:%(class) event (orig. title)
DTSTART:20090805T100000Z
DTEND:20090805T140000Z
CLASS:%(class)
DESCRIPTION:%(class) description
LOCATION:location
%(organizer_line)%(attendee_line)CREATED:20090805T100000Z
DTSTAMP:20090805T100000Z
END:VEVENT
END:VCALENDAR`

  const task_template = `BEGIN:VCALENDAR
PRODID:-//Inverse//Event Generator//EN
VERSION:2.0
BEGIN:VTODO
CREATED:20100122T201440Z
LAST-MODIFIED:20100201T175246Z
DTSTAMP:20100201T175246Z
UID:12345-%(class)-%(filename)
SUMMARY:%(class) event (orig. title)
CLASS:%(class)
DESCRIPTION:%(class) description
STATUS:IN-PROCESS
PERCENT-COMPLETE:0
END:VTODO
END:VCALENDAR`

  const resource = `/SOGo/dav/${config.username}/Calendar/test-dav-acl/`
  const classToICSClass = {
    'pu': 'PUBLIC',
    'pr': 'PRIVATE',
    'co': 'CONFIDENTIAL'
  }

  let user

  const _checkViewEventRight = function(operation, event, eventClass, right) {
    if (right) {
      expect(event)
        .withContext(`Returned event during operation '${operation}'`)
        .toBeTruthy()
      if (['v', 'r', 'm'].includes(right)) {
        const iscClass = classToICSClass[eventClass]
        const expectedEvent = utility.formatTemplate(event_template, {
          'class': iscClass,
          'filename': `${iscClass.toLowerCase()}-event.ics`
        })
        expect(event).toBe(expectedEvent)
      }
      else if (right == 'd') {
        _testEventIsSecureVersion(eventClass, event)
      }
      else {
        throw new Error(`Right '${right} is not supported`)
      }
    }
    else {
      expect(event).toBeFalsy()
    }
  }

  const _currentUserPrivilegeSet = async function(resource, expectedCode = 207) {
    const results = await webdav_subscriber.currentUserPrivilegeSet(resource)
    expect(results.length).toBe(1)
    const response = results[0]
    expect(response.status).toBe(expectedCode)
    let privileges = []
    if (expectedCode < 300) {
      privileges = response.props.currentUserPrivilegeSet.privilege.map(o => {
        return Object.keys(o)[0]
      })
    }
    return privileges
  }

  const _deleteEvent = async function(client, filename, expectedCode = 204) {
    const response = await client.deleteObject(resource + filename)
    expect(response.status).toBe(expectedCode)
  }

  const _getEvent = async function(eventClass, isInvitation = false) {
    const iscClass = classToICSClass[eventClass].toLowerCase()
    const filename = (isInvitation ? `invitation-${iscClass}` : iscClass) + '-event.ics'
    const [{ status, raw = '' }] = await webdav_subscriber.getEvent(resource, filename)

    if (status == 200)
      return raw.replace(/\r\n/g,'\n')
    else
      return undefined
  }

  const _multigetEvent = async function(eventClass) {
    const iscClass = classToICSClass[eventClass].toLowerCase()
    const filename = `${iscClass}-event.ics`
    let event = undefined
    const results = await webdav_subscriber.calendarMultiGet(resource, filename)
    if (results.status !== 404) {
      results.find(o => {
        if (o.href == resource + filename) {
          const { props: { calendarData = '' } } = o
          event = calendarData.replace(/\r\n/g,'\n')
          return true
        }
        return false
      })
    }
    return event
  }

  const _propfindEvent = async function(eventClass) {
    const iscClass = classToICSClass[eventClass].toLowerCase()
    const filename = `${iscClass}-event.ics`
    const results = await webdav_subscriber.propfindEvent(resource + filename)
    let event = undefined
    if (results.status !== 404) {
      results.find(o => {
        if (o.href == resource + filename) {
          const { props: { calendarData = '' } } = o
          event = calendarData.replace(/\r\n/g,'\n')
          return true
        }
        return false
      })
    }
    return event
  }

  const _putEvent = async function(client, filename, eventClass = 'PUBLIC', expectedCode = 201, organizer, attendee, partstat = 'NEEDS-ACTION') {
    const organizer_line = organizer ? `ORGANIZER:${organizer}\n` : ''
    const attendee_line = attendee ? `ATTENDEE;PARTSTAT=${partstat}:${attendee}\n` : ''
    const event = utility.formatTemplate(event_template, {
      'class': eventClass,
      'filename': filename,
      organizer_line,
      attendee_line
    })
    const response = await client.createCalendarObject(resource, filename, event)
    expect(response.status).toBe(expectedCode)
  }

  const _webdavSyncEvent = async function(eventClass) {
    const iscClass = classToICSClass[eventClass].toLowerCase()
    const filename = `${iscClass}-event.ics`
    let event = undefined
    const results = await webdav_subscriber.syncColletion(resource)
    if (results.status !== 404) {
      results.find(o => {
        if (o.href == resource + filename) {
          const { props: { calendarData = '' } } = o
          event = calendarData.length ? calendarData.replace(/\r\n/g,'\n') : undefined
          return true
        }
        return false
      })
    }
    return event
  }

  const _testCreate = async function(rights) {
    let expectedCode
    if (rights.c)
      expectedCode = 201
    else if (Object.keys(rights).length === 0)
      expectedCode = 404
    else
      expectedCode = 403
    return _putEvent(webdav_subscriber, 'creation-test.ics', 'PUBLIC', expectedCode)
  }

  const _testCollectionDAVAcl = async function(rights) {
    let expectedPrivileges = []
    if (Object.keys(rights).length > 0) {
      expectedPrivileges.push('read', 'readCurrentUserPrivilegeSet', 'readFreeBusy')
    }
    if (rights.c) {
      expectedPrivileges.push(
        'bind',
        'writeContent',
        'schedule',
        'schedulePost',
        'schedulePostVevent',
        'schedulePostVtodo',
        'schedulePostVjournal',
        'schedulePostVfreebusy',
        'scheduleDeliver',
        'scheduleDeliverVevent',
        'scheduleDeliverVtodo',
        'scheduleDeliverVjournal',
        'scheduleDeliverVfreebusy',
        'scheduleRespond',
        'scheduleRespondVevent',
        'scheduleRespondVtodo'
      )
    }
    if (rights.d) {
      expectedPrivileges.push('unbind')
    }
    const expectedCode = (expectedPrivileges.length == 0) ? 404 : 207
    const privileges = await _currentUserPrivilegeSet(resource, expectedCode)

    // When comparing privileges on DAV collection, we remove all 'default'
    // privileges on the collection.
    for (const c of ['Public', 'Private', 'Confidential']) {
      for (const r of ['viewdant', 'viewwhole', 'modify', 'respondto']) {
        const i = privileges.indexOf(`${r}${c}Records`)
        if (i >= 0) {
          privileges.splice(i, 1)
        }
      }
    }
    // for (const privilege of ['read', 'readCurrentUserPrivilegeSet', 'readFreeBusy']) {
    for (const expectedPrivilege of expectedPrivileges) {
      expect(privileges).toContain(expectedPrivilege)
    }
  }

  const _testEventIsSecureVersion = function(eventClass, event) {
    const iscClass = classToICSClass[eventClass].toLowerCase().replace(/^\w/, c => c.toUpperCase())
    const expectedDict = {
      version: 'VERSION:2.0',
      prodid: 'PRODID:-//Inverse//Event Generator//EN',
      summary: `SUMMARY:(${iscClass} event)`,
      dtstart: 'DTSTART:20090805T100000Z',
      dtend: 'DTEND:20090805T140000Z',
      dtstamp: 'DTSTAMP:20090805T100000Z',
      'x-sogo-secure': 'X-SOGO-SECURE:YES'
    }
    const eventDict = utility.versitDict(event)
    // Ignore UID
    for (const key of Object.keys(eventDict).filter(k => k !== 'uid')) {
      expect(expectedDict[key])
        .withContext(`Key ${key} of secure event is expected`)
        .toBeTruthy()
      if (expectedDict[key])
        expect(expectedDict[key])
        .withContext(`Value of key ${key} of secure event is valid`)
        .toBe(eventDict[key])
    }
    for (const key of Object.keys(expectedDict)) {
      expect(eventDict[key])
        .withContext(`Key ${key} of secure event is present`)
        .toBeTruthy()
    }
  }

  const _testModify = async function(eventClass, right, errorCode) {
    const iscClass = classToICSClass[eventClass]
    const filename = `${iscClass.toLowerCase()}-event.ics`
    let expectedCode = errorCode
    if (['r', 'm'].includes(right))
      expectedCode = 204
    return _putEvent(webdav_subscriber, filename, iscClass, expectedCode)
  }

  const _testRespondTo = async function(eventClass, right, errorCode) {
    const iscClass = classToICSClass[eventClass]
    const filename = `invitation-${iscClass.toLowerCase()}-event.ics`
    let expectedCode = errorCode
    if (['r', 'm'].includes(right))
      expectedCode = 204

    await _putEvent(webdav, filename, iscClass, 201, 'mailto:nobody@somewhere.com', user.email, 'NEEDS-ACTION')

    // here we only do 'passive' validation: if a user has a "respond to"
    // right, only the attendee entry will me modified. The change of
    // organizer must thus be silently ignored below.
    await _putEvent(webdav_subscriber, filename, iscClass, expectedCode, 'mailto:someone@nowhere.com', user.email, 'ACCEPTED')

    if (expectedCode == 204) {
      const attendee_line = `ATTENDEE;PARTSTAT=ACCEPTED:${user.email}\n`
      let expectedEvent
      if (right == 'r') {
        expectedEvent = utility.formatTemplate(event_template, {
          'class': iscClass,
          'filename': filename,
          organizer_line: 'ORGANIZER;CN=nobody@somewhere.com:mailto:nobody@somewhere.com\n',
          attendee_line
        })
      }
      else {
        expectedEvent = utility.formatTemplate(event_template, {
          'class': iscClass,
          'filename': filename,
          organizer_line: 'ORGANIZER;CN=someone@nowhere.com:mailto:someone@nowhere.com\n',
          attendee_line
        })
      }
      const event = await _getEvent(eventClass, true)
      expect(utility.calendarsAreEqual(expectedEvent, event))
        .withContext('Calendars of organizer and attendee are identical')
        .toBe(true)
    }
  }

  const _testEventDAVAcl = async function(eventClass, right, errorCode) {
    const iscClass = classToICSClass[eventClass].toLowerCase()
    for (const suffix of ['event', 'task']) {
      const filename = `${iscClass}-${suffix}.ics`
      let expectedCode = errorCode
      let expectedPrivileges = []
      if (right) {
        expectedCode = 207
        expectedPrivileges.push('readCurrentUserPrivilegeSet', 'viewDateAndTime', 'read')
        if (right != 'd') {
          expectedPrivileges.push('viewWholeComponent')
          if (right != 'v') {
            expectedPrivileges.push('respondToComponent', 'writeContent')
            if (right != 'r') {
              expectedPrivileges.push('writeProperties', 'write')
            }
          }
        }
      }
      const privileges = await _currentUserPrivilegeSet(resource + filename, expectedCode)
      if (errorCode != expectedCode) {
        for (const expectedPrivilege of expectedPrivileges) {
          expect(privileges).toContain(expectedPrivilege)
        }
      }
    }
  }

  const _testEventRight = async function(eventClass, rights) {
    const right = Object.keys(rights).includes(eventClass) ? rights[eventClass] : undefined

    let event

    event = await _getEvent(eventClass)
    _checkViewEventRight('GET', event, eventClass, right)

    event = await _propfindEvent(eventClass)
    _checkViewEventRight('PROPFIND', event, eventClass, right)

    event = await _multigetEvent(eventClass)
    _checkViewEventRight('multiget', event, eventClass, right)

    event = await _webdavSyncEvent(eventClass)
    _checkViewEventRight('webdav-sync', event, eventClass, right)

    const errorCode = (Object.keys(rights).length > 0) ? 403 : 404
    await _testModify(eventClass, right, errorCode)
    await _testRespondTo(eventClass, right, errorCode)
    await _testEventDAVAcl(eventClass, right, errorCode)
  }

  const _testDelete = async function(rights) {
    let expectedCode = 403
    if (rights && rights.d) {
      expectedCode = 204
    }
    else if (Object.keys(rights) == 0) {
      expectedCode = 404
    }
    for (const eventClass of Object.values(classToICSClass)) {
      await _deleteEvent(webdav_subscriber, `${eventClass.toLocaleLowerCase()}-event.ics`, expectedCode)
    }
  }

  const _testRights = async function(rights) {
    const results = await utility.setupCalendarRights(resource, config.subscriber_username, rights)
    expect(results.length).toBe(1)
    expect(results[0].status)
      .withContext(`Setup rights (${JSON.stringify(rights)}) on ${resource}`)
      .toBe(204)
    await _testCreate(rights)
    await _testCollectionDAVAcl(rights)
    await _testEventRight('pu', rights)
    await _testEventRight('pr', rights)
    await _testEventRight('co', rights)
    await _testDelete(rights)
  }

  beforeEach(async function() {
    user = await utility.fetchUserInfo(config.username)
    await webdav.deleteObject(resource)
    await webdav.makeCalendar(resource)
    for (const c of Object.values(classToICSClass)) {
      // Create event for each class
      const eventFilename = `${c.toLowerCase()}-event.ics`
      const event = utility.formatTemplate(event_template, {
        'class': c,
        'filename': eventFilename
      })
      let response = await webdav.createCalendarObject(resource, eventFilename, event)
      expect(response.status)
        .withContext(`HTTP status when creating event with ${c} class`)
        .toBe(201)
      // Create task for each class
      const taskFilename = `${c.toLowerCase()}-task.ics`
      const task = utility.formatTemplate(task_template, {
        'class': c,
        'filename': taskFilename
      })
      response = await webdav.createCalendarObject(resource, taskFilename, task)
      expect(response.status)
        .withContext(`HTTP status when creating task with ${c} class`)
        .toBe(201)
    }
  })

  afterEach(async function() {
    await webdav_su.deleteObject(resource)
  })

  // DAVCalendarAclTest

  it("'view all' on a specific class (PUBLIC)", async function() {
    await _testRights({ pu: 'v' })
  })

  it("'modify' PUBLIC, 'view all' PRIVATE, 'view d&t' confidential", async function() {
    await _testRights({ pu: 'm', pr: 'v', co: 'd' })
  })

  it("'create' only", async function() {
    await _testRights({ c: true })
  })

  it("'delete' only", async function() {
    await _testRights({ d: true })
  })

  it("'create', 'delete', 'view d&t' PUBLIC, 'modify' PRIVATE", async function() {
    await _testRights({ c: true, d: true, pu: 'd', pr: 'm' })
  })

  it("'create', 'respond to' PUBLIC", async function() {
    await _testRights({ c: true, pu: 'r' })
  })

  it("no right given", async function() {
    await _testRights({})
  })

})