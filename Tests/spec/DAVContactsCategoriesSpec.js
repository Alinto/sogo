import config from '../lib/config'
import { default as WebDAV, DAVInverse } from '../lib/WebDAV'

describe('contacts categories', function() {
  const webdav = new WebDAV(config.username, config.password)

  const _setCategories = async function(categories = []) {
    const resource = `/SOGo/dav/${config.username}/Contacts/`
    const elements = categories.map(c => {
      return { 'category': c }
    })
    const properties = { 'contacts-categories': elements.length ? elements : '' }

    const results = await webdav.proppatchWebdav(resource, properties, DAVInverse)
    expect(results.length)
      .withContext(`Set contacts categories to ${categories.join(', ')}`)
      .toBe(1)

    return results[0].status
  }

  const _getCategories = async function() {
    const resource = `/SOGo/dav/${config.username}/Contacts/`
    const properties = ['contacts-categories']

    const results = await webdav.propfindWebdav(resource, properties, DAVInverse)
    expect(results.length)
      .toBe(1)
    const { props: { contactsCategories: { category } = {} } = {} } = results[0]

    return category
  }

  // HTTPContactCategoriesTest

  it('setting contacts categories', async function() {
    let status, results

    status = await _setCategories()
    expect(status)
      .withContext('Removing contacts categories')
      .toBe(207)
    results = await _getCategories()
    expect(results)
      .toBeUndefined()

    status = await _setCategories(['Coucou'])
    expect(status)
      .withContext('Setting one contacts category')
      .toBe(207)
    results = await _getCategories()
    expect(results)
      .toBe('Coucou')

    status = await _setCategories(['Toto', 'Cuicui'])
    expect(status)
      .withContext('Setting two contacts category')
      .toBe(207)

    results = await _getCategories()
    expect(results.length)
      .toBe(2)
    expect(results)
      .toContain('Toto')
    expect(results)
      .toContain('Cuicui')
  }, config.timeout || 10000)
})