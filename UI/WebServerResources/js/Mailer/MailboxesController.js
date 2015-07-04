/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  MailboxesController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$mdDialog', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Account', 'Mailbox', 'User', 'stateAccounts'];
  function MailboxesController($scope, $rootScope, $stateParams, $state, $timeout, $mdDialog, focus, encodeUriFilter, Dialog, Settings, Account, Mailbox, User, stateAccounts) {
    $scope.activeUser = Settings.activeUser;
    $scope.accounts = stateAccounts;

    $scope.newFolder = function(parentFolder) {
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
    };
    $scope.delegate = function(account) {
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
        vm.selectedUser = null;
        vm.userToAdd = '';
        vm.searchText = '';
        vm.userFilter = userFilter;
        vm.closeModal = closeModal;
        vm.removeUser = removeUser;
        vm.addUser = addUser;
        vm.selectUser = selectUser;

        function userFilter($query) {
          //return User.$filter($query, folder.$acl.users);
          return User.$filter($query, account.delegates);
        }

        function closeModal() {
          $mdDialog.hide();
        }

        function removeUser(user) {
          account.$removeDelegate(user.uid).then(function() {
            if (user.uid == vm.selectedUser.uid) {
              vm.selectedUser = null;
            }
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'))
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

        function selectUser(user) {
          // Check if it is a different user
          if (vm.selectedUser != user) {
            vm.selectedUser = user;
          }
        }
      }
    };
    $scope.editFolder = function(folder) {
      $scope.editMode = folder.path;
      focus('mailboxName_' + folder.path);
    };
    $scope.revertEditing = function(folder) {
      folder.$reset();
      $scope.editMode = false;
    };
    $scope.selectFolder = function(account, folder) {
      if ($scope.editMode == folder.path)
        return;
      $rootScope.currentFolder = folder;
      $scope.editMode = false;
      $rootScope.message = null;
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(folder.path) });
    };
    $scope.saveFolder = function(folder) {
      folder.$rename();
    };
    $scope.exportMails = function() {
      window.location.href = ApplicationBaseURL + '/' + $rootScope.currentFolder.id + '/exportFolder';
    };
    $scope.confirmDelete = function(folder) {
      if (folder.path != $scope.currentFolder.path) {
        // Counter the possibility to click on the "hidden" secondary button
        $scope.selectFolder(folder.$account, folder);
        return;
      }
      Dialog.confirm(l('Confirmation'), l('Do you really want to move this folder into the trash ?'))
        .then(function() {
          folder.$delete()
            .then(function() {
              $rootScope.currentFolder = null;
              $state.go('mail');
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the mailbox "%{0}".', folder.name),
                           l(data.error));
            });
        });
    };
    $scope.share = function(folder) {
      //if (addressbook.id != vm.service.selectedFolder.id) {
      // Counter the possibility to click on the "hidden" secondary button
      //select(addressbook);
      //  return;
      //}
      // Fetch list of ACL users
      folder.$acl.$users().then(function() {
        // Show ACL editor
        $mdDialog.show({
          templateUrl: folder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: MailboxACLController,
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

      /**
       * @ngInject
       */
      MailboxACLController.$inject = ['$scope', '$mdDialog', 'usersWithACL', 'User', 'folder'];
      function MailboxACLController($scope, $mdDialog, usersWithACL, User, folder) {
        var vm = this;

        vm.users = usersWithACL; // ACL users
        vm.folder = folder;
        vm.selectedUser = null;
        vm.userToAdd = '';
        vm.searchText = '';
        vm.userFilter = userFilter;
        vm.closeModal = closeModal;
        vm.saveModal = saveModal;
        vm.confirmChange = confirmChange;
        vm.removeUser = removeUser;
        vm.addUser = addUser;
        vm.selectUser = selectUser;

        function userFilter($query) {
          return User.$filter($query, folder.$acl.users);
        }

        function closeModal() {
          folder.$acl.$resetUsersRights(); // cancel changes
          $mdDialog.hide();
        }

        function saveModal() {
          folder.$acl.$saveUsersRights().then(function() {
            $mdDialog.hide();
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        }

        function confirmChange(user) {
          var confirmation = user.$confirmRights();
          if (confirmation) {
            Dialog.confirm(l('Warning'), confirmation).catch(function() {
              user.$resetRights(true);
            });
          }
        }

        function removeUser(user) {
          folder.$acl.$removeUser(user.uid).then(function() {
            if (user.uid == vm.selectedUser.uid) {
              vm.selectedUser = null;
            }
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'))
          });
        }

        function addUser(data) {
          if (data) {
            folder.$acl.$addUser(data).then(function() {
              vm.userToAdd = '';
              vm.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
        }

        function selectUser(user) {
          // Check if it is a different user
          if (vm.selectedUser != user) {
            vm.selectedUser = user;
            vm.selectedUser.$rights();
          }
        }
      }
    };
    $scope.unselectMessages = function() {
      _.each($rootScope.mailbox.$messages, function(message) { message.selected = false; });
    };

    $scope.confirmDeleteSelectedMessages = function() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected messages?'))
        .then(function() {
          // User confirmed the deletion
          var selectedMessages = _.filter($rootScope.mailbox.$messages, function(message) { return message.selected });
          var selectedUIDs = _.pluck(selectedMessages, 'uid');
          $rootScope.mailbox.$deleteMessages(selectedUIDs).then(function() {
            $rootScope.mailbox.$messages = _.difference($rootScope.mailbox.$messages, selectedMessages);
          });
        },  function(data, status) {
          // Delete failed
        });
    };

    $scope.copySelectedMessages = function(folder) {
      var selectedMessages = _.filter($rootScope.mailbox.$messages, function(message) { return message.selected });
      var selectedUIDs = _.pluck(selectedMessages, 'uid');
      $rootScope.mailbox.$copyMessages(selectedUIDs, '/' + folder).then(function() {
        // TODO: refresh target mailbox?
      }, function(error) {
        Dialog.alert(l('Error'), error.error);
      });
    };

    // $scope.moveSelectedMessages = function(folder) {
    //   var selectedMessages = _.filter($rootScope.mailbox.$messages, function(message) { return message.selected });
    //   var selectedUIDs = _.pluck(selectedMessages, 'uid');
    //   $rootScope.mailbox.$moveMessages(selectedUIDs, '/' + folder).then(function() {
    //     // TODO: refresh target mailbox?
    //     $rootScope.mailbox.$messages = _.difference($rootScope.mailbox.$messages, selectedMessages);
    //   });
    // };

    if ($state.current.name == 'mail' && $scope.accounts.length > 0 && $scope.accounts[0].$mailboxes.length > 0) {
      // Redirect to first mailbox of first account if no mailbox is selected
      var account = $scope.accounts[0];
      var mailbox = account.$mailboxes[0];
      $state.go('mail.account.mailbox', { accountId: account.id, mailboxId: encodeUriFilter(mailbox.path) });
    }
  }

  angular
    .module('SOGo.MailerUI')  
    .controller('MailboxesController', MailboxesController);                                    
})();

