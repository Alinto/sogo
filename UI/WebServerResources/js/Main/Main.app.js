/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for MainUI (SOGoRootPage) */

(function() {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Common', 'SOGo.Authentication'])
    .controller('loginController', loginController);

  loginController.$inject = ['$scope', '$mdDialog', 'Authentication'];
  function loginController($scope, $mdDialog, Authentication) {
    $scope.warning = false;
    $scope.creds = { username: cookieUsername, password: null };
    $scope.login = function(creds) {
      $scope.warning = false;
      Authentication.login(creds)
        .then(function(url) {
          window.location.href = url;
        }, function(msg) {
          $scope.warning = msg.error;
        });
      return false;
    };
    $scope.showAbout = function($event) {
      $mdDialog.show({
        targetEvent: $event,
        templateUrl: 'aboutBox.html',
        controller: AboutDialogController
      });
      AboutDialogController.$inject = ['scope', '$mdDialog'];
      function AboutDialogController(scope, $mdDialog) {
        scope.closeDialog = function() {
          $mdDialog.hide();
        };
      }
    };
  }
})();
