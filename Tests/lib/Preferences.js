import cookie from 'cookie'
import { fetch } from 'cross-fetch'
import config from './config'

/**
 * NOTE
 *
 * For this class to be used, make sure XSRF validation is disabled on the server.
 * In sogo.conf, you must have:
 *
 *   SOGoXSRFValidationEnabled = NO;
 */

class Preferences {
  constructor(un, pw) {
    this.username = un
    this.password = pw
    this.serverUrl = `http://${config.hostname}:${config.port}`
    this.cookie = null
    this.preferences = null
  }

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

  async getDefaults() {
    const resource = `/SOGo/so/${this.username}/jsonDefaults`
    const authCookie = await this.getAuthCookie()
    const response = await fetch(this.serverUrl + resource, {
      method: 'GET',
      headers: {
        Cookie: authCookie,
        ...this.headers
      }
    })
    if (response.status == 200) {
      const defaults = await response.json()
      return defaults
    }
    else
      throw new Error(`Can't fetch defaults of user ${this.username}: ${response.status}`)
  }

  async getSettings() {
    const resource = `/SOGo/so/${this.username}/jsonSettings`
    const authCookie = await this.getAuthCookie()
    const response = await fetch(this.serverUrl + resource, {
      method: 'GET',
      headers: {
        Cookie: authCookie,
        ...this.headers
      }
    })
    if (response.status == 200) {
      const settings = await response.json()
      return settings
    }
    else
      throw new Error(`Can't fetch settings of user ${this.username}: ${response.status}`)
  }

  async loadPreferences() {
    const defaults = await this.getDefaults()
    const settings = await this.getSettings()

    this.preferences = { defaults, settings }
  }

  findKey(obj, key) {
    if (Object.keys(obj).includes(key)) {
      return obj
    }
    for (let k of Object.keys(obj)) {
      if (typeof obj[k] == 'object') {
        let o = this.findKey(obj[k], key)
        if (o !== null)
          return o
      }
    }
    return null
  }

  async get(preference, withCache = true) {
    if (!withCache || !this.preferences)
      await this.loadPreferences()

    if (!preference)
      return this.preferences // return everything

    const obj = this.findKey(this.preferences, preference)
    if (obj)
      return obj[preference]
    else
      return null
  }

  async setNoSave(preference, value) {
    if (!this.preferences)
      await this.loadPreferences()

    const obj = this.findKey(this.preferences, preference)
    if (obj == null)
      throw new Error(`Can't find key ${preference} in preferences`)

    if (typeof value == 'undefined')
      delete obj[preference]
    else
      obj[preference] = value
  }

  async set(preference, value) {
    await this.setNoSave(preference, value)
    return await this.save()
  }

  async setOrCreate(preference, value, paths = ['defaults']) {
    if (!this.preferences)
      await this.loadPreferences()

    let obj = this.findKey(this.preferences, preference)
    if (obj == null) {
      obj = this.preferences
      for (let path of paths) {
        if (typeof obj[path] == 'undefined')
          obj[path] = {}
        obj = obj[path]
      }
    }
    obj[preference] = value
  }

  async save() {
    const resource = `/SOGo/so/${this.username}/Preferences/save`
    const authCookie = await this.getAuthCookie()
    const response = await fetch(this.serverUrl + resource, {
      method: 'POST',
      headers: {
        Cookie: authCookie,
        'Content-Type': 'application/json',
        ...this.headers
      },
      body: JSON.stringify(this.preferences)
    })
    return response
  }
}

export default Preferences