/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  navController.$inject =  ['$rootScope', '$scope', '$timeout', '$interval', '$http', '$mdSidenav', '$mdToast', '$mdMedia', '$log', 'sgConstant', 'sgSettings', 'Alarm'];
  function navController($rootScope, $scope, $timeout, $interval, $http, $mdSidenav, $mdToast, $mdMedia, $log, sgConstant, sgSettings, Alarm) {

    $scope.isPopup = sgSettings.isPopup;
    $scope.activeUser = sgSettings.activeUser();
    $scope.baseURL = sgSettings.baseURL();
    $scope.leftIsClose = $mdMedia(sgConstant.xs);

    // Show current day in top bar
    $scope.currentDay = window.currentDay;
    $timeout(function() {
      // Update date when day ends
      $interval(function() {
        $http.get('../date').then(function(data) {
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
      return $mdMedia(sgConstant['gt-sm']);
    }, function(newVal) {
      $scope.isGtMedium = newVal;
      if (newVal) {
        $scope.leftIsClose = false;
      }
    });

    function leftIsClose() {
      return !$mdSidenav('left').isOpen();
    }

    function onHttpError(event, response) {
      var message;
      if (response.data && response.data.message && angular.isString(response.data.message))
        message = response.data.message;
      else if (response.status)
        message = response.statusText;

      if (message)
        $mdToast.show({
          template: [
            '<md-toast>',
            '  <div class="md-toast-content">',
            '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
            '    <span flex>' + l(message) + '</span>',
            '  </div>',
            '</md-toast>'
          ].join(''),
          hideDelay: 5000,
          position: 'top right'
        });
      else
        $log.debug('untrap error');
    }

    // Listen to HTTP errors broadcasted from HTTP interceptor
    $rootScope.$on('http:Error', onHttpError);

    Alarm.getAlarms();
  }

  angular.module('SOGo.Common')
    .controller('navController', navController);
})();
