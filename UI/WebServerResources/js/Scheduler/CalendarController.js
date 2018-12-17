/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint loopfunc: true */
  'use strict';

  /**
   * @ngInject
   */
  CalendarController.$inject = ['$scope', '$rootScope', '$state', '$stateParams', '$mdDialog', 'sgHotkeys', 'Calendar', 'Component', 'Preferences', 'stateEventsBlocks'];
  function CalendarController($scope, $rootScope, $state, $stateParams, $mdDialog ,sgHotkeys, Calendar, Component, Preferences, stateEventsBlocks) {
    var vm = this, deregisterCalendarsList, hotkeys = [];

    this.$onInit = function() {
      // Make the toolbar state of all-day events persistent
      if (angular.isUndefined(CalendarController.expandedAllDays))
        CalendarController.expandedAllDays = false;

      this.selectedDate = $stateParams.day.asDate();
      this.selectableDays = _.map(Preferences.defaults.SOGoCalendarWeekdays, function(day) {
        return _.indexOf(['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'], day);
      });
      this.expandedAllDays = CalendarController.expandedAllDays;
      this.views = stateEventsBlocks;

      _registerHotkeys(hotkeys);

      _formatDate(this.selectedDate);

      // Refresh current view when the list of calendars is modified
      deregisterCalendarsList = $rootScope.$on('calendars:list', _updateView);

      // NOTE: $onDestroy won't work with ui-router (tested with v1.0.20).
      $scope.$on('$destroy', function() {
        // Destroy event listener when the controller is being deactivated
        deregisterCalendarsList();
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
      });
    };

    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_today'),
        description: l('Today'),
        callback: vm.changeDate,
        args: new Date()
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_dayview'),
        description: l('Day'),
        callback: vm.changeView,
        args: 'day'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_weekview'),
        description: l('Week'),
        callback: vm.changeView,
        args: 'week'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_monthview'),
        description: l('Month'),
        callback: vm.changeView,
        args: 'month'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_multicolumndayview'),
        description: l('Multicolumn Day View'),
        callback: vm.changeView,
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
        while (!vm.isSelectableDay(date)) {
          date = date.addDays(direction);
        }
      }

      vm.changeDate($event, date);
    }

    /**
     * Format a date according to the current view.
     * - Day/Multicolumn: name of weekday
     * - Week: week number
     * - Month: name of month
     */
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

    function _updateView() {
      // The list of calendars has changed; update the views
      // See stateEventsBlocks in Scheduler.app.js
      Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate()).then(function(data) {
        var i, j, view;
        for (i = 0; i < data.length; i++) {
          view = data[i];
          if (vm.views[i]) {
            _.forEach(view.allDayBlocks, function(blocks, day) {
              vm.views[i].allDayBlocks[day] = blocks;
            });
            _.forEach(view.blocks, function(blocks, day) {
              vm.views[i].blocks[day] = blocks;
            });
          }
          else {
            vm.views[i] = view;
          }
          if (view.id) {
            // Note: this can't be done in Component service since it would make Component dependent on
            // the Calendar service and create a circular dependency
            vm.views[i].calendar = new Calendar({ id: view.id, name: view.calendarName });
          }
        }
        // Remove previous views
        for (j = vm.views.length; j >= i; j--)
          vm.views.splice(j, 1);
      });
    }

    // Expand or collapse all-day events
    this.toggleAllDays = function() {
      CalendarController.expandedAllDays = !CalendarController.expandedAllDays;
      this.expandedAllDays = CalendarController.expandedAllDays;
    };

    // Change calendar's date
    this.changeDate = function($event, newDate) {
      var date = newDate? newDate.getDayString() : angular.element($event.currentTarget).attr('date');
      if (newDate)
        _formatDate(newDate);
      $state.go('calendars.view', { day: date });
      // $state.transitionTo('calendars.view', { day: date });
    };

    // Change calendar's view
    this.changeView = function($event, view) {
      $state.go('calendars.view', { view: view });
    };

    this.printView = function(centerIsClose, componentType) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: 'UIxCalPrintDialog', // See UIxCalMainView.wox
        controller: PrintController,
        controllerAs: '$PrintDialogController',
        locals: {
          calendarView: $stateParams.view,
          visibleList: centerIsClose? undefined : componentType
        }
      });

    };

    // Check if the week day should be visible/selectable
    this.isSelectableDay = function(date) {
      return _.includes(vm.selectableDays, date.getDay());
    };
  }

  /**
   * @ngInject
   */
  PrintController.$inject = ['$rootScope', '$scope', '$window', '$stateParams', '$mdDialog', '$log', '$mdToast', 'Dialog', 'sgSettings', 'Preferences', 'Calendar', 'calendarView', 'visibleList'];
  function PrintController($rootScope, $scope, $window, $stateParams, $mdDialog, $log, $mdToast, Dialog, Settings, Preferences, Calendar, calendarView, visibleList) {
    var vm = this;
    var orientations = {
      day: 'portrait',
      week: 'landscape',
      month: 'landscape',
      multicolumnday: 'landscape'
    };

    this.$onInit = function() {
      // Default values
      this.pageSize = 'letter';
      this.workingHoursOnly = true;
      this.calendarView = calendarView;
      this.orientation = orientations[this.calendarView];
      this.visibleList = visibleList;

      angular.element(document.body).addClass(this.orientation);
      $scope.$watch(function() { return vm.pageSize; }, angular.bind(this, function(newSize, oldSize) {
        angular.element(document.body).removeClass(oldSize);
        angular.element(document.body).addClass(newSize);
      }));
    };

    this.$onDestroy = function() {
      angular.element(document.body).removeClass(['portrait', 'landscape', 'letter', 'legal', 'a4']);
    };

    this.print = function($event) {
      $window.print();
      $event.stopPropagation();
      return false;
    };

    this.close = function () {
      $mdDialog.hide();
    };
  }

  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarController', CalendarController);
})();
