/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$state', '$timeout', '$mdDialog', 'stateAccounts', 'stateAccount', 'stateMailbox', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($state, $timeout, $mdDialog, stateAccounts, stateAccount, stateMailbox, encodeUriFilter, focus, Dialog, Account, Mailbox) {
    var vm = this;

    Mailbox.selectedFolder = stateMailbox;

    vm.service = Mailbox;
    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.selectedFolder = stateMailbox;
    vm.selectMessage = selectMessage;
    vm.unselectMessages = unselectMessages;
    vm.confirmDeleteSelectedMessages = confirmDeleteSelectedMessages;
    vm.copySelectedMessages = copySelectedMessages;
    // vm.moveSelectedMessages = moveSelectedMessages;
    vm.selectAll = selectAll;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.mode = { search: false };

    function selectMessage(message) {
      $state.go('mail.account.mailbox.message', {accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path), messageId: message.uid});
    }

    function unselectMessages() {
      _.each(vm.selectedFolder.$messages, function(message) { message.selected = false; });
    }

    function confirmDeleteSelectedMessages() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected messages?'))
        .then(function() {
          // User confirmed the deletion
          var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
          var selectedUIDs = _.pluck(selectedMessages, 'uid');
          vm.selectedFolder.$deleteMessages(selectedUIDs).then(function() {
            vm.selectedFolder.$messages = _.difference(vm.selectedFolder.$messages, selectedMessages);
          });
        },  function(data, status) {
          // Delete failed
        });
    }

    function copySelectedMessages(folder) {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');
      vm.selectedFolder.$copyMessages(selectedUIDs, '/' + folder).then(function() {
        // TODO: refresh target mailbox?
      }, function(error) {
        Dialog.alert(l('Error'), error.error);
      });
    }

    // function moveSelectedMessages(folder) {
    //   var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected });
    //   var selectedUIDs = _.pluck(selectedMessages, 'uid');
    //   vm.selectedFolder.$moveMessages(selectedUIDs, '/' + folder).then(function() {
    //     // TODO: refresh target mailbox?
    //     vm.selectedFolder.$messages = _.difference(vm.selectedFolder.$messages, selectedMessages);
    //   });
    // }

    function selectAll() {
      _.each(vm.selectedFolder.$messages, function(message) {
        message.selected = true;
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
      $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: $event,
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: 'UIxMailEditor',
        controller: 'MessageEditorController',
        controllerAs: 'editor',
        locals: {
          stateAccounts: vm.accounts,
          stateMessage: vm.account.$newMessage()
        }
      });
    }
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxController', MailboxController);                                    
})();

