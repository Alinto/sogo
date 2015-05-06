/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$scope', '$rootScope', '$stateParams', 'stateAccount', 'stateMailbox', '$timeout', 'sgFocus', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($scope, $rootScope, $stateParams, stateAccount, stateMailbox, $timeout, focus, Dialog, Account, Mailbox) {
    $scope.account = stateAccount;
    $rootScope.mailbox = stateMailbox;
    $rootScope.currentFolder = stateMailbox;
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxController', MailboxController);                                    
})();

