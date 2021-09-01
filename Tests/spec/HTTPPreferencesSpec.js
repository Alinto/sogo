import config from '../lib/config'
import Preferences from '../lib/Preferences'

const prefs = new Preferences(config.username, config.password)

beforeAll(async function() {
  // because if not set in vacation will not be found later
  // we must make sure they are there at the start
  await prefs.setOrCreate('autoReplyText', '', ['defaults', 'Vacation'])
  await prefs.setOrCreate('PreventInvitations', 0, ['settings', 'Calendar'])
  await prefs.setOrCreate('PreventInvitationsWhitelist', {}, ['settings', 'Calendar'])
})

describe('preferences', function() {

  const _setTextPref = async function(prefText) {
    await prefs.set('autoReplyText', prefText)
    const prefData = await prefs.get('Vacation')

    expect(prefData.autoReplyText)
      .withContext(`Set a text preference to a known value`)
      .toEqual(prefText)
  }

  // preferencesTest

  it('Set/get a text preference - normal characters', async function() {
    await _setTextPref('defaultText')
  })

  it('Set/get a text preference - weird characters - used to crash on 1.3.12', async function() {
    const prefText = `weird data   \ ' \"; ^`
    await _setTextPref(prefText)
  })

  it('Set/get the PreventInvitation pref', async function() {
    await prefs.set('PreventInvitations', 0)
    const notset = await prefs.get('Calendar', false)
    expect(notset.PreventInvitations)
      .withContext(`Set/get Settings/Calendar/PreventInvitations (0)`)
      .toEqual(0)
    await prefs.set('PreventInvitations', 1)
    const isset = await prefs.get('Calendar', false)
    expect(isset.PreventInvitations)
      .withContext(`Set/get Settings/Calendar/PreventInvitations (1)`)
      .toEqual(1)
  })

  it('Set/get the PreventInvitations Whitelist', async function() {
    await prefs.set('PreventInvitationsWhitelist', config.white_listed_attendee)
    const whitelist = await prefs.get('Calendar', false)
    expect(whitelist.PreventInvitationsWhitelist)
      .withContext(`Set/get Settings/Calendar/PreventInvitationsWhitelist`)
      .toEqual(config.white_listed_attendee)
  })
})
