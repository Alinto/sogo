/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationAclController.$inject = ['$timeout', '$state', '$mdMedia', '$mdToast', 'stateUser', 'stateFolder', 'User'];
  function AdministrationAclController($timeout, $state, $mdMedia, $mdToast, stateUser, stateFolder, User) {
    var vm = this;

    vm.user = stateUser;
    vm.folder = stateFolder;
    vm.folderType = angular.isDefined(stateFolder.$cards)? 'AddressBook' : 'Calendar';
    vm.selectedUser = null;
    vm.selectedUid = null;
    vm.selectUser = selectUser;
    vm.selectAllRights = selectAllRights;
    vm.showRights = showRights;
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

    function selectAllRights(user) {
      stateFolder.$acl.$selectAllRights(user);
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
        vm.selectedUser.$rights();
      }
    }

    function showRights(user) {
      return vm.selectedUid == user.uid && user.rights;
    }

    function userFilter($query) {
      return User.$filter($query, stateFolder.$acl.users, { dry: true, uid: vm.user.uid });
    }

    function removeUser(user) {
      $timeout(function() {
        stateFolder.$acl.$removeUser(user.uid, stateFolder.owner);
      }, 500); // wait for CSS transition to complete (see card.scss)
    }

    function addUser(data) {
      if (data) {
        stateFolder.$acl.$addUser(data, stateFolder.owner).then(function(user) {
          vm.userToAdd = '';
          vm.searchText = '';
          vm.selectedUid = null;
          if (user)
            selectUser(user);
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
            .position('bottom right')
            .hideDelay(3000)
        );
        // Close acls on small devices
        if ($mdMedia('xs'))
          close();
      });
    }
  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationAclController', AdministrationAclController);

})();
