/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for MainUI (SOGoRootPage) */

(function() {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Common', 'SOGo.Authentication']);

  /**
   * @ngInject
   */
  LoginController.$inject = ['$scope', '$window', '$timeout', 'Dialog', '$mdDialog', 'Authentication'];
  function LoginController($scope, $window, $timeout, Dialog, $mdDialog, Authentication) {
    var vm = this;

    vm.creds = {
      username: $window.cookieUsername,
      password: null,
      rememberLogin: angular.isDefined($window.cookieUsername) && $window.cookieUsername.length > 0
    };
    vm.login = login;
    vm.loginState = false;
    vm.showAbout = showAbout;

    // Show login once everything is initialized
    vm.showLogin = false;
    $timeout(function() { vm.showLogin = true; }, 100);

    function login() {
      vm.loginState = 'authenticating';
      Authentication.login(vm.creds)
        .then(function(data) {
          vm.loginState = 'logged';
          vm.cn = data.cn;

          // Let the user see the succesfull message before reloading the page
          $timeout(function() {
            if ($window.location.href === data.url)
              $window.location.reload(true);
            else
              $window.location.href = data.url;
          }, 1000);
        }, function(msg) {
          vm.loginState = 'error';
          vm.errorMessage = msg.error;
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
