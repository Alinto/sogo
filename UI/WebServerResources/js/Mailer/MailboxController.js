/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$scope', '$rootScope', '$state', '$stateParams', 'stateAccount', 'stateMailbox', '$timeout', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($scope, $rootScope, $state, $stateParams, stateAccount, stateMailbox, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox) {
    $scope.account = stateAccount;
    $rootScope.mailbox = stateMailbox;
    $rootScope.currentFolder = stateMailbox;
    
    $scope.selectMessage = function(message) {
      $state.go('mail.account.mailbox.message', {accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path), messageId: message.uid});
    };

  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxController', MailboxController);                                    
})();

