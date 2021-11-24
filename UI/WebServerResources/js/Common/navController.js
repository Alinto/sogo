/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /**
   * @ngInject
   */
  navController.$inject =  ['$rootScope', '$scope', '$timeout', '$interval', '$http', '$window', '$mdSidenav', '$mdToast', '$mdMedia', '$log', 'sgConstant', 'sgSettings', 'Resource', 'Preferences'];
  function navController($rootScope, $scope, $timeout, $interval, $http, $window, $mdSidenav, $mdToast, $mdMedia, $log, sgConstant, sgSettings, Resource, Preferences) {
    var resource = new Resource(sgSettings.baseURL(), sgSettings.activeUser());

    this.$onInit = function() {
      $scope.isPopup = sgSettings.isPopup;
      $scope.activeUser = sgSettings.activeUser();
      $scope.baseURL = sgSettings.baseURL();
      $scope.leftIsClose = !$mdMedia(sgConstant['gt-md']);
      // Don't hide the center list when on a small device
      $scope.centerIsClose = !!$window.centerIsClose && !$scope.leftIsClose;

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

      // Track the 600px window width threashold
      $scope.$watch(function() {
        return $mdMedia(sgConstant['gt-xs']);
      }, function(newVal) {
        $scope.isGtExtraSmall = newVal;
      });

      // Track the 1024px window width threashold
      $scope.$watch(function() {
        return $mdMedia(sgConstant['gt-md']);
      }, function(newVal) {
        $scope.isGtMedium = newVal;
        if (newVal) {
          $scope.leftIsClose = false;
        }
      });

      // Listen to HTTP errors broadcasted from HTTP interceptor
      $rootScope.$on('http:Error', onHttpError);

      if (!isPopup) {
        if (sgSettings.activeUser('path').calendar) {
          // Fetch Calendar alarms
          Preferences.getAlarms();
        }

        if (sgSettings.activeUser('path').mail) {
          // Poll inbox for new messages
          Preferences.pollInbox();
        }
      }
    };

    $scope.toggleLeft = function() {
      if ($scope.isGtMedium) {
        // Left sidenav is toggled while sidenav is locked open; bypass $mdSidenav
        $scope.leftIsClose = !$scope.leftIsClose;
      }
      else {
        $scope.leftIsClose = leftIsClose();
        // Fire a window resize when opening the sidenav on a small device.
        // This is a fix until the following issue is officially resolved:
        // https://github.com/angular/material/issues/7309
        if ($scope.leftIsClose)
          angular.element($window).triggerHandler('resize');
        $mdSidenav('left').toggle()
          .then(function () {
            $log.debug("toggle left is done");
          });
      }
    };
    $scope.toggleRight = function() {
      $mdSidenav('right').toggle()
        .then(function () {
          $log.debug("toggle right is done");
        });
    };
    $scope.toggleCenter = function(options) {
      $scope.centerIsClose = !$scope.centerIsClose;
      if (options && options.save)
        resource.post(null, 'saveListState', { state: $scope.centerIsClose? 'collapse' : 'rise' });
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
  }

  angular.module('SOGo.Common')
    .controller('navController', navController);
})();
