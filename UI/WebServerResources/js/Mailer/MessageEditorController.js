/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$scope', '$window', '$stateParams', '$mdConstant', '$mdDialog', '$mdToast', 'FileUploader', 'stateAccount', 'stateMessage', 'encodeUriFilter', '$timeout', 'Dialog', 'AddressBook', 'Card', 'Preferences'];
  function MessageEditorController($scope, $window, $stateParams, $mdConstant, $mdDialog, $mdToast, FileUploader, stateAccount, stateMessage, encodeUriFilter, $timeout, Dialog, AddressBook, Card, Preferences) {
    var vm = this, hotkeys = [];

    vm.addRecipient = addRecipient;
    vm.autocomplete = {to: {}, cc: {}, bcc: {}};
    vm.autosave = null;
    vm.autosaveDrafts = autosaveDrafts;
    vm.cancel = cancel;
    vm.contactFilter = contactFilter;
    vm.isFullscreen = false;
    vm.hideBcc = (stateMessage.editable.bcc.length === 0);
    vm.hideCc = (stateMessage.editable.cc.length === 0);
    vm.identities = _.map(stateAccount.identities, 'full');
    vm.message = stateMessage;
    vm.recipientSeparatorKeys = [
      $mdConstant.KEY_CODE.ENTER,
      $mdConstant.KEY_CODE.TAB,
      $mdConstant.KEY_CODE.COMMA,
      $mdConstant.KEY_CODE.SEMICOLON
    ];
    vm.removeAttachment = removeAttachment;
    vm.save = save;
    vm.send = send;
    vm.sendState = false;
    vm.toggleFullscreen = toggleFullscreen;
    vm.uploader = new FileUploader({
      url: stateMessage.$absolutePath({asDraft: true, withResourcePath: true}) + '/save',
      autoUpload: true,
      alias: 'attachments',
      removeAfterUpload: false,
      // onProgressItem: function(item, progress) {
      //   console.debug(item); console.debug(progress);
      // },
      onSuccessItem: function(item, response, status, headers) {
        stateMessage.$setUID(response.uid);
        stateMessage.$reload({asDraft: false});
        item.inlineUrl = response.lastAttachmentAttrs[0].url;
        //console.debug(item); console.debug('success = ' + JSON.stringify(response, undefined, 2));
      },
      onCancelItem: function(item, response, status, headers) {
        //console.debug(item); console.debug('cancel = ' + JSON.stringify(response, undefined, 2));
        // We remove the attachment
        stateMessage.$deleteAttachment(item.file.name);
        this.removeFromQueue(item);
      },
      onErrorItem: function(item, response, status, headers) {
        $mdToast.show(
          $mdToast.simple()
            .content(l('Error while uploading the file \"%{0}\":', item.file.name) +
                     ' ' + (response.message? l(response.message) : ''))
            .position('top right')
            .action(l('OK'))
            .hideDelay(false));
        this.removeFromQueue(item);
        //console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
      }
    });

    // Destroy file uploader when the controller is being deactivated
    $scope.$on('$destroy', function() { vm.uploader.destroy(); });

    if ($stateParams.actionName == 'reply') {
      stateMessage.$reply().then(function(msgObject) {
        vm.message = msgObject;
        vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length === 0);
        vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length === 0);
      });
    }
    else if ($stateParams.actionName == 'replyall') {
      stateMessage.$replyAll().then(function(msgObject) {
        vm.message = msgObject;
        vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length === 0);
        vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length === 0);
      });
    }
    else if ($stateParams.actionName == 'forward') {
      stateMessage.$forward().then(function(msgObject) {
        vm.message = msgObject;
        addAttachments();
      });
    }
    else if (angular.isDefined(stateMessage)) {
      vm.message = stateMessage;
      addAttachments();
    }

    /**
     * If this is a popup window, retrieve the mailbox controller of the parent window.
     */
    function $parentControllers() {
      var originMessage, ctrls = {};

      try {
        if ($window.opener) {
          if ('$mailboxController' in $window.opener &&
              'selectedFolder' in $window.opener.$mailboxController) {
            if ($window.opener.$mailboxController.selectedFolder.type == 'draft') {
              ctrls.draftMailboxCtrl = $window.opener.$mailboxController;
              if ('$messageController' in $window.opener &&
                  $window.opener.$messageController.message.uid == stateMessage.uid) {
                // The draft is opened in the parent window
                ctrls.draftMessageCtrl = $window.opener.$messageController;
              }
            }
            else if (stateMessage.origin) {
              originMessage = stateMessage.origin.message;
              if ($window.opener.$mailboxController.selectedFolder.$id() == originMessage.$mailbox.$id()) {
                // The message mailbox is opened in the parent window
                ctrls.originMailboxCtrl = $window.opener.$mailboxController;
              }
            }
          }
        }
      }
      catch (e) {}

      return ctrls;
    }

    function addAttachments() {
      // Add existing attached files to uploader
      var i, data, fileItem, attrs = vm.message.editable.attachmentAttrs;
      if (attrs)
        for (i = 0; i < attrs.length; i++) {
          data = {
            name: attrs[i].filename,
            type: attrs[i].mimetype,
            size: parseInt(attrs[i].size)
          };
          fileItem = new FileUploader.FileItem(vm.uploader, data);
          fileItem.progress = 100;
          fileItem.isUploaded = true;
          fileItem.isSuccess = true;
          fileItem.inlineUrl = attrs[i].url;
          vm.uploader.queue.push(fileItem);
        }
    }

    function removeAttachment(item, id) {
      if (item.isUploading)
        vm.uploader.cancelItem(item);
      else {
        vm.message.$deleteAttachment(item.file.name);
        item.remove();
      }
      // Hack to allow adding the same file again
      // See https://github.com/nervgh/angular-file-upload/issues/671
      var element = $window.document.getElementById(id);
      if (element)
        angular.element(element).prop('value', null);
    }

    function cancel() {
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      if (vm.message.isNew && vm.message.attachmentAttrs)
        vm.message.$mailbox.$deleteMessages([vm.message]);

      $mdDialog.cancel();
    }

    function save() {
      var ctrls = $parentControllers();
      vm.message.$save().then(function(data) {
        vm.message.$rawSource = null;
        if (ctrls.draftMailboxCtrl) {
          // We're saving a draft from a popup window.
          // Reload draft mailbox
          ctrls.draftMailboxCtrl.selectedFolder.$filter().then(function() {
            if (ctrls.draftMessageCtrl) {
              // Reload selected message
              ctrls.draftMessageCtrl.$state.go('mail.account.mailbox.message', { messageId: vm.message.uid });
            }
          });
        }
        $mdToast.show(
          $mdToast.simple()
            .content(l('Your email has been saved'))
            .position('top right')
            .hideDelay(3000));
      });
    }

    function send() {
      var ctrls = $parentControllers();

      vm.sendState = 'sending';
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      vm.message.$send().then(function(data) {
        vm.sendState = 'sent';
        if (ctrls.draftMailboxCtrl) {
          // We're sending a draft from a popup window and the draft mailbox is opened.
          // Reload draft mailbox
          ctrls.draftMailboxCtrl.selectedFolder.$filter().then(function() {
            if (ctrls.draftMessageCtrl) {
              // Close draft
              ctrls.draftMessageCtrl.close();
            }
          });
        }
        if (ctrls.originMailboxCtrl) {
          // We're sending a draft from a popup window and the original mailbox is opened.
          // Reload mailbox
          ctrls.originMailboxCtrl.selectedFolder.$filter();
        }
        $mdToast.show(
          $mdToast.simple()
            .content(l('Your email has been sent'))
            .position('top right')
            .hideDelay(3000));

        // Let the user see the succesfull message before closing the dialog
        $timeout($mdDialog.hide, 1000);
      }, function(response) {
        vm.sendState = 'error';
        vm.errorMessage = response.data? response.data.message : response.statusText;
      });
    }

    function toggleFullscreen() {
      vm.isFullscreen = !vm.isFullscreen;
    }

    function contactFilter($query) {
      return AddressBook.$filterAll($query).then(function(cards) {
        // Divide the matching cards by email addresses so the user can select
        // the recipient address of her choice
        var explodedCards = [];
        _.forEach(_.invokeMap(cards, 'explode'), function(manyCards) {
          _.forEach(manyCards, function(card) {
            explodedCards.push(card);
          });
        });
        // Remove duplicates
        return _.uniqBy(explodedCards, function(card) {
          return card.$$fullname + ' ' + card.$$email;
        });
      });
    }

    function addRecipient(contact, field) {
      var recipients, recipient, list;

      recipients = vm.message.editable[field];

      if (angular.isString(contact)) {
        _.forEach(contact.split(/[,;]/), function(address) {
          recipients.push(address);
        });
        return null;
      }

      if (contact.$isList({expandable: true})) {
        // If the list's members were already fetch, use them
        if (angular.isDefined(contact.refs) && contact.refs.length) {
          _.forEach(contact.refs, function(ref) {
            if (ref.email.length)
              recipients.push(ref.$shortFormat());
          });
        }
        else {
          list = Card.$find(contact.container, contact.c_name);
          list.$id().then(function(listId) {
            _.forEach(list.refs, function(ref) {
              if (ref.email.length)
                recipients.push(ref.$shortFormat());
            });
          });
        }
      }
      else {
        recipient = contact.$shortFormat();
      }

      if (recipient)
        return recipient;
      else
        return null;
    }

    // Drafts autosaving
    function autosaveDrafts() {
      vm.message.$save();
      if (Preferences.defaults.SOGoMailAutoSave)
        vm.autosave = $timeout(vm.autosaveDrafts, Preferences.defaults.SOGoMailAutoSave*1000*60);
    }

    // Read user's defaults
    Preferences.ready().then(function() {
      if (Preferences.defaults.SOGoMailAutoSave)
        // Enable auto-save of draft
        vm.autosave = $timeout(vm.autosaveDrafts, Preferences.defaults.SOGoMailAutoSave*1000*60);
      // Set the locale of CKEditor
      vm.localeCode = Preferences.defaults.LocaleCode;
    });
  }

  SendMessageToastController.$inject = ['$scope', '$mdToast'];
  function SendMessageToastController($scope, $mdToast) {
    $scope.closeToast = function() {
      $mdToast.hide();
    };
  }

  angular
    .module('SOGo.MailerUI')
    .controller('SendMessageToastController', SendMessageToastController)
    .controller('MessageEditorController', MessageEditorController);

})();
