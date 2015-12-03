/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgCalendarDay - An element that represents a day in the calendar's view
   * @memberof SOGo.SchedulerUI
   * @restrict element
   * @param {string} sgDay - the day of the events to display (YYYYMMDD)
   * @param {string} sgDayString - the day in ISO8601 format (YYYY-MM-DDTHH:MM+-HH:MM)
   * @param {number} sgDayNumber - the day index within the calendar's view
   *
   * @example:

   <sg-calendar-day
       sg-day-string="2015-11-01T00:00-05:00"
       sg-day-number="0"
       sg-day="20151101">
     ..
   </sg-calendar-day-table>
  */
  function sgCalendarDay() {
    return {
      restrict: 'E',
      scope: {
        day: '@sgDay',
        dayNumber: '@sgDayNumber',
        dayString: '@sgDayString'
      },
      controller: sgCalendarDayController
    };
  }

  /**
   * @ngInject
   */
  sgCalendarDayController.$inject = ['$scope'];
  function sgCalendarDayController($scope) {
    // Expose some scope variables to the controller
    // See the sgCalendarDayTable directive
    this.day = $scope.day;
    this.dayNumber = $scope.dayNumber;
    this.dayString = $scope.dayString;
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarDay', sgCalendarDay);
})();
