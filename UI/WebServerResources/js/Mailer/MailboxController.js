/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxController.$inject = ['$window', '$scope', '$timeout', '$q', '$state', '$mdDialog', '$mdToast', 'stateAccounts', 'stateAccount', 'stateMailbox', 'sgHotkeys', 'encodeUriFilter', 'sgConstant', 'sgSettings', 'sgFocus', 'Dialog', 'Preferences', 'Account', 'Mailbox'];
  function MailboxController($window, $scope, $timeout, $q, $state, $mdDialog, $mdToast, stateAccounts, stateAccount, stateMailbox, sgHotkeys, encodeUriFilter, sgConstant, sgSettings, focus, Dialog, Preferences, Account, Mailbox) {
    var vm = this,
        defaultWindowTitle = angular.element($window.document).find('title').attr('sg-default') || "SOGo",
        hotkeys = [],
        sortLabels,
        popupWindow = null,
        msgHeight = 56; // must match md-item-size of md-list-item in UIxMailFolderTemplate

    sortLabels = {
      subject: 'Subject',
      from: 'From',
      date: 'Date',
      size: 'Size',
      arrival: 'Order Received'
    };

    this.$onInit = function() {
      // Expose controller for eventual popup windows
      $window.$mailboxController = vm;

      this.service = Mailbox;
      this.accounts = stateAccounts;
      this.account = stateAccount;
      this.selectedFolder = stateMailbox;
      this.messageDialog = null; // also access from Message controller
      this.mode = { search: false, multiple: 0 };
      this.allSelected = false;
      this.isLoadingMessage = false;
      this.nextAction = null;

      if (!Mailbox.$virtualMode)
        this.selectedFolder.getLabels(); // fetch labels from server

      _registerHotkeys(hotkeys);

      // Expunge mailbox when leaving the Mail module
      angular.element($window).on('beforeunload', _compactBeforeUnload);
      $scope.$on('$destroy', function() {
        angular.element($window).off('beforeunload', _compactBeforeUnload);
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
        // if (vm.mode.search) {
        //   vm.mode.search = false;
        //   vm.selectedFolder.$reset({ filter: true });
        // }
      });

      // Update window's title with unseen messages count of selected mailbox
      $scope.$watch(function() { return vm.selectedFolder.unseenCount; }, function(unseenCount) {
        var title = '';
        if (unseenCount)
          title += '(' + unseenCount + ') ';
        title += vm.selectedFolder.$displayName;
        title += ' | ' + defaultWindowTitle;
        $window.document.title = title;
      });
    };

    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_search'),
        description: l('Search'),
        callback: vm.searchMode
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_compose'),
        description: l('Write a new message'),
        callback: function($event) {
          if (vm.messageDialog === null)
            vm.newMessage($event);
        }
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('shift+j'),
        description: l('Mark the selected messages as junk'),
        callback: vm.markOrUnMarkMessagesAsJunk
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'space',
        description: l('Toggle item'),
        callback: vm.toggleMessageSelection
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'shift+space',
        description: l('Toggle range of items'),
        callback: vm.toggleMessageSelection
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
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          description: l('Delete selected message or folder'),
          callback: vm.confirmDeleteSelectedMessages
        }));
      });

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    function _compactBeforeUnload(event) {
      if (Mailbox.$virtualMode)
        return true;
      return vm.selectedFolder.$compact();
    }

    this.centerIsClose = function(navController_centerIsClose) {
      // Allow the messages list to be hidden only if a message is selected
      return this.selectedFolder.hasSelectedMessage() && !!navController_centerIsClose;
    };

    this.sort = function(field) {
      if (field) {
        vm.selectedFolder.$filter({ sort: field });
      }
      else {
        return sortLabels[vm.service.$query.sort];
      }
    };

    this.sortedBy = function(field) {
      return Mailbox.$query.sort == field;
    };

    this.ascending = function() {
      return Mailbox.$query.asc;
    };

    this.refresh = function () {
      Preferences.pollInbox();
      this.selectedFolder.$filter();
    };

    this.searchMode = function($event) {
      vm.mode.search = true;
      focus('search');
      if ($event)
        $event.preventDefault();
    };

    this.cancelSearch = function() {
      // Clean highlights
      if (vm.account) {
        vm.account.$getMailboxes().$$state.value.forEach((mailbox) => {
          mailbox.setHighlightWords([]);
        });
      }
      vm.mode.search = false;
      vm.selectedFolder.$filter(vm.service.$query).then(function() {
        if (vm.selectedFolder.$selectedMessage) {
          vm.selectedFolder.$topIndex = vm.selectedFolder.uidsMap[vm.selectedFolder.$selectedMessage];
        }
      });
    };

    this.composeWindowEnabled = function() {
      return Preferences.defaults.SOGoMailComposeWindowEnabled;
    };

    this.openInPopup = function(message, action) {
      var url = [sgSettings.baseURL(),
                 'UIxMailPopupView#!/Mail',
                 this.account.id],
          wId = this.account.id + '/' + Math.random(0, 1000);
      if (message) {
        // The double-encoding is necessary
        url.push(encodeUriFilter(encodeUriFilter(message.$mailbox.path)));
        url.push(message.uid);
        wId = message.$absolutePath();
      }
      if (action) {
        wId += '/' + action;
        url.push(action);
      }
      url = url.join('/');
      popupWindow = $window.open(url, wId,
                                 ["resizable=1",
                                  "scrollbars=1",
                                  "toolbar=0",
                                  "location=0",
                                  "directories=0",
                                  "status=0",
                                  "menubar=0",
                                  "copyhistory=0"]
                                 .join(','));
    };

    this.closePopup = function() {
      if ($window.document.body.classList.contains('popup'))
        $window.close();
    };

    /**
     * To keep track of the currently active dialog, we share a common variable with the parent controller.
     */
    function _messageDialog() {
      if ($scope.mailbox) {
        if (arguments.length > 0)
          $scope.mailbox.messageDialog = arguments[0];
        return $scope.mailbox.messageDialog;
      }
      return null;
    }

    function _showMailEditor($event, message) {
      if (_messageDialog() === null) {
        var onCompleteDeferred = $q.defer();
        _messageDialog(
          $mdDialog
            .show({
              parent: angular.element(document.body),
              targetEvent: $event,
              clickOutsideToClose: false,
              escapeToClose: false,
              templateUrl: 'UIxMailEditor',
              controller: 'MessageEditorController',
              controllerAs: 'editor',
              onComplete: function (scope, element) {
                return onCompleteDeferred.resolve(element);
              },
              locals: {
                stateParent: $scope,
                stateAccount: vm.account,
                stateMessage: message,
                onCompletePromise: function () {
                  return onCompleteDeferred.promise;
                }
              }
            })
            .catch(_.noop) // Cancel
            .finally(function() {
              _messageDialog(null);
              vm.closePopup();
            })
        );
      }
    }

    this._showMailEditorInPopup = function(message, action, inPopup) {
      if (!sgSettings.isPopup &&
          (Preferences.defaults.SOGoMailComposeWindow == 'popup' || inPopup)) {
        this.openInPopup(message, action);
        return true;
      }
      return false;
    };

    this.newMessage = function($event, inPopup) {
      if (!this._showMailEditorInPopup(null, 'new', inPopup)) {
        this.account.$newMessage().then(function(message) {
          _showMailEditor($event, message);
        });
      }
    };

    /**
     * User has pressed up arrow key
     */
    function _nextMessage($event) {
      if (vm.isLoadingMessage) {
        vm.nextAction = { m: _nextMessage, p: $event };
      }

      var index = vm.selectedFolder.$selectedMessageIndex();

      if (angular.isDefined(index)) {
        index--;
        if (vm.selectedFolder.$topIndex > 0)
          _scrollToIndex(index);
      }
      else {
        // No message is selected, show oldest message
        index = vm.selectedFolder.getLength() - 1;
        vm.selectedFolder.$topIndex = vm.selectedFolder.getLength();
      }

      if (index > -1 && !vm.isLoadingMessage)
        vm.selectMessage(vm.selectedFolder.getItemAtIndex(index));

      $event.preventDefault();

      return index;
    }

    /**
     * User has pressed the down arrow key
     */
    function _previousMessage($event) {
      if (vm.isLoadingMessage) {
        vm.nextAction = { m: _previousMessage, p: $event };
      }

      var index = vm.selectedFolder.$selectedMessageIndex();

      if (angular.isDefined(index)) {
        index++;
        if (vm.selectedFolder.$topIndex < vm.selectedFolder.getLength())
          _scrollToIndex(index);
      }
      else
        // No message is selected, show newest
        index = 0;

      if (index < vm.selectedFolder.getLength() && !vm.isLoadingMessage)
        vm.selectMessage(vm.selectedFolder.getItemAtIndex(index));
      else
        index = -1;

      $event.preventDefault();

      return index;
    }

    /**
     * Perform a smoother scrolling than modifying vm.selectedFolder.$topIndex directly
     */
    function _scrollToIndex(index) {
      var scroller = document.querySelector('[ui-view=mailbox] .md-virtual-repeat-scroller'),
          scrollTop = index * msgHeight;

      if (scrollTop < scroller.scrollTop || (scrollTop + msgHeight) > scroller.scrollTop + scroller.clientHeight)
        document.querySelectorAll('.md-virtual-repeat-scroller')[1].scrollTo({
          top: msgHeight * index - (scroller.clientHeight - msgHeight)/2,
          behavior: 'smooth'
        });
    }

    function _addNextMessageToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedMessage()) {
        index = _nextMessage($event);
        if (index >= 0)
          vm.toggleMessageSelection($event, vm.selectedFolder.$messages[index]);
      }
    }

    function _addPreviousMessageToSelection($event) {
      var index;

      if (vm.selectedFolder.hasSelectedMessage()) {
        index = _previousMessage($event);
        if (index >= 0)
          vm.toggleMessageSelection($event, vm.selectedFolder.$messages[index]);
      }
    }

    this.selectMessage = function(message) {
      if (Mailbox.$virtualMode) {
        vm.isLoadingMessage = true;
        $state.go('mail.account.virtualMailbox.message', { mailboxId: encodeUriFilter(encodeUriFilter(message.$mailbox.path)), messageId: message.uid }).then(function () {

        }).catch((err) => {
          console.error(err);
        })
          .finally(() => {
            vm.isLoadingMessage = false;
            if (vm.nextAction) {
              vm.nextAction.m(vm.nextAction.p);
              vm.nextAction = null;
            }
          });
      } else {
        vm.isLoadingMessage = true;
        $state.go('mail.account.mailbox.message', { mailboxId: encodeUriFilter(encodeUriFilter(message.$mailbox.path)), messageId: message.uid }).then(function () {

        }).catch((err) => {
          console.error(err);
        })
          .finally(() => {
            vm.isLoadingMessage = false;
            if (vm.nextAction) {
              vm.nextAction.m(vm.nextAction.p);
              vm.nextAction = null;
            }
          });
      }
    };

    this.toggleMessageSelection = function($event, message) {
      var folder = vm.selectedFolder,
          selectedIndex, nextSelectedIndex, i;

      if (!message)
        message = folder.selectedMessage();
      if (!message)
        return true;

      message.selected = !message.selected;

      // Select closest range of messages when shift key is pressed
      if ($event.shiftKey && folder.selectedCount() > 0) {
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

      folder.selectedMessages({ updateCache: true });
      vm.mode.multiple = vm.selectedFolder.selectedCount();
      $event.preventDefault();
      $event.stopPropagation();
    };

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
      vm.mode.multiple = vm.selectedFolder.selectedCount();
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
    }

    this.confirmDeleteSelectedMessages = function($event) {
      var selectedMessages = vm.selectedFolder.selectedMessages();

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
                vm.selectedFolder.$deleteMessages(selectedMessages, { withoutTrash: true })
                  .then(function(index) {
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
                  })
                  .finally(function() {
                    vm.messageDialog = null;
                  });
              });
          });
        })
        .finally(function() {
          vm.messageDialog = null;
        });

      $event.preventDefault();
    };

    this.markOrUnMarkMessagesAsJunk = function() {
      var moveSelectedMessage = vm.selectedFolder.hasSelectedMessage();
      var selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) === 0 && moveSelectedMessage)
        // No selection, user has pressed keyboard shortcut
        selectedMessages = [vm.selectedFolder.selectedMessage()];
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
    };

    this.copySelectedMessages = function(dstFolder) {
      var selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$copyMessages(selectedMessages, '/' + dstFolder).then(function() {
          $mdToast.show(
            $mdToast.simple()
              .textContent(l('%{0} message(s) copied', vm.selectedFolder.selectedCount()))
              .position(sgConstant.toastPosition)
              .hideDelay(2000));
        });
    };

    this.moveSelectedMessages = function(dstFolder) {
      var moveSelectedMessage = vm.selectedFolder.hasSelectedMessage();
      var selectedMessages = vm.selectedFolder.selectedMessages();
      var count = vm.selectedFolder.selectedCount();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$moveMessages(selectedMessages, '/' + dstFolder).then(function(index) {
          $mdToast.show(
            $mdToast.simple()
              .textContent(l('%{0} message(s) moved', count))
              .position(sgConstant.toastPosition)
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
    };

    this.selectAll = function() {
      var count = 0;
      _.forEach(_currentMailboxes(), function(folder) {
        var i = 0, length = folder.$messages.length;
        folder.$selectedMessages = [];
        for (; i < length; i++) {
          folder.$messages[i].selected = !vm.allSelected;
          if(folder.$messages[i].selected)
            folder.$selectedMessages.push(folder.$messages[i]);
            count++;
        }
      });
      vm.allSelected = !vm.allSelected;
      vm.mode.multiple = count;
    };

    this.unselectMessages = function() {
      _.forEach(_currentMailboxes(), function(folder) {
        folder.$selectedMessages = [];
        _.forEach(folder.$messages, function(message) {
          message.selected = false;
        });
      });
      vm.mode.multiple = 0;
    };

    this.markSelectedMessagesAsFlagged = function() {
      var selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) > 0)
        vm.selectedFolder.$flagMessages(selectedMessages, '\\Flagged', 'add').then(function(messages) {
          _.forEach(messages, function(message) {
            message.isflagged = true;
          });
        });
    };

    this.markSelectedMessagesAsUnread = function() {
      var selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) > 0) {
        vm.selectedFolder.$flagMessages(selectedMessages, 'seen', 'remove').then(function(messages) {
          _.forEach(messages, function(message) {
            if (message.isread)
              message.$mailbox.unseenCount++;
            message.isread = false;
          });
        });
      }
    };

    this.markSelectedMessagesAsRead = function() {
      var selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) > 0) {
        vm.selectedFolder.$flagMessages(selectedMessages, 'seen', 'add').then(function(messages) {
          _.forEach(messages, function(message) {
            if (!message.isread)
              message.$mailbox.unseenCount--;
            message.isread = true;
          });
        });
      }
    };

    this.forwardSelectedMessages = function($event) {
      var _this = this,
          selectedMessages = vm.selectedFolder.selectedMessages();
      if (_.size(selectedMessages) > 0) {
        vm.selectedFolder.forwardMessages(selectedMessages).then(function(message) {
          if (!_this._showMailEditorInPopup(message, 'edit')) {
            message.$editableContent().then(function() {
              _showMailEditor($event, message);
            });
          }
        });
      }
    };

  }

  angular
    .module('SOGo.MailerUI')
    .controller('MailboxController', MailboxController);

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
    .module('material.components.virtualRepeat')
    .decorator('mdVirtualRepeatContainerDirective', mdVirtualRepeatContainerDirectiveDecorator);

})();

