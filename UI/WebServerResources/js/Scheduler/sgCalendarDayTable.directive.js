/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayTable - Build list of blocks for a specific day
   * @memberof SOGo.SchedulerUI
   * @restrict element
   * @param {object} sgBlocks - the events blocks definitions for the current view
   * @param {string} sgDay - the day of the events to display
   * @param {function} sgClick - the function to call when clicking on a block.
   *        Two variables are available: event (the event that triggered the mouse click),
   *        and component (a Component object)
   *
   * @example:

   <sg-calendar-day-table
       sg-blocks="calendar.blocks"
       sg-day="20150330"
       sg-click="open({ event: clickEvent, component: clickComponent })"/>
  */
  function sgCalendarDayTable() {
    return {
      restrict: 'E',
      scope: {
        blocks: '=sgBlocks',
        day: '@sgDay',
        clickBlock: '&sgClick'
      },
      template: [
        '<sg-calendar-day-block',
        '  class="sg-draggable-calendar-block"',
        '  ng-repeat="block in blocks[day]"',
        '  sg-block="block"',
        '  sg-click="clickBlock({event: clickEvent, component: clickComponent})"/>'
      ].join('')
    };
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarDayTable', sgCalendarDayTable);
})();
