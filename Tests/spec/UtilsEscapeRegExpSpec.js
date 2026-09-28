const path = require('path')

global.Element = class Element {}

require(path.join(__dirname, '../../WebServerResources/js/Common/utils.js'))

describe('String.prototype.escapeRegExp', function() {

  it('escapes a signature holding regular expression metacharacters', function() {
    const signature = '<div style="color: rgb(0, 0, 204); font-size:13.3333px">Sig (A)+B?.|</div>';
    const re = new RegExp('(<p>)?' + signature.escapeRegExp());
    const text = '<p>Hello</p>some text ' + signature + ' trailing text';

    expect(text.search(re)).toBeGreaterThan(-1);
    expect(text.replace(re, 'X')).toBe('<p>Hello</p>some text X trailing text');
  });

  it('replaces the previous signature when switching identity (#6168, #6214)', function() {
    const signatureA = '<div style="color: rgb(0, 0, 204); font-size:13.3333px">Sig (A)+B?.|</div>';
    const signatureB = '<div>Signature B</div>';
    const text = '<p>Hello</p><br />--&nbsp;<br />' + signatureA;
    const re = new RegExp('(<p>)?(<br ?\/?>(&nbsp;)?[ \\n]?)?--&nbsp;<br ?\/?>(&nbsp;)?[ \\n]?(<\/p>)?' + signatureA.escapeRegExp());
    const result = text.replace(re, signatureB);

    expect(result).toBe('<p>Hello</p>' + signatureB);
    expect(result.indexOf(signatureA)).toBe(-1);
    expect(result.split(signatureB).length - 1).toBe(1);
  });

  it('returns strings without metacharacters unchanged', function() {
    expect('SOGo'.escapeRegExp()).toBe('SOGo');
    expect('abc_123'.escapeRegExp()).toBe('abc_123');
  });
});
