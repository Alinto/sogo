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
    $scope.showAbout = function() {
      var alert;
      alert = $mdDialog.alert({
        title: 'About SOGo',
        content: 'This is SOGo v3!',
        ok: 'OK'
      });
      $mdDialog
        .show( alert )
        .finally(function() {
          alert = undefined;
        });
    };
  }
})();
