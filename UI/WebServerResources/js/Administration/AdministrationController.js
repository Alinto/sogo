/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationController.$inject = ['$state', '$window', '$mdToast', '$mdMedia', '$mdSidenav', 'sgConstant', 'Dialog', 'encodeUriFilter', 'User'];
  function AdministrationController($state, $window, $mdToast, $mdMedia, $mdSidenav, sgConstant, Dialog, encodeUriFilter, User) {
    var vm = this,
        defaultWindowTitle = angular.element($window.document).find('title').attr('sg-default') || "SOGo";

    this.$onInit = function() {
      this.service = User;

      this.selectedUser = null;
      this.users = User.$users;
    };

    this.go = function (module) {
      $state.go('administration.' + module);
      // Close sidenav on small devices
      if (!$mdMedia(sgConstant['gt-md']))
        $mdSidenav('left').close();
    };

    this.filter = function (searchText) {
      User.$filter(searchText);
    };

    this.selectUser = function (i) {
      if (this.selectedUser == this.users[i]) {
        this.selectedUser = null;
      }
      else {
        // Fetch folders of specific type for selected user
        this.users[i].$folders().then(function() {
          vm.selectedUser = vm.users[i];
        });
      }
    };

    this.selectFolder = function (folder) {
      $state.go('administration.rights.edit', {userId: this.selectedUser.uid, folderId: encodeUriFilter(folder.name)});
    };

  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationController', AdministrationController);

})();
