/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Mailbox
   * @constructor
   * @param {object} futureMailboxData - either an object literal or a promise
   */
  function Mailbox(account, futureMailboxData) {
    this.$account = account;
    // Data is immediately available
    if (typeof futureMailboxData.then !== 'function') {
      angular.extend(this, futureMailboxData);
      this.id = this.$id();
    }
    else {
      // The promise will be unwrapped first
      // NOTE: this condition never happen for the moment
      this.$unwrap(futureMailboxData);
    }
  }

  /**
   * @memberof Mailbox
   * @desc The factory we'll use to register with Angular
   * @returns the Mailbox constructor
   */
  Mailbox.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgResource', 'sgMessage', 'sgMailbox_PRELOAD', function($q, $timeout, $log, Settings, Resource, Message, PRELOAD) {
    angular.extend(Mailbox, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.baseURL, Settings.activeUser),
      $Message: Message,
      PRELOAD: PRELOAD
    });

    return Mailbox; // return constructor
  }];

  angular.module('SOGo.MailerUI')
  /* Factory constants */
    .constant('sgMailbox_PRELOAD', {
      LOOKAHEAD: 50,
      SIZE: 100
    })
  /* Factory registration in Angular module */
    .factory('sgMailbox', Mailbox.$factory);

  /**
   * @function $delete
   * @memberof Mailbox.prototype
   * @desc Delete the mailbox from the server
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$delete = function() {
    var _this = this,
        d = Mailbox.$q.defer(),
        promise;

    promise = Mailbox.$$resource.remove(this.id);

    promise.then(function() {
      _this.$account.$getMailboxes();
      d.resolve(true);
    }, function(data, status) {
      d.reject(data);
    });
    return d.promise;
  };
    
  /**
   * @memberof Mailbox
   * @desc Fetch list of mailboxes of a specific account
   * @param {string} accountId - the account
   * @return a promise of the HTTP operation
   * @see {@link Account.$getMailboxes}
   */
  Mailbox.$find = function(account) {
    var path, futureMailboxData;

    futureMailboxData = this.$$resource.post(account.id, 'view', {sortingAttributes: {sort: 'date', asc: false}});

    return Mailbox.$unwrapCollection(account, futureMailboxData); // a collection of mailboxes
  };

  /**
   * @memberof Mailbox
   * @desc Unwrap to a collection of Mailbox instances.
   * @param {string} account - the account
   * @param {promise} futureMailboxData - a promise of the mailboxes metadata
   * @returns a promise of a collection of Mailbox objects
   */
  Mailbox.$unwrapCollection = function(account, futureMailboxData) {
    var collection = [],
        // Local recursive function
        createMailboxes = function(mailbox) {
          for (var i = 0; i < mailbox.children.length; i++) {
            mailbox.children[i] = new Mailbox(account, mailbox.children[i]);
            createMailboxes(mailbox.children[i]);
          }
        };
    //collection.$futureMailboxData = futureMailboxData;

    return futureMailboxData.then(function(data) {
      return Mailbox.$timeout(function() {
        // Each entry is spun up as a Mailbox instance
        angular.forEach(data.mailboxes, function(data, index) {
          var mailbox = new Mailbox(account, data);
          createMailboxes(mailbox); // recursively create all sub-mailboxes
          collection.push(mailbox);
        });
        return collection;
      });
    });
  };

  /**
   * @memberof Mailbox
   * @desc Build the path of the mailbox (or account only).
   * @param {string} accountId - the account ID
   * @param {string} [mailboxPath] - an array of the mailbox path components
   * @returns a string representing the path relative to the mail module
   */
  Mailbox.$absolutePath = function(accountId, mailboxPath) {
    var path = [];

    if (mailboxPath) {
      path = _.map(mailboxPath.split('/'), function(component) {
        return 'folder' + component.asCSSIdentifier();
      });
    }

    path.splice(0, 0, accountId); // insert account ID

    return path.join('/');
  };
  
  /**
   * @function $id
   * @memberof Mailbox.prototype
   * @desc Build the unique ID to identified the mailbox.
   * @returns a string representing the path relative to the mail module
   */
  Mailbox.prototype.$id = function() {
    return Mailbox.$absolutePath(this.$account.id, this.path);
  };

  /**
   * @function $update
   * @memberof Mailbox.prototype
   * @desc Fetch the messages metadata of the mailbox.
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$update = function() {
    var futureMailboxData;

    futureMailboxData = Mailbox.$$resource.post(this.id, 'view', {sortingAttributes: {sort: 'date', asc: false}});

    return this.$unwrap(futureMailboxData);
  };

  /**
   * @function $loadMessage
   * @memberof Mailbox.prototype
   * @desc Check if the message is loaded and in any case, fetch more messages headers from the server.
   * @returns true if the message metadata are already fetched
   */
  Mailbox.prototype.$loadMessage = function(messageId) {
    var startIndex = this.uidsMap[messageId],
        endIndex,
        max = this.$messages.length,
        loaded = false,
        uids,
        futureHeadersData;
    if (angular.isDefined(this.uidsMap[messageId]) && startIndex < this.$messages.length) {
      // Index is valid
      if (angular.isDefined(this.$messages[startIndex].subject)) {// || this.$messages[startIndex].loading) {
        // Message headers are loaded or data is coming
        loaded = true;
      }

      // Preload more headers if possible
      endIndex = Math.min(startIndex + Mailbox.PRELOAD.LOOKAHEAD, max - 1);
      if (!angular.isDefined(this.$messages[endIndex].subject)
          && !angular.isDefined(this.$messages[endIndex].loading)) {
        endIndex = Math.min(startIndex + Mailbox.PRELOAD.SIZE, max);
        for (uids = []; startIndex < endIndex && startIndex < max; startIndex++) {
          if (angular.isDefined(this.$messages[startIndex].subject) || this.$messages[startIndex].loading) {
            // Message at this index is already loaded; increase the end index
            endIndex++;
          }
          else {
            // Message at this index will be loaded
            uids.push(this.$messages[startIndex].uid);
            this.$messages[startIndex].loading = true;
          }
        }

        Mailbox.$log.debug('Loading UIDs ' + uids.join(' '));
        futureHeadersData = Mailbox.$$resource.post(this.id, 'headers', {uids: uids});
        this.$unwrapHeaders(futureHeadersData);
      }
    }
    return loaded;
  };

  /**
   * @function $deleteMessages
   * @memberof Mailbox.prototype
   * @desc Delete multiple messages from mailbox.
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$deleteMessages = function(uids) {
    return Mailbox.$$resource.post(this.id, 'batchDelete', {uids: uids});
  };

  /**
   * @function $omit
   * @memberof Mailbox.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Mailbox instance
   */
  Mailbox.prototype.$omit = function() {
    var mailbox = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          key != 'children' &&
          key[0] != '$') {
        mailbox[key] = value;
      }
    });
    return mailbox;
  };

  /**
   * @function $unwrap
   * @memberof Mailbox.prototype
   * @desc Unwrap a promise and instanciate new Message objects using received data.
   * @param {promise} futureMailboxData - a promise of the Mailbox's metadata
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$unwrap = function(futureMailboxData) {
    var _this = this,
        deferred = Mailbox.$q.defer();

    this.$futureMailboxData = futureMailboxData;
    this.$futureMailboxData.then(function(data) {
      Mailbox.$timeout(function() {
        var uids, headers;

        angular.extend(_this, data);
        _this.$messages = [];
        _this.uidsMap = {};

        if (_this.uids) {
          // First entry of 'headers' are keys
          headers = _.invoke(_this.headers[0], 'toLowerCase');
          _this.headers.splice(0, 1);

          // First entry of 'uids' are keys when threaded view is enabled
          if (_this.threaded) {
            uids = _this.uids[0];
            _this.uids.splice(0, 1);
          }

          // Instanciate Message objects
          _.reduce(_this.uids, function(msgs, msg, i) {
            var data;
            if (_this.threaded)
              data = _.object(uids, msg);
            else
              data = {uid: msg.toString()};

            // Build map of UID <=> index
            _this.uidsMap[data.uid] = i;

            msgs.push(new Mailbox.$Message(_this.$account.id, _this.path, data));

            return msgs;
          }, _this.$messages);

          // Extend Message objects with received headers
          _.each(_this.headers, function(data) {
            var msg = _.object(headers, data),
                i = _this.uidsMap[msg.uid.toString()];
            _.extend(_this.$messages[i], msg);
          });
        }
        Mailbox.$log.debug('mailbox ' + _this.id + ' ready');
        deferred.resolve(_this.$messages);
      });
    }, function(data) {
      angular.extend(_this, data);
      _this.isError = true;
      deferred.reject();
    });

    return deferred.promise;
  };

  /**
   * @function $unwrapHeaders
   * @memberof Mailbox.prototype
   * @desc Unwrap a promise and extend matching Message objects using received data.
   * @param {promise} futureHeadersData - a promise of some messages metadata
   */
  Mailbox.prototype.$unwrapHeaders = function(futureHeadersData) {
    var _this = this;

    futureHeadersData.then(function(data) {
      Mailbox.$timeout(function() {
        var headers, j;
        if (data.length > 0) {
          // First entry of 'headers' are keys
          headers = _.invoke(data[0], 'toLowerCase');
          data.splice(0, 1);
          _.each(data, function(messageHeaders) {
            messageHeaders = _.object(headers, messageHeaders);
            j = _this.uidsMap[messageHeaders.uid.toString()];
            if (angular.isDefined(j)) {
              _.extend(_this.$messages[j], messageHeaders);
            }
          });
        }
      });
    });
  };
  
})();
