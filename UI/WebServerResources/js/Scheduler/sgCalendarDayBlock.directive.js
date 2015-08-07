/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayBlock - An event block to be displayed in a week
   * @memberof SOGo.Common
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
  function sgCalendarDayBlock() {
    return {
      restrict: 'E',
      scope: {
        block: '=sgBlock',
        clickBlock: '&sgClick'
      },
      replace: true,
      template: [
        '<div class="sg-event sg-draggable">',
        '  <div class="eventInside" ng-click="clickBlock({clickEvent: $event, clickComponent: block.component})">',
        '      <div class="gradient">',
        '      </div>',
        '      <div class="text">{{ block.component.c_title }}',
        '        <span class="icons">',
        // Component has an alarm
        '          <md-icon ng-if="block.component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        // Component is confidential
        '          <md-icon ng-if="block.component.c_classification == 1" class="material-icons icon-visibility-off"></md-icon>',
        // Component is private
        '          <md-icon ng-if="block.component.c_classification == 2" class="material-icons icon-vpn-key"></md-icon>',
        '       </span></div>',
        '    </div>',
        '    <div class="topDragGrip"></div>',
        '    <div class="bottomDragGrip"></div>',
        '</div>'
      ].join(''),
      link: link
    };

    function link(scope, iElement, attrs) {
      // Compute overlapping (5%)
      var pc = 100 / scope.block.siblings,
          left = scope.block.position * pc,
          right = 100 - (scope.block.position + 1) * pc;

      if (pc < 100) {
        if (left > 0)
          left -= 5;
        if (right > 0)
          right -= 5;
      }

      // Set position
      iElement.css('left', left + '%');
      iElement.css('right', right + '%');
      iElement.addClass('starts' + scope.block.start);
      iElement.addClass('lasts' + scope.block.length);
      iElement.addClass('bg-folder' + scope.block.component.c_folder);
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarDayBlock', sgCalendarDayBlock);
})();
