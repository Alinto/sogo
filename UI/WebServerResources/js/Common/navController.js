/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  navController.$inject =  ['$scope', '$timeout', '$interval', '$http', '$mdSidenav', '$mdBottomSheet', '$mdMedia', '$log', 'sgConstant', 'sgSettings', 'Alarm'];
  function navController($scope, $timeout, $interval, $http, $mdSidenav, $mdBottomSheet, $mdMedia, $log, sgConstant, sgSettings, Alarm) {

    $scope.isPopup = sgSettings.isPopup;
    $scope.activeUser = sgSettings.activeUser();
    $scope.baseURL = sgSettings.baseURL();
    $scope.leftIsClose = false;

    // Show current day in top bar
    $scope.currentDay = window.currentDay;
    $timeout(function() {
      // Update date when day ends
      $interval(function() {
        $http.get('../date').success(function(data) {
          $scope.currentDay = data;
        });
      }, 24 * 3600 * 1000);
    }, window.currentDay.secondsBeforeTomorrow * 1000);

    $scope.toggleLeft = function() {
      $scope.leftIsClose = leftIsClose();
      $mdSidenav('left').toggle()
        .then(function () {
          $log.debug("toggle left is done");
        });
    };
    $scope.toggleRight = function() {
      $mdSidenav('right').toggle()
        .then(function () {
          $log.debug("toggle right is done");
        });
    };
    // $scope.openBottomSheet = function() {
    //   $mdBottomSheet.show({
    //     parent: angular.element(document.getElementById('left-sidenav')),
    //     templateUrl: 'bottomSheetTemplate.html'
    //   });
    // };
    // $scope.toggleDetailView = function() {
    //   var detail = angular.element(document.getElementById('detailView'));
    //   detail.toggleClass('sg-close');
    // };
    $scope.$watch(function() {
      return $mdMedia(sgConstant['gt-md']);
    }, function(newVal) {
      $scope.isGtMedium = newVal;
      if (newVal) {
        $scope.leftIsClose = false;
      }
    });

    function leftIsClose() {
      return !$mdSidenav('left').isOpen();
    }

    Alarm.getAlarms();
  }

  angular.module('SOGo.Common')
    .controller('navController', navController);
})();
