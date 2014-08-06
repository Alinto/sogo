/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* JavaScript for SOGoRootPage (mobile) */

(function() {
    'use strict';

    angular.module('SOGo.RootPage', ['SOGo.Authentication', 'SOGo.UIMobile', 'ionic'])

    .constant('sgSettings', {
        'baseURL': '/SOGo/so/francis/'
    })

    .run(function($ionicPlatform) {
        $ionicPlatform.ready(function() {
            // Hide the accessory bar by default (remove this to show the accessory bar above the keyboard
            // for form inputs)
            if(window.cordova && window.cordova.plugins.Keyboard) {
                cordova.plugins.Keyboard.hideKeyboardAccessoryBar(true);
            }
            if(window.StatusBar) {
                // org.apache.cordova.statusbar required
                StatusBar.styleDefault();
            }
        });
    })

    .config(function($stateProvider, $urlRouterProvider) {
        $stateProvider

            .state('app', {
                url: "/app",
                abstract: true,
                templateUrl: "menu.html",
                controller: 'AppCtrl'
            })

            .state('app.login', {
                url: "/login",
                views: {
                    'menuContent': {
                        templateUrl: "login.html",
                        controller: 'LoginCtrl'
                    }
                }
            });

        // if none of the above states are matched, use this as the fallback
        $urlRouterProvider.otherwise('/app/login');
    })

    .controller('AppCtrl', function($scope) {
        $scope.ApplicationBaseURL = ApplicationBaseURL;
    })

    .controller('LoginCtrl', ['$scope', 'Authentication', 'sgDialog', function($scope, Authentication, Dialog) {
        $scope.creds = { 'username': null, 'password': null };
        $scope.login = function(creds) {
            Authentication.login(creds)
                .then(function(url) {
                    window.location.href = url;
                }, function(msg) {
                    Dialog.alert(l('Warning'), msg.error);
                });
        };
    }]);
})();
