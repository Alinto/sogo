/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$scope', '$window', '$stateParams', '$mdConstant', '$mdUtil', '$mdDialog', '$mdToast', 'FileUploader', 'stateParent', 'stateAccount', 'stateMessage', 'onCompletePromise', 'encodeUriFilter', '$timeout', 'sgFocus', 'Dialog', 'AddressBook', 'Card', 'Preferences'];
  function MessageEditorController($scope, $window, $stateParams, $mdConstant, $mdUtil, $mdDialog, $mdToast, FileUploader, stateParent, stateAccount, stateMessage, onCompletePromise, encodeUriFilter, $timeout, focus, Dialog, AddressBook, Card, Preferences) {
    var vm = this;

    this.$onInit = function() {
      $scope.isPopup = stateParent.isPopup;
      vm.addRecipient = addRecipient;
      vm.autocomplete = {to: {}, cc: {}, bcc: {}};
      vm.autosave = null;
      vm.autosaveDrafts = autosaveDrafts;
      vm.cancel = cancel;
      vm.contactFilter = contactFilter;
      vm.isFullscreen = false;
      vm.hideBcc = (stateMessage.editable.bcc.length === 0);
      vm.hideCc = (stateMessage.editable.cc.length === 0);
      vm.identities = _.uniq(_.map(stateAccount.identities, 'full'));
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
      this.firstFocus = true;

      _initFileUploader();

      // Read user's defaults
      if (Preferences.defaults.SOGoMailAutoSave)
        // Enable auto-save of draft
        vm.autosave = $timeout(vm.autosaveDrafts, Preferences.defaults.SOGoMailAutoSave*1000*60);
      // Set the locale of CKEditor
      vm.localeCode = Preferences.defaults.LocaleCode;

      this.replyPlacement = Preferences.defaults.SOGoMailReplyPlacement;
      if (this.message.origin && this.message.origin.action == 'forward') {
        // For forwards, place caret at top unconditionally
        this.replyPlacement = 'above';
      }

      // Destroy file uploader when the controller is being deactivated
      $scope.$on('$destroy', function() { vm.uploader.destroy(); });

      if ($stateParams.actionName == 'reply') {
        stateMessage.$reply().then(function(msgObject) {
          vm.message = msgObject;
          vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length === 0);
          vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length === 0);
          _updateFileUploader();
        });
      }
      else if ($stateParams.actionName == 'replyall') {
        stateMessage.$replyAll().then(function(msgObject) {
          vm.message = msgObject;
          vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length === 0);
          vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length === 0);
          _updateFileUploader();
        });
      }
      else if ($stateParams.actionName == 'forward') {
        stateMessage.$forward().then(function(msgObject) {
          vm.message = msgObject;
          _updateFileUploader();
          _addAttachments();
        });
      }
      else if (angular.isDefined(stateMessage)) {
        vm.message = stateMessage;
        _updateFileUploader();
        _addAttachments();
      }
    };

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

    function _initFileUploader() {
      vm.uploader = new FileUploader({
        url: vm.message.$absolutePath({asDraft: true, withResourcePath: true}) + '/save',
        autoUpload: true,
        alias: 'attachments',
        removeAfterUpload: false,
        // onProgressItem: function(item, progress) {
        //   console.debug(item); console.debug(progress);
        // },
        onSuccessItem: function(item, response, status, headers) {
          vm.message.$setUID(response.uid);
          vm.message.$reload({asDraft: false});
          item.inlineUrl = response.lastAttachmentAttrs[0].url;
          //console.debug(item); console.debug('success = ' + JSON.stringify(response, undefined, 2));
        },
        onCancelItem: function(item, response, status, headers) {
          //console.debug(item); console.debug('cancel = ' + JSON.stringify(response, undefined, 2));
          // We remove the attachment
          vm.message.$deleteAttachment(item.file.name);
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
    }

    function _updateFileUploader() {
      vm.uploader.url = vm.message.$absolutePath({asDraft: true, withResourcePath: true}) + '/save';
    }

    function _addAttachments() {
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
      vm.sendState = 'sending';
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      vm.message.$send().then(function(data) {
        var ctrls = $parentControllers();
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
        $timeout(function() {
          vm.sendState = 'error';
          vm.errorMessage = response.data? response.data.message : response.statusText;
        });
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
      var recipients, recipient, list, i, address;
      var emailRE = /([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)/i;

      recipients = vm.message.editable[field];

      if (angular.isString(contact)) {
        // Examples that are handled:
        //   Smith, John <john@smith.com>
        //   <john@appleseed.com>;<foo@bar.com>
        //   foo@bar.com abc@xyz.com
        address = '';
        for (i = 0; i < contact.length; i++) {
          if ((contact.charCodeAt(i) ==  9 ||   // tab
               contact.charCodeAt(i) == 32 ||   // space
               contact.charCodeAt(i) == 44 ||   // ,
               contact.charCodeAt(i) == 59) &&  // ;
              emailRE.test(address)) {
            recipients.push(address);
            address = '';
          }
          else {
            address += contact.charAt(i);
          }
        }
        if (address)
          recipients.push(address);
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

    this.isNew = function () {
      return typeof this.message.origin == 'undefined';
    };

    this.onTextFocus = function ($event) {
      var textArea = $event.target;

      function adjustOffset(val, offset) {
        var newOffset = offset, matches;
        if (val.indexOf("\r\n") > -1) {
          matches = val.replace(/\r\n/g, "\n").slice(0, offset).match(/\n/g);
          newOffset -= matches ? matches.length - 1 : 0;
        }
        return newOffset;
      }

      if (this.firstFocus) {
        onCompletePromise().then(function(element) {
          var textContent = angular.element(textArea).val(),
              hasSignature = (Preferences.defaults.SOGoMailSignature &&
                              Preferences.defaults.SOGoMailSignature.length > 0),
              signatureLength = 0,
              sigLimit,
              caretPosition;

          if (vm.replyPlacement == 'above') {
            textArea.setCaretTo(0);
            element.find('md-dialog-content')[0].scrollTop = 0;
          }
          else {
            if (hasSignature) {
              sigLimit = textContent.lastIndexOf("--");
              if (sigLimit > -1)
                signatureLength = (textContent.length - sigLimit);
            }
            caretPosition = textContent.length - signatureLength;
            caretPosition = adjustOffset(textContent, caretPosition);
            if (hasSignature)
              caretPosition -= 2;
            textArea.setCaretTo(caretPosition);
          }
        });

        this.firstFocus = false;
      }
    };

    this.onHTMLFocus = function ($event) {
      var caretAtTop = (this.replyPlacement == 'above');

      if (this.firstFocus) {
        onCompletePromise().then(function(element) {
          var selected = $event.editor.getSelection(),
              selected_ranges = selected.getRanges(),
              children = $event.editor.document.getBody().getChildren(),
              node;

          if (caretAtTop) {
            node = children.getItem(0);
          }
          else {
            // Search for signature starting from bottom
            node = children.getItem(children.count() - 1);
            while (true) {
              var x = node.getPrevious();
              if (x === null) {
                break;
              }
              if (x.getText() == '--') {
                node = x.getPrevious().getPrevious();
                break;
              }
              node = x;
            }
          }
          selected.selectElement(node);

          // Place the caret
          if (caretAtTop)
            selected.scrollIntoView(); // top
          selected_ranges = selected.getRanges();
          selected_ranges[0].collapse(true);
          selected.selectRanges(selected_ranges);
          if (!caretAtTop)
            selected.scrollIntoView(); // bottom
        });

        this.firstFocus = false;
      }
    };
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
