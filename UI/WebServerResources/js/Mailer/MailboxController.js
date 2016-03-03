/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$window', '$timeout', '$state', '$mdDialog', 'stateAccounts', 'stateAccount', 'stateMailbox', 'encodeUriFilter', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($window, $timeout, $state, $mdDialog, stateAccounts, stateAccount, stateMailbox, encodeUriFilter, Dialog, Account, Mailbox) {
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
    vm.markOrUnMarkMessagesAsJunk = markOrUnMarkMessagesAsJunk;
    vm.copySelectedMessages = copySelectedMessages;
    vm.moveSelectedMessages = moveSelectedMessages;
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
        $state.go('mail.account.mailbox.message', {messageId: message.uid});
    }

    function toggleMessageSelection($event, message) {
      message.selected = !message.selected;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function unselectMessages() {
      _.forEach(vm.selectedFolder.$messages, function(message) { message.selected = false; });
    }

    function confirmDeleteSelectedMessages() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected messages?'),
                     { ok: l('Delete') })
        .then(function() {
          var deleteSelectedMessage = false;
          var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) {
            if (message.selected &&
                message.uid == vm.selectedFolder.selectedMessage)
              deleteSelectedMessage = true;
            return message.selected;
          });
          vm.selectedFolder.$deleteMessages(selectedMessages).then(function(index) {
            unselectMessage(deleteSelectedMessage, index);
          });
        });
    }

    function markOrUnMarkMessagesAsJunk() {
      var moveSelectedMessage = false;
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) {
        if (message.selected &&
            message.uid == vm.selectedFolder.selectedMessage)
          moveSelectedMessage = true;
        return message.selected;
      });

      vm.selectedFolder.$markOrUnMarkMessagesAsJunk(selectedMessages).then(function() {
        var folder = '/' + vm.account.id + '/folderINBOX';

        if (vm.selectedFolder.type != 'junk') {
          folder = '/' + vm.account.$getMailboxByType('junk').id;
        }

        vm.selectedFolder.$moveMessages(selectedMessages, folder).then(function(index) {
          unselectMessage(moveSelectedMessage, index);
        });
      });
    }

    function unselectMessage(message, index) {
      // Unselect current message and cleverly load the next message
      var nextMessage, previousMessage, nextIndex = index;
      if (message) {
        if (Mailbox.$virtualMode) {
          $state.go('mail.account.virtualMailbox');
        }
        else {
          // Select either the next or previous message
          if (index > 0) {
            nextIndex -= 1;
            nextMessage = vm.selectedFolder.$messages[nextIndex];
          }
          if (index < vm.selectedFolder.$messages.length)
            previousMessage = vm.selectedFolder.$messages[index];
          if (nextMessage) {
            if (nextMessage.isread && previousMessage && !previousMessage.isread) {
              nextIndex = index;
              nextMessage = previousMessage;
            }
          }
          else if (previousMessage) {
            nextIndex = index;
            nextMessage = previousMessage;
          }
          if (nextMessage) {
            $state.go('mail.account.mailbox.message', { messageId: nextMessage.uid });
            vm.selectedFolder.$topIndex = nextIndex;
          }
          else {
            $state.go('mail.account.mailbox');
          }
        }
      }
    }

    function copySelectedMessages(folder) {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.map(selectedMessages, 'uid');
      vm.selectedFolder.$copyMessages(selectedUIDs, '/' + folder);
    }

    function moveSelectedMessages(folder) {
      var moveSelectedMessage = false;
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) {
        if (message.selected &&
            message.uid == vm.selectedFolder.selectedMessage)
          moveSelectedMessage = true;
        return message.selected;
      });
      vm.selectedFolder.$moveMessages(selectedMessages, '/' + folder).then(function(index) {
        unselectMessage(moveSelectedMessage, index);
      });
    }

    function saveSelectedMessages() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.map(selectedMessages, 'uid');
      window.location.href = ApplicationBaseURL + '/' + vm.selectedFolder.id + '/saveMessages?uid=' + selectedUIDs.join(",");
    }

    function selectAll() {
      var i = 0, length = vm.selectedFolder.$messages.length;
      for (; i < length; i++)
        vm.selectedFolder.$messages[i].selected = true;
    }

    function markSelectedMessagesAsFlagged() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.map(selectedMessages, 'uid');

      vm.selectedFolder.$flagMessages(selectedUIDs, '\\Flagged', 'add').then(function(d) {
        // Success
        _.forEach(selectedMessages, function(message) {
          message.isflagged = true;
        });
      });
    }

    function markSelectedMessagesAsUnread() {
      var selectedMessages = _.filter(vm.selectedFolder.$messages, function(message) { return message.selected; });
      var selectedUIDs = _.map(selectedMessages, 'uid');

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
      vm.selectedFolder.$filter().then(function() {
        if (vm.selectedFolder.selectedMessage) {
          $timeout(function() {
            vm.selectedFolder.$topIndex = vm.selectedFolder.uidsMap[vm.selectedFolder.selectedMessage];
          });
        }
      });
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
    .module('material.components.virtualRepeat')
    .decorator('mdVirtualRepeatContainerDirective', mdVirtualRepeatContainerDirectiveDecorator);

  /**
   * @ngInject
   */
  mdVirtualRepeatContainerDirectiveDecorator.$inject = ['$delegate'];
  function mdVirtualRepeatContainerDirectiveDecorator($delegate) {
    $delegate[0].controller.prototype.resetScroll = function() {
      // Don't scroll to top if current virtual repeater is the messages list
      // but do update the container size
      if (this.$element.parent().attr('id') == 'messagesList')
        this.updateSize();
      else
        this.scrollTo(0);
    };
    return $delegate;
  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxController', MailboxController);
})();

