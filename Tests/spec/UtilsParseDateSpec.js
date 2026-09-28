const path = require('path')

global._ = global._ || {
  toLower: text => String(text).toLowerCase(),
  map: (list, fn) => list.map(fn),
  indexOf: (list, item) => list.indexOf(item)
}
global.Element = global.Element || class Element {}

require(path.join(__dirname, '../../UI/WebServerResources/js/Common/utils.js'))

describe('String.prototype.parseDate', function () {
  const digitMonths = name => Array.from({ length: 12 }, (unused, index) => `${index + 1}${name}`)
  const locales = {
    english: {
      shortMonths: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
      months: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
    },
    japanese: { shortMonths: digitMonths('月'), months: digitMonths('月') },
    korean: { shortMonths: digitMonths('월'), months: digitMonths('월') }
  }

  const expectDate = (date, year, month, day) => {
    expect(date.getFullYear())
      .withContext(`parsed year of "${date}"`)
      .toBe(year)
    expect(date.getMonth())
      .withContext(`parsed month of "${date}"`)
      .toBe(month)
    expect(date.getDate())
      .withContext(`parsed day of "${date}"`)
      .toBe(day)
  }

  it('parses month names prefixed with a digit in Japanese (%d-%b-%y)', function () {
    expectDate('01-7月-26'.parseDate(locales.japanese, '%d-%b-%y'), 2026, 6, 1)
  })

  it('parses month names prefixed with a digit in Korean (%d-%b-%y)', function () {
    expectDate('01-7월-26'.parseDate(locales.korean, '%d-%b-%y'), 2026, 6, 1)
  })

  it('still parses English abbreviated month names (%d-%b-%y)', function () {
    expectDate('01-Jul-26'.parseDate(locales.english, '%d-%b-%y'), 2026, 6, 1)
  })

  it('still parses numeric months (%d-%m-%y)', function () {
    expectDate('31-12-26'.parseDate(locales.english, '%d-%m-%y'), 2026, 11, 31)
  })

  it('rejects tokens that are not month names', function () {
    expect('01-XX-26'.parseDate(locales.english, '%d-%b-%y').getTime())
      .withContext('a non-month token must yield an invalid date')
      .toBeNaN()
  })
})
