/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$stateParams', '$mdDialog', '$mdToast', 'FileUploader', 'stateAccounts', 'stateMessage', 'stateRecipients', '$timeout', 'Dialog', 'AddressBook', 'Preferences'];
  function MessageEditorController($stateParams, $mdDialog, $mdToast, FileUploader, stateAccounts, stateMessage, stateRecipients, $timeout, Dialog, AddressBook, Preferences) {
    var vm = this;

    vm.addRecipient = addRecipient;
    vm.autocomplete = {to: {}, cc: {}, bcc: {}};
    vm.autosave = null;
    vm.autosaveDrafts = autosaveDrafts;
    vm.hideCc = true;
    vm.hideBcc = true;
    vm.cancel = cancel;
    vm.send = send;
    vm.removeAttachment = removeAttachment;
    vm.contactFilter = contactFilter;
    vm.identities = _.pluck(_.flatten(_.pluck(stateAccounts, 'identities')), 'full');
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
      // TODO: delete draft?
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      $mdDialog.cancel();
    }

    function send() {
      if (vm.autosave)
        $timeout.cancel(vm.autosave);

      vm.message.$send().then(function(data) {
        $mdDialog.hide();
      }, function(data) {
        $mdToast.show({
            controller: 'SendMessageToastController',
            template: [
              '<md-toast>',
              '   <span flex>' + l(data.message) + '</span>',
              '   <md-button class="md-icon-button md-primary" ng-click="closeToast()">',
              '      <md-icon>close</md-icon>',
              '   </md-button>',
              '</md-toast>'
            ].join(''),
            hideDelay: 2000,
            position: 'top right'
          });
      });
    }

    function contactFilter($query) {
      return AddressBook.$filterAll($query);
    }

    function addRecipient(user) {
      var recipient = [];

      if (angular.isString(user))
        return user;
      if (user.$$fullname)
        recipient.push(user.$$fullname);
      if (user.$$email)
        recipient.push('<' + user.$$email + '>');

      return recipient.join(' ');
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
