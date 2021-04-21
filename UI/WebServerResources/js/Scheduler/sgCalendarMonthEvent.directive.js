/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarMonthEvent - An event block to be displayed in a month
   * @memberof SOGo.Common
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @ngInject
   * @example:

   <sg-calendar-month-event
       ng-repeat="block in blocks[day]"
       sg-block="block"/>
  */
  function sgCalendarMonthEvent() {
    return {
      restrict: 'E',
      scope: {
        block: '=sgBlock',
        clickBlock: '&sgClick'
      },
      replace: true,
      template: template,
      link: link
    };

    function template(tElem, tAttrs) {
      var p = _.has(tAttrs, 'sgCalendarGhost')? '' : '::';

      return [
        '<div class="sg-event"',
        //  Add a class while dragging
        '   ng-class="{\'sg-event--dragging\': block.dragging}"',
        '   ng-click="clickBlock({clickEvent: $event, clickComponent: block.component})">',
        // Categories color stripes
        '  <div class="sg-category" ng-repeat="category in '+p+'block.component.categories"',
        '     ng-class="'+p+'(\'bg-category\' + category)"',
        '     ng-style="'+p+'{ right: ($index * 10) + \'%\' }"></div>',
        '  <div class="text">',
        //   Start hour
        '    <span class="secondary" ng-if="'+p+'(!block.component.c_isallday && block.isFirst)">{{ '+p+'block.component.startHour }}</span>',
        //   Priority
        '    <span ng-show="'+p+'block.component.c_priority" class="sg-priority">{{'+p+'block.component.c_priority}}</span>',
        //   Summary
        '    {{ '+p+'block.component.summary }}',
        '    <span class="sg-icons">',
        //     Component is reccurent
        '      <md-icon ng-if="'+p+'block.component.occurrenceId">repeat</md-icon>',
        //     Component has an alarm
        '      <md-icon ng-if="'+p+'block.component.c_nextalarm">alarm</md-icon>',
        //     Component is confidential
        '      <md-icon ng-if="'+p+'block.component.c_classification == 2">visibility_off</md-icon>',
        //     Component is private
        '      <md-icon ng-if="'+p+'block.component.c_classification == 1">vpn_key</md-icon>',
        '    </span>',
        '  </div>',
        '</div>'
      ].join('');
    }

    function link(scope, iElement, attrs) {
      if (!_.has(attrs, 'sgCalendarGhost')) {

        // Add class for user's participation state
        if (scope.block.userState)
          iElement.addClass('sg-event--' + scope.block.userState);

        if (scope.block.component) {
          // Set background color
          iElement.addClass('bg-folder' + scope.block.component.pid);

          // Add class for transparency
          if (scope.block.component.c_isopaque === 0)
            iElement.addClass('sg-event--transparent');

          // Add class for cancelled event
          if (scope.block.component.c_status === 0)
            iElement.addClass('sg-event--cancelled');
        }

      }
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarMonthEvent', sgCalendarMonthEvent);
})();
