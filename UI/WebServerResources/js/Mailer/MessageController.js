/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MessageController.$inject = ['$scope', '$state', '$mdDialog', 'stateAccounts', 'stateAccount', 'stateMailbox', 'stateMessage', 'encodeUriFilter', 'sgFocus', 'Dialog', 'Account', 'Mailbox', 'Message'];
  function MessageController($scope, $state, $mdDialog, stateAccounts, stateAccount, stateMailbox, stateMessage, encodeUriFilter, focus, Dialog, Account, Mailbox, Message) {
    var vm = this, messageDialog = null;

    vm.accounts = stateAccounts;
    vm.account = stateAccount;
    vm.mailbox = stateMailbox;
    vm.message = stateMessage;
    vm.service = Message;
    vm.tags = { searchText: '', selected: '' };
    vm.doDelete = doDelete;
    vm.close = close;
    vm.reply = reply;
    vm.replyAll = replyAll;
    vm.forward = forward;
    vm.edit = edit;
    vm.newMessage = newMessage;
    vm.saveMessage = saveMessage;
    vm.viewRawSource = viewRawSource;

    // Watch the message model "flags" attribute to remove on-the-fly a tag from the IMAP message
    // when removed from the message viewer.
    // TODO: this approach should be reviewed once md-chips supports ng-change.
    $scope.$watchCollection('viewer.message.flags', function(oldTags, newTags) {
      _.each(_.difference(newTags, oldTags), function(tag) {
        vm.message.removeTag(tag);
      });
    });

    function doDelete() {
      stateMailbox.$deleteMessages([stateMessage.uid]).then(function() {
        // Remove message from list of messages
        var index = _.findIndex(stateMailbox.$messages, function(o) {
          return o.uid == stateMessage.uid;
        });
        if (index != -1)
          stateMailbox.$messages.splice(index, 1);
        // Remove message object from scope
        vm.message = null;
        $state.go('mail.account.mailbox', { accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path) });
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
              stateMessage: message,
              stateRecipients: recipients
            }
          })
          .finally(function() {
            messageDialog = null;
          });
      }
    }

    function close() {
      $state.go('mail.account.mailbox', { accountId: stateAccount.id, mailboxId: encodeUriFilter(stateMailbox.path) }).then(function() {
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

    function newMessage($event, recipient) {
      var message = vm.account.$newMessage();
      showMailEditor($event, message, [recipient]);
    }

    function saveMessage() {
      window.location.href = ApplicationBaseURL + '/' + vm.mailbox.id + '/saveMessages?uid=' + vm.message.uid;
    }

    function viewRawSource($event) {
      Message.$$resource.post(vm.message.id, "viewsource").then(function(data) {
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: $event,
          clickOutsideToClose: true,
          escapeToClose: true,
          template: [
            '<md-dialog flex="80" flex-sm="100" aria-label="' + l('View Message Source') + '">',
            '  <md-dialog-content>',
            '    <pre>',
            data,
            '    </pre>',
            '  </md-dialog-content>',
            '  <div class="md-actions">',
            '    <md-button ng-click="close()">' + l('Close') + '</md-button>',
            '  </div>',
            '</md-dialog>'
          ].join(''),
          controller: MessageRawSourceDialogController
        });

        /**
         * @ngInject
         */
        MessageRawSourceDialogController.$inject = ['scope', '$mdDialog'];
        function MessageRawSourceDialogController(scope, $mdDialog) {
          scope.close = function() {
            $mdDialog.hide();
          };
        }
      });
    }
  }
  
  angular
    .module('SOGo.MailerUI')  
    .controller('MessageController', MessageController);                                    
})();
