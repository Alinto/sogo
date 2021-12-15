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
      this.init(futureMailboxData);
      if (this.name && !this.path) {
        // Create a new mailbox on the server
        var newMailboxData = Mailbox.$$resource.create('createFolder', this.name);
        this.$unwrap(newMailboxData);
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
  Mailbox.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Message', 'Acl', 'Preferences', 'sgMailbox_PRELOAD', 'sgMailbox_BATCH_DELETE_LIMIT', function($q, $timeout, $log, Settings, Resource, Message, Acl, Preferences, PRELOAD, BATCH_DELETE_LIMIT) {
    angular.extend(Mailbox, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Mail', Settings.activeUser()),
      $Message: Message,
      $$Acl: Acl,
      $Preferences: Preferences,
      $query: { sort: 'arrival', asc: 0 }, // The default sort must match [UIxMailListActions defaultSortKey]
      selectedFolder: null,
      $refreshTimeout: null,
      $virtualMode: false,
      $virtualPath: false,
      PRELOAD: PRELOAD,
      BATCH_DELETE_LIMIT: BATCH_DELETE_LIMIT
    });
    // Initialize sort parameters from user's settings
    if (Preferences.settings.Mail.SortingState) {
      Mailbox.$query.sort = Preferences.settings.Mail.SortingState[0];
      Mailbox.$query.asc = parseInt(Preferences.settings.Mail.SortingState[1]);
    }

    return Mailbox; // return constructor
  }];

  /**
   * @module SOGo.MailerUI
   * @desc Factory registration of Mailbox in Angular module.
   */
  try {
    angular.module('SOGo.MailerUI');
  }
  catch(e) {
    angular.module('SOGo.MailerUI', ['SOGo.Common']);
  }
  angular.module('SOGo.MailerUI')
    .constant('sgMailbox_PRELOAD', {
      LOOKAHEAD: 50,
      SIZE: 100
    })
    .constant('sgMailbox_BATCH_DELETE_LIMIT', 1000)
    .factory('Mailbox', Mailbox.$factory);

  /**
   * @memberof Mailbox
   * @desc Fetch list of mailboxes of a specific account
   * @param {string} accountId - the account
   * @return a promise of the HTTP operation
   * @see {@link Account.$getMailboxes}
   */
  Mailbox.$find = function(account, options) {
    var path, futureMailboxData;

    if (options && options.all)
      futureMailboxData = this.$$resource.fetch(account.id.toString(), 'viewAll');
    else
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
          mailbox.isSentFolder = mailbox.isSentFolder || mailbox.type == 'sent';
          for (var i = 0; i < mailbox.children.length; i++) {
            mailbox.children[i].level = level;
            mailbox.children[i] = new Mailbox(account, mailbox.children[i]);
            if (mailbox.isSentFolder)
              mailbox.children[i].isSentFolder = true;
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
        // Update inbox quota
        if (data.quotas)
          account.updateQuota(data.quotas);
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
   * @function init
   * @memberof Mailbox.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of mailbox
   */
  Mailbox.prototype.init = function(data) {
    var _this = this;
    if (angular.isUndefined(this.uidsMap) || data.headers) {
      this.$isLoading = true;
      this.$messages = [];
      this.uidsMap = {};
      this.$visibleMessages = this.$messages;
      this.$selectedMessages = [];
    }
    angular.extend(this, data);
    if (this.path) {
      this.id = this.$id();
      this.$acl = new Mailbox.$$Acl('Mail/' + this.id);
      if (this.threaded) {
        this.$collapsedThreads = [];
        if (Mailbox.$Preferences.settings.Mail.threadsCollapsed && Mailbox.$Preferences.settings.Mail.threadsCollapsed['/' + this.id]) {
          this.$collapsedThreads = Mailbox.$Preferences.settings.Mail.threadsCollapsed['/' + this.id];
        }
      }
    }
    this.$displayName = this.name;
    if (this.type) {
      this.$isEditable = this.isEditable();
      this.$isSpecial = true;
      if (this.type == 'inbox') {
        this.$displayName = l('InboxFolderName');
        this.$icon = 'inbox';
      }
      else if (this.type == 'draft') {
        this.$displayName = l('DraftsFolderName');
        this.$icon = 'drafts';
      }
      else if (this.type == 'sent') {
        this.$displayName = l('SentFolderName');
        this.$icon = 'send';
      }
      else if (this.type == 'trash') {
        this.$displayName = l('TrashFolderName');
        this.$icon = 'delete';
      }
      else if (this.type == 'junk') {
        this.$displayName = l('JunkFolderName');
        this.$icon = 'thumb_down';
      }
      else if (this.type == 'additional') {
        this.$icon = 'folder';
      }
      else if (this.type == 'shared') {
        this.$icon = 'folder_shared';
      }
      else if (this.type == 'otherUsers') {
        this.$icon = 'folder_shared';
      }
      else if (this.type == 'dropbox') {
        this.$icon = 'drive_folder_upload';
      }
      else {
        this.$isSpecial = false;
        this.$icon = 'folder';
      }
    }
    this.$isNoInferiors = this.isNoInferiors();
    if (angular.isUndefined(this.$shadowData)) {
      // Make a copy of the data for an eventual reset
      this.$shadowData = this.$omit();
    }
  };

  /**
   * @function selectFolder
   * @memberof Mailbox.prototype
   * @desc Mark the folder as selected in the constructor unless virtual mode is active
   */
  Mailbox.prototype.selectFolder = function() {
    if (!Mailbox.$virtualMode)
      Mailbox.selectedFolder = this;
  };

  /**
   * @function getLength
   * @memberof Mailbox.prototype
   * @desc Used by md-virtual-repeat / md-on-demand
   * @returns the number of messages in the mailbox
   */
  Mailbox.prototype.getLength = function() {
    return this.$visibleMessages.length;
  };

  /**
   * @function getItemAtIndex
   * @memberof Mailbox.prototype
   * @desc Used by md-virtual-repeat / md-on-demand
   * @returns the message at the specified index
   */
  Mailbox.prototype.getItemAtIndex = function(index) {
    var message;

    if (index >= 0 && index < this.$visibleMessages.length) {
      message = this.$visibleMessages[index];
      this.$lastVisibleIndex = Math.max(0, index - 3); // Magic number is NUM_EXTRA from virtual-repeater.js
      this.$loadMessage(message.uid);
      return message; // skeleton is displayed while headers are being fetched
    }
    return null;
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
   * @function selectedMessages
   * @memberof Mailbox.prototype
   * @desc Return the messages selected by the user.
   * @returns Message instances
   */
  Mailbox.prototype.selectedMessages = function(options) {
    if (options && options.updateCache)
      this.$selectedMessages = _.filter(this.$messages, function(message) { return message.selected; });
    return this.$selectedMessages;
  };

  /**
   * @function selectedCount
   * @memberof Mailbox.prototype
   * @desc Return the number of messages selected by the user.
   * @returns the number of selected messages
   */
  Mailbox.prototype.selectedCount = function() {
    return this.$selectedMessages.length;
  };

  /**
   * @function $unselectMessages
   * @memberof Mailbox.prototype
   * @desc Unselect all messages.
   */
  Mailbox.prototype.$unselectMessages = function() {
    _.forEach(this.$selectedMessages, function(message) {
      message.selected = false;
    });
    this.$selectedMessages = [];
  };

  /**
   * @function isSelectedMessage
   * @memberof Mailbox.prototype
   * @desc Check if the specified message is displayed in the detailed view.
   * @param {string} messageId
   * @returns true if the specified message is displayed
   */
  Mailbox.prototype.isSelectedMessage = function(messageId) {
    return this.$selectedMessage == messageId;
  };

  /**
   * @function $selectedMessage
   * @memberof Mailbox.prototype
   * @desc Return the currently visible message.
   * @returns a Message instance or undefined if no message is displayed
   */
  Mailbox.prototype.selectedMessage = function() {
    var _this = this;
    return _.find(this.$messages, function(message) { return message.uid == _this.$selectedMessage; });
  };

  /**
   * @function $selectedMessageIndex
   * @memberof Mailbox.prototype
   * @desc Return the index of the currently visible message.
   * @returns a number or undefined if no message is selected
   */
  Mailbox.prototype.$selectedMessageIndex = function() {
    return this.uidsMap[this.$selectedMessage];
  };

  /**
   * @function hasSelectedMessage
   * @memberof Mailbox.prototype
   * @desc Check if a message is selected.
   * @returns true if the a message is selected
   */
  Mailbox.prototype.hasSelectedMessage = function() {
    return angular.isDefined(this.$selectedMessage);
  };

  /**
   * @function $filter
   * @memberof Mailbox.prototype
   * @desc Fetch the messages metadata of the mailbox
   * @param {object} [sortsortingAttributes] - sort preferences. Defaults to descendent by date.
   * @param {string} sortingAttributes.match - either AND or OR
   * @param {string} sortingAttributes.sort - either arrival, subject, from, to, date, or size
   * @param {boolean} sortingAttributes.asc - sort is ascendant if true
   * @param {object[]} [filters] - list of filters for the query
   * @param {string} filters.searchBy - either subject, from, to, cc, or body
   * @param {string} filters.searchInput - the search string to match
   * @param {boolean} filters.negative - negate the condition
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$filter = function(sortingAttributes, filters) {
    var _this = this, action = 'view', options = {};

    if (!angular.isDefined(this.unseenCount))
      this.unseenCount = 0;

    this.$isLoading = true;

    if (Mailbox.$refreshTimeout)
      Mailbox.$timeout.cancel(Mailbox.$refreshTimeout);

    if (sortingAttributes)
      // Sorting preferences are common to all mailboxes
      angular.extend(Mailbox.$query, sortingAttributes);

    angular.extend(options, { sortingAttributes: Mailbox.$query });
    if (angular.isDefined(filters)) {
      options.filters = _.reject(angular.copy(filters), function(filter) {
        return !filter.searchInput || filter.searchInput.length === 0;
      });
      // Decompose filters that match two fields
      _.forEach(options.filters, function(filter) {
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
    else if (!sortingAttributes && this.$syncToken) {
      action = 'changes';
      options.syncToken = this.$syncToken;
    }

    if (this.$unseenOnly)
      options.unseenOnly = 1;

    if (this.$flaggedOnly)
      options.flaggedOnly = 1;

    var labels = _.filter(_.keys(this.$filteredLabels), function (k) {
      return !!_this.$filteredLabels[k];
    });
    if (labels.length)
      options.labels = labels;

    // Restart the refresh timer, if needed
    if (!Mailbox.$virtualMode) {
      var refreshViewCheck = Mailbox.$Preferences.defaults.SOGoRefreshViewCheck;
      if (refreshViewCheck && refreshViewCheck != 'manually') {
        var f = angular.bind(this, Mailbox.prototype.$filter, null, filters);
        Mailbox.$refreshTimeout = Mailbox.$timeout(f, refreshViewCheck.timeInterval()*1000);
      }
    }

    var futureMailboxData = Mailbox.$$resource.post(this.id, action, options);
    return this.$unwrap(futureMailboxData);
  };

  /**
   * @function $loadMessage
   * @memberof Mailbox.prototype
   * @desc Check if the message headers are loaded and in any case, fetch more messages headers from the server.
   * @returns true if the message metadata are already fetched
   */
  Mailbox.prototype.$loadMessage = function(messageId) {
    var startIndex = this.uidsMap[messageId],
        endIndex,
        index,
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
      if (angular.isDefined(this.$messages[endIndex].subject) ||
          angular.isDefined(this.$messages[endIndex].loading)) {
        index = Math.max(startIndex - Mailbox.PRELOAD.LOOKAHEAD, 0);
        if (!angular.isDefined(this.$messages[index].subject) &&
            !angular.isDefined(this.$messages[index].loading)) {
          // Previous messages not loaded; preload more headers further up
          endIndex = startIndex;
          startIndex = Math.max(startIndex - Mailbox.PRELOAD.SIZE, 0);
        }
      }
      else
        // Next messages not load; preload more headers further down
        endIndex = Math.min(startIndex + Mailbox.PRELOAD.SIZE, max - 1);

      if (!angular.isDefined(this.$messages[startIndex].subject) &&
          !angular.isDefined(this.$messages[startIndex].loading) ||
          !angular.isDefined(this.$messages[endIndex].subject) &&
          !angular.isDefined(this.$messages[endIndex].loading)) {

        for (uids = []; startIndex < endIndex && startIndex < max; startIndex++) {
          if (angular.isDefined(this.$messages[startIndex].subject) || this.$messages[startIndex].loading) {
            // Message at this index is already loaded; increase the end index
            endIndex++;
          }
          else {
            // Message at this index will be loaded
            uids.push(this.$messages[startIndex].uid);
            //console.debug('loading ' + this.$messages[startIndex].uid);
            this.$messages[startIndex].loading = true;
          }
        }

        if (uids.length) {
          Mailbox.$log.debug('Loading UIDs ' + uids.join(' '));
          futureHeadersData = Mailbox.$$resource.post(this.id, 'headers', {uids: uids});
          this.$unwrapHeaders(futureHeadersData);
        }
      }
    }
    return loaded;
  };

  /**
   * @function isEditable
   * @memberof Mailbox.prototype
   * @desc Checks if the mailbox is editable based on its type.
   * @returns true if the mailbox is not a special folder.
   */
  Mailbox.prototype.isEditable = function() {
    return this.type == 'folder';
  };

  /**
   * @function isNoInferiors
   * @memberof Mailbox.prototype
   * @desc Checks if the mailbox can contain submailboxes
   * @returns true if the mailbox can not contain submailboxes
   */
  Mailbox.prototype.isNoInferiors = function() {
    return this.flags.indexOf('noinferiors') >= 0;
  };

  /**
   * @function isNoSelect
   * @memberof Mailbox.prototype
   * @desc Checks if the mailbox can be selected
   * @returns true if the mailbox can not be selected
   */
  Mailbox.prototype.isNoSelect = function() {
    return this.flags.indexOf('noselect') >= 0;
  };

  /**
   * @function isWritable
   * @memberof Mailbox.prototype
   * @desc Checks the user can write to the mailbox
   * @returns true if messages can be inserted
   */
  Mailbox.prototype.isWritable = function() {
    return this.flags.indexOf('noselect') < 0 || this.type == 'dropbox';
  };

  /**
   * @function getClassName
   * @memberof Mailbox.prototype
   * @desc Not used but defined because it is called from UIxAclEditor.wox.
   * @returns a string representing the foreground CSS class name
   */
  Mailbox.prototype.getClassName = function(base) {
    return false;
  };

  /**
   * @function $rename
   * @memberof AddressBook.prototype
   * @desc Rename the mailbox and keep the list sorted
   * @param {string} name - the new name
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$rename = function() {
    var _this = this,
        findParent,
        parent,
        children,
        i;

    if (this.name == this.$shadowData.name) {
      // Name hasn't changed
      return Mailbox.$q.when();
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
    if (parent === null)
      children = this.$account.$mailboxes;
    else
      children = parent.children;

    // Find index of mailbox among siblings
    i = _.indexOf(_.map(children, 'id'), this.id);

    return this.$save().then(function(data) {
      var sibling, oldPath = _this.path;
      _this.init(data); // update the path and id

      // Move mailbox among its siblings according to its new name
      children.splice(i, 1);
      sibling = _.find(children, function(o) {
        return (o.type == 'folder' && o.name.localeCompare(_this.name) > 0);
      });
      if (sibling) {
        i = _.indexOf(_.map(children, 'id'), sibling.id);
      }
      else {
        i = children.length;
      }
      children.splice(i, 0, _this);

      // Update the path and id of children
      var pathRE = new RegExp('^' + oldPath);
      var _updateChildren = function(mailbox) {
        _.forEach(mailbox.children, function(child) {
          child.path = child.path.replace(pathRE, _this.path);
          child.id = child.$id();
          _updateChildren(child);
        });
      };
      _updateChildren(_this);
    });
  };

  /**
   * @function $compact
   * @memberof Mailbox.prototype
   * @desc Compact the mailbox
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$compact = function() {
    var _this = this;
    return Mailbox.$$resource.post(this.id, 'expunge')
      .then(function(data) {
        // Update inbox quota
        if (data.quotas)
          _this.$account.updateQuota(data.quotas);
        return true;
      });
  };

  /**
   * @function $canFolderAs
   * @memberof Mailbox.prototype
   * @desc Check if the folder can be set as Drafts/Sent/Trash
   * @returns true if folder is eligible
   */
  Mailbox.prototype.$canFolderAs = function() {
    return this.type == 'folder';
  };

  /**
   * @function $setFolderAs
   * @memberof Mailbox.prototype
   * @desc Set a folder as Drafts/Sent/Trash
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$setFolderAs = function(type) {
    return Mailbox.$$resource.post(this.id, 'setAs' + type + 'Folder');
  };

  /**
   * @function $empty
   * @memberof Mailbox.prototype
   * @desc Empty the Trash folder.
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$empty = function() {
    var _this = this,
        action = 'empty' + this.type[0].capitalize() + this.type.substring(1);

    return Mailbox.$$resource.post(this.id, action).then(function(data) {
      // Remove all messages from the mailbox
      _this.$messages = _this.$visibleMessages = [];
      _this.uidsMap = {};
      _this.unseenCount = 0;

      // If we had any submailboxes, lets do a refresh of the mailboxes list
      if (angular.isDefined(_this.children) && _this.children.length)
        _this.$account.$getMailboxes({reload: true});

      // Update inbox quota
      if (data.quotas)
        _this.$account.updateQuota(data.quotas);
    });
  };

  /**
   * @function $markAsRead
   * @memberof Mailbox.prototype
   * @desc Mark all messages from folder as read
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$markAsRead = function() {
    var _this = this;

    return Mailbox.$$resource.post(this.id, 'markRead').then(function() {
      _this.unseenCount = 0;
      _.forEach(_this.$messages, function(message) {
        message.isread = true;
      });
    });
  };

  /**
   * @function getLabels
   * @memberof Mailbox.prototype
   * @desc Fetch the list of labels associated to the mailbox. Use the cached value if available.
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.getLabels = function(options) {
    var _this = this;

    if (this.$labels && !(options && options.reload))
      return Mailbox.$q.when(this.$labels);

    if (angular.isUndefined(this.$filteredLabels))
      this.$filteredLabels = {};
    return Mailbox.$$resource.fetch(this.id, 'labels').then(function(data) {
      _this.$labels = data;
      return _this.$labels;
    });
  };

  Mailbox.prototype.filteredByLabel = function() {
    return _.includes(this.$filteredLabels, 1);
  };

  /**
   * @function $flagMessages
   * @memberof Mailbox.prototype
   * @desc Add or remove a flag on a message set
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$flagMessages = function(messages, flags, operation) {
    var data = {msgUIDs: _.map(messages, 'uid'),
                flags: flags,
                operation: operation};

    return Mailbox.$$resource.post(this.id, 'addOrRemoveLabel', data).then(function() {
      return messages;
    });
  };

  /**
   * @function saveSelectedMessages
   * @memberof Mailbox.prototype
   * @desc Download the selected messages
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.saveSelectedMessages = function() {
    var data, options, selectedMessages, selectedUIDs;

    selectedMessages = _.filter(this.$messages, function(message) { return message.selected; });
    selectedUIDs = _.map(selectedMessages, 'uid');
    data = { uids: selectedUIDs };
    options = { filename: l('Saved Messages.zip') };

    return Mailbox.$$resource.download(this.id, 'saveMessages', {uids: selectedUIDs});
  };

  /**
   * @function exportFolder
   * @memberof Mailbox.prototype
   * @desc Export this mailbox
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.exportFolder = function() {
    var options;

    options = { filename: this.name + '.zip' };

    return Mailbox.$$resource.open(this.id, 'exportFolder', null, options);
  };

  /**
   * @function $delete
   * @memberof Mailbox.prototype
   * @desc Delete the mailbox from the server
   * @param {object} [options] - additional options (use {withoutTrash: true} to delete immediately)
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$delete = function(options) {
    var _this = this;

    return Mailbox.$$resource.post(this.id, 'delete', options)
      .then(function() {
        _this.$account.$getMailboxes({reload: true});
        return true;
      });
  };

  /**
   * @function $_deleteMessages
   * @memberof Mailbox.prototype
   * @desc Delete multiple messages from Mailbox object.
   * @param {string[]} uids - the messages uids
   * @return the index of the first deleted message
   */
  Mailbox.prototype.$_deleteMessages = function(uids) {
    var _this = this, firstIndex = this.$messages.length;

    // Remove messages from $messages and uidsMap
    _.forEachRight(this.$messages, function(message, index) {
      var selectedIndex = _.findIndex(uids, function(uid) {
        return message.uid == uid;
      });
      if (selectedIndex > -1) {
        uids.splice(selectedIndex, 1);
        delete _this.uidsMap[message.uid];
        if (message.uid == _this.$selectedMessage)
          delete _this.$selectedMessage;
        _this.$messages.splice(index, 1);
        if (index < firstIndex)
          firstIndex = index;
      }
      else {
        _this.uidsMap[message.uid] -= uids.length;
      }
    });

    if (this.threaded) {
      this.updateVisibleMessages();
    }

    // Return the index of the first deleted message
    return firstIndex;
  };

  /**
   * @function $deleteMessages
   * @memberof Mailbox.prototype
   * @desc Delete multiple messages from mailbox by batch of 1000 messages (see constant sgMailbox_BATCH_DELETE_LIMIT).
   * @param {object} [options] - additional options (use {withoutTrash: true} to delete immediately)
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$deleteMessages = function(messages, options) {
    var _this = this, uids,
        batchSize = Mailbox.BATCH_DELETE_LIMIT;

    uids = _.map(messages, 'uid');

    // Recursive function to synchronously delete batch of messages
    function _deleteMessages(start, end) {
      var currentUids = uids.slice(start, end),
          data = { uids: currentUids };
      if (options) angular.extend(data, options);
      return Mailbox.$$resource.post(_this.id, 'batchDelete', data).then(function(data) {
        if (data.unseenCount) {
          _this.unseenCount = data.unseenCount;
        }
        if (end < uids.length) {
          _this.$_deleteMessages(currentUids);
          return _deleteMessages(end, Math.min(end + batchSize, uids.length));
        }
        else {
          // Last API call; update inbox quota
          if (data.quotas)
            _this.$account.updateQuota(data.quotas);
          return _this.$_deleteMessages(currentUids);
        }
      });
    }

    return _deleteMessages(0, Math.min(batchSize, uids.length)).then(function(firstIndex) {
      _this.$selectedMessages = []; // reset selection
      return firstIndex;
    });
  };

  /**
   * @function $markOrUnMarkMessagesAsJunk
   * @memberof Mailbox.prototype
   * @desc Mark messages as junk/not junk
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$markOrUnMarkMessagesAsJunk = function(messages) {
    var _this = this,
        uids = _.map(messages, 'uid'),
        method = (this.type == 'junk' ? 'markMessagesAsNotJunk' : 'markMessagesAsJunk');

    return Mailbox.$$resource.post(this.id, method, {uids: uids});
  };

  /**
   * @function $copyMessages
   * @memberof Mailbox.prototype
   * @desc Copy multiple messages from the current mailbox to a target one
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$copyMessages = function(messages, folder) {
    var _this = this,
        uids = _.map(messages, 'uid');

    return Mailbox.$$resource.post(this.id, 'copyMessages', {uids: uids, folder: folder})
      .then(function(data) {
        // Update inbox quota
        if (data.quotas)
          _this.$account.updateQuota(data.quotas);
      });
  };

  /**
   * @function $moveMessages
   * @memberof Mailbox.prototype
   * @desc Move multiple messages from the current mailbox to a target one
   * @return a promise of the HTTP operation
   */
  Mailbox.prototype.$moveMessages = function(messages, folder) {
    var _this = this, uids;

    uids = _.map(messages, 'uid');
    return Mailbox.$$resource.post(this.id, 'moveMessages', {uids: uids, folder: folder})
      .then(function(data) {
        if (data.unseenCount) {
          _this.unseenCount = data.unseenCount;
        }
        _this.$selectedMessages = []; // reset selection
        return _this.$_deleteMessages(uids);
      });
  };

  /**
   * @function $move
   * @memberof Mailbox.prototype
   * @desc Move the mailbox to a different parent. Will reload the mailboxes list.
   * @returns a promise of the HTTP operation
   */
  Mailbox.prototype.$move = function(parentPath) {
    var _this = this;

    return Mailbox.$$resource.post(this.id, 'move', {parent: parentPath}).finally(function() {
      _this.$account.$getMailboxes({reload: true});
      return true;
    });
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
    }, function(response) {
      Mailbox.$log.error(JSON.stringify(response.data, undefined, 2));
      // Restore previous version
      _this.$reset();
      return response.data;
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
   * @function $reset
   * @memberof Mailbox.prototype
   * @desc Reset the original state the mailbox's data.
   */
  Mailbox.prototype.$reset = function(options) {
    var _this = this;
    angular.forEach(this.$shadowData, function(value, key) {
      delete _this[key];
    });
    angular.extend(this, this.$shadowData);
    this.$shadowData = this.$omit();
    if (options && options.filter) {
      this.$messages = [];
      this.$visibleMessages = [];
      delete this.$syncToken;
    }
  };

  /**
   * @function $omit
   * @memberof Mailbox.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Mailbox instance
   */
  Mailbox.prototype.$omit = function(deep) {
    var mailbox = {},
        _visit = function(children) {
          var childrenArray = [];
          _.forEach(children, function(o) {
            childrenArray.push(o.$omit(deep));
          });
          return childrenArray;
        };

    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          key != 'children' &&
          key != 'headers' &&
          key != 'uids' &&
          key != 'uidsMap' &&
          key[0] != '$') {
        mailbox[key] = value;
      }
    });
    if (deep && this.children) {
      mailbox.children = _visit(this.children);
    }
    return mailbox;
  };

  /**
   * @function updateVisibleMessages
   * @memberof Mailbox.prototype
   * @desc Update list of visible messages when in threaded mode.
   */
  Mailbox.prototype.updateVisibleMessages = function() {
    var collapsedThread = false;

    if (this.threaded) {
      this.$visibleMessages = _.filter(this.$messages, function(msg, i) {
        if (msg.first) {
          collapsedThread = msg.collapsed;
        } else if (msg.level < 0) {
          collapsedThread = false; // leaving the thread
        }
        return msg.first || collapsedThread === false;
      });
    }
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
      var selectedMessages = _.map(_this.$selectedMessages, 'uid');
      Mailbox.$timeout(function() {
        var uids, headers, headersFields, msgObject, hasNewMessages = false;

        if (!data.uids || _this.$topIndex > data.uids.length - 1)
          _this.$topIndex = 0;
        if (data.syncToken)
          _this.$syncToken = data.syncToken;

        if (data.deleted) {
          _.forEachRight(data.deleted, function(uid, i) {
            var j = _this.uidsMap[uid.toString()];
            if (j < 0 || !_this.$messages[j])
              // Unkown message
              data.deleted.splice(i, 1);
          });
          if (data.deleted.length)
            _this.$_deleteMessages(data.deleted);
        }
        if (data.changed) {
          var i = 0, j;
          _.forEach(data.changed, function(uid) {
            if (angular.isUndefined(_this.uidsMap[uid.toString()])) {
              // New messsage; update map of UID <=> index
              _this.uidsMap[uid] = i;
              _this.$messages.splice(i, 0, {uid: uid});
              hasNewMessages = true;
              i++;
            }
          });

          if (i > 0) {
            // New messages received, update uidsMap for existing messages
            for (j = i; j < _this.$messages.length; j++) {
              msgObject = _this.$messages[j];
              _this.uidsMap[msgObject.uid] += i;
            }
          }
        }
        if (angular.isDefined(data.unseenCount)) {
          _this.unseenCount = data.unseenCount;
        }

        if (data.uids) {
          // Initialization phase, we received complete list of UIDs
          Mailbox.$log.debug('unwrapping ' + data.uids.length + ' messages');

          _this.init(data);

          // First entry of 'uids' are keys when threaded view is enabled
          if (_this.threaded) {
            uids = _this.uids[0]; // uid, level, first
            _this.uids.splice(0, 1);
          }

          // Populate $messages with object literals
          _.reduce(_this.uids, function(msgs, msg, i) {
            var data;
            if (_this.threaded) {
              data = _.zipObject(uids, msg);
              if (data.first === 1) {
                var count = 1;
                while (_this.uids[i + count] &&
                       _this.uids[i + count][1] >= 0 &&
                       _this.uids[i + count][2] !== 1) {
                  count++;
                }
                data.count = count;
                data.collapsed = false;
                if (_this.$collapsedThreads.indexOf(data.uid.toString()) >= 0) {
                  data.collapsed = true;
                }
              }
              else if (!isNaN(data.level) && data.level >= 0) {
                data.threadMember = true;
              }

            } else {
              data = {uid: msg};
            }

            // Build map of UID <=> index
            _this.uidsMap[data.uid] = i;

            // Restore selection
            data.selected = selectedMessages.indexOf(data.uid) > -1;

            // Add an object literal to be used later to create a Message object
            msgs.push(data);

            return msgs;
          }, _this.$messages);
        }

        if (data.headers) {
          // First entry of 'headers' are keys
          headersFields = _.invokeMap(data.headers.splice(0, 1)[0], 'toLowerCase');
          headers = data.headers;

          // Instanciate or extend Message objects with received headers
          _.forEach(headers, function(data) {
            var msg = _.zipObject(headersFields, data),
                i = _this.uidsMap[msg.uid.toString()];
            if (!(_this.$messages[i] instanceof Mailbox.$Message)) {
              _this.$messages[i] = new Mailbox.$Message(_this.$account.id, _this, _this.$messages[i], true);
            }
            _this.$messages[i].init(msg);
          });
        }

        if (hasNewMessages && _this.threaded) {
          _this.updateVisibleMessages();
        }

        Mailbox.$log.debug('mailbox ' + _this.id + ' ready');
        _this.$isLoading = false;
        deferred.resolve(_this.$messages);
      });
    }, function(data) {
      Mailbox.$log.error(data);
      angular.extend(_this, data);
      _this.isError = true;
      _this.$isLoading = false;
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
          headers = _.invokeMap(data[0], 'toLowerCase');
          data.splice(0, 1);
          _.forEach(data, function(messageHeaders) {
            messageHeaders = _.zipObject(headers, messageHeaders);
            j = _this.uidsMap[messageHeaders.uid.toString()];
            if (angular.isDefined(j)) {
              if (!(_this.$messages[j] instanceof Mailbox.$Message)) {
                _this.$messages[j] = new Mailbox.$Message(_this.$account.id, _this, _this.$messages[j], true);
              }
              _this.$messages[j].init(messageHeaders);
            }
          });
          if (_this.threaded) {
            _this.updateVisibleMessages();
          }
        }
      });
    });
  };

  /**
   * @function $updateSubscribe
   * @memberof Mailbox.prototype
   * @desc Update mailbox subscription state with server.
   */
  Mailbox.prototype.$updateSubscribe = function() {
    var action = this.subscribed? 'subscribe' : 'unsubscribe';

    Mailbox.$$resource.post(this.id, action);
  };

})();
