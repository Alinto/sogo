/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Message
   * @constructor
   * @param {string} accountId - the account ID
   * @param {string} mailboxPath - an array of the mailbox path components
   * @param {object} futureAddressBookData - either an object literal or a promise
   * @param {bool} lazy - do "lazy loading" so we are very quick at initializing message instances
   */
  function Message(accountId, mailbox, futureMessageData, lazy) {
    this.accountId = accountId;
    this.$mailbox = mailbox;
    this.$hasUnsafeContent = false;
    this.$loadUnsafeContent = false;
    this.editable = {to: [], cc: [], bcc: []};
    this.selected = false;

    // Data is immediately available
    if (typeof futureMessageData.then !== 'function') {
      //console.debug(JSON.stringify(futureMessageData, undefined, 2));
      if (angular.isUndefined(lazy) || !lazy) {
        this.init(futureMessageData);
      }
      this.uid = parseInt(futureMessageData.uid);
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureMessageData);
    }
  }

  /**
   * @memberof Message
   * @desc The factory we'll use to register with Angular
   * @returns the Message constructor
   */
  Message.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgMessage_STATUS', 'Resource', 'Preferences', function($q, $timeout, $log, Settings, Message_STATUS, Resource, Preferences) {
    angular.extend(Message, {
      STATUS: Message_STATUS,
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Mail', Settings.activeUser()),
      $Preferences: Preferences,
      $avatar: angular.bind(Preferences, Preferences.avatar)
    });

    // Initialize tags form user's defaults
    if (Preferences.defaults.SOGoMailLabelsColors) {
      Message.$tags = Preferences.defaults.SOGoMailLabelsColors;
    }
    if (Preferences.defaults.SOGoMailDisplayRemoteInlineImages &&
        Preferences.defaults.SOGoMailDisplayRemoteInlineImages == 'always') {
      Message.$displayRemoteInlineImages = true;
    }

    return Message; // return constructor
  }];

  /**
   * @module SOGo.MailerUI
   * @desc Factory registration of Message in Angular module.
   */
  try {
    angular.module('SOGo.MailerUI');
  }
  catch(e) {
    angular.module('SOGo.MailerUI', ['SOGo.Common']);
  }
  angular.module('SOGo.MailerUI')
    .constant('sgMessage_STATUS', {
      NOT_LOADED:      0,
      DELAYED_LOADING: 1,
      LOADING:         2,
      LOADED:          3,
      DELAYED_MS:      300
    })
    .factory('Message', Message.$factory);

  /**
   * @function filterTags
   * @memberof Message.prototype
   * @desc Search for tags (ie., mail labels) matching some criterias
   * @param {string} search - the search string to match
   * @returns a collection of strings
   */
  Message.filterTags = function(query, excludedTags) {
    var re = new RegExp(query, 'i'),
        results = [];

    _.forEach(_.keys(Message.$tags), function(tag) {
      var pair = Message.$tags[tag];
      if (pair[0].search(re) != -1) {
        if (!_.includes(excludedTags, tag))
          results.push({ name: tag, description: pair[0], color: pair[1] });
      }
    });

    return results;
  };

  /**
   * @function init
   * @memberof Message.prototype
   * @desc Extend instance with new data and massage some attributes.
   * @param {object} data - attributes of message
   */
  Message.prototype.init = function(data) {
    var _this = this;
    angular.extend(this, data);
    this.$formatFullAddresses();
    this.$loadUnsafeContent = false;
    _.forEach(this.flags, function(flag, i) {
      if (flag.charAt(0) == '$') {
        _this.flags.splice(i, 1,'_' + flag);
      }
    });
  };

  /**
   * @function $absolutePath
   * @memberof Message.prototype
   * @desc Build the path of the message
   * @returns a string representing the path relative to the mail module
   */
  Message.prototype.$absolutePath = function(options) {
    var _this = this, id = this.id;

    function buildPath() {
      var path;
      path = _.map(_this.$mailbox.path.split('/'), function(component) {
        return 'folder' + component.asCSSIdentifier();
      });
      path.splice(0, 0, _this.accountId); // insert account ID
      return path.join('/');
    }

    if (angular.isUndefined(this.id) || options && options.nocache) {
      this.id = buildPath() + '/' + this.uid; // add message UID
      id = this.id;
    }
    if (options && options.asDraft && this.draftId) {
      id = buildPath() + '/' + this.draftId; // add draft ID
    }
    if (options && options.withResourcePath) {
      id = Message.$$resource.path(id); // return absolute URL
    }

    return id;
  };

  /**
   * @function $setUID
   * @memberof Message.prototype
   * @desc Change the UID of the message. This happens when saving a draft.
   * @param {number} uid - the new message UID
   */
  Message.prototype.$setUID = function(uid) {
    var oldUID = (this.uid || -1), _this = this, index;

    if (oldUID != parseInt(uid)) {
      this.uid = parseInt(uid);
      this.$absolutePath({nocache: true});
      if (oldUID > -1) {
        oldUID = oldUID.toString();
        if (angular.isDefined(this.$mailbox.uidsMap[oldUID])) {
          index = this.$mailbox.uidsMap[oldUID];
          this.$mailbox.uidsMap[uid] = index;
          delete this.$mailbox.uidsMap[oldUID];
          this.$mailbox.$messages[index].uid = this.uid;

          // Update messages list of mailbox
          _.forEach(['from', 'to', 'subject'], function(attr) {
            _this.$mailbox.$messages[index][attr] = _this.editable[attr];
          });
        }
      }
      else {
        // Refresh selected folder if it's the drafts mailbox
        if (this.$mailbox.constructor.selectedFolder &&
            this.$mailbox.constructor.selectedFolder.type == 'draft') {
          this.$mailbox.constructor.selectedFolder.$filter();
        }
      }
    }
  };

  /**
   * @function $formatFullAddresses
   * @memberof Message.prototype
   * @desc Format all sender and recipients addresses with a complete description (name <email>).
   *       This function also generates the avatar URL for each email address and a short name
   */
  Message.prototype.$formatFullAddresses = function() {
    var _this = this;
    var identities = _.map(_this.$mailbox.$account.identities, 'email');

    // Build long representation of email addresses
    _.forEach(['from', 'to', 'cc', 'bcc', 'reply-to'], function(type) {
      _.forEach(_this[type], function(data) {
        if (data.name && data.name != data.email) {
          data.full = data.name + ' <' + data.email + '>';

          if (data.name.length < 10)
            // Name is already short
            data.shortname = data.name;
          else if (data.name.split(' ').length)
            // If we have "Alice Foo" or "Foo, Alice" as name, we grab "Alice"
            data.shortname = _.first(_.last(data.name.split(/, */)).split(/ +/)).replace('\'','');
        }
        else if (data.email) {
          data.full = '<' + data.email + '>';
          data.shortname = data.email.split('@')[0];
        }

        data.image = Message.$avatar(data.email, 32);

        // If the current user is the recepient, overwrite
        // the short name with 'me'
        if (_.indexOf(identities, data.email) >= 0)
          data.shortname = l('me');
      });
    });
  };

  /**
   * @function $shortRecipients
   * @memberof Message.prototype
   * @desc Format all recipients into a very compact string
   * @returns a compacted string of all recipients
   */
  Message.prototype.$shortRecipients = function(max) {
    var _this = this, result = [], count = 0, total = 0;

    // Build short representation of email addresses
    _.forEach(['to', 'cc', 'bcc'], function(type) {
      total += _this[type]? _this[type].length : 0;
      _.forEach(_this[type], function(data, i) {
        if (count < max)
          result.push(data.shortname);
        count++;
      });
    });

    if (total > max)
      result.push(l('and %{0} more...', (total - max)));

    return result.join(', ');
  };

  /**
   * @function $shortAddress
   * @memberof Message.prototype
   * @desc Format the first address of a specific type with a short description.
   * @returns a string of the name or the email of the envelope address type
   */
  Message.prototype.$shortAddress = function(type) {
    var address = '';
    if (this[type] && this[type].length > 0) {
      address = this[type][0].name || this[type][0].email || '';
    }

    return address;
  };

  /**
   * @function allowReplyAll
   * @memberof Message.prototype
   * @desc Check if 'Reply to All' is an appropriate action on the message.
   * @returns true if the message is not a draft and has more than one recipient
   */
  Message.prototype.allowReplyAll = function() {
    var identities = _.map(this.$mailbox.$account.identities, 'email');
    var recipientsCount = 0;
    recipientsCount = _.reduce(['to', 'cc', 'bcc', 'reply-to'], _.bind(function(count, type) {
      var typeCount = 0;
      if (this[type]) {
        typeCount = this[type].length;
        _.forEach(this[type], function(recipient) {
          if (_.indexOf(identities, recipient.email) >= 0) {
            typeCount--;
          }
        });
        return count + typeCount;
      }
      else {
        return count;
      }
    }, this), recipientsCount);

    return !this.isDraft && recipientsCount > 1;
  };

  /**
   * @function loadUnsafeContent
   * @memberof Message.prototype
   * @desc Mark the message to load unsafe resources when calling $content().
   */
  Message.prototype.loadUnsafeContent = function() {
    this.$loadUnsafeContent = true;
    delete this.$parts;
  };

  /**
   * @function $content
   * @memberof Message.prototype
   * @desc Get the message body as accepted by SCE (Angular Strict Contextual Escaping).
   * @returns the HTML representation of the body
   */
  Message.prototype.$content = function() {
    var _this = this,
        parts = [],
        _visit = function(part) {
          part.msgclass = 'msg-attachment-other';
          if (part.type == 'UIxMailPartAlternativeViewer') {
            _visit(_.find(part.content, function(alternatePart) {
              return part.preferredPart == alternatePart.contentType;
            }));
          }
          // Can be used for UIxMailPartMixedViewer, UIxMailPartMessageViewer, and UIxMailPartSignedViewer
          else if (angular.isArray(part.content)) {
            if (part.type == 'UIxMailPartSignedViewer' && part['supports-smime'] === 1) {
              _this.signed = {
                valid: part.valid,
                certificate: part.certificates[part.certificates.length - 1],
                message: part.message
              };
            }
            else if (part.type == 'UIxMailPartEncryptedViewer') {
              _this.encrypted = {
                valid: part.valid
              };
              if (part.valid)
                _this.encrypted.message = l("This message is encrypted");
              else
                _this.encrypted.message = l("This message can't be decrypted. Please make sure you have uploaded your S/MIME certificate from the mail preferences module.");
            }
            _.forEach(part.content, function(mixedPart) {
              _visit(mixedPart);
            });
          }
          else {
            if (angular.isUndefined(part.safeContent)) {
              // Keep a copy of the original content
              part.safeContent = part.content;
              _this.$hasUnsafeContent |= (part.safeContent.indexOf(' unsafe-') > -1);
            }
            if (part.type == 'UIxMailPartHTMLViewer') {
              part.html = true;
              if (_this.$loadUnsafeContent || Message.$displayRemoteInlineImages) {
                if (angular.isUndefined(part.unsafeContent)) {
                  part.unsafeContent = document.createElement('div');
                  part.unsafeContent.innerHTML = part.safeContent;
                  angular.forEach(['src', 'data', 'classid', 'background', 'style'], function(suffix) {
                    var elements = part.unsafeContent.querySelectorAll('[unsafe-' + suffix + ']'),
                        element,
                        value,
                        i;
                    for (i = 0; i < elements.length; i++) {
                      element = angular.element(elements[i]);
                      value = element.attr('unsafe-' + suffix);
                      element.attr(suffix, value);
                      element.removeAttr('unsafe-' + suffix);
                    }
                  });
                  _this.$hasUnsafeContent = false;
                }
                part.content = part.unsafeContent.innerHTML;
              }
              else {
                part.content = part.safeContent;
              }
              parts.push(part);
            }
            else if (part.type == 'UIxMailPartICalViewer' ||
                     part.type == 'UIxMailPartImageViewer' ||
                     part.type == 'UIxMailPartLinkViewer') {

              if (part.type == 'UIxMailPartImageViewer')
                part.msgclass = 'msg-attachment-image';
              else if (part.type == 'UIxMailPartLinkViewer')
                part.msgclass = 'msg-attachment-link';

              // Trusted content that can be compiled (Angularly-speaking)
              part.compile = true;
              parts.push(part);
            }
            else {
              part.html = true;
              part.content = part.safeContent;
              parts.push(part);
            }
          }
        };

    if (this.$parts)
      // Use the cache
      return this.$parts;

    else if (this.parts)
      _visit(this.parts);

    // Cache result
    this.$parts = parts;

    return parts;
  };

  /**
   * @function $editableContent
   * @memberof Message.prototype
   * @desc First, fetch the draft ID that corresponds to the temporary draft object on the SOGo server.
   * Secondly, fetch the editable message body along with other metadata such as the recipients.
   * @returns the HTML representation of the body
   */
  Message.prototype.$editableContent = function() {
    var _this = this;

    return Message.$$resource.fetch(this.$absolutePath(), 'edit').then(function(data) {
      angular.extend(_this, data);
      return Message.$$resource.fetch(_this.$absolutePath({asDraft: true}), 'edit').then(function(data) {
        // Try to match a known account identity from the specified "from" address
        var identity = _.find(_this.$mailbox.$account.identities, function(identity) {
          return data.from.toLowerCase().indexOf(identity.email) !== -1;
        });
        if (identity)
          data.from = identity.full;
        var accountDefaults = Message.$Preferences.defaults.AuxiliaryMailAccounts[_this.$mailbox.$account.id];
        if (accountDefaults.security) {
          if (accountDefaults.security.alwaysSign)
            data.sign = true;
          if (accountDefaults.security.alwaysEncrypt)
            data.encrypt = true;
        }
        Message.$log.debug('editable = ' + JSON.stringify(data, undefined, 2));
        angular.extend(_this.editable, data);
        return data.text;
      });
    });
  };

  /**
   * @function $plainContent
   * @memberof Message.prototype
   * @returns the a plain text representation of the subject and body
   */
  Message.prototype.$plainContent = function() {
    return Message.$$resource.fetch(this.$absolutePath(), 'viewplain');
  };

  /**
   * @function addTag
   * @memberof Message.prototype
   * @desc Add a mail tag on the current message.
   * @param {string} tag - the tag name
   * @returns a promise of the HTTP operation
   */
  Message.prototype.addTag = function(tag) {
    return this.$addOrRemoveTag('add', tag);
  };

  /**
   * @function removeTag
   * @memberof Message.prototype
   * @desc Remove a mail tag from the current message.
   * @param {string} tag - the tag name
   * @returns a promise of the HTTP operation
   */
  Message.prototype.removeTag = function(tag) {
    return this.$addOrRemoveTag('remove', tag);
  };

  /**
   * @function $addOrRemoveTag
   * @memberof Message.prototype
   * @desc Add or remove a mail tag on the current message.
   * @param {string} operation - the operation name to perform
   * @param {string} tag - the tag name
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$addOrRemoveTag = function(operation, tag) {
    var data = {
      operation: operation,
      msgUIDs: [this.uid],
      flags: tag.replace(/^_\$/, '$')
    };

    if (tag)
      return Message.$$resource.post(this.$mailbox.$id(), 'addOrRemoveLabel', data);
  };

  /**
   * @function $imipAction
   * @memberof Message.prototype
   * @desc Perform IMIP actions on the current message.
   * @param {string} path - the path of the IMIP calendar part
   * @param {string} action - the the IMIP action to perform
   * @param {object} data - the delegation info
   */
  Message.prototype.$imipAction = function(path, action, data) {
    var _this = this;
    Message.$$resource.post([this.$absolutePath(), path].join('/'), action, data).then(function(data) {
      Message.$timeout(function() {
        _this.$reload();
      });
    });
  };

  /**
   * @function $sendMDN
   * @memberof Message.prototype
   * @desc Send MDN response for current email message
   */
  Message.prototype.$sendMDN = function() {
    this.shouldAskReceipt = 0;
    return Message.$$resource.post(this.$absolutePath(), 'sendMDN');
  };

  /**
   * @function $deleteAttachment
   * @memberof Message.prototype
   * @desc Delete an attachment from a message being composed
   * @param {string} filename - the filename of the attachment to delete
   */
  Message.prototype.$deleteAttachment = function(filename) {
    var data = { 'filename': filename };
    var _this = this;
    Message.$$resource.fetch(this.$absolutePath({asDraft: true}), 'deleteAttachment', data).then(function(data) {
      Message.$timeout(function() {
        _this.editable.attachmentAttrs = _.filter(_this.editable.attachmentAttrs, function(attachment) {
          return attachment.filename != filename;
        });
      });
    });
  };

  /**
   * @function $markAsFlaggedOrUnflagged
   * @memberof Message.prototype
   * @desc Add or remove a the \\Flagged flag on the current message.
   * @returns a promise of the HTTP operation
   */
  Message.prototype.toggleFlag = function() {
    var _this = this,
        action = 'markMessageFlagged';

    if (this.isflagged)
      action = 'markMessageUnflagged';

    return Message.$$resource.post(this.$absolutePath(), action).then(function(data) {
      Message.$timeout(function() {
        _this.isflagged = !_this.isflagged;
      });
    });
  };

  /**
   * @function $isLoading
   * @memberof Message.prototype
   * @returns true if the Message content is still being retrieved from server after a specific delay
   * @see sgMessage_STATUS
   */
  Message.prototype.$isLoading = function() {
    return this.$loaded == Message.STATUS.LOADING;
  };

  /**
   * @function $reload
   * @memberof Message.prototype
   * @desc Fetch the viewable message body along with other metadata such as the list of attachments.
   * @param {object} [options] - set {useCache: true} to use already fetched data
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$reload = function(options) {
    var _this = this, futureMessageData;

    if (options && options.useCache && this.$futureMessageData) {
      if (!this.isread) {
        Message.$$resource.fetch(this.$absolutePath(), 'markMessageRead').then(function() {
          Message.$timeout(function() {
            _this.isread = true;
            _this.$mailbox.unseenCount--;
          });
        });
      }
      return this;
    }

    futureMessageData = Message.$$resource.fetch(this.$absolutePath(options), 'view');

    return this.$unwrap(futureMessageData);
  };

  /**
   * @function $parseMailto
   * @memberof Message.prototype
   * @desc Extend the editable content of the message with the
   * information parsed from the specified "mailto:" link.
   */
  Message.prototype.$parseMailto = function(mailto) {
    var to, data, match = /^mailto:([^\?]+)/.exec(mailto);
    if (match) {
      // Recipients
      to = _.map(decodeURIComponent(match[1]).split(','), function(email) {
        return '<' + email.trim() + '>';
      });
      data = { to: to };
      // Subject & body
      _.forEach(['subject', 'body'], function(param) {
        var re = new RegExp(param + '=([^&]+)');
        param = (param == 'body')? 'text' : param;
        match = re.exec(mailto);
        if (match)
          data[param] = decodeURIComponent(match[1]);
      });
      // Other Recipients
      _.forEach(['cc', 'bcc'], function(param) {
        var re = new RegExp(param + '=([^&]+)');
        match = re.exec(mailto);
        if (match)
          data[param] = _.map(decodeURIComponent(match[1]).split(','), function(email) {
            return '<' + email.trim() + '>';
          });
      });
      angular.extend(this.editable, data);
    }
  };

  /**
   * @function $reply
   * @memberof Message.prototype
   * @desc Prepare a new Message object as a reply to the sender.
   * @returns a promise of the HTTP operations
   */
  Message.prototype.$reply = function() {
    return this.$newDraft('reply');
  };

  /**
   * @function $replyAll
   * @memberof Message.prototype
   * @desc Prepare a new Message object as a reply to the sender and all recipients.
   * @returns a promise of the HTTP operations
   */
  Message.prototype.$replyAll = function() {
    return this.$newDraft('replyall');
  };

  /**
   * @function $forward
   * @memberof Message.prototype
   * @desc Prepare a new Message object as a forward.
   * @returns a promise of the HTTP operations
   */
  Message.prototype.$forward = function() {
    return this.$newDraft('forward');
  };

  /**
   * @function $newDraft
   * @memberof Message.prototype
   * @desc Prepare a new Message object as a reply or a forward of the current message and associated
   * to the draft mailbox.
   * @see {@link Account.$newMessage}
   * @see {@link Message.$editableContent}
   * @see {@link Message.$reply}
   * @see {@link Message.$replyAll}
   * @see {@link Message.$forwad}
   * @param {string} action - the HTTP action to perform on the message
   * @returns a promise of the HTTP operations
   */
  Message.prototype.$newDraft = function(action) {
    var _this = this;

    // Query server for draft folder and draft UID
    return Message.$$resource.fetch(this.$absolutePath(), action).then(function(data) {
      var mailbox, message;
      Message.$log.debug('New ' + action + ': ' + JSON.stringify(data, undefined, 2));
      mailbox = _this.$mailbox.$account.$getMailboxByPath(data.mailboxPath);
      message = new Message(data.accountId, mailbox, data);
      // Fetch draft initial data
      return Message.$$resource.fetch(message.$absolutePath({asDraft: true}), 'edit').then(function(data) {
        Message.$log.debug('New ' + action + ': ' + JSON.stringify(data, undefined, 2) + ' original UID: ' + _this.uid);
        var accountDefaults = Message.$Preferences.defaults.AuxiliaryMailAccounts[_this.$mailbox.$account.id];
        if (accountDefaults.security) {
          if (accountDefaults.security.alwaysSign)
            data.sign = true;
          if (accountDefaults.security.alwaysEncrypt)
            data.encrypt = true;
        }
        angular.extend(message.editable, data);

        // We keep a reference to our original message in order to update the flags
        message.origin = {message: _this, action: action};
        return message;
      });
    });
  };

  /**
   * @function $save
   * @memberof Message.prototype
   * @desc Save the message to the server.
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$save = function() {
    var _this = this,
        data = this.editable;

    Message.$log.debug('save = ' + JSON.stringify(data, undefined, 2));

    return Message.$$resource.save(this.$absolutePath({asDraft: true}), data).then(function(response) {
      Message.$log.debug('save = ' + JSON.stringify(response, undefined, 2));
      _this.$setUID(response.uid);
      _this.$reload(); // fetch a new viewable version of the message
      _this.isNew = false;
    });
  };

  /**
   * @function $send
   * @memberof Message.prototype
   * @desc Send the message.
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$send = function() {
    var _this = this,
        data = angular.copy(this.editable);

    Message.$log.debug('send = ' + JSON.stringify(data, undefined, 2));

    return Message.$$resource.post(this.$absolutePath({asDraft: true}), 'send', data).then(function(response) {
      if (response.status == 'success') {
        if (angular.isDefined(_this.origin)) {
          if (_this.origin.action.startsWith('reply'))
            _this.origin.message.isanswered = true;
          else if (_this.origin.action == 'forward')
            _this.origin.message.isforwarded = true;
        }
        return response;
      }
      else {
        return Message.$q.reject(response.data);
      }
    });
  };

  /**
   * @function $unwrap
   * @memberof Message.prototype
   * @desc Unwrap a promise.
   * @param {promise} futureMessageData - a promise of some of the Message's data
   */
  Message.prototype.$unwrap = function(futureMessageData) {
    var _this = this;

    // Message is not loaded yet
    this.$loaded = Message.STATUS.DELAYED_LOADING;
    Message.$timeout(function() {
      if (_this.$loaded != Message.STATUS.LOADED)
        _this.$loaded = Message.STATUS.LOADING;
    }, Message.STATUS.DELAYED_MS);

    // Resolve and expose the promise
    this.$futureMessageData = futureMessageData.then(function(data) {
      // Calling $timeout will force Angular to refresh the view
      if (_this.isread === 0) {
        _this.isread = true;
        _this.$mailbox.unseenCount--;
      }
      return Message.$timeout(function() {
        delete _this.$parts;
        _this.$loaded = Message.STATUS.LOADED;
        _this.init(data);
        return _this;
      });
    });

    return this.$futureMessageData;
  };

  /**
   * @function $omit
   * @memberof Message.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Message instance
   */
  Message.prototype.$omit = function(options) {
    var message = {},
        privateAttributes = options && options.privateAttributes;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$' || privateAttributes) {
        message[key] = value;
      }
    });

    return message;
  };

  /**
   * @function download
   * @memberof Message.prototype
   * @desc Download the current message
   * @returns a promise of the HTTP operation
   */
  Message.prototype.download = function() {
    var data, options;

    data = { uids: [this.uid] };
    options = { filename: this.subject + '.zip' };

    return Message.$$resource.download(this.$mailbox.id, 'saveMessages', data, options);
  };

  /**
   * @function downloadAttachments
   * @memberof Message.prototype
   * @desc Download an archive of all attachments
   * @returns a promise of the HTTP operation
   */
  Message.prototype.downloadAttachments = function() {
    var options;

    options = { filename: l('attachments') + "-" + this.uid + ".zip" };

    return Message.$$resource.download(this.$absolutePath(), 'archiveAttachments', null, options);
  };

})();
