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
  function Message(accountId, mailboxPath, futureMessageData) {
    this.accountId = accountId;
    this.mailboxPath = mailboxPath;
    // Data is immediately available
    if (typeof futureMessageData.then !== 'function') {
      //console.debug(JSON.stringify(futureMessageData, undefined, 2));
      angular.extend(this, futureMessageData);
      this.id = this.$absolutePath();
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
  Message.$factory = ['$q', '$timeout', '$log', '$sce', 'sgSettings', 'sgResource', function($q, $timeout, $log, $sce, Settings, Resource) {
    angular.extend(Message, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $sce: $sce,
      $$resource: new Resource(Settings.baseURL, Settings.activeUser)
    });

    return Message; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.MailerUI')
    .factory('sgMessage', Message.$factory);

  /**
   * @function $absolutePath
   * @memberof Message.prototype
   * @desc Build the path of the message
   * @returns a string representing the path relative to the mail module
   */
  Message.prototype.$absolutePath = function() {
    var path;

    path = _.map(this.mailboxPath.split('/'), function(component) {
      return 'folder' + component.asCSSIdentifier();
    });
    path.splice(0, 0, this.accountId); // insert account ID
    path.push(this.uid); // add message UID

    return path.join('/');
  };

  /**
   * @function $content
   * @memberof Message.prototype
   * @desc Fetch the message body along with other metadata such as the list of attachments.
   * @returns the HTML representation of the body or a promise of the HTTP operation
   */
  Message.prototype.$content = function() {
    var futureMessageData;

    if (this.$futureMessageData) {
      return Message.$sce.trustAs('html', this.content);
    }

    futureMessageData = Message.$$resource.fetch(this.id, 'view');

    return this.$unwrap(futureMessageData);
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
        // Build long representation of email addresses
        _.each(['from', 'to', 'cc', 'bcc', 'replyTo'], function(type) {
          _.each(_this[type + 'Addresses'], function(data, i) {
            if (data.name != data.address)
              data.full = data.name + ' <' + data.address + '>';
            else
              data.full = '<' + data.address + '>';
          });
        });
        deferred.resolve(_this.content);
      });
    }, function(data) {
      angular.extend(_this, data);
      _this.isError = true;
      Message.$log.error(_this.error);
      deferred.reject();
    });

    return deferred.promise;
  };

})();
