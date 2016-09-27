/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarController.$inject = ['$scope', '$rootScope', '$state', '$stateParams', 'sgHotkeys', 'Calendar', 'Component', 'Preferences', 'stateEventsBlocks'];
  function CalendarController($scope, $rootScope, $state, $stateParams, sgHotkeys, Calendar, Component, Preferences, stateEventsBlocks) {
    var vm = this, deregisterCalendarsList, hotkeys = [];

    // Make the toolbar state of all-day events persistent
    if (angular.isUndefined(CalendarController.expandedAllDays))
      CalendarController.expandedAllDays = false;

    vm.selectedDate = $stateParams.day.asDate();
    vm.expandedAllDays = CalendarController.expandedAllDays;
    vm.toggleAllDays = toggleAllDays;
    vm.views = stateEventsBlocks;
    vm.changeDate = changeDate;
    vm.changeView = changeView;


    _registerHotkeys(hotkeys);

    Preferences.ready().then(function() {
      _formatDate(vm.selectedDate);
    });

    // Refresh current view when the list of calendars is modified
    deregisterCalendarsList = $rootScope.$on('calendars:list', updateView);

    $scope.$on('$destroy', function() {
      // Destroy event listener when the controller is being deactivated
      deregisterCalendarsList();
      // Deregister hotkeys
      _.forEach(hotkeys, function(key) {
        sgHotkeys.deregisterHotkey(key);
      });
    });


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_today'),
        description: l('Today'),
        callback: changeDate,
        args: new Date()
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_dayview'),
        description: l('Day'),
        callback: changeView,
        args: 'day'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_weekview'),
        description: l('Week'),
        callback: changeView,
        args: 'week'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_monthview'),
        description: l('Month'),
        callback: changeView,
        args: 'month'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_multicolumndayview'),
        description: l('Multicolumn Day View'),
        callback: changeView,
        args: 'multicolumnday'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'left',
        description: l('Move backward'),
        callback: _goToPeriod,
        args: -1
      }));
      keys.push(sgHotkeys.createHotkey({
        key: 'right',
        description: l('Move forward'),
        callback: _goToPeriod,
        args: +1
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }


    function _goToPeriod($event, direction) {
      var date;

      if ($stateParams.view == 'week') {
        date = vm.selectedDate.beginOfWeek(Preferences.defaults.SOGoFirstDayOfWeek).addDays(7 * direction);
      }
      else if ($stateParams.view == 'month') {
        date = vm.selectedDate;
        date.setDate(1);
        date.setMonth(date.getMonth() + direction);
      }
      else {
        date = vm.selectedDate.addDays(direction);
      }

      changeDate($event, date);
    }

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
    function changeView($event, view) {
      $state.go('calendars.view', { view: view });
    }
}

  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarController', CalendarController);
})();
