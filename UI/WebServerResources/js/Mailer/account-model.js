/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Account
   * @constructor
   * @param {object} futureAccountData
   */
  function Account(futureAccountData) {
    // Data is immediately available
    if (typeof futureAccountData.then !== 'function') {
      angular.extend(this, futureAccountData);
      Account.$log.debug('Account:' + JSON.stringify(futureAccountData, undefined, 2));
    }
    else {
      // The promise will be unwrapped first
      //this.$unwrap(futureAccountData);
    }
  }

  /**
   * @memberof Account
   * @desc The factory we'll use to register with Angular
   * @returns the Account constructor
   */
  Account.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgResource', 'sgMailbox', function($q, $timeout, $log, Settings, Resource, Mailbox) {
    angular.extend(Account, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.baseURL, Settings.activeUser),
      $Mailbox: Mailbox
    });

    return Account; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.MailerUI')
    .factory('sgAccount', Account.$factory);

  /**
   * @memberof Account
   * @desc Set the list of accounts and instanciate a new Account object for each item.
   * @param {array} [data] - the metadata of the accounts
   * @returns the list of accounts
   */
  Account.$findAll = function(data) {
    var collection = [];
    if (data) {
      // Each entry is spun up as an Account instance
      angular.forEach(data, function(o, i) {
        o.id = i;
        collection[i] = new Account(o);
      });
    }
    return collection;
  };

  /**
   * @function $getMailboxes
   * @memberof Account.prototype
   * @desc Fetch the list of mailboxes for the current account.
   * @returns a promise of the HTTP operation
   */
  Account.prototype.$getMailboxes = function() {
    var _this = this;

    var mailboxes = Account.$Mailbox.$find(this).then(function(data) {
      _this.$mailboxes = data;
    });

    return mailboxes;
  };

})();
