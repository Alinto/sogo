import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'

describe('identity switch duplicates the signature (#6168)', function() {
  let MessageEditorController

  beforeAll(function() {
    let editorController
    const moduleChain = {
      controller: function(name, controller) {
        if (name == 'MessageEditorController')
          editorController = controller
        return moduleChain
      }
    }
    const angularStub = {
      isDefined: function(value) { return value !== undefined },
      isUndefined: function(value) { return value === undefined },
      isNumber: function(value) { return typeof value == 'number' },
      module: function() { return moduleChain }
    }
    const source = readFileSync(fileURLToPath(new URL('../../UI/WebServerResources/js/Mailer/MessageEditorController.js', import.meta.url)), 'utf8')
    new Function('angular', '_', 'screen', `${source}
                                  return angular.module('SOGo.MailerUI');`)(angularStub,
                                                                            { find: function(collection, predicate) { return collection.find(predicate) } },
                                                                            { orientation: { type: 'landscape-primary' } })
    MessageEditorController = editorController
  })

  const identityA = { full: 'Alice Agency <alice@example.com>' }
  const identityB = { full: 'Bob <bob@example.com>' }
  const identityShared = { full: 'Shared mailbox <shared@example.com>' }

  function inserted(composeType, placement, signature) {
    const html = composeType != 'text'
    const nl = html ? '<br />' : '\n'
    const space = html ? '&nbsp;' : ' '
    const n = placement == 'below' ? 1 : 2
    if (!signature)
      return ''
    return nl.repeat(n) + '--' + space + nl + signature
  }

  function newEditor(text, options) {
    options = options || {}
    const signatureA = options.signatureA
    const signatureB = options.signatureB
    const identities = options.identities || [
      { full: identityA.full, signature: signatureA },
      { full: identityB.full, signature: signatureB }
    ]
    const stateMessage = {
      editable: {
        from: identityA.full,
        to: [], cc: [], bcc: [],
        text: text
      },
      origin: options.origin,
      $absolutePath: function() { return '/dav/drafts/123' }
    }
    class FileUploader {
      constructor(uploaderOptions) { this.url = uploaderOptions.url }
    }
    const Preferences = {
      defaults: {
        SOGoMailAutoSave: 0,
        SOGoMailUseSignatureOnNew: options.useOnNew === undefined ? 1 : options.useOnNew,
        SOGoMailUseSignatureOnForward: options.useOnForward === undefined ? 1 : options.useOnForward,
        SOGoMailUseSignatureOnReply: options.useOnReply === undefined ? 1 : options.useOnReply,
        SOGoMailComposeMessageType: options.composeType || 'html',
        SOGoMailSignaturePlacement: options.signaturePlacement || 'above',
        SOGoMailReplyPlacement: options.replyPlacement || 'above'
      }
    }
    const editor = new MessageEditorController({ $on: function() {} }, {}, {}, {}, {}, {}, FileUploader,
                                                { isPopup: false },
                                                { identities: identities },
                                                stateMessage,
                                                function() {}, function(value) { return value }, function() {},
                                                { toastPosition: 'bottom right' }, function() {}, {}, {}, {}, Preferences)
    editor.$onInit()
    return editor
  }

  function switchTo(editor, signature) {
    const identity = signature === undefined
          ? { full: identityShared.full }
          : { full: identityB.full, signature: signature }
    editor.setFromIdentity(identity)
  }

  const plainB = '<b>Bob</b>'
  const textB = 'Bob'

  const replacements = [
    {
      name: 'keeps a single signature when the HTML has no metacharacters',
      signatureA: '<b>Alice Agency</b><br />Sales',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains parentheses',
      signatureA: '<span style="color:rgb(0, 0, 204)">Alice</span>',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains dots',
      signatureA: '<span style="font-size:13.3333px">Alice</span>',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a plus',
      signatureA: 'Tel +33 1 23 45 67 89',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a question mark',
      signatureA: '<a href="https://example.com/?from=sig">Alice</a>',
      signatureB: plainB
    },
    {
      name: 'replaces a signature whose braces are not a quantifier',
      signatureA: '<span style="font-family:{Foo}">Alice</span>',
      signatureB: plainB
    },
    {
      name: 'replaces a signature whose braces are a quantifier',
      signatureA: 'range {1,2} Alice',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains square brackets',
      signatureA: 'Team [Sales]',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a pipe',
      signatureA: 'Alice|Agency',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a star',
      signatureA: 'Alice * Agency',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that starts with a star',
      signatureA: '* Alice',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a backslash',
      signatureA: 'C:\\docs\\alice',
      signatureB: plainB
    },
    {
      name: 'replaces a signature that contains a hash',
      signatureA: '<a href="https://example.com/team#alice">Alice</a>',
      signatureB: plainB
    },
    {
      name: 'replaces the reporter signature (rgb, dotted font-size, url query)',
      signatureA: '<span style="color:rgb(0, 0, 204);font-size:13.3333px">Alice Agency</span><br />https://example.com/?from=sig',
      signatureB: '<span style="color:rgb(204, 0, 0)">Bob</span>'
    },
    {
      name: 'replaces an external image whose url has a query string',
      signatureA: '<img src="https://cdn.example.com/logo.png?size=2" alt="Alice" />',
      signatureB: plainB
    },
    {
      name: 'replaces an external image url that only contains dots',
      signatureA: '<img src="https://cdn.example.com/logo.png" alt="Alice" />',
      signatureB: plainB
    },
    {
      name: 'replaces a signature placed below the message',
      placement: 'below',
      signatureA: '<span style="color:rgb(0, 0, 204)">Alice</span>',
      signatureB: plainB
    },
    {
      name: 'replaces a plain-text signature',
      composeType: 'text',
      signatureA: 'Alice Agency\nSales',
      signatureB: textB
    },
    {
      name: 'replaces a plain-text signature that contains parentheses, plus and a question mark',
      composeType: 'text',
      signatureA: 'Alice (Agency) +33\nhttps://example.com/?from=sig',
      signatureB: textB
    },
    {
      name: 'replaces a plain-text signature placed below the message',
      composeType: 'text',
      placement: 'below',
      signatureA: 'Alice (Agency)',
      signatureB: textB
    }
  ]

  const unusual = [
    {
      name: 'replaces an unusual signature with accents, guillemets, euro and an emoji',
      signatureA: 'Alice Dupont — Agence « Été » 10 € 🌞',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that mixes CJK and latin',
      signatureA: '田中 アリス / Alice Tanaka',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature laid out as a table',
      signatureA: '<table><tr><td>Alice</td><td>Sales</td></tr><tr><td>Paris</td><td>Nord</td></tr></table>',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature made of HTML entities',
      signatureA: 'Alice &amp; Bob &lt;sales&gt;&nbsp;&quot;Nord&quot;',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that contains a delimiter lookalike',
      signatureA: 'Alice -- directrice<br />-- ne pas effacer le message',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature with nested inline tags',
      signatureA: '<span><b><i>Alice</i></b> <u>Agency</u></span>',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that is a list',
      signatureA: '<ul><li>Tel 01 02 03</li><li>Paris</li></ul>',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that starts with an HTML comment',
      signatureA: '<!-- carte -->Alice Agency',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that uses single-quoted attributes',
      signatureA: "<span style='color:navy'>Alice</span>",
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature that is only non-breaking spaces',
      signatureA: '&nbsp;&nbsp;',
      signatureB: plainB
    },
    {
      name: 'replaces an unusual signature with a zero-width space, an ellipsis and a percent',
      signatureA: 'Alice\u200b… 100%',
      signatureB: plainB
    },
    {
      name: 'inserts an unusual signature unchanged when replacing a plain one',
      signatureA: '<b>Alice</b>',
      signatureB: 'Bob — « Nord » 🌞 &amp; fils'
    }
  ]

  replacements.forEach(function(spec) {
    const composeType = spec.composeType || 'html'
    const placement = spec.placement || 'above'

    it(spec.name, function() {
      const prefix = 'Hello'
      const suffix = composeType == 'text' ? '\nPS keep' : '<br />PS keep'
      const editor = newEditor(prefix + inserted(composeType, placement, spec.signatureA) + suffix, {
        composeType: composeType,
        signaturePlacement: placement,
        signatureA: spec.signatureA,
        signatureB: spec.signatureB
      })

      switchTo(editor, spec.signatureB)

      expect(editor.message.editable.text)
        .toBe(prefix + inserted(composeType, placement, spec.signatureB) + suffix)
    })
  })

  unusual.forEach(function(spec) {
    it(spec.name, function() {
      const prefix = 'Hello'
      const suffix = '<br />PS keep'
      const editor = newEditor(prefix + inserted('html', 'above', spec.signatureA) + suffix, {
        signatureA: spec.signatureA,
        signatureB: spec.signatureB
      })

      switchTo(editor, spec.signatureB)

      const text = editor.message.editable.text
      expect(text.startsWith(prefix)).toBe(true)
      expect(text.endsWith(suffix)).toBe(true)
      expect(text).not.toContain(spec.signatureA)
      expect(text.split(spec.signatureB).length - 1).toBe(1)
    })
  })

  it('removes the previous HTML signature when the new identity has none', function() {
    const signatureA = '<span style="color:rgb(0, 0, 204)">Alice</span>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA
    })

    switchTo(editor)

    expect(editor.message.editable.text).toBe('Hello')
  })

  it('removes a plain-text signature when the new identity has none', function() {
    const signatureA = 'Alice (Agency)'
    const editor = newEditor('Hello' + inserted('text', 'above', signatureA), {
      composeType: 'text',
      signatureA: signatureA
    })

    switchTo(editor)

    expect(editor.message.editable.text).toBe('Hello')
  })

  it('replaces the signature after the editor rewrote inner line breaks', function() {
    const signatureA = '<b>Alice</b><br />Sales'
    const editor = newEditor('Hello<br /><br />--&nbsp;<br /><b>Alice</b><br>Sales', {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('replaces the signature after the editor wrapped it in a paragraph', function() {
    const signatureA = '<b>Alice</b><br />https://example.com/?from=sig'
    const editor = newEditor('<p>Hello</p><p><br><br>--&nbsp;<br><b>Alice</b><br>https://example.com/?from=sig</p>', {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('<p>Hello</p>' + inserted('html', 'above', plainB))
  })

  it('replaces a base64 image signature that exceeds the regex size limit', function() {
    const signatureA = '<img src="data:image/png;base64,' + 'A'.repeat(50000) + '" />'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('replaces an unbalanced parenthesis instead of appending', function() {
    const signatureA = 'Call me (Alice'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('does not append when another identity earlier in the list has an invalid signature', function() {
    const signatureA = '<b>Alice</b>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: plainB,
      identities: [
        { full: 'Broken <broken@example.com>', signature: 'note (draft' },
        { full: identityA.full, signature: signatureA },
        { full: identityB.full, signature: plainB }
      ]
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('keeps a single signature across two switches', function() {
    const signatureA = '<a href="https://example.com/?from=sig">Alice</a>'
    const signatureB = '<span style="color:rgb(204, 0, 0)">Bob</span>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: signatureB
    })

    switchTo(editor, signatureB)
    editor.setFromIdentity({ full: identityA.full, signature: signatureA })

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', signatureA))
  })

  it('leaves the draft unchanged when the selected identity is already the current one', function() {
    const signatureA = '<a href="https://example.com/?from=sig">Alice</a>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: plainB
    })

    editor.setFromIdentity({ full: identityA.full, signature: signatureA })

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', signatureA))
  })

  it('appends exactly one signature when the draft has none yet', function() {
    const editor = newEditor('Hello', {
      signatureA: '<b>Alice</b>',
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('replaces the signature above a reply quote', function() {
    const signatureA = '<a href="https://example.com/?from=sig">Alice</a>'
    const quote = '<br/><br/><blockquote type="cite">quoted</blockquote>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA) + quote, {
      signatureA: signatureA,
      signatureB: plainB,
      origin: { action: 'reply' }
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB) + quote)
  })

  it('replaces the signature of the first identity when six identities are configured', function() {
    const signatureA = '<a href="https://example.com/?from=sig">Alice</a>'
    const identities = [ { full: identityA.full, signature: signatureA } ]
    for (let i = 2; i <= 5; i++)
      identities.push({ full: 'User ' + i + ' <user' + i + '@example.com>', signature: '<b>User ' + i + '</b>' })
    identities.push({ full: identityB.full, signature: plainB })
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA), {
      signatureA: signatureA,
      signatureB: plainB,
      identities: identities
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB))
  })

  it('inserts one signature above a plain-text reply quote', function() {
    const quote = '\n\nOn January 1, 2026 at 10:00, a@example.com wrote:\n\n> quoted'
    const editor = newEditor(quote, {
      composeType: 'text',
      origin: { action: 'reply' },
      signatureA: 'Alice',
      signatureB: textB
    })

    switchTo(editor, textB)

    expect(editor.message.editable.text)
      .toBe('\n' + inserted('text', 'above', textB) +
            '\nOn January 1, 2026 at 10:00, a@example.com wrote:\n\n> quoted')
  })

  it('inserts one signature above an HTML reply quote that uses br without a slash', function() {
    const quote = '<br>On January 1, 2026 at 10:00, a@example.com wrote:<br><br><blockquote type="cite">quoted</blockquote>'
    const editor = newEditor('Hello' + quote, {
      origin: { action: 'reply' },
      signatureA: '<b>Alice</b>',
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB) + quote)
  })

  it('replaces the signature and keeps the forwarded body', function() {
    const signatureA = '<b>Alice</b>'
    const forwarded = '<br/><br/><blockquote type="cite">forwarded</blockquote>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA) + forwarded, {
      origin: { action: 'forward' },
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB) + forwarded)
  })

  it('appends one signature at the end of a reply when the reply is placed below', function() {
    const quote = 'On January 1, 2026 at 10:00, a@example.com wrote:<br /><br /><blockquote type="cite">quoted</blockquote>'
    const editor = newEditor(quote, {
      origin: { action: 'reply' },
      replyPlacement: 'below',
      signatureA: '<b>Alice</b>',
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe(quote + inserted('html', 'above', plainB))
  })

  it('does not change the draft when signatures are disabled on a new message', function() {
    const signatureA = '<b>Alice</b>'
    const body = 'Hello' + inserted('html', 'above', signatureA)
    const editor = newEditor(body, {
      useOnNew: 0,
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.from).toBe(identityB.full)
    expect(editor.message.editable.text).toBe(body)
  })

  it('does not change the draft when signatures are disabled on reply', function() {
    const signatureA = '<b>Alice</b>'
    const body = 'Hello' + inserted('html', 'above', signatureA)
    const editor = newEditor(body, {
      useOnReply: 0,
      origin: { action: 'reply' },
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe(body)
  })

  it('removes the previous signature when a shared identity has none', function() {
    const signatureA = '<b>Alice</b>'
    const quote = '<br/><br/><blockquote type="cite">quoted</blockquote>'
    const editor = newEditor('Hello' + inserted('html', 'above', signatureA) + quote, {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor)

    expect(editor.message.editable.from).toBe(identityShared.full)
    expect(editor.message.editable.text).toBe('Hello' + quote)
  })

  it('keeps an HTML signature as HTML when the compose mode is plain text', function() {
    const signatureA = '<b>Alice</b><br />Sales'
    const signatureB = '<i>Bob</i>'
    const editor = newEditor('Hello' + inserted('text', 'above', signatureA), {
      composeType: 'text',
      signatureA: signatureA,
      signatureB: signatureB
    })

    switchTo(editor, signatureB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('text', 'above', signatureB))
  })

  it('keeps a user-written dashed line and appends the new signature once', function() {
    const body = 'Hello<br /><br />--&nbsp;<br />see you tomorrow'
    const editor = newEditor(body, {
      signatureA: '<b>Alice</b>',
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe(body + inserted('html', 'above', plainB))
  })

  it('does not splice a signature the user has edited', function() {
    const signatureA = '<b>Alice</b><br />Sales'
    const body = 'Hello<br /><br />--&nbsp;<br /><b>Alice</b><br />Edited'
    const editor = newEditor(body, {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe(body + inserted('html', 'above', plainB))
  })

  it('replaces a signature that has only one break before the delimiter', function() {
    const signatureA = '<b>Alice</b>'
    const editor = newEditor('Hello<br />--&nbsp;<br />' + signatureA + '<br />PS keep', {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', plainB) + '<br />PS keep')
  })

  it('keeps a break that exceeds the usual delimiter', function() {
    const signatureA = '<b>Alice</b>'
    const editor = newEditor('Hello<br /><br /><br />--&nbsp;<br />' + signatureA + '<br />PS keep', {
      signatureA: signatureA,
      signatureB: plainB
    })

    switchTo(editor, plainB)

    expect(editor.message.editable.text).toBe('Hello<br />' + inserted('html', 'above', plainB) + '<br />PS keep')
  })

  it('sets Reply-To from the identity and does not clear it afterwards', function() {
    const editor = newEditor('Hello', {
      signatureA: '<b>Alice</b>',
      signatureB: plainB
    })

    editor.setFromIdentity({ full: identityB.full, signature: plainB, replyTo: 'bob-reply@example.com' })
    expect(editor.message.editable.replyTo).toBe('bob-reply@example.com')

    editor.setFromIdentity({ full: identityA.full, signature: '<b>Alice</b>' })

    expect(editor.message.editable.replyTo).toBe('bob-reply@example.com')
    expect(editor.message.editable.text).toBe('Hello' + inserted('html', 'above', '<b>Alice</b>'))
  })

  it('leaves a single image when the same identity is selected again', function() {
    const signatureA = '<img src="data:image/png;base64,' + 'A'.repeat(50000) + '" />'
    const body = 'Hello' + inserted('html', 'above', signatureA)
    const editor = newEditor(body, {
      signatureA: signatureA,
      signatureB: plainB
    })

    editor.setFromIdentity({ full: identityA.full, signature: signatureA })

    expect(editor.message.editable.text).toBe(body)
  })
})
