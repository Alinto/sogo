/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* Angular JavaScript for common UI services */
// TODO: Normalize the namespace and prefixes


/**
 * The common SOGo UI, app module
 *
 * @type {angular.Module}
 */
(function() {
  'use strict';
  angular.module('SOGo.UI', ['ngMaterial' ])

    .config(function($mdThemingProvider) {
      $mdThemingProvider.theme('default')
        .primaryColor('grey', {
          'default': '800'
        });
    })

    .controller('toggleCtrl', ['$scope', '$timeout', '$mdSidenav', '$log', function($scope, $timeout, $mdSidenav, $log) {
      $scope.toggleLeft = function() {
        $mdSidenav('left').toggle()
                          .then(function(){
                              $log.debug("toggle left is done");
                          });
      };
      $scope.toggleRight = function() {
        $mdSidenav('right').toggle()
                            .then(function(){
                              $log.debug("toggle RIGHT is done");
                            });
      };
    }])

    .controller('LeftCtrl', function($scope, $timeout, $mdSidenav, $log) {
      $scope.close = function() {
        $mdSidenav('left').close()
                          .then(function(){
                            $log.debug("close LEFT is done");
                          });
      };
    })

    .controller('RightCtrl', function($scope, $timeout, $mdSidenav, $log) {
      $scope.close = function() {
        $mdSidenav('right').close()
                            .then(function(){
                              $log.debug("close RIGHT is done");
                            });
      };
    });

})();

