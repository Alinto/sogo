/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', 'stateAccount', 'stateMailbox', 'stateMessage', '$timeout', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox'];
  function MessageController($scope, $rootScope, $stateParams, $state, stateAccount, stateMailbox, stateMessage, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox) {
    $rootScope.message = stateMessage;
    $scope.tags = {};
    $scope.addOrRemoveTag = function(operation, tag) {
      if (tag) {
        stateMessage.$addOrRemoveTag(operation, tag);
      }
    };
    $scope.markAsFlaggedOrUnflagged = function() {
      var operation = (stateMessage.isflagged ? 'remove' : 'add');
      stateMessage.$markAsFlaggedOrUnflagged(operation).then(function() {
        stateMessage.isflagged = !stateMessage.isflagged;
      });
    };
    $scope.doDelete = function() {
      stateMailbox.$deleteMessages([stateMessage.uid]).then(function() {
        // Remove card from list of addressbook
        stateMailbox.$messages = _.reject(stateMailbox.$messages, function(o) {
          return o.uid == stateMessage.uid;
        });
        // Remove card object from scope
        $rootScope.message = null;
        $state.go('mail.account.mailbox', { accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path) });
      });
    };
  }
  
  angular
    .module('SOGo.MailerUI')  
    .controller('MessageController', MessageController);                                    
})();
