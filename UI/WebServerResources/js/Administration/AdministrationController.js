/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationController.$inject = ['$state', '$mdDialog', '$mdToast', 'Dialog', 'User', 'Administration'];
  function AdministrationController($state, $mdDialog, $mdToast, Dialog, User, Administration) {
    var vm = this;

    vm.administration = Administration;

    vm.selectedUser = null;
    vm.users = User.$users;

    vm.go = go;
    vm.filter = filter;
    vm.selectUser = selectUser;
    vm.selectFolder = selectFolder;

    function go(module) {
      $state.go('administration.' + module);
    }

    function filter(searchText) {
      User.$filter(searchText).then(function() {
      });
    }

    function selectUser(i) {
      if (vm.selectedUser == vm.users[i]) {
        vm.selectedUser = null;
      }
      else {
        // Fetch folders of specific type for selected user
        vm.users[i].$folders().then(function() {
          vm.selectedUser = vm.users[i];
        });
      }
    }

    function selectFolder(folder) {
      $state.go('administration.rights.edit', {userId: vm.selectedUser.uid, folderId: folder.name});
    }

  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationController', AdministrationController);

})();
