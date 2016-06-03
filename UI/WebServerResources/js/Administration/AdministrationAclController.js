/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationAclController.$inject = ['$animate', '$state', '$mdMedia', '$mdToast', 'stateUser', 'stateFolder', 'User'];
  function AdministrationAclController($animate, $state, $mdMedia, $mdToast, stateUser, stateFolder, User) {
    var vm = this;

    vm.user = stateUser;
    vm.folder = stateFolder;
    vm.folderType = angular.isDefined(stateFolder.$cards)? 'AddressBook' : 'Calendar';
    vm.selectedUser = null;
    vm.selectedUid = null;
    vm.selectUser = selectUser;
    vm.removeUser = removeUser;
    vm.getTemplate = getTemplate;
    vm.close = close;
    vm.save = save;

    vm.userToAdd = '';
    vm.searchText = '';
    vm.userFilter = userFilter;
    vm.addUser = addUser;

    stateFolder.$acl.$users(stateFolder.owner).then(function(data) {
      vm.users = data;
    });

    function getTemplate() {
      if (angular.isDefined(stateFolder.$cards))
        return '../' + stateFolder.owner + '/Contacts/' + stateFolder.id + '/UIxContactsUserRightsEditor';

      return '../' + stateFolder.owner + '/Calendar/' + stateFolder.id + '/UIxCalUserRightsEditor';
    }

    function selectUser(user) {
      if (vm.selectedUid == user.uid) {
        vm.selectedUid = null;
      }
      else {
        vm.selectedUid = user.uid;
        vm.selectedUser = user;
        vm.selectedUser.$rights();
      }
    }

    function userFilter($query) {
      return User.$filter($query, stateFolder.$acl.users, { dry: true });
    }

    function removeUser(user) {
      stateFolder.$acl.$removeUser(user.uid, stateFolder.owner).catch(function(data, status) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }

    function addUser(data) {
      if (data) {
        stateFolder.$acl.$addUser(data, stateFolder.owner).then(function() {
          vm.userToAdd = '';
          vm.searchText = '';
        }, function(error) {
          Dialog.alert(l('Warning'), error);
        });
      }
    }

    function close() {
      $state.go('administration.rights').then(function() {
        delete vm.user.selectedFolder;
        vm.user = null;
      });
    }

    function save() {
      stateFolder.$acl.$saveUsersRights(stateFolder.owner).then(function() {
        $mdToast.show(
          $mdToast.simple()
            .content(l('ACLs saved'))
            .position('top right')
            .hideDelay(3000)
        );
        // Close acls on small devices
        if ($mdMedia('xs'))
          close();
      }, function(data, status) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }
  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationAclController', AdministrationAclController);

})();
