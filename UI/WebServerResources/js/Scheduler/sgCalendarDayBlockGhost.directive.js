/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarDayBlockGhost - An event ghost block to be displayed while dragging an event block. Each day of the
   *   calendar's view is associated to a ghost block.
   * @memberof SOGo.SchedulerUI
   * @restrict element
   *
   * @example:

   <sg-calendar-day-block-ghost/>
  */
  sgCalendarDayBlockGhost.$inject = ['$rootScope', '$timeout', 'CalendarSettings', 'Calendar', 'Component'];
  function sgCalendarDayBlockGhost($rootScope, $timeout, CalendarSettings, Calendar, Component) {
    return {
      restrict: 'E',
      require: ['^sgCalendarDay', '^sgCalendarScrollView'],
      replace: true,
      template: [
        '<div class="sg-event sg-event--ghost ng-hide">',
        '  <div class="eventInside">',
        //   Categories color stripes
        '    <div class="category" ng-repeat="category in block.component.categories"',
        '         ng-class="\'bg-category\' + category"',
        '         ng-style="{ right: ($index * 10) + \'%\' }"></div>',
        '    <div class="text">{{ block.component.summary }}',
        '      <span class="icons">',
        //       Component is reccurent
        '        <md-icon ng-if="block.component.occurrenceId" class="material-icons icon-repeat"></md-icon>',
        //       Component has an alarm
        '        <md-icon ng-if="block.component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        //       Component is confidential
        '        <md-icon ng-if="block.component.c_classification == 1" class="material-icons icon-visibility-off"></md-icon>',
        //       Component is private
        '        <md-icon ng-if="block.component.c_classification == 2" class="material-icons icon-vpn-key"></md-icon>',
        '      </span>',
        //     Location
        '      <div class="secondary" ng-if="block.component.c_location">',
        '        <md-icon>place</md-icon> {{block.component.c_location}}',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="ghostStartHour" ng-if="startHour">{{ startHour }}</div>',
        '  <div class="ghostEndHour" ng-if="endHour">{{ endHour }}</div>',
        '</div>'
      ].join(''),
      link: link
    };

    function link(scope, iElement, attrs, ctrls) {
      var domElement, calendarDayCtrl, scrollViewCtrl;

      domElement = iElement[0];
      calendarDayCtrl = ctrls[0];
      scrollViewCtrl = ctrls[1];

      // Listen on drag gestures
      var deregisterDragStart = $rootScope.$on('calendar:dragstart', initGhost);
      var deregisterDrag = $rootScope.$on('calendar:drag', updateGhost);
      var deregisterDragEnd = $rootScope.$on('calendar:dragend', hideGhost);

      // Deregister listeners on destroy
      scope.$on('$destroy', function() {
        deregisterDragStart();
        deregisterDrag();
        deregisterDragEnd();
      });

      function initGhost() {
        // Expose ghost block to the scope
        scope.block = Component.$ghost;
        // Set background color
        iElement.addClass('bg-folder' + scope.block.component.pid);
      }

      function hideGhost() {
        // Remove background color
        _.forEachRight(domElement.classList, function(c) {
          if (/^bg-folder/.test(c))
            iElement.removeClass(c);
        });
        // Hide ghost
        iElement.addClass('ng-hide');
      }

      function updateGhost() {
        // From SOGoEventDragGhostController._updateGhosts
        var showGhost, isAllDay, originalDay, currentDay, wasOtherBlock,
            start, duration, durationLeft, maxDuration, enableTransition;

        showGhost = false;
        enableTransition = function() {
          iElement.removeClass('sg-event--notransition');
        };

        if (Calendar.$view && Calendar.$view.type == scrollViewCtrl.type) {
          // The view of the dragging block is the scrolling view of this ghost block

          isAllDay     = scope.block.component.c_isallday;
          originalDay  = scope.block.pointerHandler.originalEventCoordinates.dayNumber;
          currentDay   = scope.block.pointerHandler.currentEventCoordinates.dayNumber;
          start        = scope.block.pointerHandler.currentEventCoordinates.start;
          durationLeft = scope.block.pointerHandler.currentEventCoordinates.duration;
          maxDuration  = CalendarSettings.EventDragDayLength - start;

          if (angular.isUndefined(durationLeft))
            return;

          duration = durationLeft;
          if (duration > maxDuration)
            duration = maxDuration;

          delete scope.startHour;
          delete scope.endHour;

          if (currentDay > -1 && currentDay == calendarDayCtrl.dayNumber) {
            // This ghost block (day) is the first of the dragging event
            showGhost = true;
            if (!isAllDay)  {
              // Show start hour and set the vertical position
              scope.startHour = getStartTime(start);
              wasOtherBlock = parseInt(iElement.css('top')) === 0;
              if (wasOtherBlock)
                iElement.addClass('sg-event--notransition');
              iElement.css('top', (start * Calendar.$view.quarterHeight) + 'px');
              iElement.css('height', (duration * Calendar.$view.quarterHeight) + 'px');
              if (wasOtherBlock)
                $timeout(enableTransition);
            }
            iElement.removeClass('fg-folder' + scope.block.component.pid);
            iElement.removeClass('sg-event--ghost--last');
            iElement.addClass('sg-event--ghost--first');
          }

          durationLeft -= duration;
          currentDay++;

          // Search a subsequent block that matches the current ghost's day
          while (!showGhost && durationLeft && currentDay <= calendarDayCtrl.dayNumber) {
            duration = durationLeft;
            if (duration > CalendarSettings.EventDragDayLength)
              duration = CalendarSettings.EventDragDayLength;
            if (currentDay > -1 && currentDay == calendarDayCtrl.dayNumber) {
              // The dragging event overlaps this current ghost's day
              showGhost = true;
              if (!isAllDay) {
                wasOtherBlock = parseInt(iElement.css('top')) !== 0;
                if (wasOtherBlock)
                  iElement.addClass('sg-event--notransition');
                // Set the height
                iElement.css('top', '0px');
                iElement.css('height', (duration * Calendar.$view.quarterHeight) + 'px');
                if (wasOtherBlock)
                  $timeout(enableTransition);
              }
              iElement.removeClass('sg-event--ghost--first');
              iElement.removeClass('sg-event--ghost--last');
              // Trick for all-day events: set the foreground color to the background color so the event's title
              // is not visible but the div size remains identical.
              iElement.addClass('fg-folder' + scope.block.component.pid);
            }
            durationLeft -= duration;
            currentDay++;
            start = 0;
          }
          if (!durationLeft) {
            // Reached last ghost block
            if (isAllDay) {
              iElement.addClass('sg-event--ghost--last');
            }
            else {
              // Set the end date
              scope.endHour = getEndTime(start, duration);
            }
          }
        }

        if (showGhost)
          iElement.removeClass('ng-hide');
        else
          iElement.addClass('ng-hide');
      }

      function quartersToHM(quarters) {
        var minutes, hours, mins;

        minutes = quarters * 15;
        hours = Math.floor(minutes / 60);
        if (hours < 10)
            hours = "0" + hours;
        mins = minutes % 60;
        if (mins < 10)
            mins = "0" + mins;

        return "" + hours + ":" + mins;
      }

      function getStartTime(start) {
        return quartersToHM(start);
      }

      function getEndTime(start, duration) {
        var end = (start + duration) % CalendarSettings.EventDragDayLength;
        return quartersToHM(end);
      }
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarDayBlockGhost', sgCalendarDayBlockGhost);
})();
