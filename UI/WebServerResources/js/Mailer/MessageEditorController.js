/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$window', '$stateParams', '$mdConstant', '$mdDialog', '$mdToast', 'FileUploader', 'stateAccounts', 'stateMessage', 'stateRecipients', 'encodeUriFilter', '$timeout', 'Dialog', 'AddressBook', 'Card', 'Preferences'];
  function MessageEditorController($window, $stateParams, $mdConstant, $mdDialog, $mdToast, FileUploader, stateAccounts, stateMessage, stateRecipients, encodeUriFilter, $timeout, Dialog, AddressBook, Card, Preferences) {
    var vm = this, semicolon = 186;

    vm.addRecipient = addRecipient;
    vm.autocomplete = {to: {}, cc: {}, bcc: {}};
    vm.autosave = null;
    vm.autosaveDrafts = autosaveDrafts;
    vm.hideCc = true;
    vm.hideBcc = true;
    vm.cancel = cancel;
    vm.save = save;
    vm.send = send;
    vm.removeAttachment = removeAttachment;
    vm.contactFilter = contactFilter;
    vm.identities = _.pluck(_.flatten(_.pluck(stateAccounts, 'identities')), 'full');
    vm.recipientSeparatorKeys = [$mdConstant.KEY_CODE.ENTER, $mdConstant.KEY_CODE.TAB, $mdConstant.KEY_CODE.COMMA, semicolon];
    vm.uploader = new FileUploader({
      url: stateMessage.$absolutePath({asDraft: true}) + '/save',
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
        //console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
      }
    });

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

    if (angular.isDefined(stateRecipients)) {
      vm.message.editable.to = _.union(vm.message.editable.to, _.pluck(stateRecipients, 'full'));
    }

    /**
     * If this is a popup window, retrieve the mailbox controller of the parent window.
     */
    function $parentControllers() {
      var originMessage, ctrls = {};
      if ($window.opener) {
        if ($window.opener.$mailboxController) {
          if ($window.opener.$mailboxController.selectedFolder.type == 'draft') {
            ctrls.draftMailboxCtrl = $window.opener.$mailboxController;
            if ($window.opener.$messageController &&
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
      return ctrls;
    }

    function addAttachments() {
      // Add existing attached files to uploader
      var i, data, fileItem;
      if (vm.message.attachmentAttrs)
        for (i = 0; i < vm.message.attachmentAttrs.length; i++) {
          data = {
            name: vm.message.attachmentAttrs[i].filename,
            type: vm.message.attachmentAttrs[i].mimetype,
            size: parseInt(vm.message.attachmentAttrs[i].size)
          };
          fileItem = new FileUploader.FileItem(vm.uploader, data);
          fileItem.progress = 100;
          fileItem.isUploaded = true;
          fileItem.isSuccess = true;
          fileItem.inlineUrl = vm.message.attachmentAttrs[i].url;
          vm.uploader.queue.push(fileItem);
        }
    }

    function removeAttachment(item) {
      if (item.isUploading)
        vm.uploader.cancelItem(item);
      else {
        vm.message.$deleteAttachment(item.file.name);
        item.remove();
      }
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
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      vm.message.$send().then(function(data) {
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
        $mdDialog.hide();
      });
    }

    function contactFilter($query) {
      AddressBook.$filterAll($query);
      return AddressBook.$cards;
    }

    function addRecipient(contact, field) {
      var recipients, recipient, list;

      if (angular.isString(contact))
        return contact;

      recipients = vm.message.editable[field];

      if (contact.$isList()) {
        // If the list's members were already fetch, use them
        if (angular.isDefined(contact.refs) && contact.refs.length) {
          _.each(contact.refs, function(ref) {
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
