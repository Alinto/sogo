/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayBlock - An event block to be displayed in a week
   * @memberof SOGo.Common
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @ngInject
   * @example:

   <sg-calendar-day-block
   ng-repeat="block in blocks[day]"
   sg-block="block"/>
  */
  function sgCalendarDayBlock() {
    return {
      restrict: 'E',
      scope: {
        block: '=sgBlock'
      },
      replace: true,
      template: [
        '<div class="event draggable">',
        '  <div class="eventInside">',
        '      <div class="gradient">',
        '      </div>',
        '      <div class="text">{{ block.component.c_title }}',
        '        <span class="icons">',
        '          <i ng-if="block.component.c_nextalarm" class="md-icon-alarm"></i>',
        '          <i ng-if="block.component.c_classification == 1" class="md-icon-visibility-off"></i>',
        '          <i ng-if="block.component.c_classification == 2" class="md-icon-vpn-key"></i>',
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
