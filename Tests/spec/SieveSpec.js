import config from '../lib/config'
import WebDAV from '../lib/WebDAV'
import TestUtility from '../lib/utilities'
import Preferences from '../lib/Preferences'
import ManageSieve from '../lib/ManageSieve'

let prefs, webdav, utility, manageSieve, user

describe('Sieve', function() {

  async function _getSogoSieveScript() {
    const scripts = await manageSieve.listScripts()

    expect(Object.keys(scripts))
    .withContext(`sogo sieve script has been created`)
    .toContain('sogo')
    expect(scripts['sogo'])
    .withContext(`sogo sieve script is active`)
    .toMatch(/ACTIVE/i)

    const script = await manageSieve.getScript('sogo')

    return script
  }

  async function _killFilters() {
    // kill existing filters
    await prefs.setOrCreate('SOGoSieveFilters', [], ['defaults'])
    // vacation filters
    await prefs.setOrCreate('autoReplyText', '', ['defaults', 'Vacation'])
    await prefs.setOrCreate('customSubjectEnabled', 0, ['defaults', 'Vacation'])
    await prefs.setOrCreate('customSubject', '', ['defaults', 'Vacation'])
    await prefs.setOrCreate('autoReplyEmailAddresses', [], ['defaults', 'Vacation'])
    await prefs.setOrCreate('daysBetweenResponse', 7, ['defaults', 'Vacation'])
    await prefs.setOrCreate('ignoreLists', 0, ['defaults', 'Vacation'])
    await prefs.setOrCreate('startDate', 0, ['defaults', 'Vacation'])
    await prefs.setOrCreate('endDate', 0, ['defaults', 'Vacation'])
    await prefs.setOrCreate('enabled', 0, ['defaults', 'Vacation'])
    // forwarding filters
    await prefs.setOrCreate('forwardAddress', [], ['defaults', 'Forward'])
    await prefs.setOrCreate('keepCopy', 0, ['defaults', 'Forward'])
  }

  beforeAll(async function() {
    prefs = new Preferences(config.username, config.password)
    webdav = new WebDAV(config.username, config.password)
    utility = new TestUtility(webdav)
    manageSieve = new ManageSieve(config.username, config.username, config.password)
    user = await utility.fetchUserInfo(config.username)
  })

  beforeEach(async function() {
    await _killFilters()
    await manageSieve.authenticate(true)
  })

  afterAll(async function() {
    await _killFilters()
    await prefs.save()
  })

  it('enable simple vacation script', async function() {
    const vacationMsg = 'vacation test'
    const daysInterval = 5
    const mailaddr = user.email.replace(/mailto:/, '')
    const sieveSimpleVacation = `require ["vacation"];\r\nvacation :days ${daysInterval} :addresses ["${mailaddr}"] text:\r\n${vacationMsg}\r\n.\r\n;\r\n`
    let vacation

    vacation = await prefs.get('Vacation')
    vacation.enabled = 1
    await prefs.setNoSave('autoReplyText', vacationMsg)
    await prefs.setNoSave('daysBetweenResponse', daysInterval)
    await prefs.setNoSave('autoReplyEmailAddresses', [mailaddr])
    await prefs.save()

    const createdScript = await _getSogoSieveScript()
    expect(createdScript)
    .withContext(`sogo Sieve script`)
    .toBe(sieveSimpleVacation)
  })

  it('enable vacation script - ignore lists', async function() {
    const vacationMsg = 'vacation test - ignore list'
    const daysInterval = 3
    const mailaddr = user.email
    const sieveVacationIgnoreLists = `require ["vacation"];\r\nif allof ( not exists ["list-help", "list-unsubscribe", "list-subscribe", "list-owner", "list-post", "list-archive", "list-id", "Mailing-List"], not header :comparator "i;ascii-casemap" :is "Precedence" ["list", "bulk", "junk"], not header :comparator "i;ascii-casemap" :matches "To" "Multiple recipients of*" ) { vacation :days ${daysInterval} :addresses ["${mailaddr}"] text:\r\n${vacationMsg}\r\n.\r\n;\r\n}\r\n`
    let vacation

    vacation = await prefs.get('Vacation')
    vacation.enabled = 1
    await prefs.setNoSave('autoReplyText', vacationMsg)
    await prefs.setNoSave('daysBetweenResponse', daysInterval)
    await prefs.setNoSave('autoReplyEmailAddresses', [user.email])
    await prefs.setNoSave('ignoreLists', 1)
    await prefs.save()

    const createdScript = await _getSogoSieveScript()
    expect(createdScript)
    .withContext(`sogo Sieve script`)
    .toBe(sieveVacationIgnoreLists)
  })

  it('enable simple forwarding', async function() {
    const redirectMailaddr = 'nonexistent@inverse.com'
    const sieveSimpleForward  = `redirect "${redirectMailaddr}";\r\n`
    let forward

    // Enabling Forward now is an 'enabled' setting in the subdict Forward
    // We need to get that subdict first -- next save/set will also save this
    forward = await prefs.get('Forward')
    forward.enabled = 1
    await prefs.set('forwardAddress', [redirectMailaddr])

    const createdScript = await _getSogoSieveScript()
    expect(createdScript)
    .withContext(`sogo Sieve script`)
    .toBe(sieveSimpleForward)
  })

  it('enable email forwarding - keep a copy', async function() {
    const redirectMailaddr = 'nonexistent@inverse.com'
    const sieveForwardKeep  = `redirect "${redirectMailaddr}";\r\nkeep;\r\n`
    let forward

    // Enabling Forward now is an 'enabled' setting in the subdict Forward
    // We need to get that subdict first -- next save/set will also save this
    forward = await prefs.get('Forward')
    forward.enabled = 1
    await prefs.setNoSave('forwardAddress', [redirectMailaddr])
    await prefs.setNoSave('keepCopy', 1)
    await prefs.save()

    const createdScript = await _getSogoSieveScript()
    expect(createdScript)
    .withContext(`sogo Sieve script`)
    .toBe(sieveForwardKeep)
  })

  it('add simple sieve filter', async function() {
    const folderName = 'Sent'
    const subject = 'add simple sieve filter'
    const sieveFilter = `require ["fileinto"];\r\nif anyof (header :contains "subject" "${subject}") {\r\n    fileinto "${folderName}";\r\n}\r\n`

    await prefs.set('SOGoSieveFilters', [{
      active: true,
      actions: [{
        method: 'fileinto',
        argument: 'Sent'
      }],
      rules: [{
        operator: 'contains',
        field: 'subject',
        value: subject
      }],
      match: 'any',
      name: folderName
    }])

    const createdScript = await _getSogoSieveScript()
    expect(createdScript)
    .withContext(`sogo Sieve script`)
    .toBe(sieveFilter)
  })
})