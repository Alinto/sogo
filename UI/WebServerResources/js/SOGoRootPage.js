/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoContacts */

'use strict';

var SOGoRootPageApp = angular.module('SOGoRootPage', ['SOGoAuthentication']);

SOGoRootPageApp.controller('loginController', ['$scope', '$http', 'SOGoAuthentication', function($scope, $http, SOGoAuthentication) {
    $scope.warning = false;
    $scope.login = function($event) {
        //$event.stopPropagation();
        $scope.warning = false;

        var username = $scope.username,
            password = $scope.password,
            domain = $scope.domain,
            language,
            rememberLogin = $scope.rememberLogin ? 1 : 0;

        if ($scope.loginSuffix && !username.endsWith($scope.loginSuffix)) {
            username += loginSuffix;
            domain = false;
        }
        if ($scope.language && $scope.language != 'WONoSelectionString') {
            language = $scope.language;
        }

        SOGoAuthentication.login(username, password, domain, language, rememberLogin)
        .then(function(url) {
            window.location.href = url;
        }, function(msg) {
            $scope.warning = msg;
        });
//        $http({
//            method: 'POST',
//            url: 'http://debian.inverse.ca/SOGo/connect',
//            params: postData})
//            .success(function(data, status, headers, config) {
//                alert('success: ' + status);
//            }).error(function(data, status, headers, config) {
//                alert('error: ' + status);
//            });
        return false;
    };
}]);
