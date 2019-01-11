/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageController.$inject = ['$window', '$scope', '$q', '$state', '$mdMedia', '$mdDialog', '$mdPanel', 'sgConstant', 'stateAccounts', 'stateAccount', 'stateMailbox', 'stateMessage', 'sgHotkeys', 'encodeUriFilter', 'sgSettings', 'ImageGallery', 'sgFocus', 'Dialog', 'Preferences', 'Calendar', 'Component', 'Account', 'Mailbox', 'Message', 'AddressBook', 'Card'];
  function MessageController($window, $scope, $q, $state, $mdMedia, $mdDialog, $mdPanel, sgConstant, stateAccounts, stateAccount, stateMailbox, stateMessage, sgHotkeys, encodeUriFilter, sgSettings, ImageGallery, focus, Dialog, Preferences, Calendar, Component, Account, Mailbox, Message, AddressBook, Card) {
    var vm = this, popupWindow = null, hotkeys = [];

    this.$onInit = function() {
      var isPopupWindow = false;

      // Expose controller
      $window.$messageController = vm;

      // Initialize image gallery service
      ImageGallery.setMessage(stateMessage);

      this.$state = $state;
      this.accounts = stateAccounts;
      this.account = stateAccount;
      this.mailbox = stateMailbox;
      this.message = stateMessage;
      this.service = Message;
      this.tags = { searchText: '', selected: '' };
      this.showFlags = stateMessage.flags && stateMessage.flags.length > 0;
      this.$alwaysShowDetailedRecipients = (!stateMessage.to || stateMessage.to.length < 5) && (!stateMessage.cc || stateMessage.cc.length < 5);
      this.$showDetailedRecipients = this.$alwaysShowDetailedRecipients;
      this.showRawSource = false;

      _registerHotkeys(hotkeys);

      // Detect if this is message appears in a separate window
      try {
        isPopupWindow = $window.opener && '$mailboxController' in $window.opener;
      }
      catch (e) {}

      // One-way refresh of the parent window when modifying the message from a popup window.
      if (isPopupWindow) {
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

    }; // $onInit


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
        callback: _unlessInDialog(angular.bind(vm, vm.reply))
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_replyall'),
        description: l('Reply to sender and all recipients'),
        callback: _unlessInDialog(angular.bind(vm, vm.replyAll))
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_forward'),
        description: l('Forward selected message'),
        callback: _unlessInDialog(angular.bind(vm, vm.forward))
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_flag'),
        description: l('Flagged'),
        callback: _unlessInDialog(angular.bind(stateMessage, stateMessage.toggleFlag))
      }));
      _.forEach(['backspace', 'delete'], function(hotkey) {
        keys.push(sgHotkeys.createHotkey({
          key: hotkey,
          callback: _unlessInDialog(function($event) {
            if (vm.mailbox.$selectedCount() === 0)
              vm.deleteMessage();
            $event.preventDefault();
          }),
        }));
      });

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
        if ('$mailboxController' in $window.opener &&
            'selectedFolder' in $window.opener.$mailboxController &&
            $window.opener.$mailboxController.selectedFolder.$id() == stateMailbox.$id()) {
            // The message mailbox is opened in the parent window
            mailbox = $window.opener.$mailboxController;
            ctrls.mailboxCtrl = mailbox;
            if ('$messageController' in $window.opener &&
                $window.opener.$messageController.message.uid == stateMessage.uid) {
              // The message is opened in the parent window
              message = $window.opener.$messageController;
              ctrls.messageCtrl = message;
            }
        }
      }
      return ctrls;
    }

    this.addFlags = function($event) {
      $event.stopPropagation();
      $event.preventDefault();
      this.showFlags = true;
      focus("flags");
    };

    this.toggleDetailedRecipients = function($event) {
      this.$showDetailedRecipients = !this.$showDetailedRecipients;
      $event.stopPropagation();
      $event.preventDefault();
    };

    this.focusChip = function($event) {
      var chipElement = $event.target;
      while (chipElement.tagName !== 'MD-CHIP') {
        chipElement = chipElement.parentNode;
      }
      chipElement.classList.add('md-focused');
    };

    this.blurChip = function($event) {
      var chipElement = $event.target;
      while (chipElement.tagName !== 'MD-CHIP') {
        chipElement = chipElement.parentNode;
      }
      chipElement.classList.remove('md-focused');
      if ($event.relatedTarget && $event.relatedTarget.tagName === 'MD-CHIP-TEMPLATE') {
        // Moving to another chip; close menu
        vm.panel.close();
      }
    };

    this.selectRecipient = function(recipient, $event) {
      // Fetch addressbooks list
      AddressBook.$findAll([]);

      var targetElement = $event.target;

      var panelPosition = $mdPanel.newPanelPosition()
          .relativeTo(targetElement)
          .addPanelPosition(
            $mdPanel.xPosition.ALIGN_START,
            $mdPanel.yPosition.ALIGN_TOPS
          );

      var panelAnimation = $mdPanel.newPanelAnimation()
          .openFrom(targetElement)
          .duration(100)
          .withAnimation($mdPanel.animation.FADE);

      var config = {
        attachTo: angular.element(document.body),
        locals: {
          recipient: recipient,
          addressbooks: AddressBook.$addressbooks,
          subscriptions: AddressBook.$subscriptions,
          newMessage: angular.bind(this, this.newMessage)
        },
        bindToController: true,
        controller: MenuController,
        controllerAs: '$menuCtrl',
        position: panelPosition,
        animation: panelAnimation,
        targetEvent: $event,
        templateUrl: 'UIxMailViewRecipientMenu',
        trapFocus: true,
        clickOutsideToClose: true,
        escapeToClose: true,
        focusOnOpen: false
      };

      $mdPanel.open(config)
        .then(function(panelRef) {
          vm.panel = panelRef;
          // Automatically close panel when clicking inside of it
          panelRef.panelEl.one('click', function() {
            panelRef.close();
          });
        });

      MenuController.$inject = ['mdPanelRef', '$state', '$mdToast'];
      function MenuController(mdPanelRef, $state, $mdToast) {
        this.onKeyDown = function($event) {
          if ($event.which === 9) { // Tab
            mdPanelRef.close();
          }
        };

        this.newCard = function(recipient, addressbookId) {
          var card = new Card({
            pid: addressbookId,
            c_cn: recipient.name,
            emails: [{ value: recipient.email }]
          });
          card.$id().then(function(id) {
            card.$save().then(function() {
              // Show success toast when action succeeds
              $mdToast.show(
                $mdToast.simple()
                  .content(l('Successfully created card'))
                  .position('top right')
                  .hideDelay(2000));
            });
          });
          mdPanelRef.close();
        };
      }

      if (targetElement.tagName === 'A') {
        $event.stopPropagation();
        $event.preventDefault();
      }
    };

    this.filterMailtoLinks = function($event) {
      var href, match, to, cc, bcc, subject, body, data;
      if ($event.target.tagName == 'A' && 'href' in $event.target.attributes) {
        href = $event.target.attributes.href.value;
        match = /^mailto:([^\?]+)/.exec(href);
        if (match) {
          delete $event.target.attributes.target;
          this.newMessage($event, href); // will stop event propagation
        }
      }
    };

    this.deleteMessage = function() {
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
      if (Mailbox.$virtualMode) {
        mailbox = Mailbox.selectedFolder; // the VirtualMailbox instance
      }

      mailbox.$deleteMessages([message]).then(function(index) {
        var nextIndex = index;
        // Remove message object from scope
        message = null;
        if (angular.isDefined(state)) {
          // Select either the next or previous message
          if (index > 0) {
            nextIndex -= 1;
            nextMessage = mailbox.getItemAtIndex(nextIndex);
          }
          if (index < mailbox.getLength())
            previousMessage = mailbox.getItemAtIndex(index);

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
              if (Mailbox.$virtualMode)
                state.go('mail.account.virtualMailbox.message', {mailboxId: encodeUriFilter(nextMessage.$mailbox.path), messageId: nextMessage.uid});
              else
                state.go('mail.account.mailbox.message', {messageId: nextMessage.uid});
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
        vm.closePopup();
      });
    };

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

    this._showMailEditorInPopup = function(action) {
      if (!sgSettings.isPopup &&
          Preferences.defaults.SOGoMailComposeWindow == 'popup') {
        this.openInPopup(action);
        return true;
      }
      return false;
    };

    this.close = function() {
      var destination = Mailbox.$virtualMode ? 'mail.account.virtualMailbox' : 'mail.account.mailbox';
      $state.go(destination).then(function() {
        vm.message = null;
        delete stateMailbox.selectedMessage;
      });
    };

    this.reply = function($event) {
      if (!this._showMailEditorInPopup('reply')) {
        _showMailEditor($event, this.message.$reply());
      }
    };

    this.replyAll = function($event) {
      if (!this._showMailEditorInPopup('replyall')) {
        _showMailEditor($event, this.message.$replyAll());
      }
    };

    this.forward = function($event) {
      if (!this._showMailEditorInPopup('forward')) {
        _showMailEditor($event, this.message.$forward());
      }
    };

    this.edit = function($event) {
      if (!this._showMailEditorInPopup('edit')) {
        this.message.$editableContent().then(function() {
          _showMailEditor($event, vm.message);
        });
      }
    };

    this.openInPopup = function(action) {
      var url = [sgSettings.baseURL(),
                 'UIxMailPopupView#!/Mail',
                 this.message.accountId,
                 // The double-encoding is necessary
                 encodeUriFilter(encodeUriFilter(this.message.$mailbox.path)),
                 this.message.uid]
          .join('/'),
          wId = this.message.$absolutePath();
      if (action) url += '/' + action;
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
    };

    this.closePopup = function() {
      if ($window.document.body.classList.contains('popup'))
        $window.close();
    };

    this.newMessage = function($event, mailto) {
      if ($event.target.tagName === 'A') {
        $event.stopPropagation();
        $event.preventDefault();
      }
      this.account.$newMessage({ mailto: mailto }).then(function(message) {
        _showMailEditor($event, message);
      });
    };

    this.toggleRawSource = function($event) {
      if (!this.showRawSource && !this.message.$rawSource) {
        Message.$$resource.post(this.message.id, "viewsource").then(function(data) {
          vm.message.$rawSource = data;
          vm.showRawSource = true;
        });
      }
      else {
        this.showRawSource = !this.showRawSource;
      }
    };

    this.print = function($event) {
      $window.print();
    };

    this.convertToEvent = function($event) {
      return _convertToComponent($event, 'appointment');
    };

    this.convertToTask = function($event) {
      return _convertToComponent($event, 'task');
    };

    function _convertToComponent($event, type) {
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
