/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$window', '$scope', '$timeout', '$q', '$state', '$mdDialog', '$mdToast', 'stateAccounts', 'stateAccount', 'stateMailbox', 'sgHotkeys', 'encodeUriFilter', 'sgSettings', 'sgFocus', 'Dialog', 'Account', 'Mailbox'];
  function MailboxController($window, $scope, $timeout, $q, $state, $mdDialog, $mdToast, stateAccounts, stateAccount, stateMailbox, sgHotkeys, encodeUriFilter, sgSettings, focus, Dialog, Account, Mailbox) {
    var vm = this,
        defaultWindowTitle = angular.element($window.document).find('title').attr('sg-default') || "SOGo",
        hotkeys = [];

    // Expose controller for eventual popup windows
    $window.$mailboxController = vm;

    vm.service = Mailbox;
    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.selectedFolder = stateMailbox;
    vm.selectMessage = selectMessage;
    vm.messageDialog = null; // also access from Message controller
    vm.toggleMessageSelection = toggleMessageSelection;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.searchMode = searchMode;
    vm.cancelSearch = cancelSearch;
    vm.newMessage = newMessage;
    vm.mode = { search: false, multiple: 0 };
    vm.confirmDeleteSelectedMessages = confirmDeleteSelectedMessages;
    vm.markOrUnMarkMessagesAsJunk = markOrUnMarkMessagesAsJunk;
    vm.copySelectedMessages = copySelectedMessages;
    vm.moveSelectedMessages = moveSelectedMessages;
    vm.markSelectedMessagesAsFlagged = markSelectedMessagesAsFlagged;
    vm.markSelectedMessagesAsUnread = markSelectedMessagesAsUnread;
    vm.markSelectedMessagesAsRead = markSelectedMessagesAsRead;
    vm.selectAll = selectAll;
    vm.unselectMessages = unselectMessages;


    stateMailbox.selectFolder();

    _registerHotkeys(hotkeys);

    // Expunge mailbox when leaving the Mail module
    angular.element($window).on('beforeunload', _compactBeforeUnload);
    $scope.$on('$destroy', function() {
      angular.element($window).off('beforeunload', _compactBeforeUnload);
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });

    // Update window's title with unseen messages count of selected mailbox
    $scope.$watch(function() { return vm.selectedFolder.unseenCount; }, function(unseenCount) {
      var title = defaultWindowTitle + ' - ';
      if (unseenCount)
        title += '(' + unseenCount + ') ';
      title += vm.selectedFolder.$displayName;
      $window.document.title = title;
    });


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_search'),
        description: l('Search'),
        callback: searchMode
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_compose'),
        description: l('Write a new message'),
        callback: function($event) {
          if (vm.messageDialog === null)
            newMessage($event);
        }
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_junk'),
        description: l('Mark the selected messages as junk'),
        callback: markOrUnMarkMessagesAsJunk
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'space',
        description: l('Toggle item'),
        callback: toggleMessageSelection
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+space',
        description: l('Toggle range of items'),
        callback: toggleMessageSelection
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'up',
        description: l('View next item'),
        callback: _nextMessage,
        preventInClass: ['sg-mail-part']
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'down',
        description: l('View previous item'),
        callback: _previousMessage,
        preventInClass: ['sg-mail-part']
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+up',
        description: l('Add next item to selection'),
        callback: _addNextMessageToSelection,
        preventInClass: ['sg-mail-part']
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+down',
        description: l('Add previous item to selection'),
        callback: _addPreviousMessageToSelection,
        preventInClass: ['sg-mail-part']
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'backspace',
        description: l('Delete selected message or folder'),
        callback: confirmDeleteSelectedMessages
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function _compactBeforeUnload(event) {
      return vm.selectedFolder.$compact();
    }

    function sort(field) {
      vm.selectedFolder.$filter({ sort: field });
    }

    function sortedBy(field) {
      return Mailbox.$query.sort == field;
    }

    function searchMode() {
      vm.mode.search = true;
      focus('search');
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

    function newMessage($event, inPopup) {
      var message;

      if (vm.messageDialog === null) {
        if (inPopup)
          _newMessageInPopup();
        else {
          message = vm.account.$newMessage();
          vm.messageDialog = $mdDialog
            .show({
              parent: angular.element(document.body),
              targetEvent: $event,
              clickOutsideToClose: false,
              escapeToClose: false,
              templateUrl: 'UIxMailEditor',
              controller: 'MessageEditorController',
              controllerAs: 'editor',
              locals: {
                stateAccount: vm.account,
                stateMessage: message
              }
            })
            .finally(function() {
              vm.messageDialog = null;
            });
        }
      }
    }

    function _newMessageInPopup() {
      var url = [sgSettings.baseURL(),
                 'UIxMailPopupView#!/Mail',
                 vm.account.id,
                 // The double-encoding is necessary
                 encodeUriFilter(encodeUriFilter(vm.selectedFolder.path)),
                 'new']
          .join('/'),
          wId = vm.selectedFolder.$id() + '/' + Math.random(0, 1000);
      console.debug(url);
      $window.open(url, wId,
                   ["width=680",
                    "height=520",
                    "resizable=1",
                    "scrollbars=1",
                    "toolbar=0",
                    "location=0",
                    "directories=0",
                    "status=0",
                    "menubar=0",
                    "copyhistory=0"]
                   .join(','));
    }

    /**
     * User has pressed up arrow key
     */
    function _nextMessage($event) {
      var index = vm.selectedFolder.$selectedMessageIndex();

      if (angular.isDefined(index)) {
        index--;
        if (vm.selectedFolder.$topIndex > 0)
          vm.selectedFolder.$topIndex--;
      }
      else {
        // No message is selected, show oldest message
        index = vm.selectedFolder.getLength() - 1;
        vm.selectedFolder.$topIndex = vm.selectedFolder.getLength();
      }

      if (index > -1)
        selectMessage(vm.selectedFolder.$messages[index]);

      $event.preventDefault();

      return index;
    }

    /**
     * User has pressed the down arrow key
     */
    function _previousMessage($event) {
      var index = vm.selectedFolder.$selectedMessageIndex();

      if (angular.isDefined(index)) {
        index++;
        if (vm.selectedFolder.$topIndex < vm.selectedFolder.getLength())
          vm.selectedFolder.$topIndex++;
      }
      else
        // No message is selected, show newest
        index = 0;

      if (index < vm.selectedFolder.getLength())
        selectMessage(vm.selectedFolder.$messages[index]);
      else
        index = -1;

      $event.preventDefault();

      return index;
    }

    function _addNextMessageToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedMessage()) {
        index = _nextMessage($event);
        if (index >= 0)
          toggleMessageSelection($event, vm.selectedFolder.$messages[index]);
      }
    }

    function _addPreviousMessageToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedMessage()) {
        index = _previousMessage($event);
        if (index >= 0)
          toggleMessageSelection($event, vm.selectedFolder.$messages[index]);
      }
    }

    function selectMessage(message) {
      if (Mailbox.$virtualMode)
        $state.go('mail.account.virtualMailbox.message', {mailboxId: encodeUriFilter(message.$mailbox.path), messageId: message.uid});
      else
        $state.go('mail.account.mailbox.message', {messageId: message.uid});
    }

    function toggleMessageSelection($event, message) {
      var folder = vm.selectedFolder,
          selectedIndex, nextSelectedIndex, i;

      if (!message)
        message = folder.$selectedMessage();
      message.selected = !message.selected;
      vm.mode.multiple += message.selected? 1 : -1;

      // Select closest range of messages when shift key is pressed
      if ($event.shiftKey && folder.$selectedCount() > 1) {
        selectedIndex = folder.uidsMap[message.uid];
        // Search for next selected message above
        nextSelectedIndex = selectedIndex - 2;
        while (nextSelectedIndex >= 0 &&
               !folder.$messages[nextSelectedIndex].selected)
          nextSelectedIndex--;
        if (nextSelectedIndex < 0) {
          // Search for next selected message bellow
          nextSelectedIndex = selectedIndex + 2;
          while (nextSelectedIndex < folder.getLength() &&
                 !folder.$messages[nextSelectedIndex].selected)
            nextSelectedIndex++;
        }
        if (nextSelectedIndex >= 0 && nextSelectedIndex < folder.getLength()) {
          for (i = Math.min(selectedIndex, nextSelectedIndex);
               i <= Math.max(selectedIndex, nextSelectedIndex);
               i++)
            folder.$messages[i].selected = true;
        }
      }

      $event.preventDefault();
      $event.stopPropagation();
    }

    /**
     * Batch operations
     */

    function _currentMailboxes() {
      if (Mailbox.$virtualMode)
        return vm.selectedFolder.$mailboxes;
      else
        return [vm.selectedFolder];
    }

    // Unselect current message and cleverly load the next message.
    // This function must not be called in virtual mode.
    function _unselectMessage(message, index) {
      var nextMessage, previousMessage, nextIndex = index;
      vm.mode.multiple = vm.selectedFolder.$selectedCount();
      if (message) {
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
          vm.selectedFolder.$topIndex = nextIndex;
          $state.go('mail.account.mailbox.message', { messageId: nextMessage.uid });
        }
        else {
          $state.go('mail.account.mailbox');
        }
      }
      else {
        $timeout(function() {
          console.warn('go to mailbox');
          $state.go('mail.account.mailbox');
        });
      }
    }

    function confirmDeleteSelectedMessages($event) {
      var selectedMessages = vm.selectedFolder.$selectedMessages();

      if (vm.messageDialog === null && _.size(selectedMessages) > 0)
        vm.messageDialog = Dialog.confirm(l('Confirmation'),
                                       l('Are you sure you want to delete the selected messages?'),
                                       { ok: l('Delete') })
        .then(function() {
          var deleteSelectedMessage = vm.selectedFolder.hasSelectedMessage();
          vm.selectedFolder.$deleteMessages(selectedMessages).then(function(index) {
            if (Mailbox.$virtualMode) {
              // When performing an advanced search, we refresh the view if the selected message
              // was deleted, but only once all promises have completed.
              if (deleteSelectedMessage)
                $state.go('mail.account.virtualMailbox');
            }
            else {
              // In normal mode, we immediately unselect the selected message.
              _unselectMessage(deleteSelectedMessage, index);
            }
          }, function(response) {
            vm.messageDialog = Dialog.confirm(l('Warning'),
                                           l('The messages could not be moved to the trash folder. Would you like to delete them immediately?'),
                                           { ok: l('Delete') })
              .then(function() {
                vm.selectedFolder.$deleteMessages(selectedMessages, { withoutTrash: true }).then(function(index) {
                  if (Mailbox.$virtualMode) {
                    // When performing an advanced search, we refresh the view if the selected message
                    // was deleted, but only once all promises have completed.
                    if (deleteSelectedMessage)
                      $state.go('mail.account.virtualMailbox');
                  }
                  else {
                    // In normal mode, we immediately unselect the selected message.
                    _unselectMessage(deleteSelectedMessage, index);
                  }
                });
              });
          });
        })
        .finally(function() {
          vm.messageDialog = null;
        });

      $event.preventDefault();
    }

    function markOrUnMarkMessagesAsJunk() {
      var moveSelectedMessage = vm.selectedFolder.hasSelectedMessage();
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      if (_.size(selectedMessages) === 0 && moveSelectedMessage)
        selectedMessages = [vm.selectedFolder.$selectedMessage()];
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$markOrUnMarkMessagesAsJunk(selectedMessages).then(function() {
          var dstFolder = '/' + vm.account.id + '/folderINBOX';
          if (vm.selectedFolder.type != 'junk') {
            dstFolder = '/' + vm.account.$getMailboxByType('junk').id;
          }
          vm.selectedFolder.$moveMessages(selectedMessages, dstFolder).then(function(index) {
            if (Mailbox.$virtualMode) {
              // When performing an advanced search, we refresh the view if the selected message
              // was deleted, but only once all promises have completed.
              if (moveSelectedMessage)
                $state.go('mail.account.virtualMailbox');
            }
            else {
              // In normal mode, we immediately unselect the selected message.
              _unselectMessage(moveSelectedMessage, index);
            }
          });
        });
    }

    function copySelectedMessages(dstFolder) {
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$copyMessages(selectedMessages, '/' + dstFolder).then(function() {
          $mdToast.show(
            $mdToast.simple()
              .content(l('%{0} message(s) copied', vm.selectedFolder.$selectedCount()))
              .position('top right')
              .hideDelay(2000));
        });
    }

    function moveSelectedMessages(dstFolder) {
      var moveSelectedMessage = vm.selectedFolder.hasSelectedMessage();
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      var count = vm.selectedFolder.$selectedCount();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$moveMessages(selectedMessages, '/' + dstFolder).then(function(index) {
          $mdToast.show(
            $mdToast.simple()
              .content(l('%{0} message(s) moved', count))
              .position('top right')
              .hideDelay(2000));
          if (Mailbox.$virtualMode) {
            // When performing an advanced search, we refresh the view if the selected message
            // was moved, but only once all promises have completed.
            if (moveSelectedMessage)
              $state.go('mail.account.virtualMailbox');
          }
          else {
            // In normal mode, we immediately unselect the selected message.
            _unselectMessage(moveSelectedMessage, index);
          }
        });
    }

    function selectAll() {
      var count = 0;
      _.forEach(_currentMailboxes(), function(folder) {
        var i = 0, length = folder.$messages.length;
        for (; i < length; i++)
          folder.$messages[i].selected = true;
        count += length;
      });
      vm.mode.multiple = count;
    }

    function unselectMessages() {
      _.forEach(_currentMailboxes(), function(folder) {
        _.forEach(folder.$messages, function(message) {
          message.selected = false;
        });
      });
      vm.mode.multiple = 0;
    }

    function markSelectedMessagesAsFlagged() {
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$flagMessages(selectedMessages, '\\Flagged', 'add').then(function(messages) {
          _.forEach(messages, function(message) {
            message.isflagged = true;
          });
        });
    }

    function markSelectedMessagesAsUnread() {
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      if (_.size(selectedMessages) > 0) {
        vm.selectedFolder.$flagMessages(selectedMessages, 'seen', 'remove').then(function(messages) {
          _.forEach(messages, function(message) {
            if (message.isread)
              message.$mailbox.unseenCount++;
            message.isread = false;
          });
        });
      }
    }

    function markSelectedMessagesAsRead() {
      var selectedMessages = vm.selectedFolder.$selectedMessages();
      if (_.size(selectedMessages) > 0) {
        vm.selectedFolder.$flagMessages(selectedMessages, 'seen', 'add').then(function(messages) {
          _.forEach(messages, function(message) {
            if (!message.isread)
              message.$mailbox.unseenCount--;
            message.isread = true;
          });
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

