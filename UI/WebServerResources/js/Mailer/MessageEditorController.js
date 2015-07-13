/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$stateParams', '$state', '$q', 'FileUploader', 'stateAccounts', 'stateMessage', '$timeout', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox', 'AddressBook'];
  function MessageEditorController($stateParams, $state, $q, FileUploader, stateAccounts, stateMessage, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox, AddressBook) {
    var vm = this;

    vm.autocomplete = {to: {}, cc: {}, bcc: {}};
    vm.hideCc = true;
    vm.hideBcc = true;
    vm.cancel = cancel;
    vm.send = send;
    vm.userFilter = userFilter;
    vm.identities = _.pluck(_.flatten(_.pluck(stateAccounts, 'identities')), 'full');
    vm.uploader = new FileUploader({
      url: stateMessage.$absolutePath({asDraft: true}) + '/save',
      autoUpload: true,
      alias: 'attachments',
      onProgressItem: function(item, progress) {
        console.debug(item); console.debug(progress);
      },
      onSuccessItem: function(item, response, status, headers) {
        stateMessage.$setUID(response.uid);
        stateMessage.$reload();
        console.debug(item); console.debug('success = ' + JSON.stringify(response, undefined, 2));
      },
      onCancelItem: function(item, response, status, headers) {
        console.debug(item); console.debug('cancel = ' + JSON.stringify(response, undefined, 2));

        // We remove the attachment
        stateMessage.$deleteAttachment(item.file.name);
        this.removeFromQueue(item);
      },
      onErrorItem: function(item, response, status, headers) {
        console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
      }
    });

    if ($stateParams.actionName == 'reply') {
      stateMessage.$reply().then(function(msgObject) {
        vm.message = msgObject;
        vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length == 0);
        vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length == 0);
      });
    }
    else if ($stateParams.actionName == 'replyall') {
      stateMessage.$replyAll().then(function(msgObject) {
        vm.message = msgObject;
        vm.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length == 0);
        vm.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length == 0);
      });
    }
    else if ($stateParams.actionName == 'forward') {
      stateMessage.$forward().then(function(msgObject) {
        vm.message = msgObject;
      });
    }
    else if (angular.isDefined(stateMessage)) {
      vm.message = stateMessage;
    }

    function cancel() {
      // TODO: delete draft?
      if ($state.params.mailboxId)
        $state.go('mail.account.mailbox', { accountId: $state.params.accountId, mailboxId: $state.params.mailboxId });
      else
        $state.go('mail');
    }

    function send() {
      vm.message.$send().then(function(data) {
        $state.go('mail');
      }, function(data) {
        console.debug('failure ' + JSON.stringify(data, undefined, 2));
      });
    }

    function userFilter($query) {
      var deferred = $q.defer();
      AddressBook.$filterAll($query).then(function(results) {
        deferred.resolve(_.invoke(results, '$shortFormat', $query));
      });
      return deferred.promise;
    }
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MessageEditorController', MessageEditorController);                                    
})();
