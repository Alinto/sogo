/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$state', '$timeout', '$mdDialog', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Account', 'Mailbox', 'User', 'Preferences', 'stateAccounts'];
  function MailboxesController($state, $timeout, $mdDialog, focus, encodeUriFilter, Dialog, Settings, Account, Mailbox, User, Preferences, stateAccounts) {
    var vm = this,
        account,
        mailbox;

    vm.service = Mailbox;
    vm.accounts = stateAccounts;
    vm.newFolder = newFolder;
    vm.delegate = delegate;
    vm.editFolder = editFolder;
    vm.revertEditing = revertEditing;
    vm.selectFolder = selectFolder;
    vm.saveFolder = saveFolder;
    vm.compactFolder = compactFolder;
    vm.emptyTrashFolder = emptyTrashFolder;
    vm.exportMails = exportMails;
    vm.confirmDelete = confirmDelete;
    vm.markFolderRead = markFolderRead;
    vm.share = share;
    vm.metadataForFolder = metadataForFolder;
    vm.setFolderAs = setFolderAs;
    vm.refreshUnseenCount = refreshUnseenCount;

    if ($state.current.name == 'mail' && vm.accounts.length > 0 && vm.accounts[0].$mailboxes.length > 0) {
      // Redirect to first mailbox of first account if no mailbox is selected
      account = vm.accounts[0];
      mailbox = account.$mailboxes[0];
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
    }

    function newFolder(parentFolder) {
      Dialog.prompt(l('New folder'),
                    l('Enter the new name of your folder :'))
        .then(function(name) {
          parentFolder.$newMailbox(parentFolder.id, name)
            .then(function() {
              // success
            }, function(data, status) {
              Dialog.alert(l('An error occured while creating the mailbox "%{0}".', name),
                           l(data.error));
            });
        });
    }

    function delegate(account) {
      $mdDialog.show({
        templateUrl: account.id + '/delegation', // UI/Templates/MailerUI/UIxMailUserDelegation.wox
        controller: MailboxDelegationController,
        controllerAs: 'delegate',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          User: User,
          account: account
        }
      });

      /**
       * @ngInject
       */
      MailboxDelegationController.$inject = ['$scope', '$mdDialog', 'User', 'account'];
      function MailboxDelegationController($scope, $mdDialog, User, account) {
        var vm = this;

        vm.users = account.delegates;
        vm.account = account;
        vm.userToAdd = '';
        vm.searchText = '';
        vm.userFilter = userFilter;
        vm.closeModal = closeModal;
        vm.removeUser = removeUser;
        vm.addUser = addUser;

        function userFilter($query) {
          return User.$filter($query, account.delegates);
        }

        function closeModal() {
          $mdDialog.hide();
        }

        function removeUser(user) {
          account.$removeDelegate(user.uid).catch(function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        }

        function addUser(data) {
          if (data) {
            account.$addDelegate(data).then(function() {
              vm.userToAdd = '';
              vm.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
        }
      }
    } // delegate

    function editFolder(folder) {
      vm.editMode = folder.path;
      focus('mailboxName_' + folder.path);
    }

    function revertEditing(folder) {
      folder.$reset();
      vm.editMode = false;
    }

    function selectFolder(account, folder) {
      if (vm.editMode == folder.path)
        return;
      vm.editMode = false;
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
    }

    function saveFolder(folder) {
      folder.$rename();
    }

    function compactFolder(folder) {
      folder.$compact().then(function() {
        // Success
      }, function(error) {
        Dialog.alert(l('Warning'), error);
      });
    }

    function emptyTrashFolder(folder) {
      folder.$emptyTrash().then(function() {
        // Success - remove all messages from the mailbox
        folder.$messages = [];
        folder.uidsMap = {};
        folder.unseenCount = 0;
      }, function(error) {
        Dialog.alert(l('Warning'), error);
      });
    }

    function exportMails(folder) {
      window.location.href = ApplicationBaseURL + '/' + folder.id + '/exportFolder';
    }

    function confirmDelete(folder) {
      Dialog.confirm(l('Confirmation'), l('Do you really want to move this folder into the trash ?'))
        .then(function() {
          folder.$delete()
            .then(function() {
              $state.go('mail');
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', folder.name),
                           l(data.error));
            });
        });
    }

    function markFolderRead(folder) {
      folder.$markAsRead();
    }

    function share(folder) {
      // Fetch list of ACL users
      folder.$acl.$users().then(function() {
        // Show ACL editor
        $mdDialog.show({
          templateUrl: folder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: 'AclController', // from the ng module SOGo.Common
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: folder.$acl.users,
            User: User,
            folder: folder
          }
        });
      });
    } // share

    function metadataForFolder(folder) {
      if (folder.type == 'inbox')
        return {name: folder.name, icon:'inbox'};
      else if (folder.type == 'draft')
        return {name: l('DraftsFolderName'), icon: 'drafts'};
      else if (folder.type == 'sent')
        return {name: l('SentFolderName'), icon: 'send'};
      else if (folder.type == 'trash')
        return {name: l('TrashFolderName'), icon: 'delete'};
      else if (folder.type == 'additional')
        return {name: folder.name, icon: 'folder_shared'};

      //if ($rootScope.currentFolder == folder)
      //  return 'folder_open';

      return {name: folder.name, icon: 'folder'};
    }

    function setFolderAs(folder, type) {
      folder.$setFolderAs(type).then(function() {
        folder.$account.$getMailboxes({reload: true});
      }, function(error) {
        Dialog.alert(l('Warning'), error);
      });
    }

    function refreshUnseenCount() {
      var unseenCountFolders = window.unseenCountFolders;

      _.forEach(vm.accounts, function(account) {

        // Always include the INBOX
        if (!_.includes(unseenCountFolders, account.id + '/folderINBOX'))
          unseenCountFolders.push(account.id + '/folderINBOX');

        _.forEach(account.$$flattenMailboxes, function(mailbox) {
          if (angular.isDefined(mailbox.unseenCount) &&
              !_.includes(unseenCountFolders, mailbox.id))
            unseenCountFolders.push(mailbox.id);
        });
      });

      Account.$$resource.post('', 'unseenCount', {mailboxes: unseenCountFolders}).then(function(data) {
        _.forEach(vm.accounts, function(account) {
          _.forEach(account.$$flattenMailboxes, function(mailbox) {
            if (data[mailbox.id])
              mailbox.unseenCount = data[mailbox.id];
          });
        });
      });

      Preferences.ready().then(function() {
        var refreshViewCheck = Preferences.defaults.SOGoRefreshViewCheck;
        if (refreshViewCheck && refreshViewCheck != 'manually')
          $timeout(vm.refreshUnseenCount, refreshViewCheck.timeInterval()*1000);
      });
    }

    vm.refreshUnseenCount();
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxesController', MailboxesController);                                    
})();

