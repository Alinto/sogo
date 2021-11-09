import config from '../lib/config'

class ManageSieve {
  constructor(login, authname, password) {
    const Telnet = require('telnet-client')

    this.login = login
    this.authname = authname
    this.password = password
    this.params = {
      host: config.sieve_server,
      port: config.sieve_port,
      shellPrompt: /\bOK "/,
      timeout: 1500
    }
    this.connection = new Telnet()
    this.sasl = []
    this.ready = false
  }

  async connect() {
    let response, parsedResponse

    if (!this.ready) {
      await this.connection.connect(this.params)
      response = await this.connection.send('CAPABILITY', { waitfor: /\b(OK|NO) "/ })
      // console.debug(`ManageSieve.connect => ${response}`)
      parsedResponse = this.parseResponse(response)
      if (!parsedResponse['OK']) {
        throw new Error(`Connection failed: ${parsedResponse['NO']}`)
      }
      this.ready = true
      if (parsedResponse['SASL']) {
        this.sasl =  parsedResponse['SASL'].split(/ /)
      }
    }
  }

  async authenticate() {
    let buff, base64, response, parsedResponse

    await this.connect()

    buff = Buffer.from(`${this.login}\0${this.authname}\0${this.password}`)
    base64 = buff.toString('base64')
    response = await this.connection.send(`AUTHENTICATE "PLAIN" {${base64.length}+}\n${base64}`, { waitfor: /\b(OK|NO) "/ })
    // console.debug(`ManageSieve.authenticate => ${response}`)
    parsedResponse = this.parseResponse(response)
    if (!parsedResponse['OK']) {
      throw new Error(`Authentication failed: ${parsedResponse['NO']}`)
    }
  }

  async listScripts() {
    let response, parsedResponse

    await this.connect()

    response = await this.connection.send(`LISTSCRIPTS`, { waitfor: /\b(OK|NO) "/ })
    parsedResponse = this.parseResponse(response)
    // console.debug(`ManageSieve.listScripts => ${JSON.stringify(parsedResponse, undefined, 2)}`)
    if (!parsedResponse['OK']) {
      throw new Error(`List scripts failed: ${parsedResponse['NO']}`)
    }
    return parsedResponse
  }

  async getScript(scriptname) {
    let response, parsedResponse, script = null

    await this.connect()

    response = await this.connection.send(`GETSCRIPT "${scriptname}"`, { waitfor: /\b(OK|NO) "/ })
    // console.debug(`ManageSieve.getScript(${scriptname}) => |${response}|`)
    const lengthMatch = response.match(/{([0-9]+)}\r?\n/)
    if (lengthMatch) {
      const scriptLength = lengthMatch[1]
      script = response.substr(lengthMatch[0].length, scriptLength)
    }
    else
      throw new Error(`Can't find length of Sieve script`)

    return script
  }

  parseResponse(str) {
    const re = new RegExp(/[^\s"]+|"([^"]*)"/gi)
    let parsed = {}
    for (let line of (str.split(/\r?\n/))) {
      if (line.length) {
        let rematch, key, value, i = 0
        while ((rematch = re.exec(line))) {
          value = rematch[1] ? rematch[1] : rematch[0]
          if (key && i > 0)
            parsed[key] = value
          else
            key = value
          i++
        }
        if (key && i == 1) {
          parsed[key] = null
        }
      }
    }
    // console.debug(`ManageSieve.parseResponse => ${JSON.stringify(parsed, undefined, 2)}`)
    return parsed
  }

}

export default ManageSieve