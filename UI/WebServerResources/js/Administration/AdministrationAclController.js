/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationAclController.$inject = ['$state', '$mdToast', 'stateFolder', 'User'];
  function AdministrationAclController($state, $mdToast, stateFolder, User) {
    var vm = this;

    vm.selectedUser = null;
    vm.getTemplate = getTemplate;
    vm.selectUser = selectUser;
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
      if (vm.selectedUser == user) {
        vm.selectedUser = null;
      }
      else {
        vm.selectedUser = user;
        vm.selectedUser.$rights();
      }
    }

    function userFilter($query) {
      return User.$filter($query, stateFolder.$acl.users);
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

    function save() {
      stateFolder.$acl.$saveUsersRights(stateFolder.owner).then(function() {
        $mdToast.show(
          $mdToast.simple()
            .content(l('ACLs saved'))
            .position('top right')
            .hideDelay(3000)
        );
      }, function(data, status) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }
    
  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationAclController', AdministrationAclController);

})();
