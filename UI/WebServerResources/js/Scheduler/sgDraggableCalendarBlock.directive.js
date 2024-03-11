/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgDraggableCalendarBlock - Make an element draggable
   * @memberof SOGo.SchedulerUI
   * @restrict class or attribute
   *
   * @example:

   <div class="sg-draggable-calendar-block"/>
  */
  sgDraggableCalendarBlock.$inject = ['$rootScope', '$timeout', '$log', 'Preferences', 'Calendar', 'CalendarSettings', 'Component'];
  function sgDraggableCalendarBlock($rootScope, $timeout, $log, Preferences, Calendar, CalendarSettings, Component) {
    return {
      restrict: 'CA',
      require: '^sgCalendarDay',
      link: link
    };

    function link(scope, element, attrs, calendarDayCtrl) {
      if (scope.block) {
        if (scope.block.component.editable && !scope.block.userState) {
          // Add dragging grips to existing event block
          initGrips();
        }
        else {
          element.removeClass('sg-draggable-calendar-block');
          return;
        }
      }

      // Start dragging on mousedown
      element.on('mousedown', onDragDetect);
      element.on('dblclick', onDoubleClick);

      // Deregister listeners when removing the element from the DOM
      scope.$on('$destroy', function() {
        element.off('mousedown', onDragDetect);
        element.off('mousemove', onDrag);
      });

      function initGrips() {
        var component, dayIndex, blockIndex, isFirstBlock, isLastBlock,
            dragGrip, leftGrip, rightGrip, topGrip, bottomGrip;

        // Don't show grips for blocks of less than 45 minutes
        if (scope.block.length < 3) return;

        component = scope.block.component;
        dayIndex = scope.block.dayIndex;
        blockIndex = _.findIndex(component.blocks, ['dayIndex', dayIndex]);
        isFirstBlock = (blockIndex === 0);
        isLastBlock = (blockIndex === component.blocks.length - 1);

        dragGrip = angular.element('<div class="dragGrip"></div>');
        dragGrip.addClass('bdr-folder' + component.pid);

        if (component.c_isallday ||
            element[0].parentNode.tagName === 'SG-CALENDAR-MONTH-DAY') {
          if (isFirstBlock) {
            leftGrip = angular.element('<div class="dragGrip-left"></div>').append(dragGrip);
            element.append(leftGrip);
          }
          if (isLastBlock) {
            rightGrip = angular.element('<div class="dragGrip-right"></div>').append(dragGrip.clone());
            element.append(rightGrip);
          }
        }
        else {
          if (isFirstBlock) {
            topGrip = angular.element('<div class="dragGrip-top"></div>').append(dragGrip);
            element.append(topGrip);
          }
          if (isLastBlock) {
            bottomGrip = angular.element('<div class="dragGrip-bottom"></div>').append(dragGrip.clone());
            element.append(bottomGrip);
          }
        }
      }

      function onDragDetect(ev) {
        var dragMode, pointerHandler, hasVerticalScrollbar, rect, scrollableZone;

        ev.stopPropagation();

        hasVerticalScrollbar = ev.target.scrollHeight > ev.target.clientHeight + 1;

        if (hasVerticalScrollbar) {
          // Check if mouse click is inside scrollbar
          rect = ev.target.getBoundingClientRect();
          scrollableZone = rect.left + rect.width - 18;
          if (ev.pageX > scrollableZone)
            return;
        }

        dragMode = 'move-event';

        if (scope.block && scope.block.component) {
          // Move or resize existing component
          if (ev.target.className == 'dragGrip-top' ||
              ev.target.className == 'dragGrip-left')
            dragMode = 'change-start';
          else if (ev.target.className == 'dragGrip-bottom' ||
                   ev.target.className == 'dragGrip-right' )
            dragMode = 'change-end';
        }
        else {
          // Create new component from dragging
          dragMode = 'change-end';
        }

        // Initialize pointer handler
        pointerHandler = new SOGoEventDragPointerHandler(dragMode);
        pointerHandler.initFromEvent(ev);

        // Update Component.$ghost
        Component.$ghost.pointerHandler = pointerHandler;

        // Stop dragging on the next "mouseup"
        angular.element(document).one('mouseup', onDragEnd);

        // Listen to mousemove and start dragging when mouse has moved from at least 3 pixels
        angular.element(document).on('mousemove', onDrag);
      }

      function dragStart(ev) {
        var block, eventType, isHourCell, isMonthly, startDate, newData, newComponent, pointerHandler, calendarData;

        isHourCell = element.hasClass('clickableHourCell');
        isMonthly = (element[0].parentNode.tagName == 'SG-CALENDAR-MONTH-DAY') ||
          element.hasClass('clickableDayCell');

        calendarData = calendarDayCtrl.calendarData();

        if (scope.block && scope.block.component) {
          // Move or resize existing component
          block = scope.block;
        }
        else {
          // Create new component from dragging
          startDate = calendarDayCtrl.dayString.parseDate(Preferences.$mdDateLocaleProvider, '%Y-%m-%e');
          newData = {
            type: 'appointment',
            pid: calendarData? calendarData.pid : Calendar.$defaultCalendar(),
            summary: l('New Event'),
            startDate: startDate,
            isAllDay: isHourCell? 0 : 1
          };
          newComponent = new Component(newData);
          block = {
            component: newComponent,
            dayNumber: calendarDayCtrl.dayNumber,
            length: 0
          };
          block.component.blocks = [block];
        }

        // Determine event type
        eventType = 'multiday';
        if (isMonthly)
          eventType = 'monthly';
        else if (block.component.c_isallday)
          eventType = 'multiday-allday';

        // Mark all blocks as being dragged
        _.forEach(block.component.blocks, function(b) {
          b.dragging = true;
        });

        // Update pointer handler
        pointerHandler = Component.$ghost.pointerHandler;
        pointerHandler.prepareWithEventType(eventType);
        pointerHandler.initFromBlock(block);
        if (calendarData)
          // When the day is associated to a calendar, the day number becomes the calendar index
          // among the active calendars
          pointerHandler.initFromCalendar(calendarData);

        // Update Component.$ghost
        Component.$ghost.component = block.component;

        $log.debug('emit calendar:dragstart ' + eventType);
        $rootScope.$emit('calendar:dragstart');
      }

      function onDrag(ev) {
        var pointerHandler = Component.$ghost.pointerHandler;

        // Update
        // - currentCoordinates
        // - currentViewCoordinates
        // - currentEventCoordinates
        $timeout(function() {
          pointerHandler.updateFromEvent(ev);
        });
      }

      function onDragEnd(ev) {
        var block, pointer;

        block = scope.block;
        pointer = Component.$ghost.pointerHandler;

        // Deregister mouse events
        angular.element(document).off('mousemove', onDrag);

        if (pointer.dragHasStarted) {
          $rootScope.$emit('calendar:dragend');
          pointer.dragHasStarted = false;
        }

        // Unmark all blocks as being dragged
        if (block && block.component)
          _.forEach(block.component.blocks, function(b) {
            b.dragging = false;
          });
      }

      function onDoubleClick(ev) {
        var block, pointerHandler, startDate, newData, newComponent;
        
        startDate = calendarDayCtrl.dayString.parseDate(Preferences.$mdDateLocaleProvider, '%Y-%m-%e');
        newData = {
          type: 'appointment',
          pid: Calendar.$defaultCalendar(),
          summary: l('New Event'),
          startDate: startDate,
          isAllDay: 1
        };
        newComponent = new Component(newData);
        block = {
          component: newComponent,
          dayNumber: calendarDayCtrl.dayNumber,
          length: 0
        };
        block.component.blocks = [block];

        pointerHandler = new SOGoEventDragPointerHandler('double-click');
        pointerHandler.initFromBlock(block);
        pointerHandler.currentEventCoordinates.duration = 0;
        
        // Update Component.$ghost
        Component.$ghost.pointerHandler = pointerHandler;

        Component.$ghost.component = block.component;
        $rootScope.$emit('calendar:doubleclick');
      }

      /**
       * SOGoCoordinates
       */
      function SOGoCoordinates() {
      }

      SOGoCoordinates.prototype = {
        x: -1,
        y: -1,

        getDelta: function SC_getDelta(otherCoordinates) {
          var delta = new SOGoCoordinates();
          delta.x = this.x - otherCoordinates.x;
          delta.y = this.y - otherCoordinates.y;

          if (Calendar.$view) {
            delta.days = Calendar.$view.dayNumbers[this.x] - Calendar.$view.dayNumbers[otherCoordinates.x];
          }

          return delta;
        },

        getDistance: function SC_getDistance(otherCoordinates) {
          var delta = this.getDelta(otherCoordinates);

          return Math.sqrt(delta.x * delta.x + delta.y * delta.y);
        },

        clone: function SC_clone() {
          var coordinates = new SOGoCoordinates();
          coordinates.x = this.x;
          coordinates.y = this.y;

          return coordinates;
        }
      };

      /**
       * SOGoEventDragEventCoordinates
       */
      function SOGoEventDragEventCoordinates(eventType) {
        this.setEventType(eventType);
      }

      SOGoEventDragEventCoordinates.prototype = {
        dayNumber: -1,
        weekDay: -1,
        start: -1,
        duration: -1,

        eventType: null,

        setEventType: function(eventType) {
          this.eventType = eventType;
        },

        initFromBlock: function(block) {
          var prevDayNumber = -1;

          if (this.eventType === 'monthly') {
            this.start = 0;
            this.duration = block.component.blocks.length * CalendarSettings.EventDragDayLength;
          }
          else {
            // Get the start (first quarter) from the event's first block
            // Compute overall length
            this.start = block.component.blocks[0].start;
            this.duration = _.sumBy(block.component.blocks, function(b) {
              var delta, currentDayNumber;

              currentDayNumber = b.dayNumber;
              if (prevDayNumber < 0)
                delta = 0;
              else
                delta = currentDayNumber - prevDayNumber - 1;
              prevDayNumber = currentDayNumber;

              return b.length + delta * CalendarSettings.EventDragDayLength;
            });
          }
        },

        initFromCalendar: function(calendarNumber) {
          this.dayNumber = calendarNumber;
        },

        getDelta: function(otherCoordinates) {
          var delta = new SOGoEventDragEventCoordinates();
          delta.dayNumber = (this.dayNumber - otherCoordinates.dayNumber);
          delta.start = (this.start - otherCoordinates.start);
          delta.duration = (this.duration - otherCoordinates.duration);

          return delta;
        },

        _quartersToHM: function(quarters) {
          var minutes = quarters * 15;
          var hours = Math.floor(minutes / 60);
          if (hours < 10)
            hours = "0" + hours;
          var mins = minutes % 60;
          if (mins < 10)
            mins = "0" + mins;

          return "" + hours + ":" + mins;
        },

        getStartTime: function() {
          return this._quartersToHM(this.start);
        },

        getEndTime: function() {
          var end = (this.start + this.duration) % CalendarSettings.EventDragDayLength;
          return this._quartersToHM(end);
        },

        clone: function() {
          var coordinates = new SOGoEventDragEventCoordinates();
          coordinates.dayNumber = this.dayNumber;
          coordinates.start = this.start;
          coordinates.duration = this.duration;

          return coordinates;
        }
      };

      /**
       * SOGoEventDragPointerHandler
       */
      function SOGoEventDragPointerHandler(dragMode) {
        this.dragMode = dragMode;
      }

      SOGoEventDragPointerHandler.prototype = {
        // Pointer absolute xy coordinates within page
        originalCoordinates: null,
        currentCoordinates: null,

        // Pointer relative xy coordinates within view (row-column)
        originalViewCoordinates: null,
        currentViewCoordinates: null,

        // Event start-duration coordinates
        originalEventCoordinates: null,
        currentEventCoordinates: null,

        originalCalendar: null,

        dragHasStarted: false,

        // Function to return the day and quarter coordinates of the pointer cursor
        // within the day view
        getEventViewCoordinates: null,

        initFromBlock: function SEDPH_initFromBlock(block) {
          this.currentEventCoordinates = new SOGoEventDragEventCoordinates(this.eventType);
          this.originalEventCoordinates = new SOGoEventDragEventCoordinates(this.eventType);
          this.originalEventCoordinates.initFromBlock(block);
        },

        initFromEvent: function SEDPH_initFromEvent(event) {
          this.currentCoordinates = new SOGoCoordinates();
          this.updateFromEvent(event);
          this.originalCoordinates = this.currentCoordinates.clone();
        },

        initFromCalendar: function SEDPH_initFromCalendar(calendarData) {
          this.originalCalendar = calendarData;
          this.currentEventCoordinates.initFromCalendar(calendarData.index);
          this.originalEventCoordinates.initFromCalendar(calendarData.index);
        },

        // Method continuously called while dragging
        updateFromEvent: function SEDPH_updateFromEvent(event) {
          // Event here is a DOM event, not a calendar event!
          this.currentCoordinates.x = event.pageX;
          this.currentCoordinates.y = event.pageY;

          // From SOGoEventDragGhostController.updateFromPointerHandler
          if (this.dragHasStarted && Calendar.$view) {
            var newEventCoordinates = this.getEventViewCoordinates(Calendar.$view);
            if (!this.originalViewCoordinates) {
              this.originalViewCoordinates = this.getEventViewCoordinates(Calendar.$view, this.originalCoordinates);
              if (Component.$ghost.component.isNew) {
                this.setTimeFromQuarters(Component.$ghost.component.start, this.originalViewCoordinates.y);
                $log.debug('new event start date ' + Component.$ghost.component.start);
              }
            }
            if (!this.currentViewCoordinates ||
                !newEventCoordinates ||
                newEventCoordinates.x != this.currentViewCoordinates.x ||
                newEventCoordinates.y != this.currentViewCoordinates.y) {
              this.currentViewCoordinates = newEventCoordinates;
              if (this.originalViewCoordinates) {
                if (!newEventCoordinates) {
                  this.currentViewCoordinates = this.originalViewCoordinates.clone();
                }
                this.updateEventCoordinates();
              }
            }
          }
          else if (this.originalCoordinates &&
                   this.currentCoordinates &&
                   !this.dragHasStarted) {
            var distance = this.getDistance();
            if (distance > 3) {
              this.dragHasStarted = true;
              dragStart(event);
            }
          }
        },

        // SOGoEventDragGhostController._updateCoordinates
        // Extend this.currentCoordinates with start, dayNumber and duration
        updateEventCoordinates: function SEDGC__updateCoordinates() {
          var newDuration;

          // Compute delta wrt to position of mouse at dragstart on the day/quarter grid
          var delta = this.currentViewCoordinates.getDelta(this.originalViewCoordinates);
          var deltaQuarters = delta.days * CalendarSettings.EventDragDayLength + delta.y;
          $log.debug('quarters delta ' + deltaQuarters);

          if (angular.isUndefined(this.originalEventCoordinates.start)) {
            // Creating new appointment from DnD
            this.originalEventCoordinates.dayNumber = Calendar.$view.dayNumbers[this.originalViewCoordinates.x];
            this.originalEventCoordinates.start = this.originalViewCoordinates.y;
          }
          else if (this.originalEventCoordinates.dayNumber < 0) {
            this.originalEventCoordinates.dayNumber = Calendar.$view.dayNumbers[scope.block.component.blocks[0].dayIndex];
          }
          // if (currentView == "multicolumndayview")
          //   this._updateMulticolumnViewDayNumber_SEDGC();
          // else
          this.currentEventCoordinates.dayNumber = this.originalEventCoordinates.dayNumber;

          if (this.dragMode == "move-event") {
            this.currentEventCoordinates.start = this.originalEventCoordinates.start + deltaQuarters;
            this.currentEventCoordinates.duration = this.originalEventCoordinates.duration;
          }
          else {
            if (this.dragMode == "change-start") {
              newDuration = this.originalEventCoordinates.duration - deltaQuarters;
              if (newDuration > 0) {
                this.currentEventCoordinates.start = this.originalEventCoordinates.start + deltaQuarters;
                this.currentEventCoordinates.duration = newDuration;
              }
              else if (newDuration < 0) {
                this.currentEventCoordinates.start = (this.originalEventCoordinates.start + this.originalEventCoordinates.duration);
                this.currentEventCoordinates.duration = -newDuration;
              }
            }
            else if (this.dragMode == "change-end") {
              newDuration = this.originalEventCoordinates.duration + deltaQuarters;
              if (newDuration > 0) {
                this.currentEventCoordinates.start = this.originalEventCoordinates.start;
                this.currentEventCoordinates.duration = newDuration;
              }
              else if (newDuration < 0) {
                this.currentEventCoordinates.start = this.originalEventCoordinates.start + newDuration;
                this.currentEventCoordinates.duration = -newDuration;
              }
            }
          }

          var deltaDays;
          if (this.currentEventCoordinates.start < 0) {
            deltaDays = Math.ceil(-this.currentEventCoordinates.start / CalendarSettings.EventDragDayLength);
            this.currentEventCoordinates.start += deltaDays * CalendarSettings.EventDragDayLength;
            this.currentEventCoordinates.dayNumber -= deltaDays;
          }
          else if (this.currentEventCoordinates.start >= CalendarSettings.EventDragDayLength) {
            deltaDays = Math.floor(this.currentEventCoordinates.start / CalendarSettings.EventDragDayLength);
            this.currentEventCoordinates.start -= deltaDays * CalendarSettings.EventDragDayLength;
            this.currentEventCoordinates.dayNumber += deltaDays;
          }

          $log.debug('event coordinates ' + JSON.stringify(this.currentEventCoordinates));
          $rootScope.$emit('calendar:drag');
        },

        // SOGoEventDragPointerHandler.getContainerBasedCoordinates
        getContainerBasedCoordinates: function SEDPH_getCBC(view, pointerCoordinates) {
          var currentCoordinates = pointerCoordinates || this.currentCoordinates;
          var coordinates = currentCoordinates.getDelta(view.coordinates);
          var container = view.element;

          if (coordinates.x < view.daysOffset || coordinates.x > container.clientWidth ||
              coordinates.y < 0 || coordinates.y > container.clientHeight)
            coordinates = null;

          return coordinates;
        },

        prepareWithEventType: function SEDPH_prepareWithEventType(eventType) {
          var methods = { "multiday": this.getEventMultiDayViewCoordinates,
                          "multiday-allday": this.getEventMultiDayAllDayViewCoordinates,
                          "monthly": this.getEventMonthlyViewCoordinates,
                          "unknown": null };
          var method = methods[eventType];
          this.eventType = eventType;
          this.getEventViewCoordinates = method;
        },

        getEventMultiDayViewCoordinates: function SEDPH_gEMultiDayViewC(view, pointerCoordinates) {
          /* x = day; y = quarter */
          var coordinates = this.getEventMultiDayAllDayViewCoordinates(view, pointerCoordinates); // get the x coordinate
          if (coordinates) {
            var quarterHeight = view.quarterHeight;
            var pxCoordinates = this.getContainerBasedCoordinates(view, pointerCoordinates);
            pxCoordinates.y += view.element.scrollTop;

            coordinates.y = Math.floor((pxCoordinates.y - CalendarSettings.EventDragHorizontalOffset) / quarterHeight);
            var maxY = CalendarSettings.EventDragDayLength - 1;
            if (coordinates.y < 0)
              coordinates.y = 0;
            else if (coordinates.y > maxY)
              coordinates.y = maxY;
          }

          return coordinates;
        },
        getEventMultiDayAllDayViewCoordinates: function SEDPH_gEMultiDayADVC(view, pointerCoordinates) {
          /* x = day; y = quarter */
          var coordinates;

          var pxCoordinates = this.getContainerBasedCoordinates(view, pointerCoordinates);
          if (pxCoordinates) {
            coordinates = new SOGoCoordinates();

            var dayWidth = view.dayWidth;
            var daysOffset = view.daysOffset;

            coordinates.x = Math.floor((pxCoordinates.x - daysOffset) / dayWidth);
            var minX = 0;
            var maxX = Calendar.$view.maxX;
            if (this.dragMode != 'move-event') {
              var calendarData = calendarDayCtrl.calendarData();
              if (calendarData)
                // Resizing an event can't span a different day when in multicolumn view
                minX = maxX = calendarData.index;
            }
            if (coordinates.x < minX)
              coordinates.x = minX;
            else if (coordinates.x > maxX)
              coordinates.x = maxX;
            coordinates.y = 0;
          }
          else {
            coordinates = null;
          }

          return coordinates;
        },
        getEventMonthlyViewCoordinates: function SEDPH_gEMonthlyViewC(view, pointerCoordinates) {
          /* x = day; y = quarter */
          var coordinates;

          var pxCoordinates = this.getContainerBasedCoordinates(view, pointerCoordinates);
          if (pxCoordinates) {
            coordinates = new SOGoCoordinates();

            var maxX = view.maxX;
            var daysTopOffset = 0;
            var dayWidth = view.dayWidth;
            var daysOffset = view.daysOffset;
            var dayHeight = view.dayHeight;
            var daysY = Math.floor((pxCoordinates.y - daysTopOffset) / dayHeight);
            if (daysY < 0)
              daysY = 0;

            coordinates.x = Math.floor((pxCoordinates.x - daysOffset) / dayWidth);
            if (coordinates.x < 0)
              coordinates.x = 0;
            else if (coordinates.x > maxX)
              coordinates.x = maxX;
            coordinates.x += (maxX + 1) * daysY;
            coordinates.y = 0;
          }
          else {
            coordinates = null;
          }

          return coordinates;
        },

        getDistance: function SEDPH_getDistance() {
          return this.currentCoordinates.getDistance(this.originalCoordinates);
        },

        setTimeFromQuarters: function SEDPH_setTimeFromQuarters(date, quarters) {
          var hours, minutes;
          hours = Math.floor(quarters / 4);
          minutes = (quarters % 4) * 15;
          date.setHours(hours, minutes);
        }
      };
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgDraggableCalendarBlock', sgDraggableCalendarBlock);
})();

