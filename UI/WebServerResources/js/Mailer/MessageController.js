/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageController.$inject = ['$window', '$scope', '$state', '$mdDialog', 'stateAccounts', 'stateAccount', 'stateMailbox', 'stateMessage', 'encodeUriFilter', 'sgSettings', 'sgFocus', 'Dialog', 'Account', 'Mailbox', 'Message'];
  function MessageController($window, $scope, $state, $mdDialog, stateAccounts, stateAccount, stateMailbox, stateMessage, encodeUriFilter, sgSettings, focus, Dialog, Account, Mailbox, Message) {
    var vm = this, messageDialog = null, popupWindow = null;

    // Expose controller
    $window.$messageController = vm;

    vm.$state = $state;
    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.mailbox = stateMailbox;
    vm.message = stateMessage;
    vm.service = Message;
    vm.tags = { searchText: '', selected: '' };
    vm.showFlags = stateMessage.flags && stateMessage.flags.length > 0;
    vm.$showDetailedRecipients = false;
    vm.showDetailedRecipients = showDetailedRecipients;
    vm.doDelete = doDelete;
    vm.close = close;
    vm.reply = reply;
    vm.replyAll = replyAll;
    vm.forward = forward;
    vm.edit = edit;
    vm.openPopup = openPopup;
    vm.closePopup = closePopup;
    vm.newMessage = newMessage;
    vm.saveMessage = saveMessage;
    vm.toggleRawSource = toggleRawSource;
    vm.showRawSource = false;

    // One-way refresh of the parent window when modifying the message from a popup window.
    if ($window.opener) {
      // Update the message flags. The message must be displayed in the parent window.
      $scope.$watchCollection('viewer.message.flags', function(newTags, oldTags) {
        var ctrls;
        if (newTags || oldTags) {
          ctrls = $parentControllers();
          if (ctrls.messageCtrl) {
            ctrls.messageCtrl.service.$timeout(function() {
              ctrls.messageCtrl.message.flags = newTags;
            });
          }
        }
      });
      // Update the "isflagged" (star icon) of the message. The mailbox must be displayed in the parent window.
      $scope.$watch('viewer.message.isflagged', function(isflagged, wasflagged) {
        var ctrls = $parentControllers();
        if (ctrls.mailboxCtrl) {
          ctrls.mailboxCtrl.service.$timeout(function() {
            var message = _.find(ctrls.mailboxCtrl.selectedFolder.$messages, { uid: vm.message.uid });
            message.isflagged = isflagged;
          });
        }
      });
    }

    /**
     * If this is a popup window, retrieve the matching controllers (mailbox and message) of the parent window.
     */
    function $parentControllers() {
      var message, mailbox, ctrls = {};
      if ($window.opener) {
        // Deleting the message from a popup window
        if ($window.opener.$mailboxController &&
            $window.opener.$mailboxController.selectedFolder.$id() == stateMailbox.$id()) {
            // The message mailbox is opened in the parent window
            mailbox = $window.opener.$mailboxController;
            ctrls.mailboxCtrl = mailbox;
            if ($window.opener.$messageController &&
                $window.opener.$messageController.message.uid == stateMessage.uid) {
              // The message is opened in the parent window
              message = $window.opener.$messageController;
              ctrls.messageCtrl = message;
            }
        }
      }
      return ctrls;
    }

    function showDetailedRecipients($event) {
      vm.$showDetailedRecipients = true;
      $event.stopPropagation();
      $event.preventDefault();
    }

    function doDelete() {
      var mailbox, message, state, nextMessage, previousMessage,
          parentCtrls = $parentControllers();

      if (parentCtrls.messageCtrl) {
        mailbox = parentCtrls.mailboxCtrl.selectedFolder;
        message = parentCtrls.messageCtrl.message;
        state = parentCtrls.messageCtrl.$state;
      }
      else {
        mailbox = stateMailbox;
        message = stateMessage;
        state = $state;
      }

      mailbox.$deleteMessages([message]).then(function(index) {
        var nextIndex = index;
        // Remove message object from scope
        message = null;
        if (angular.isDefined(state)) {
          // Select either the next or previous message
          if (index > 0) {
            nextIndex -= 1;
            nextMessage = mailbox.$messages[nextIndex];
          }
          if (index < mailbox.$messages.length)
            previousMessage = mailbox.$messages[index];

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

          try {
            if (nextMessage) {
              state.go('mail.account.mailbox.message', { messageId: nextMessage.uid });
              if (nextIndex < mailbox.$topIndex)
                mailbox.$topIndex = nextIndex;
              else if (nextIndex > mailbox.$lastVisibleIndex)
                mailbox.$topIndex = nextIndex - (mailbox.$lastVisibleIndex - mailbox.$topIndex);
            }
            else {
              state.go('mail.account.mailbox');
            }
          }
          catch (error) {}
        }
        closePopup();
      });
    }

    function showMailEditor($event, message, recipients) {
      if (messageDialog === null) {
        if (!angular.isDefined(recipients))
          recipients = [];

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
              stateAccount: vm.account,
              stateMessage: message,
              stateRecipients: recipients
            }
          })
          .finally(function() {
            messageDialog = null;
            closePopup();
          });
      }
    }

    function close() {
      $state.go('mail.account.mailbox').then(function() {
        vm.message = null;
        delete stateMailbox.selectedMessage;
      });
    }

    function reply($event) {
      var message = vm.message.$reply();
      showMailEditor($event, message);
    }

    function replyAll($event) {
      var message = vm.message.$replyAll();
      showMailEditor($event, message);
    }

    function forward($event) {
      var message = vm.message.$forward();
      showMailEditor($event, message);
    }

    function edit($event) {
      vm.message.$editableContent().then(function() {
        showMailEditor($event, vm.message);
      });
    }

    function openPopup() {
      var url = [sgSettings.baseURL(),
                 'UIxMailPopupView#/Mail',
                 vm.message.accountId,
                 // The double-encoding is necessary
                 encodeUriFilter(encodeUriFilter(vm.message.$mailbox.path)),
                 vm.message.uid]
          .join('/'),
          wId = vm.message.$absolutePath();
      popupWindow = $window.open(url, wId,
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

    function closePopup() {
      if ($window.opener)
        $window.close();
    }

    function newMessage($event, recipient) {
      var message = vm.account.$newMessage();
      showMailEditor($event, message, [recipient]);
      $event.stopPropagation();
      $event.preventDefault();
    }

    function saveMessage() {
      window.location.href = ApplicationBaseURL + '/' + vm.mailbox.id + '/saveMessages?uid=' + vm.message.uid;
    }

    function toggleRawSource($event) {
      if (!vm.showRawSource && !vm.rawSource) {
        Message.$$resource.post(vm.message.id, "viewsource").then(function(data) {
          vm.rawSource = data;
          vm.showRawSource = true;
        });
      }
      else {
        vm.showRawSource = !vm.showRawSource;
      }
    }
  }
  
  angular
    .module('SOGo.MailerUI')  
    .controller('MessageController', MessageController);                                    
})();
