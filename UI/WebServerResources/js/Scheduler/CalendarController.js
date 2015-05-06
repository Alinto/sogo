/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarController.$inject = ['$scope', '$state', '$stateParams', '$timeout', '$interval', '$log', 'sgFocus', 'Calendar', 'Component', 'stateEventsBlocks'];
  function CalendarController($scope, $state, $stateParams, $timeout, $interval, $log, focus, Calendar, Component, stateEventsBlocks) {
    var vm = this;

    vm.blocks = stateEventsBlocks;
    vm.changeView = changeView;

    // Refresh current view when the list of calendars is modified
    $scope.$on('calendars:list', function() {
      Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate()).then(function(data) {
        vm.blocks = data;
      });
    });

    // Change calendar's view
    function changeView($event) {
      var date = angular.element($event.currentTarget).attr('date');
      $state.go('calendars.view', { view: $stateParams.view, day: date });
    }
  }
  
  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarController', CalendarController);
})();
