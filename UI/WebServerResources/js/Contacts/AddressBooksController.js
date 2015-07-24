/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBooksController.$inject = ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'User', 'stateAddressbooks'];
  function AddressBooksController($state, $scope, $rootScope, $stateParams, $timeout, $mdDialog, focus, Card, AddressBook, Dialog, Settings, User, stateAddressbooks) {
    var vm = this;

    vm.activeUser = Settings.activeUser;
    vm.service = AddressBook;
    vm.select = select;
    vm.newAddressbook = newAddressbook;
    vm.edit = edit;
    vm.revertEditing = revertEditing;
    vm.save = save;
    vm.confirmDelete = confirmDelete;
    vm.importCards = importCards;
    vm.exportCards = exportCards;
    vm.showLinks = showLinks;
    vm.share = share;
    vm.subscribeToFolder = subscribeToFolder;

    function select(folder) {
      vm.editMode = false;
      $state.go('app.addressbook', {addressbookId: folder.id});
    }

    function newAddressbook() {
      Dialog.prompt(l('New addressbook'),
                    l('Name of new addressbook'))
        .then(function(name) {
          var addressbook = new AddressBook(
            {
              name: name,
              isEditable: true,
              isRemote: false,
              owner: UserLogin
            }
          );
          AddressBook.$add(addressbook);
        });
    }

    function edit(folder) {
      if (!folder.isRemote) {
        vm.editMode = folder.id;
        vm.originalAddressbook = angular.extend({}, folder.$omit());
        focus('addressBookName_' + folder.id);
      }
    }

    function revertEditing(folder) {
      folder.name = vm.originalAddressbook.name;
      vm.editMode = false;
    }

    function save(folder) {
      var name = folder.name;
      if (name && name.length > 0 && name != vm.originalAddressbook.name) {
        folder.$rename(name)
          .then(function(data) {
            vm.editMode = false;
          }, function(data, status) {
            Dialog.alert(l('Warning'), data);
          });
      }
    }

    function confirmDelete() {
      if (vm.service.selectedFolder.isSubscription) {
        // Unsubscribe without confirmation
        vm.service.selectedFolder.$delete()
          .then(function() {
            vm.service.selectedFolder = null;
            $state.go('app.addressbook', { addressbookId: 'personal' });
          }, function(data, status) {
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           vm.service.selectedFolder.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                       vm.service.selectedFolder.name))
          .then(function() {
            return vm.service.selectedFolder.$delete();
          })
          .then(function() {
            vm.service.selectedFolder = null;
            return true;
          })
          .catch(function(data, status) {
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           vm.service.selectedFolder.name),
                         l(data.error));
          });
      }
    }

    function importCards() {

    }

    function exportCards() {
      window.location.href = ApplicationBaseURL + '/' + vm.service.selectedFolder.id + '/exportFolder';
    }

    function showLinks(selectedFolder) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: selectedFolder.id + '/links',
        locals: {
        },
        controller: LinksDialogController
      });
      
      /**
       * @ngInject
       */
      LinksDialogController.$inject = ['scope', '$mdDialog'];
      function LinksDialogController(scope, $mdDialog) {
        scope.close = function() {
          $mdDialog.hide();
        };
      }
    }

    function share(addressbook) {
      if (addressbook.id != vm.service.selectedFolder.id) {
        // Counter the possibility to click on the "hidden" secondary button
        select(addressbook);
        return;
      }
      // Fetch list of ACL users
      addressbook.$acl.$users().then(function() {
        // Show ACL editor
        $mdDialog.show({
          templateUrl: addressbook.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: AddressBookACLController,
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: addressbook.$acl.users,
            User: User,
            folder: addressbook
          }
        });
      });

      /**
       * @ngInject
       */
      AddressBookACLController.$inject = ['$scope', '$mdDialog', 'usersWithACL', 'User', 'folder'];
      function AddressBookACLController($scope, $mdDialog, usersWithACL, User, folder) {
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
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
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
    }

    /**
     * subscribeToFolder - Callback of sgSubscribe directive
     */
    function subscribeToFolder(addressbookData) {
      console.debug('subscribeToFolder ' + addressbookData.owner + addressbookData.name);
      AddressBook.$subscribe(addressbookData.owner, addressbookData.name).catch(function(data) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }
  }

  angular
    .module('SOGo.ContactsUI')
    .controller('AddressBooksController', AddressBooksController);
})();
