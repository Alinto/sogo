/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoAdministration */

(function() {
  'use strict';
  
  /**
   * @ngInject
   */
  AdministrationController.$inject = ['$state', '$mdDialog', '$mdToast', 'Dialog', 'User', 'stateAdministration', 'Authentication'];
  function AdministrationController($state, $mdDialog, $mdToast, Dialog, User, stateAdministration, Authentication) {
    var vm = this;

    vm.administration = stateAdministration;

    vm.go = go;
  
    function go(module) {
      $state.go('administration.' + module);
    }

  }

  angular
    .module('SOGo.AdministrationUI')
    .controller('AdministrationController', AdministrationController);

})();
