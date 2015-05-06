/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayTable - Build list of blocks for a specific day
   * @memberof SOGo.Common
   * @restrict element
   * @param {object} sgBlocks - the events blocks definitions for the current view
   * @param {string} sgDay - the day of the events to display
   * @ngInject
   * @example:

   <sg-calendar-day-table
       sg-blocks="calendar.blocks"
       sg-day="20150330" />
  */
  function sgCalendarDayTable() {
    return {
      restrict: 'E',
      scope: {
        blocks: '=sgBlocks',
        day: '@sgDay'
      },
      template: [
        '<sg-calendar-day-block class="event draggable"',
        '                   ng-repeat="block in blocks[day]"',
        '                   sg-block="block"/>'
      ].join('')
    };
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarDayTable', sgCalendarDayTable);
})();
