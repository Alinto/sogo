/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AddressBooksController.$inject = ['$state', '$scope', '$rootScope', '$stateParams', '$timeout', '$q', '$mdDialog', 'sgFocus', 'Card', 'AddressBook', 'Dialog', 'sgSettings', 'User', 'stateAddressbooks'];
  function AddressBooksController($state, $scope, $rootScope, $stateParams, $timeout, $q, $mdDialog, focus, Card, AddressBook, Dialog, Settings, User, stateAddressbooks) {
    var currentAddressbook;

    $scope.activeUser = Settings.activeUser;
    $scope.service = AddressBook;

    // $scope functions
    $scope.select = function(folder) {
      $scope.editMode = false;
      $state.go('app.addressbook', {addressbookId: folder.id});
    };
    $scope.newAddressbook = function() {
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
    };
    $scope.edit = function(index, folder) {
      if (!folder.isRemote) {
        $scope.editMode = folder.id;
        $scope.originalAddressbook = angular.extend({}, folder.$omit());
        focus('addressBookName_' + folder.id);
      }
    };
    $scope.revertEditing = function(folder) {
      folder.name = $scope.originalAddressbook.name;
      $scope.editMode = false;
    };
    $scope.save = function(folder) {
      var name = folder.name;
      if (name && name.length > 0 && name != $scope.originalAddressbook.name) {
        folder.$rename(name)
          .then(function(data) {
            $scope.editMode = false;
          }, function(data, status) {
            Dialog.alert(l('Warning'), data);
          });
      }
    };
    $scope.confirmDelete = function() {
      if ($scope.currentFolder.isSubscription) {
        // Unsubscribe without confirmation
        $rootScope.currentFolder.$delete()
          .then(function() {
            $rootScope.currentFolder = null;
            $state.go('app.addressbook', { addressbookId: 'personal' });
          }, function(data, status) {
            Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                           $rootScope.currentFolder.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?',
                                       $scope.currentFolder.name))
          .then(function() {
            $rootScope.currentFolder.$delete()
              .then(function() {
                $rootScope.currentFolder = null;
              }, function(data, status) {
                Dialog.alert(l('An error occured while deleting the addressbook "%{0}".',
                               $rootScope.currentFolder.name),
                             l(data.error));
              });
          });
      }
    };
    $scope.importCards = function() {

    };
    $scope.exportCards = function() {
      window.location.href = ApplicationBaseURL + '/' + $scope.currentFolder.id + '/exportFolder';
    };
    $scope.share = function(folder) {
      if (folder.id != $scope.currentFolder.id) {
        // Counter the possibility to click on the "hidden" secondary button
        $scope.select(folder);
        return;
      }
      $mdDialog.show({
        templateUrl: $scope.currentFolder.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
        controller: AddressBookACLController,
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          usersWithACL: $scope.currentFolder.$acl.$users(),
          User: User,
          stateAddressbook: $scope.currentFolder,
          $q: $q
        }
      });
      /**
       * @ngInject
       */
      AddressBookACLController.$inject = ['$scope', '$mdDialog', 'usersWithACL', 'User', 'stateAddressbook', '$q'];
      function AddressBookACLController($scope, $mdDialog, usersWithACL, User, stateAddressbook, $q) {
        $scope.users = usersWithACL; // ACL users
        $scope.stateAddressbook = stateAddressbook;
        $scope.userToAdd = '';
        $scope.searchText = '';
        $scope.userFilter = function($query) {
          return User.$filter($query);
        };
        $scope.closeModal = function() {
          stateAddressbook.$acl.$resetUsersRights(); // cancel changes
          $mdDialog.hide();
        };
        $scope.saveModal = function() {
          stateAddressbook.$acl.$saveUsersRights().then(function() {
            $mdDialog.hide();
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        };
        $scope.confirmChange = function(user) {
          var confirmation = user.$confirmRights();
          if (confirmation) {
            Dialog.confirm(l('Warning'), confirmation).then(function(res) {
              if (!res)
                user.$resetRights(true);
            });
          }
        };
        $scope.removeUser = function(user) {
          stateAddressbook.$acl.$removeUser(user.uid).then(function() {
            if (user.uid == $scope.selectedUser.uid) {
              $scope.selectedUser = null;
            }
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'))
          });
        };
        $scope.addUser = function(data) {
          if (data) {
            stateAddressbook.$acl.$addUser(data).then(function() {
              $scope.userToAdd = '';
              $scope.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
        };
        $scope.selectUser = function(user) {
          // Check if it is a different user
          if ($scope.selectedUser != user) {
            $scope.selectedUser = user;
            $scope.selectedUser.$rights();
          }
        };
      };
    };

    /**
     * subscribeToFolder - Callback of sgSubscribe directive
     */
    $scope.subscribeToFolder = function(addressbookData) {
      console.debug('subscribeToFolder ' + addressbookData.owner + addressbookData.name);
      AddressBook.$subscribe(addressbookData.owner, addressbookData.name).catch(function(data) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    };
  }

  angular
    .module('SOGo.ContactsUI')  
    .controller('AddressBooksController', AddressBooksController);                                    
})();
