import config from '../lib/config'
import { default as WebDAV, DAVInverse } from '../lib/WebDAV'

describe('calendar classification', function() {
  const webdav = new WebDAV(config.username, config.password)

  const _setClassification = async function(component, classification = '') {
    const resource = `/SOGo/dav/${config.username}/Calendar/`
    const properties = { [`${component}-default-classification`]: classification }

    const results = await webdav.proppatchWebdav(resource, properties, DAVInverse)
    expect(results.length)
      .withContext(`Set ${component} classification to ${classification}`)
      .toBe(1)

    return results[0].status
  }

  // HTTPDefaultClassificationTest

  it('expected failure when setting a classification with an invalid property', async function() {
    let status

    status = await _setClassification('123456', 'PUBLIC')
    expect(status)
      .withContext('Setting an invalid classification property')
      .toBe(403)

    status = await _setClassification('events', '')
      expect(status)
        .withContext('Setting an empty classification')
        .toBe(403)

      status = await _setClassification('events', 'pouet')
      expect(status)
          .withContext('Setting an invalid classification')
          .toBe(403)
    })

  it('setting a valid classification', async function() {
    for (let component of ['events', 'tasks']) {
      for (let classification of ['PUBLIC', 'PRIVATE', 'CONFIDENTIAL']) {
        const status = await _setClassification(component, classification)
        expect(status)
          .withContext(`Set ${component} classification to ${classification}`)
          .toBe(207)
      }
    }
  })
})