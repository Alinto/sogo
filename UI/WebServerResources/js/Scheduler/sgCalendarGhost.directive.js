/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarBlock - Applied to an event ghost block to be displayed while dragging an event block. Each day of the
   *   calendar's view must have a ghost block.
   * @memberof SOGo.SchedulerUI
   * @restrict attribute
   *
   * @example:

   <sg-calendar-day-block
     sg-calendar-ghost
     sg-block="list.component.$ghost">/
  */
  sgCalendarGhost.$inject = ['$rootScope', '$timeout', 'CalendarSettings', 'Calendar', 'Component'];
  function sgCalendarGhost($rootScope, $timeout, CalendarSettings, Calendar, Component) {
    return {
      restrict: 'A',
      require: ['^sgCalendarDay', '^sgCalendarScrollView'],
      link: link
    };

    function link(scope, iElement, attrs, ctrls) {
      var domElement, calendarDayCtrl, scrollViewCtrl, calendarNumber, originalCalendarNumber;

      domElement = iElement[0];
      calendarDayCtrl = ctrls[0];
      scrollViewCtrl = ctrls[1];
      calendarNumber = -1;

      iElement.addClass('sg-event--ghost md-whiteframe-3dp ng-hide');

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
        var pid, calendarData, userState;

        // Expose ghost block to the scope
        scope.block = Component.$ghost;

        calendarData = calendarDayCtrl.calendarData();
        if (calendarData) {
          // A calendar is associated to the day; this is a special multicolumn day view
          calendarNumber = calendarData.index;
          pid = calendarData.pid;
          originalCalendarNumber = scope.block.pointerHandler.originalCalendar.index;
        }

        if (!pid)
          pid = scope.block.component.pid;

        // Add class for user's participation state
        userState = scope.block.component.blocks[0].userState;
        if (userState)
          iElement.addClass('sg-event--' + userState);

        // Set background color
        iElement.addClass('bg-folder' + pid);
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
        var showGhost, isRelative, currentDay,
            start, duration, durationLeft, maxDuration;

        showGhost = false;

        if (Calendar.$view && Calendar.$view.type == scrollViewCtrl.type) {
          // The view of the dragging block is the scrolling view of this ghost block

          isRelative   = scrollViewCtrl.type === 'multiday-allday';
          currentDay   = scope.block.pointerHandler.currentEventCoordinates.dayNumber;
          start        = scope.block.pointerHandler.currentEventCoordinates.start;
          durationLeft = scope.block.pointerHandler.currentEventCoordinates.duration;
          maxDuration  = CalendarSettings.EventDragDayLength - start;

          if (angular.isUndefined(durationLeft))
            return;
          duration = durationLeft;
          if (duration > maxDuration)
            duration = maxDuration;

          if (currentDay > -1 &&                                 // pointer is inside viewport
              ((calendarNumber < 0 &&                            // day is not associated to a calendar
                currentDay == calendarDayCtrl.dayNumber) ||      // pointer is inside ghost's day
               currentDay == calendarNumber &&                   // pointer is inside ghost's calendar
               (originalCalendarNumber == calendarNumber ||      // still inside original calendar
                !scope.block.component.isException)              // not an exception, event can be moved to a
                                                                 // different calendar
              )) {
            // This ghost block (day) is the first of the dragging event
            showGhost = true;
            if (!isRelative) {
              // Show start hour and set the vertical position
              scope.block.startHour = getStartTime(start);
              // Set the height
              if (Calendar.$view.quarterHeight) {
                iElement.css('top', (start * Calendar.$view.quarterHeight) + 'px');
                iElement.css('height', (duration * Calendar.$view.quarterHeight) + 'px');
              }
              else
                iElement.css('top', Calendar.$view.topOffset + 'px');
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
              if (!isRelative) {
                iElement.css('top', Calendar.$view.topOffset + 'px');
                // Set the height
                if (Calendar.$view.quarterHeight)
                  iElement.css('height', (duration * Calendar.$view.quarterHeight) + 'px');
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
            if (isRelative) {
              iElement.addClass('sg-event--ghost--last');
            }
            else {
              // Set the end date
              scope.block.endHour = getEndTime(start, duration);
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
    .directive('sgCalendarGhost', sgCalendarGhost);
})();
