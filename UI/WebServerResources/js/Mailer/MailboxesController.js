/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Account', 'Mailbox', 'stateAccounts'];
  function MailboxesController($scope, $rootScope, $stateParams, $state, $timeout, focus, encodeUriFilter, Dialog, Settings, Account, Mailbox, stateAccounts) {
    $scope.activeUser = Settings.activeUser;
    $scope.accounts = stateAccounts;

    $scope.newFolder = function(parentFolder) {
      Dialog.prompt(l('New folder'),
                    l('Enter the new name of your folder :'))
        .then(function(name) {
          parentFolder.$newMailbox(parentFolder.id, name);
        });
    };
    $scope.editFolder = function(folder) {
      $scope.editMode = folder.path;
      focus('mailboxName_' + folder.path);
    };
    $scope.revertEditing = function(folder) {
      folder.$reset();
      $scope.editMode = false;
    };
    $scope.selectFolder = function(account, folder) {
      if ($scope.editMode == folder.path)
        return;
      $rootScope.currentFolder = folder;
      $scope.editMode = false;
      $rootScope.message = null;
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
    };
    $scope.saveFolder = function(folder) {
      folder.$rename();
    };
    $scope.exportMails = function() {
      window.location.href = ApplicationBaseURL + '/' + $rootScope.currentFolder.id + '/exportFolder';
    };
    $scope.confirmDelete = function(folder) {
      if (folder.path != $scope.currentFolder.path) {
        // Counter the possibility to click on the "hidden" secondary button
        $scope.selectFolder(folder.$account, folder);
        return;
      }
      Dialog.confirm(l('Confirmation'), l('Do you really want to move this folder into the trash ?'))
        .then(function() {
          folder.$delete()
            .then(function() {
              $rootScope.currentFolder = null;
              $state.go('mail');
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', folder.name),
                           l(data.error));
            });
        });
    };

    $scope.unselectMessages = function() {
      _.each($rootScope.mailbox.$messages, function(message) { message.selected = false; });
    };

    $scope.confirmDeleteSelectedMessages = function() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected messages?'))
        .then(function() {
          // User confirmed the deletion
          var selectedMessages = _.filter($rootScope.mailbox.$messages, function(message) { return message.selected });
          var selectedUIDs = _.pluck(selectedMessages, 'uid');
          $rootScope.mailbox.$deleteMessages(selectedUIDs).then(function() {
            $rootScope.mailbox.$messages = _.difference($rootScope.mailbox.$messages, selectedMessages);
          });
        },  function(data, status) {
          // Delete failed
        });
    };
    if ($state.current.name == 'mail' && $scope.accounts.length > 0 && $scope.accounts[0].$mailboxes.length > 0) {
      // Redirect to first mailbox of first account if no mailbox is selected
      var account = $scope.accounts[0];
      var mailbox = account.$mailboxes[0];
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
    }
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxesController', MailboxesController);                                    
})();

