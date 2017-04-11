/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayBlock - An event block to be displayed in a week
   * @memberof SOGo.SchedulerUI
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @param {function} sgClick - the function to call when clicking on a block.
   *        Two variables are available: clickEvent (the event that triggered the mouse click),
   *        and clickComponent (a Component object)
   *
   * @example:

   <sg-calendar-day-block
      ng-repeat="block in blocks[day]"
      sg-block="block"
      sg-click="open(clickEvent, clickComponent)" />
  */
  sgCalendarDayBlock.$inject = ['CalendarSettings'];
  function sgCalendarDayBlock(CalendarSettings) {
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
        //    Add a class while dragging
        '     ng-class="{\'sg-event--dragging\': block.dragging}">',
        '  <div class="eventInside"',
        '       ng-click="clickBlock({clickEvent: $event, clickComponent: block.component})">',
        //   Categories color stripes
        '    <div class="sg-category" ng-repeat="category in '+p+'block.component.categories"',
        '         ng-class="'+p+'(\'bg-category\' + category)"',
        '         ng-style="'+p+'{ right: ($index * 3) + \'px\' }"></div>',
        '    <div class="text">',
        //     Priority
        '      <span ng-show="'+p+'block.component.c_priority" class="sg-priority">{{'+p+'block.component.c_priority}}</span>',
        //     Summary
        '      {{ '+p+'block.component.summary }}',
        '      <span class="icons">',
        //       Component is reccurent
        '        <md-icon ng-if="'+p+'block.component.occurrenceId" class="material-icons icon-repeat"></md-icon>',
        //       Component has an alarm
        '        <md-icon ng-if="'+p+'block.component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        //       Component is confidential
        '        <md-icon ng-if="'+p+'block.component.c_classification == 2" class="material-icons icon-visibility-off"></md-icon>',
        //       Component is private
        '        <md-icon ng-if="'+p+'block.component.c_classification == 1" class="material-icons icon-vpn-key"></md-icon>',
        '      </span>',
        //     Location
        '      <div class="secondary" ng-if="'+p+'block.component.c_location">',
        '        <md-icon>place</md-icon> {{'+p+'block.component.c_location}}',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="ghostStartHour" ng-if="block.startHour">{{ block.startHour }}</div>',
        '  <div class="ghostEndHour" ng-if="block.endHour">{{ block.endHour }}</div>',
        '</div>'
      ].join('');
    }

    function link(scope, iElement, attrs) {
      var pc, left, right;

      if (!_.has(attrs, 'sgCalendarGhost')) {

        // Compute overlapping (2%)
        pc = 100 / scope.block.siblings;
        left = scope.block.position * pc;
        right = 100 - (scope.block.position + 1) * pc;
        if (pc < 100) {
          if (left > 0)
            left -= 2;
          if (right > 0)
            right -= 2;
        }

        // Add some padding (2%)
        if (left === 0)
          left = 2;
        if (right === 0)
          right = 2;

        // Set position
        iElement.css('left', left + '%');
        iElement.css('right', right + '%');
        if (!scope.block.component || !scope.block.component.c_isallday) {
          iElement.addClass('starts' + scope.block.start);
          iElement.addClass('lasts' + scope.block.length);
        }

        // Add class for user's participation state
        if (scope.block.userState)
          iElement.addClass('sg-event--' + scope.block.userState);

        if (scope.block.component) {
          // Set background color
          iElement.addClass('bg-folder' + scope.block.component.pid);
          iElement.addClass('contrast-bdr-folder' + scope.block.component.pid);

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
    .directive('sgCalendarDayBlock', sgCalendarDayBlock);
})();
