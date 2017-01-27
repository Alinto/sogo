/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  AclController.$inject = ['$timeout', '$mdDialog', 'Dialog', 'usersWithACL', 'User', 'folder'];
  function AclController($timeout, $mdDialog, Dialog, usersWithACL, User, folder) {
    var vm = this;

    vm.users = usersWithACL; // ACL users
    vm.folder = folder;
    vm.selectedUser = null;
    vm.selectedUid = null;
    vm.userToAdd = '';
    vm.searchText = '';
    vm.userFilter = userFilter;
    vm.closeModal = closeModal;
    vm.saveModal = saveModal;
    vm.confirmChange = confirmChange;
    vm.removeUser = removeUser;
    vm.addUser = addUser;
    vm.selectAllRights = selectAllRights;
    vm.selectUser = selectUser;
    vm.showRights = showRights;
    vm.confirmation = { showing: false,
                        message: ''};

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
      var confirmation = user.$confirmRights(vm.folder);
      if (confirmation) {
        vm.confirmation.showing = true;
        vm.confirmation.message = confirmation;
      }
    }

    function removeUser(user) {
      $timeout(function() {
        folder.$acl.$removeUser(user.uid);
      }, 500); // wait for CSS transition to complete (see card.scss)
    }

    function addUser(data) {
      if (data) {
        folder.$acl.$addUser(data).then(function(user) {
          vm.userToAdd = '';
          vm.searchText = '';
          vm.selectedUid = null;
          if (user)
            selectUser(user);
        });
      }
    }

    function selectAllRights(user) {
      folder.$acl.$selectAllRights(user);
    }

    function selectUser(user, $event) {
      if ($event && $event.target.parentNode.classList.contains('md-secondary'))
        return false;
      if (vm.selectedUid == user.uid) {
        vm.selectedUid = null;
      }
      else {
        vm.selectedUid = user.uid;
        vm.selectedUser = user;
        if (!user.inactive)
          vm.selectedUser.$rights();
      }
    }

    function showRights(user) {
      return vm.selectedUid == user.uid && !user.inactive;
    }
  }

  angular
    .module('SOGo.Common')
    .controller('AclController', AclController);
})();
