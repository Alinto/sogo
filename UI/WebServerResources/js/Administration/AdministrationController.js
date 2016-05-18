/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationController.$inject = ['$state', '$mdToast', '$mdMedia', '$mdSidenav', 'sgConstant', 'Dialog', 'encodeUriFilter', 'User'];
  function AdministrationController($state, $mdToast, $mdMedia, $mdSidenav, sgConstant, Dialog, encodeUriFilter, User) {
    var vm = this;

    vm.service = User;

    vm.selectedUser = null;
    vm.users = User.$users;

    vm.go = go;
    vm.filter = filter;
    vm.selectUser = selectUser;
    vm.selectFolder = selectFolder;

    function go(module) {
      $state.go('administration.' + module);
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
    }

    function filter(searchText) {
      User.$filter(searchText);
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
      $state.go('administration.rights.edit', {userId: vm.selectedUser.uid, folderId: encodeUriFilter(folder.name)});
    }

  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationController', AdministrationController);

})();
