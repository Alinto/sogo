/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageController.$inject = ['$window', '$scope', '$state', '$mdMedia', '$mdDialog', 'sgConstant', 'stateAccounts', 'stateAccount', 'stateMailbox', 'stateMessage', 'sgHotkeys', 'encodeUriFilter', 'sgSettings', 'ImageGallery', 'sgFocus', 'Dialog', 'Calendar', 'Component', 'Account', 'Mailbox', 'Message'];
  function MessageController($window, $scope, $state, $mdMedia, $mdDialog, sgConstant, stateAccounts, stateAccount, stateMailbox, stateMessage, sgHotkeys, encodeUriFilter, sgSettings, ImageGallery, focus, Dialog, Calendar, Component, Account, Mailbox, Message) {
    var vm = this, popupWindow = null, hotkeys = [];

    // Expose controller
    $window.$messageController = vm;

    // Initialize image gallery service
    ImageGallery.setMessage(stateMessage);

    vm.$state = $state;
    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.mailbox = stateMailbox;
    vm.message = stateMessage;
    vm.service = Message;
    vm.tags = { searchText: '', selected: '' };
    vm.showFlags = stateMessage.flags && stateMessage.flags.length > 0;
    vm.$showDetailedRecipients = false;
    vm.toggleDetailedRecipients = toggleDetailedRecipients;
    vm.filterMailtoLinks = filterMailtoLinks;
    vm.deleteMessage = deleteMessage;
    vm.close = close;
    vm.reply = reply;
    vm.replyAll = replyAll;
    vm.forward = forward;
    vm.edit = edit;
    vm.openPopup = openPopup;
    vm.closePopup = closePopup;
    vm.newMessage = newMessage;
    vm.toggleRawSource = toggleRawSource;
    vm.showRawSource = false;
    vm.print = print;
    vm.convertToEvent = convertToEvent;
    vm.convertToTask = convertToTask;

    _registerHotkeys(hotkeys);

    // One-way refresh of the parent window when modifying the message from a popup window.
    if ($window.opener) {
      // Update the message flags. The message must be displayed in the parent window.
      $scope.$watchCollection(function() { return vm.message.flags; }, function(newTags, oldTags) {
        var ctrls;
        if (newTags || oldTags) {
          ctrls = $parentControllers();
          if (ctrls.messageCtrl) {
            ctrls.messageCtrl.service.$timeout(function() {
              ctrls.messageCtrl.showFlags = true;
              ctrls.messageCtrl.message.flags = newTags;
            });
          }
        }
      });
      // Update the "isflagged" (star icon) of the message. The mailbox must be displayed in the parent window.
      $scope.$watch(function() { return vm.message.isflagged; }, function(isflagged, wasflagged) {
        var ctrls = $parentControllers();
        if (ctrls.mailboxCtrl) {
          ctrls.mailboxCtrl.service.$timeout(function() {
            var message = _.find(ctrls.mailboxCtrl.selectedFolder.$messages, { uid: vm.message.uid });
            message.isflagged = isflagged;
          });
        }
      });
    }
    else {
      // Flatten new tags when coming from the predefined list of tags (Message.$tags) and
      // sync tags with server when adding or removing a tag.
      $scope.$watchCollection(function() { return vm.message.flags; }, function(_newTags, _oldTags) {
        var newTags, oldTags, tags;
        if (_newTags || _oldTags) {
          newTags = _newTags || [];
          oldTags = _oldTags || [];
          _.forEach(newTags, function(tag, i) {
            if (angular.isObject(tag))
              newTags[i] = tag.name;
          });
          if (newTags.length > oldTags.length) {
            tags = _.difference(newTags, oldTags);
            _.forEach(tags, function(tag) {
              vm.message.addTag(tag);
            });
          }
          else if (newTags.length < oldTags.length) {
            tags = _.difference(oldTags, newTags);
            _.forEach(tags, function(tag) {
              vm.message.removeTag(tag);
            });
          }
        }
      });
    }

    $scope.$on('$destroy', function() {
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


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

    function _unlessInDialog(callback) {
      return function() {
        // Check if a dialog is opened either from the current controller or the parent controller
        if (_messageDialog() === null)
          return callback.apply(vm, arguments);
      };
    }

    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_reply'),
        description: l('Reply to the message'),
        callback: _unlessInDialog(reply)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_replyall'),
        description: l('Reply to sender and all recipients'),
        callback: _unlessInDialog(replyAll)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_forward'),
        description: l('Forward selected message'),
        callback: _unlessInDialog(forward)
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_flag'),
        description: l('Flagged'),
        callback: _unlessInDialog(angular.bind(stateMessage, stateMessage.toggleFlag))
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'backspace',
        callback: _unlessInDialog(function($event) {
          if (vm.mailbox.$selectedCount() === 0)
            deleteMessage();
          $event.preventDefault();
        })
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
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

    function toggleDetailedRecipients($event) {
      vm.$showDetailedRecipients = !vm.$showDetailedRecipients;
      $event.stopPropagation();
      $event.preventDefault();
    }

    function filterMailtoLinks($event) {
      var href, match, to, cc, bcc, subject, body, data;
      if ($event.target.tagName == 'A' && 'href' in $event.target.attributes) {
        href = $event.target.attributes.href.value;
        match = /^mailto:([^\?]+)/.exec(href);
        if (match) {
          // Recipients
          to = _.map(decodeURIComponent(match[1]).split(','), function(email) {
            return '<' + email + '>';
          });
          data = { to: to };
          // Subject & body
          _.forEach(['subject', 'body'], function(param) {
            var re = new RegExp(param + '=([^&]+)');
            param = (param == 'body')? 'text' : param;
            match = re.exec(href);
            if (match)
              data[param] = [decodeURIComponent(match[1])];
          });
          // Recipients
          _.forEach(['cc', 'bcc'], function(param) {
            var re = new RegExp(param + '=([^&]+)');
            match = re.exec(href);
            if (match)
              data[param] = [decodeURIComponent(match[1])];
          });
          newMessage($event, data); // will stop event propagation
        }
      }
    }

    function deleteMessage() {
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
            if (nextMessage && $mdMedia(sgConstant['gt-md'])) {
              state.go('mail.account.mailbox.message', { messageId: nextMessage.uid });
              if (nextIndex < mailbox.$topIndex)
                mailbox.$topIndex = nextIndex;
              else if (nextIndex > mailbox.$lastVisibleIndex)
                mailbox.$topIndex = nextIndex - (mailbox.$lastVisibleIndex - mailbox.$topIndex);
            }
            else {
              state.go('mail.account.mailbox').then(function() {
                message = null;
                delete mailbox.selectedMessage;
              });
            }
          }
          catch (error) {}
        }
        closePopup();
      });
    }

    function showMailEditor($event, message) {
      if (_messageDialog() === null) {
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
              locals: {
                stateAccount: vm.account,
                stateMessage: message
              }
            })
            .finally(function() {
              _messageDialog(null);
              closePopup();
            })
        );
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
                 'UIxMailPopupView#!/Mail',
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

    function newMessage($event, editableContent) {
      vm.account.$newMessage().then(function(message) {
        angular.extend(message.editable, editableContent);
        showMailEditor($event, message);
      });
      $event.stopPropagation();
      $event.preventDefault();
    }

    function toggleRawSource($event) {
      if (!vm.showRawSource && !vm.message.$rawSource) {
        Message.$$resource.post(vm.message.id, "viewsource").then(function(data) {
          vm.message.$rawSource = data;
          vm.showRawSource = true;
        });
      }
      else {
        vm.showRawSource = !vm.showRawSource;
      }
    }

    function print($event) {
      $window.print();
    }

    function convertToEvent($event) {
      return convertToComponent($event, 'appointment');
    }

    function convertToTask($event) {
      return convertToComponent($event, 'task');
    }

    function convertToComponent($event, type) {
      vm.message.$plainContent().then(function(data) {
        var componentData = {
          pid: Calendar.$defaultCalendar(),
          type: type,
          summary: data.subject,
          comment: data.content
        };
        var component = new Component(componentData);
        // UI/Templates/SchedulerUI/UIxAppointmentEditorTemplate.wox or
        // UI/Templates/SchedulerUI/UIxTaskEditorTemplate.wox
        var templateUrl = [
          sgSettings.activeUser('folderURL'),
          'Calendar',
          'UIx' + type.capitalize() + 'EditorTemplate'
        ].join('/');
        return $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: $event,
          clickOutsideToClose: true,
          escapeToClose: true,
          templateUrl: templateUrl,
          controller: 'ComponentEditorController',
          controllerAs: 'editor',
          locals: {
            stateComponent: component
          }
        });
      });
    }
  }

  angular
    .module('SOGo.MailerUI')
    .controller('MessageController', MessageController);
})();
