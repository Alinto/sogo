/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageEditorController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', '$q', 'FileUploader', 'stateAccounts', 'stateMessage', '$timeout', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox', 'AddressBook'];
  function MessageEditorController($scope, $rootScope, $stateParams, $state, $q, FileUploader, stateAccounts, stateMessage, $timeout, encodeUriFilter, focus, Dialog, Account, Mailbox, AddressBook) {
    $scope.autocomplete = {to: {}, cc: {}, bcc: {}};
    $scope.hideCc = true;
    $scope.hideBcc = true;
    $scope.hideAttachments = true;
    if ($stateParams.actionName == 'reply') {
      stateMessage.$reply().then(function(msgObject) {
        console.debug("foo");

        $scope.message = msgObject;
        $scope.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length == 0);
        $scope.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length == 0);
        $scope.hideAttachments = true;
      });
    }
    else if ($stateParams.actionName == 'replyall') {
      stateMessage.$replyAll().then(function(msgObject) {
        $scope.message = msgObject;
        $scope.hideCc = (!msgObject.editable.cc || msgObject.editable.cc.length == 0);
        $scope.hideBcc = (!msgObject.editable.bcc || msgObject.editable.bcc.length == 0);
        $scope.hideAttachments = true;
      });
    }
    else if ($stateParams.actionName == 'forward') {
      stateMessage.$forward().then(function(msgObject) {
        $scope.message = msgObject;
        $scope.hideCc = true;
        $scope.hideBcc = true;
        $scope.hideAttachments = (!msgObject.editable.attachmentAttrs || msgObject.editable.attachmentAttrs.length == 0);
      });
    }
    else if (angular.isDefined(stateMessage)) {
      $scope.message = stateMessage;
    }
    $scope.identities = _.pluck(_.flatten(_.pluck(stateAccounts, 'identities')), 'full');
    $scope.cancel = function() {
      if ($scope.mailbox)
        $state.go('mail.account.mailbox', { accountId: $scope.mailbox.$account.id, mailboxId: encodeUriFilter($scope.mailbox.path) });
      else
        $state.go('mail');
    };
    $scope.send = function(message) {
      message.$send().then(function(data) {
        $rootScope.message = null;
        $state.go('mail');
      }, function(data) {
        console.debug('failure ' + JSON.stringify(data, undefined, 2));
      });
    };
    $scope.userFilter = function($query) {
      var deferred = $q.defer();
      AddressBook.$filterAll($query).then(function(results) {
        deferred.resolve(_.invoke(results, '$shortFormat', $query));
      });
      return deferred.promise;
    };
    $scope.uploader = new FileUploader({
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
      onErrorItem: function(item, response, status, headers) {
        console.debug(item); console.debug('error = ' + JSON.stringify(response, undefined, 2));
      }
    });
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MessageEditorController', MessageEditorController);                                    
})();
