/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Mailbox
   * @constructor
   * @param {object} futureMailboxData - either an object literal or a promise
   */
  function Mailbox(account, futureMailboxData) {
    this.$isLoading = false;
    this.$account = account;
    // Data is immediately available
    if (typeof futureMailboxData.then !== 'function') {
      angular.extend(this, futureMailboxData);
      if (this.name && !this.path) {
        // Create a new mailbox on the server
        var newMailboxData = Mailbox.$$resource.create('createFolder', this.name);
        this.$unwrap(newMailboxData);
      }
      else {
        this.id = this.$id();
        this.isEditable = this.$isEditable();
        // Make a copy of the data for an eventual reset
        this.$shadowData = this.$omit();
      }
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
  Mailbox.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Message', 'sgMailbox_PRELOAD', function($q, $timeout, $log, Settings, Resource, Message, PRELOAD) {
    angular.extend(Mailbox, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL + 'Mail', Settings.activeUser),
      $Message: Message,
      PRELOAD: PRELOAD
    });

    return Mailbox; // return constructor
  }];

  /**
   * @module SOGo.MailerUI
   * @desc Factory registration of Card in Angular module.
   */
  angular.module('SOGo.MailerUI')
  /* Factory constants */
    .constant('sgMailbox_PRELOAD', {
      LOOKAHEAD: 50,
      SIZE: 100
    })
  /* Factory registration in Angular module */
    .factory('Mailbox', Mailbox.$factory);

  /**
   * @memberof Mailbox
   * @desc Fetch list of mailboxes of a specific account
   * @param {string} accountId - the account
   * @return a promise of the HTTP operation
   * @see {@link Account.$getMailboxes}
   */
  Mailbox.$find = function(account) {
    var path, futureMailboxData;

    futureMailboxData = this.$$resource.fetch(account.id.toString(), 'view');

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
        createMailboxes = function(level, mailbox) {
          for (var i = 0; i < mailbox.children.length; i++) {
            mailbox.children[i].level = level;
            mailbox.children[i] = new Mailbox(account, mailbox.children[i]);
            createMailboxes(level+1, mailbox.children[i]);
          }
        };
    //collection.$futureMailboxData = futureMailboxData;

    return futureMailboxData.then(function(data) {
      return Mailbox.$timeout(function() {
        // Each entry is spun up as a Mailbox instance
        angular.forEach(data.mailboxes, function(data, index) {
          data.level = 0;
          var mailbox = new Mailbox(account, data);
          createMailboxes(1, mailbox); // recursively create all sub-mailboxes
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
   * @param {string} [mailboxPath] - the mailbox path
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
   * @function $selectedCount
   * @memberof Mailbox.prototype
   * @desc Return the number of messages selected by the user.
   * @returns the number of selected messages
   */
  Mailbox.prototype.$selectedCount = function() {
    var count;

    count = 0;
    if (this.$messages) {
      count = (_.filter(this.$messages, function(message) { return message.selected })).length;
    }
    return count;
  };

  /**
   * @function $filter
   * @memberof Mailbox.prototype
   * @desc Fetch the messages metadata of the mailbox
   * @param {object} [sort] - sort preferences. Defaults to descendent by date.
   * @param {string} sort.match - either AND or OR
   * @param {string} sort.sort - either arrival, subject, from, to, date, or size
   * @param {boolean} sort.asc - sort is ascendant if true
   * @param {object[]} [filers] - list of filters for the query
   * @param {string} filers.searchBy - either subject, from, to, cc, or body
   * @param {string} filers.searchInput - the search string to match
   * @param {boolean} filers.negative - negate the condition
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$filter = function(sort, filters) {
    var futureMailboxData, options;

    if (!angular.isDefined(sort)) {
      sort = { sortingAttributes: { match: 'OR', sort: 'date', asc: false } };
    }
    options = { sortingAttributes: sort };
    if (angular.isDefined(filters)) {
      options.filters = _.reject(filters, function(filter) {
        return angular.isUndefined(filter.searchInput) || filter.searchInput.length == 0;
      });
      _.each(options.filters, function(filter) {
        var secondFilter,
            match = filter.searchBy.match(/(\w+)_or_(\w+)/);
        if (match) {
          options.sortingAttributes.match = 'OR';
          filter.searchBy = match[1];
          secondFilter = angular.copy(filter);
          secondFilter.searchBy = match[2];
          options.filters.push(secondFilter);
        }
      });
    }

    this.$isLoading = true;
    futureMailboxData = Mailbox.$$resource.post(this.id, 'view', options);

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
   * @function $isEditable
   * @memberof Mailbox.prototype
   * @desc Checks if the mailbox is editable based on its type.
   * @returns true if the mailbox is not a special folder.
   */
  Mailbox.prototype.$isEditable = function() {
    return _.contains(['folder', 'inbox', 'draft', 'sent', 'trash'], this.type);
  };

  /**
   * @function $rename
   * @memberof AddressBook.prototype
   * @desc Rename the addressbook and keep the list sorted
   * @param {string} name - the new name
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$rename = function() {
    var _this = this,
        findParent,
        deferred = Mailbox.$q.defer(),
        parent,
        children,
        i;

    if (this.name == this.$shadowData.name) {
      // Name hasn't changed
      deferred.resolve();
      return deferred.promise;
    }

    // Local recursive function
    findParent = function(parent, children) {
      var parentMailbox = null,
          mailbox = _.find(children, function(o) {
            return o.path == _this.path;
          });
      if (mailbox) {
        parentMailbox = parent;
      }
      else {
        angular.forEach(children, function(o) {
          if (!parentMailbox && o.children && o.children.length > 0) {
            parentMailbox = findParent(o, o.children);
          }
        });
      }
      return parentMailbox;
    };

    // Find mailbox parent
    parent = findParent(null, this.$account.$mailboxes);
    if (parent == null)
      children = this.$account.$mailboxes;
    else
      children = parent.children;

    // Find index of mailbox among siblings
    i = _.indexOf(_.pluck(children, 'id'), this.id);

    this.$save().then(function(data) {
      var sibling;
      angular.extend(_this, data); // update the path attribute
      _this.id = _this.$id();

      // Move mailbox among its siblings according to its new name
      children.splice(i, 1);
      sibling = _.find(children, function(o) {
        Mailbox.$log.debug(o.name + ' ? ' + _this.name);
        return (o.type == 'folder' && o.name.localeCompare(_this.name) > 0);
      });
      if (sibling) {
        i = _.indexOf(_.pluck(children, 'id'), sibling.id);
      }
      else {
        i = children.length;
      }
      children.splice(i, 0, _this);

      deferred.resolve();
    }, function(data) {
      deferred.reject(data);
    });

    return deferred.promise;
  };

  /**
   * @function $delete
   * @memberof Mailbox.prototype
   * @desc Delete the mailbox from the server
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$delete = function() {
    var _this = this,
        deferred = Mailbox.$q.defer(),
        promise;

    promise = Mailbox.$$resource.remove(this.id);

    promise.then(function() {
      _this.$account.$getMailboxes({reload: true});
      deferred.resolve(true);
    }, function(data, status) {
      deferred.reject(data);
    });
    return deferred.promise;
  };

  /**
   * @function $deleteMessages
   * @memberof Mailbox.prototype
   * @desc Delete multiple messages from mailbox.
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$deleteMessages = function(uids) {
    var _this = this;
    return Mailbox.$$resource.post(this.id, 'batchDelete', {uids: uids});
  };

  /**
   * @function $reset
   * @memberof Mailbox.prototype
   * @desc Reset the original state the mailbox's data.
   */
  Mailbox.prototype.$reset = function() {
    var _this = this;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key != 'children' && key[0] != '$') {
        delete _this[key];
      }
    });
    angular.extend(this, this.$shadowData);
    this.$shadowData = this.$omit();
  };

  /**
   * @function $save
   * @memberof Mailbox.prototype
   * @desc Save the mailbox to the server. This currently can only affect the name of the mailbox.
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$save = function() {
    var _this = this;

    return Mailbox.$$resource.save(this.id, this.$omit()).then(function(data) {
      // Make a copy of the data for an eventual reset
      _this.$shadowData = _this.$omit();
      Mailbox.$log.debug(JSON.stringify(data, undefined, 2));
      return data;
    }, function(data) {
      Mailbox.$log.error(JSON.stringify(data, undefined, 2));
      // Restore previous version
      _this.$reset();
    });
  };

  /**
   * @function $newMailbox
   * @memberof Mailbox.prototype
   * @desc Create a new mailbox on the server and refresh the list of mailboxes.
   * @returns a promise of the HTTP operations
   */
  Mailbox.prototype.$newMailbox = function(path, name) {
    return this.$account.$newMailbox(path, name);
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
          Mailbox.$log.debug('unwrapping ' + data.uids.length + ' messages');
          
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

            msgs.push(new Mailbox.$Message(_this.$account.id, _this, data));

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
        _this.$isLoading = false;
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
