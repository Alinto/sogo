import config from '../lib/config'

describe('config tests', function() {

  it('required configuration parameters', async function() {
    expect(config.hostname)
      .withContext(`Config 'hostname'`)
      .toBeDefined()
    expect(config.username)
      .withContext(`Config 'username'`)
      .toBeDefined()
    expect(config.subscriber_username)
      .withContext(`Config 'subscriber_username'`)
      .toBeDefined()
    expect(config.attendee1)
      .withContext(`Config 'attendee1'`)
      .toBeDefined()
    expect(config.attendee1_delegate)
      .withContext(`Config 'attendee1_delegate'`)
      .toBeDefined()
    expect(config.mailserver)
      .withContext(`Config 'mailserver'`)
      .toBeDefined()

    expect(config.subscriber_username)
    .withContext(`Config 'subscriber_username' and 'attendee1_username'`)
      .toEqual(config.attendee1_username)

    let userHash = {}
    const userList = [config.username, config.subscriber_username, config.attendee1_delegate_username]
    for (let user of userList) {
      expect(userHash[user])
        .withContext(`username, subscriber_username, attendee1_delegate_username must all be different users ('${user}')`)
        .toBeUndefined()
      userHash[user] = true
    }
  })
})