/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  navController.$inject =  ['$scope', '$timeout', '$interval', '$http', '$mdSidenav', '$mdBottomSheet', '$mdMedia', '$log', 'sgConstant'];
  function navController($scope, $timeout, $interval, $http, $mdSidenav, $mdBottomSheet, $mdMedia, $log, sgConstant) {

    // Show current day in top bar
    $scope.currentDay = window.currentDay;
    $timeout(function() {
      // Update date when day ends
      $interval(function() {
        $http.get('../date').success(function(data) {
          $scope.currentDay = data;
        });
      }, 24 * 3600 * 1000);
    }, window.secondsBeforeTomorrow * 1000);

    $scope.toggleLeft = function () {
      $mdSidenav('left').toggle()
        .then(function () {
          $log.debug("toggle left is done");
        });
    };
    $scope.toggleRight = function () {
      $mdSidenav('right').toggle()
        .then(function () {
          $log.debug("toggle RIGHT is done");
        });
    };
    $scope.openBottomSheet = function() {
      $mdBottomSheet.show({
        parent: angular.element(document.getElementById('left-sidenav')),
        templateUrl: 'bottomSheetTemplate.html'
      });
    };
    $scope.toggleDetailView = function() {
      var detail = angular.element(document.getElementById('detailView'));
      detail.toggleClass('sg-close');
    };
    $scope.$watch(function() {
      return $mdMedia(sgConstant['gt-md']);
    }, function(newVal) {
      $scope.isGtMedium = newVal;
    });
  }

  angular.module('SOGo.Common')
    .controller('navController', navController);
})();
