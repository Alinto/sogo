/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$window', '$state', '$timeout', '$mdDialog', 'stateAccounts', 'stateAccount', 'stateMailbox', 'encodeUriFilter', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($window, $state, $timeout, $mdDialog, stateAccounts, stateAccount, stateMailbox, encodeUriFilter, Dialog, Account, Mailbox) {
    var vm = this, messageDialog = null;

    // Expose controller
    $window.$mailboxController = vm;

    Mailbox.selectedFolder = stateMailbox;

    vm.service = Mailbox;
    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.selectedFolder = stateMailbox;
    vm.selectMessage = selectMessage;
    vm.toggleMessageSelection = toggleMessageSelection;
    vm.unselectMessages = unselectMessages;
    vm.confirmDeleteSelectedMessages = confirmDeleteSelectedMessages;
    vm.copySelectedMessages = copySelectedMessages;
    // vm.moveSelectedMessages = moveSelectedMessages;
    vm.saveSelectedMessages = saveSelectedMessages;
    vm.markSelectedMessagesAsFlagged = markSelectedMessagesAsFlagged;
    vm.markSelectedMessagesAsUnread = markSelectedMessagesAsUnread;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.mode = { search: false };

    function selectMessage(message) {
      if (Mailbox.$virtualMode)
        $state.go('mail.account.virtualMailbox.message', {accountId: stateAccount.id, mailboxId: encodeUriFilter(message.$mailbox.path), messageId: message.uid});
      else
        $state.go('mail.account.mailbox.message', {accountId: stateAccount.id, mailboxId: encodeUriFilter(message.$mailbox.path), messageId: message.uid});
    }

    function toggleMessageSelection($event, message) {
      message.selected = !message.selected;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function unselectMessages() {
      _.each(vm.selectedFolder.$messages, function(message) { message.selected = false; });
    }

    function confirmDeleteSelectedMessages() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected messages?'))
        .then(function() {
          // User confirmed the deletion
          var unselectMessage = false;
          var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) {
            if (message.uid == vm.selectedFolder.selectedMessage)
              unselectMessage = true;
            return message.selected;
          });
          vm.selectedFolder.$deleteMessages(selectedMessages).then(function() {
            if (unselectMessage) {
              if (Mailbox.$virtualMode)
                $state.go('mail.account.virtualMailbox',
                          {
                            accountId: stateAccount.id,
                            mailboxId: encodeUriFilter(vm.selectedFolder.path)
                          });
              else
                $state.go('mail.account.mailbox',
                          {
                            accountId: stateAccount.id,
                            mailboxId: encodeUriFilter(vm.selectedFolder.path)
                          });
            }
          });
        });
    }

    function copySelectedMessages(folder) {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');
      vm.selectedFolder.$copyMessages(selectedUIDs, '/' + folder);
    }

    // function moveSelectedMessages(folder) {
    //   var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected });
    //   var selectedUIDs = _.pluck(selectedMessages, 'uid');
    //   vm.selectedFolder.$moveMessages(selectedUIDs, '/' + folder).then(function() {
    //     // TODO: refresh target mailbox?
    //     vm.selectedFolder.$messages = _.difference(vm.selectedFolder.$messages, selectedMessages);
    //   });
    // }

    function saveSelectedMessages() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');
      window.location.href = ApplicationBaseURL + '/' + vm.selectedFolder.id + '/saveMessages?uid=' + selectedUIDs.join(",");
    }

    function selectAll() {
      var i = 0, length = vm.selectedFolder.$messages.length;
      for (; i < length; i++)
        vm.selectedFolder.$messages[i].selected = true;
    }

    function markSelectedMessagesAsFlagged() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');

      vm.selectedFolder.$flagMessages(selectedUIDs, '\\Flagged', 'add').then(function(d) {
        // Success
        _.forEach(selectedMessages, function(message) {
          message.isflagged = true;
        });
      });
    }

    function markSelectedMessagesAsUnread() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');

      vm.selectedFolder.$flagMessages(selectedUIDs, 'seen', 'remove').then(function(d) {
        // Success
        _.forEach(selectedMessages, function(message) {
          message.isread = false;
          vm.selectedFolder.unseenCount++;
        });
      });
    }

    function sort(field) {
      vm.selectedFolder.$filter({ sort: field });
    }

    function sortedBy(field) {
      return Mailbox.$query.sort == field;
    }

    function cancelSearch() {
      vm.mode.search = false;
      vm.selectedFolder.$filter();
    }

    function newMessage($event) {
      var message;

      if (messageDialog === null) {
        message = vm.account.$newMessage();
        messageDialog = $mdDialog
          .show({
            parent: angular.element(document.body),
            targetEvent: $event,
            clickOutsideToClose: false,
            escapeToClose: false,
            templateUrl: 'UIxMailEditor',
            controller: 'MessageEditorController',
            controllerAs: 'editor',
            locals: {
              stateAccounts: vm.accounts,
              stateMessage: message,
              stateRecipients: []
            }
          })
          .finally(function() {
            messageDialog = null;
          });
      }
    }
  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxController', MailboxController);
})();

