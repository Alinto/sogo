/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGoRootPage */

(function() {
  'use strict';

  angular.module('SOGo.MainUI', ['SOGo.Authentication', 'SOGo.UI'])

    .controller('loginController', ['$scope', '$mdDialog', 'Authentication', function($scope, $mdDialog, Authentication) {
      $scope.warning = false;
      $scope.creds = { username: null, password: null };
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
    }]);
})();
