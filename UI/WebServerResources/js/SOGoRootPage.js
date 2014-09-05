/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoRootPage */

(function() {
    'use strict';

    angular.module('SOGo.MainUI', ['SOGo.Authentication'])

    .controller('loginController', ['$scope', 'Authentication', function($scope, Authentication) {
        $scope.warning = false;
        $scope.creds = { 'username': null, 'password': null };
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
    }]);
})();
