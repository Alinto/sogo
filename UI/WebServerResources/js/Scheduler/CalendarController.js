/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarController.$inject = ['$scope', '$rootScope', '$state', '$stateParams', 'Calendar', 'Component', 'Preferences', 'stateEventsBlocks'];
  function CalendarController($scope, $rootScope, $state, $stateParams, Calendar, Component, Preferences, stateEventsBlocks) {
    var vm = this, deregisterCalendarsList;

    // Make the toolbar state of all-day events persistent
    if (angular.isUndefined(CalendarController.expandedAllDays))
      CalendarController.expandedAllDays = false;

    vm.selectedDate = $stateParams.day.asDate();
    vm.expandedAllDays = CalendarController.expandedAllDays;
    vm.toggleAllDays = toggleAllDays;
    vm.views = stateEventsBlocks;
    vm.changeDate = changeDate;
    vm.changeView = changeView;

    Preferences.ready().then(function() {
      _formatDate(vm.selectedDate);
    });

    // Refresh current view when the list of calendars is modified
    deregisterCalendarsList = $rootScope.$on('calendars:list', updateView);

    // Destroy event listener when the controller is being deactivated
    $scope.$on('$destroy', deregisterCalendarsList);

    function _formatDate(date) {
      if ($stateParams.view == 'month') {
        date.setDate(1);
        date.setHours(12);
        date.$dateFormat = '%B %Y';
      }
      else if ($stateParams.view == 'week') {
        date.setTime(date.beginOfWeek(Preferences.defaults.SOGoFirstDayOfWeek).getTime());
        date.$dateFormat = l('Week %d').replace('%d', '%U');
      }
      else {
        date.$dateFormat = '%A';
      }
    }

    // Expand or collapse all-day events
    function toggleAllDays() {
      CalendarController.expandedAllDays = !CalendarController.expandedAllDays;
      vm.expandedAllDays = CalendarController.expandedAllDays;
    }

    function updateView() {
      // See stateEventsBlocks in Scheduler.app.js
      Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate()).then(function(data) {
        vm.views = data;
        _.forEach(vm.views, function(view) {
          if (view.id) {
            // Note: this can't be done in Component service since it would make Component dependent on
            // the Calendar service and create a circular dependency
            view.calendar = new Calendar({ id: view.id, name: view.calendarName });
          }
        });
      });
    }

    // Change calendar's date
    function changeDate($event, newDate) {
      var date = newDate? newDate.getDayString() : angular.element($event.currentTarget).attr('date');
      if (newDate)
        _formatDate(newDate);
      $state.go('calendars.view', { day: date });
    }

    // Change calendar's view
    function changeView(view) {
      $state.go('calendars.view', { view: view });
    }
}

  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarController', CalendarController);
})();
