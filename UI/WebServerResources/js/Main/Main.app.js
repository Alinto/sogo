/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for MainUI (SOGoRootPage) */

(function() {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Common', 'SOGo.Authentication']);

  /**
   * @ngInject
   */
  LoginController.$inject = ['$scope', 'Dialog', '$mdDialog', 'Authentication'];
  function LoginController($scope, Dialog, $mdDialog, Authentication) {
    var vm = this;

    vm.creds = { username: cookieUsername, password: null };
    vm.login = login;
    vm.showAbout = showAbout;

    function login() {
      Authentication.login(vm.creds)
        .then(function(url) {
          window.location.href = url;
        }, function(msg) {
          Dialog.alert(l('Authentication Failed'), msg.error);
        });
      return false;
    }

    function showAbout($event) {
      $mdDialog.show({
        targetEvent: $event,
        templateUrl: 'aboutBox.html',
        controller: AboutDialogController,
        controllerAs: 'about'
      });
      AboutDialogController.$inject = ['$mdDialog'];
      function AboutDialogController($mdDialog) {
        this.closeDialog = function() {
          $mdDialog.hide();
        };
      }
    }
  }

  angular
    .module('SOGo.MainUI')
    .controller('LoginController', LoginController);
})();
