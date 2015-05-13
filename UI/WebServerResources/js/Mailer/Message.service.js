/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Message
   * @constructor
   * @param {string} accountId - the account ID
   * @param {string} mailboxPath - an array of the mailbox path components
   * @param {object} futureAddressBookData - either an object literal or a promise
   */
  function Message(accountId, mailbox, futureMessageData) {
    this.accountId = accountId;
    this.$mailbox = mailbox;
    this.$hasUnsafeContent = false;
    this.$loadUnsafeContent = false;
    this.editable = {to: [], cc: [], bcc: []};
    // Data is immediately available
    if (typeof futureMessageData.then !== 'function') {
      //console.debug(JSON.stringify(futureMessageData, undefined, 2));
      angular.extend(this, futureMessageData);
      this.id = this.$absolutePath();
      this.$formatFullAddresses();
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureMessageData);
    }
    this.selected = false;
  }

  /**
   * @memberof Message
   * @desc The factory we'll use to register with Angular
   * @returns the Message constructor
   */
  Message.$factory = ['$q', '$timeout', '$log', '$sce', 'sgSettings', 'Resource', function($q, $timeout, $log, $sce, Settings, Resource) {
    angular.extend(Message, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $sce: $sce,
      $$resource: new Resource(Settings.activeUser.folderURL + 'Mail', Settings.activeUser)
    });

    if (window.UserDefaults && window.UserDefaults.SOGoMailLabelsColors) {
      Message.$tags = window.UserDefaults.SOGoMailLabelsColors;
    }

    return Message; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.MailerUI')
    .factory('Message', Message.$factory);

  /**
   * @function filterTags
   * @memberof Message.prototype
   * @desc Search for tags (ie., mail labels) matching some criterias
   * @param {string} search - the search string to match
   * @returns a collection of strings
   */
  Message.filterTags = function(query) {
    var re = new RegExp(query, 'i');
    return _.filter(_.keys(Message.$tags), function(tag) {
      var value = Message.$tags[tag];
      return value[0].search(re) != -1;
    });
  };

  /**
   * @function $absolutePath
   * @memberof Message.prototype
   * @desc Build the path of the message
   * @returns a string representing the path relative to the mail module
   */
  Message.prototype.$absolutePath = function(options) {
    var path;

    path = _.map(this.$mailbox.path.split('/'), function(component) {
      return 'folder' + component.asCSSIdentifier();
    });
    path.splice(0, 0, this.accountId); // insert account ID
    if (options && options.asDraft && this.draftId) {
      path.push(this.draftId); // add draft ID
    }
    else {
      path.push(this.uid); // add message UID
    }

    return path.join('/');
  };

  /**
   * @function $setUID
   * @memberof Message.prototype
   * @desc Change the UID of the message. This happens when saving a draft.
   * @param {number} uid - the new message UID
   */
  Message.prototype.$setUID = function(uid) {
    var oldUID = this.uid || -1;

    if (oldUID != uid) {
      this.uid = uid;
      this.id = this.$absolutePath();
      if (oldUID > -1) {
        // For new messages, $mailbox doesn't exist
        this.$mailbox.uidsMap[uid] = this.$mailbox.uidsMap[oldUID];
        this.$mailbox.uidsMap[oldUID] = null;
      }
    }
  };

  /**
   * @function $formatFullAddresses
   * @memberof Message.prototype
   * @desc Format all sender and recipients addresses with a complete description (name <email>).
   */
  Message.prototype.$formatFullAddresses = function() {
    var _this = this;

    // Build long representation of email addresses
    _.each(['from', 'to', 'cc', 'bcc', 'reply-to'], function(type) {
      _.each(_this[type], function(data, i) {
        if (data.name && data.name != data.email)
          data.full = data.name + ' <' + data.email + '>';
        else
          data.full = '<' + data.email + '>';
      });
    });
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
   * @function loadUnsafeContent
   * @memberof Message.prototype
   * @desc Mark the message to load unsafe resources when calling $content().
   */
  Message.prototype.loadUnsafeContent = function() {
    this.$loadUnsafeContent = true;
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
          if (part.type == 'UIxMailPartAlternativeViewer') {
            _visit(_.find(part.content, function(alternatePart) {
              return part.preferredPart == alternatePart.contentType;
            }));
          }
          else if (angular.isArray(part.content)) {
            _.each(part.content, function(mixedPart) {
              _visit(mixedPart);
            });
          }
          else {
            if (angular.isUndefined(part.safeContent)) {
              // Keep a copy of the original content
              part.safeContent = part.content;
              _this.$hasUnsafeContent = (part.safeContent.indexOf(' unsafe-') > -1);
            }
            if (part.type == 'UIxMailPartHTMLViewer') {
              part.html = true;
              if (_this.$loadUnsafeContent) {
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
                }
                part.content = Message.$sce.trustAs('html', part.unsafeContent.innerHTML);
              }
              else {
                part.content = Message.$sce.trustAs('html', part.safeContent);
              }
              parts.push(part);
            }
            else if (part.type == 'UIxMailPartICalViewer' ||
                     part.type == 'UIxMailPartLinkViewer') {
              // Trusted content that can be compiled (Angularly-speaking)
              part.compile = true;
              parts.push(part);
            }
            else {
              part.html = true;
              part.content = Message.$sce.trustAs('html', part.safeContent);
              parts.push(part);
            }
          }
        };
    _visit(this.parts);

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
    var _this = this,
        deferred = Message.$q.defer();

    Message.$$resource.fetch(this.id, 'edit').then(function(data) {
      angular.extend(_this, data);
      Message.$$resource.fetch(_this.$absolutePath({asDraft: true}), 'edit').then(function(data) {
        Message.$log.debug('editable = ' + JSON.stringify(data, undefined, 2));
        angular.extend(_this.editable, data);
        deferred.resolve(data.text);
      }, deferred.reject);
    }, deferred.reject);

    return deferred.promise;
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
      flags: tag
    };

    if (tag)
      return Message.$$resource.post(this.$mailbox.$id(), 'addOrRemoveLabel', data);
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

    return Message.$$resource.post(this.id, action).then(function(data) {
      Message.$timeout(function() {
        _this.isflagged = !_this.isflagged;
      });
    });
  }

  /**
   * @function $reload
   * @memberof Message.prototype
   * @desc Fetch the viewable message body along with other metadata such as the list of attachments.
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$reload = function() {
    var futureMessageData;

    futureMessageData = Message.$$resource.fetch(this.id, 'view');

    return this.$unwrap(futureMessageData);
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
    var _this = this,
        deferred = Message.$q.defer(),
        mailbox,
        message;

    // Query server for draft folder and draft UID
    Message.$$resource.fetch(this.id, action).then(function(data) {
      Message.$log.debug('New ' + action + ': ' + JSON.stringify(data, undefined, 2));
      mailbox = _this.$mailbox.$account.$getMailboxByPath(data.mailboxPath);
      message = new Message(data.accountId, mailbox, data);
      // Fetch draft initial data
      Message.$$resource.fetch(message.$absolutePath({asDraft: true}), 'edit').then(function(data) {
        Message.$log.debug('New ' + action + ': ' + JSON.stringify(data, undefined, 2));
        angular.extend(message.editable, data);
        deferred.resolve(message);
      }, function(data) {
        deferred.reject(data);
      });
    }, function(data) {
      deferred.reject(data);
    });

    return deferred.promise;
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
    });
  };

  /**
   * @function $send
   * @memberof Message.prototype
   * @desc Send the message.
   * @returns a promise of the HTTP operation
   */
  Message.prototype.$send = function() {
    var data = angular.copy(this.editable),
        deferred = Message.$q.defer();

    Message.$log.debug('send = ' + JSON.stringify(data, undefined, 2));

    Message.$$resource.post(this.$absolutePath({asDraft: true}), 'send', data).then(function(data) {
      if (data.status == 'success') {
        deferred.resolve(data);
      }
      else {
        deferred.reject(data);
      }
    });

    return deferred.promise;
  };

  /**
   * @function $unwrap
   * @memberof Message.prototype
   * @desc Unwrap a promise. 
   * @param {promise} futureMessageData - a promise of some of the Message's data
   */
  Message.prototype.$unwrap = function(futureMessageData) {
    var _this = this,
        deferred = Message.$q.defer();

    // Expose the promise
    this.$futureMessageData = futureMessageData;

    // Resolve the promise
    this.$futureMessageData.then(function(data) {
      // Calling $timeout will force Angular to refresh the view
      Message.$timeout(function() {
        angular.extend(_this, data);
        _this.id = _this.$absolutePath();
        _this.$formatFullAddresses();
        _this.$loadUnsafeContent = false;
        deferred.resolve(_this);
      });
      if (!_this.isread) {
        Message.$$resource.fetch(_this.id, 'markMessageRead').then(function() {
          Message.$timeout(function() {
            _this.isread = true;
          });
        });
      }
    }, function(data) {
      angular.extend(_this, data);
      _this.isError = true;
      Message.$log.error(_this.error);
      deferred.reject();
    });

    return deferred.promise;
  };

  /**
   * @function $omit
   * @memberof Message.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Message instance
   */
  Message.prototype.$omit = function() {
    var message = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        message[key] = value;
      }
    });

    // Format addresses as arrays
    _.each(['from', 'to', 'cc', 'bcc', 'reply-to'], function(type) {
      if (message[type])
        message[type] = _.invoke(message[type].split(','), 'trim');
    });

    //Message.$log.debug(JSON.stringify(message, undefined, 2));
    return message;
  };

})();
