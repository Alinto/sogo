import {
  DAVNamespace,
  davRequest,
  propfind
} from 'tsdav'
import ICAL from 'ical.js'

class TestUtility {
  constructor(webdav) {
    this.webdav = webdav
    this.userInfo = {}
  }

  async fetchUserInfo(login) {
    if (!this.userInfo[login]) {
      const results = await propfind({
        url: `${this.webdav.serverUrl}/SOGo/dav/${login}/`,
        props: [
           { name: 'displayname', namespace: DAVNamespace.DAV },
           { name: 'calendar-user-address-set', namespace: DAVNamespace.CALDAV }
        ],
        depth: '0',
        headers: this.webdav.headers,
      })
      if (results.length != 1) {
        throw new Error(`Unexpected number of status in profind for user ${login}`)
      }

      const response = results[0]
      if (!response.props.calendarUserAddressSet.href.length) {
        throw new Error(`No address found in calendar-user-address-set for user ${login}`)
      }

      let displayname = response.props.displayname || ''
      let email = response.props.calendarUserAddressSet.href[0]
      this.userInfo[login] = { displayname: displayname, email: email }
    }
    return this.userInfo[login]
  }

  formatTemplate(template, vars) {
    var s = template
    Object.keys(vars).forEach(k => {
      s = s.replace(new RegExp(`%\\(${k}\\)`, 'g'), vars[k])
    })
    s = s.replace(/%\([^\)]+\)/g, '') // clear all reminding placeholders
    return s;
  }

  setupRights(resource, username, rights) {
    const action = (typeof rights == 'undefined') ? 'remove-user' : 'set-roles'
    return davRequest({
      url: `${this.webdav.serverUrl}${resource}`,
      init: {
        method: 'POST',
        headers: this.webdav.headers,
        body: {
          'acl-query': {
            _attributes: { xmlns: 'urn:inverse:params:xml:ns:inverse-dav' },
            [action]: {
              _attributes: { user: username.replace('<', '&lt;').replace('>', '&gt;') },
              ...rights
            }
          }
        }
      }
    })
  }

  setupCalendarRights(resource, username, rights) {
    let sogoRights = {}
    if (rights.c)
      sogoRights.ObjectCreator = {}
    if (rights.d)
      sogoRights.ObjectEraser = {}

    const classes = {
      pu: 'Public',
      pr: 'Private',
      co: 'Confidential'
    }
    const rightsTable = {
      v: 'Viewer',
      d: 'DAndTViewer',
      m: 'Modifier',
      r: 'Responder'
    }
    Object.keys(classes).forEach(c => {
      if (rights[c]) {
        const right = rights[c]
        const sogoRight = `${classes[c]}${rightsTable[right]}`
        sogoRights[sogoRight] = {}
      }
    })

    return this.setupRights(resource, username, sogoRights)
  }

  setupAddressBookRights(resource, username, rights) {
    let sogoRights = {}

    const rightsTable = {
      c: 'ObjectCreator',
      d: 'ObjectEraser',
      v: 'ObjectViewer',
      e: 'ObjectEditor'
    }
    Object.keys(rights).forEach(r => {
      if (rightsTable[r]) {
        sogoRights[rightsTable[r]] = {}
      }
    })

    return this.setupRights(resource, username, sogoRights)
  }

  _subscriptionOperation(resource, subscribers, operation) {
    return davRequest({
      url: `${this.webdav.serverUrl}${resource}`,
      init: {
        method: 'POST',
        headers: {
          'Content-Type': 'application/xml; charset="utf-8"',
          ...this.webdav.headers
        },
        body: {
          [operation]: {
            _attributes: {
              xmlns: 'urn:inverse:params:xml:ns:inverse-dav',
              users: subscribers.join(',')
            }
          }
        }
      }
    })
  }

  subscribe(resource, subscribers) {
    return this._subscriptionOperation(resource, subscribers, 'subscribe')
  }

  unsubscribe(resource, subscribers) {
    return this._subscriptionOperation(resource, subscribers, 'unsubscribe')
  }

  versitDict(component) {
    const comp = ICAL.Component.fromString(component)
    let props = {}

    for (const prop of comp.getAllProperties()) {
      props[prop.name] = prop.toICALString()
    }
    for (const subcomp of comp.getAllSubcomponents()) {
      for (const prop of subcomp.getAllProperties()) {
        props[prop.name] = prop.toICALString()
      }
    }
    return props
  }

  componentsAreEqual(comp1, comp2) {
    const props1 = this.versitDict(comp1)
    const props2 = this.versitDict(comp2)
    for (const prop of Object.keys(props1)) {
      if (props1[prop] != props2[prop]) {
        console.debug(`Difference detected in ${prop}:\n\t1: ${props1[prop]}\n\t2: ${props2[prop]}`)
        return false
      }
    }
    return true
  }

  createDateTimeProperty(propertyName, dateObject = new Date()) {
    let property = new ICAL.Property(propertyName)
    property.setParameter('tzid', 'America/Toronto')
    property.setValue(ICAL.Time.fromJSDate(dateObject))

    return property
  }

  createCalendar(summary = 'test event', uid = 'test', transp = 'OPAQUE') {
    const vcalendar = new ICAL.Component('vcalendar')
    const vevent = new ICAL.Component('vevent')
    const now = new Date()
    const later = new Date(now.getTime() + 1000*60*60) // event lasts one hour

    vcalendar.addSubcomponent(vevent)
    vevent.addPropertyWithValue('uid', uid)
    vevent.addPropertyWithValue('summary', summary)
    vevent.addPropertyWithValue('transp', transp)
    vevent.addProperty(this.createDateTimeProperty('dtstart', now))
    vevent.addProperty(this.createDateTimeProperty('dtend', later))
    vevent.addProperty(this.createDateTimeProperty('dtstamp', now))
    vevent.addProperty(this.createDateTimeProperty('last-modified', now))
    vevent.addProperty(this.createDateTimeProperty('created', now))
    vevent.addPropertyWithValue('class', 'PUBLIC')
    vevent.addPropertyWithValue('sequence', '0')

    return vcalendar
  }

}

export default TestUtility