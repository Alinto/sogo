/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name VirtualMailbox
   * @constructor
   * @param {object} account - the mail account associated with the virtual search
   */
  function VirtualMailbox(account) {
    this.$account = account;
  }

  /**
   * @memberof VirtualMailbox
   * @desc The factory we'll use to register with Angular
   * @returns the VirtualMailbox constructor
   */
  VirtualMailbox.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Message', 'Mailbox', 'sgMailbox_PRELOAD', function($q, $timeout, $log, Settings, Resource, Mailbox, Message, PRELOAD) {
    angular.extend(VirtualMailbox, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Mail', Settings.activeUser()),
      $Message: Message,
      selectedFolder: null,
      PRELOAD: PRELOAD
    });

    return VirtualMailbox; // return constructor
  }];

  /**
   * @module SOGo.MailerUI
   * @desc Factory registration of VirtualMailbox in Angular module.
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
    .factory('VirtualMailbox', VirtualMailbox.$factory);

  /**
   * @memberof VirtualMailbox
   * @desc Build the path of the virtual mailbox (or account only).
   * @param {string} accountId - the account ID
   * @returns a string representing the path relative to the mail module
   */
  VirtualMailbox.$absolutePath = function(accountId) {
    return [accountId, "virtual"].join('/');
  };

  /**
   * @function init
   * @memberof VirtualMailbox.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of mailbox
   */
  VirtualMailbox.prototype.init = function(data) {
    this.$isLoading = false;
    this.$mailboxes = [];
    this.uidsMap = {};
    angular.extend(this, data);
    this.id = this.$id();
  };

  VirtualMailbox.prototype.setMailboxes = function(data) {
    this.$mailboxes = data;

    _.forEach(this.$mailboxes, function(mailbox) {
      mailbox.$messages = [];
      mailbox.uidsMap = {};
    });
  };

  VirtualMailbox.prototype.startSearch = function(match, params) {
    var _this = this,
        search = VirtualMailbox.$q.when();

    this.$isLoading = true;

    _.forEach(this.$mailboxes, function(mailbox) {
      search = search.then(function() {
        if (_this.$isLoading) {
          VirtualMailbox.$log.debug("searching mailbox " + mailbox.path);
          return mailbox.$filter( {sort: "date", asc: false, match: match}, params);
        }
      });
    });

    search.finally(function() {
      _this.$isLoading = false;
    });
  };

  VirtualMailbox.prototype.stopSearch = function() {
    VirtualMailbox.$log.debug("stopping search...");
    this.$isLoading = false;
  };

  /**
   * @function selectFolder
   * @memberof VirtualMailbox.prototype
   * @desc A no-op for virtual mailbox
   */
  VirtualMailbox.prototype.selectFolder = function() {
    return;
  };

  /**
   * @function resetSelectedMessage
   * @memberof VirtualMailbox.prototype
   * @desc Delete 'selectedMessage' attribute of all submailboxes.
   */
  VirtualMailbox.prototype.resetSelectedMessage = function() {
    _.forEach(this.$mailboxes, function(mailbox) {
      delete mailbox.$selectedMessage;
    });
  };

  /**
   * @function hasSelectedMessage
   * @memberof VirtualMailbox.prototype
   * @desc Check if a message is selected among the resulting mailboxes
   * @returns true if one message is selected
   */
  VirtualMailbox.prototype.hasSelectedMessage = function() {
    return angular.isDefined(_.find(this.$mailboxes, function(mailbox) {
      return angular.isDefined(mailbox.$selectedMessage);
    }));
  };

  /**
   * @function isSelectedMessage
   * @memberof VirtualMailbox.prototype
   * @desc Check if the message of the specified mailbox is selected.
   * @param {string} messageId
   * @param {string} mailboxPath
   * @returns true if the specified message is selected
   */
  VirtualMailbox.prototype.isSelectedMessage = function(messageId, mailboxPath) {
    return angular.isDefined(_.find(this.$mailboxes, function(mailbox) {
      return mailbox.path == mailboxPath && mailbox.$selectedMessage == messageId;
    }));
  };

  /**
   * @function getLength
   * @memberof VirtualMailbox.prototype
   * @desc Used by md-virtual-repeat / md-on-demand
   * @returns the number of items in the mailbox
   */
  VirtualMailbox.prototype.getLength = function() {
    var len = 0;

    if (!angular.isDefined(this.$mailboxes))
      return len;

    _.forEach(this.$mailboxes, function(mailbox) {
      len += mailbox.$messages.length;
    });

    return len;
  };

  /**
   * @function getItemAtIndex
   * @memberof VirtualMailbox.prototype
   * @desc Used by md-virtual-repeat / md-on-demand
   * @returns the message as the specified index
   */
  VirtualMailbox.prototype.getItemAtIndex = function(index) {
    var i, j, k, mailbox, message;

    if (angular.isDefined(this.$mailboxes) && index >= 0) {
      i = 0;
      for (j = 0; j < this.$mailboxes.length; j++) {
        mailbox = this.$mailboxes[j];
        for (k = 0; k < mailbox.$messages.length; i++, k++) {
          if (i == index) {
            message = mailbox.$messages[k];
            if (mailbox.$loadMessage(message.uid))
              return message;
          }
        }
      }
    }

    return null;
  };

  /**
   * @function $id
   * @memberof VirtualMailbox.prototype
   * @desc Build the unique ID to identified the mailbox.
   * @returns a string representing the path relative to the mail module
   */
  VirtualMailbox.prototype.$id = function() {
    return VirtualMailbox.$absolutePath(this.$account.id);
  };

  /**
   * @function $selectedMessageIndex
   * @memberof Mailbox.prototype
   * @desc Return the index of the currently visible message.
   * @returns a number or undefined if no message is selected
   */
  VirtualMailbox.prototype.$selectedMessageIndex = function() {
    var offset = 0;
    var selectedMailbox = _.find(this.$mailboxes, function(mailbox) {
      if (angular.isDefined(mailbox.$selectedMessage)) {
        return true;
      }
      else {
        offset += mailbox.getLength();
        return false;
      }
    });
    return offset + selectedMailbox.uidsMap[selectedMailbox.$selectedMessage];
  };

  /**
   * @function $selectedMessages
   * @memberof VirtualMailbox.prototype
   * @desc Return an associative array of the selected messages for each mailbox. Keys are the mailboxes ids.
   * @returns an associative array
   */
  VirtualMailbox.prototype.selectedMessages = function(options) {
    var messagesMap = {};
    return _.filter(_.transform(this.$mailboxes, function(messagesMap, mailbox) {
      if (options && options.updateCache)
        mailbox.$selectedMessages = _.filter(mailbox.$messages, function (message) { return message.selected; });
      messagesMap[mailbox.id] = mailbox.$selectedMessages;
    }, {}), function(o) {
      return _.size(o) > 0;
    });
  };

  /**
   * @function selectedCount
   * @memberof VirtualMailbox.prototype
   * @desc Return the number of messages selected by the user.
   * @returns the number of selected messages
   */
  VirtualMailbox.prototype.selectedCount = function() {
    return _.sum(_.invokeMap(this.$mailboxes, 'selectedCount'));
  };

  /**
   * @function $flagMessages
   * @memberof VirtualMailbox.prototype
   * @desc Add or remove a flag on a message set
   * @param {object} messagesMap
   * @param {array} flags
   * @param {string} operation
   * @returns a promise of the HTTP operation
   */
  VirtualMailbox.prototype.$flagMessages = function(messagesMap, flags, operation) {
    var data = {
      flags: flags,
      operation: operation
    };
    var allMessages = [];
    var promises = [];

    _.forEach(messagesMap, function(messages, id) {
      if (messages.length > 0) {
        var uids = _.map(messages, 'uid');
        allMessages.push(messages);
        var promise = VirtualMailbox.$$resource.post(id, 'addOrRemoveLabel', _.assign(data, {msgUIDs: uids}));
        promises.push(promise);
      }
    });

    return VirtualMailbox.$q.all(promises).then(function() {
      return _.flatten(allMessages);
    });
  };

  /**
   * @function $deleteMessages
   * @memberof VirtualMailbox.prototype
   * @desc Delete one or multiple messages from mailbox.
   * @param {object} messagesMap
   * @return a promise of the HTTP operation
   */
  VirtualMailbox.prototype.$deleteMessages = function(messagesMap) {
    var _this = this, promises = [];

    if (_.isArray(messagesMap) && messagesMap.length === 1 
      && messagesMap[0] && messagesMap[0].mailbox && !_.isArray(messagesMap[0].mailbox)) {
      // Deleting one message
      var message = messagesMap[0];
      var mailbox = message.$mailbox;
      return mailbox.$deleteMessages([message]).then(function(index) {
        var offset = 0;
        _.find(_this.$mailboxes, function(currentMailbox) {
          if (currentMailbox.id === mailbox.id) {
            return true;
          }
          else {
            offset += currentMailbox.getLength();
            return false;
          }
        });
        return offset + index;
      });
    }
    else {
      // Deleting multiple messages from different mailboxes
      _.forEach(messagesMap, function(messages, id) {
        if (messages.length > 0) {
          var mailbox = messages[0].$mailbox;
          var promise = mailbox.$deleteMessages(messages);
          promises.push(promise);
        }
      });

      return VirtualMailbox.$q.all(promises);
    }
  };

  /**
   * @function $markOrUnMarkMessagesAsJunk
   * @memberof VirtualMailbox.prototype
   * @desc Mark messages as junk/not junk
   * @param {object} messagesMap
   * @return a promise of the HTTP operation
   */
  VirtualMailbox.prototype.$markOrUnMarkMessagesAsJunk = function(messagesMap) {
    var promises = [];

    _.forEach(messagesMap, function(messages, id) {
      if (messages.length > 0) {
        var mailbox = messages[0].$mailbox;
        var promise = mailbox.$markOrUnMarkMessagesAsJunk(messages);
        promises.push(promise);
      }
    });

    return VirtualMailbox.$q.all(promises);
  };

  /**
   * @function $copyMessages
   * @memberof VirtualMailbox.prototype
   * @desc Copy multiple messages from the current mailbox to a target one
   * @param {object} messagesMap
   * @param {string} folder
   * @return a promise of the HTTP operation
   */
  VirtualMailbox.prototype.$copyMessages = function(messagesMap, folder) {
    var promises = [];

    _.forEach(messagesMap, function(messages, id) {
      if (messages.length > 0) {
        var mailbox = messages[0].$mailbox;
        var promise = mailbox.$copyMessages(messages, folder);
        promises.push(promise);
      }
    });

    return VirtualMailbox.$q.all(promises);
  };

  /**
   * @function $moveMessages
   * @memberof VirtualMailbox.prototype
   * @desc Move multiple messages from the current mailbox to a target one
   * @param {object} messagesMap
   * @param {string} folder
   * @return a promise of the HTTP operation
   */
  VirtualMailbox.prototype.$moveMessages = function(messagesMap, folder) {
    var promises = [];

    _.forEach(messagesMap, function(messages, id) {
      if (messages.length > 0) {
        var mailbox = messages[0].$mailbox;
        var promise = mailbox.$moveMessages(messages, folder);
        promises.push(promise);
      }
    });

    return VirtualMailbox.$q.all(promises);
  };

  /**
   * @function $compact
   * @memberof VirtualMailbox.prototype
   * @desc Called when leaving the Mailer module. No-op when in advanced search.
   */
  VirtualMailbox.prototype.$comact = function() {
    return true;
  };

  /**
   * @function $reset
   * @memberof VirtualMailbox.prototype
   * @desc Reset the original state all mailboxes data.
   */
  VirtualMailbox.prototype.$reset = function(options) {
    _.forEach(this.$mailboxes, function(mailbox) {
      mailbox.$reset(options);
    });
  };

})();
