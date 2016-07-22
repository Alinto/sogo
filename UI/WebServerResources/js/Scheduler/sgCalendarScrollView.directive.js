/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgCalendarScrollView - scrollable view that contains draggable elements
   * @memberof SOGo.SchedulerUI
   * @restrict attribute
   * @param {string} sgCalendarScrollView - the view type (multiday, multiday-allday, or monthly)
   *
   * @example:

   <md-content sg-calendar-scroll-view="multiday">
     ..
   </md-content>
  */
  sgCalendarScrollView.$inject = ['$rootScope', '$window', '$document', '$q', '$timeout', '$mdGesture', 'Calendar', 'Component', 'Preferences'];
  function sgCalendarScrollView($rootScope, $window, $document, $q, $timeout, $mdGesture, Calendar, Component, Preferences) {
    return {
      restrict: 'A',
      scope: {
        type: '@sgCalendarScrollView'
      },
      controller: sgCalendarScrollViewController,
      link: function(scope, element, attrs, controller) {
        var view, type, deregisterDragStart, deregisterDragStop;

        view = null;
        type = scope.type; // multiday, multiday-allday, monthly, unknown?

        // Listen to dragstart and dragend events
        deregisterDragStart = $rootScope.$on('calendar:dragstart', onDragStart);
        deregisterDragStop = $rootScope.$on('calendar:dragend', onDragEnd);

        // Update the "view" object literal once the Angular template has been transformed
        $timeout(initView);

        // Deregister listeners when destroying the view
        scope.$on('$destroy', function() {
          deregisterDragStart();
          deregisterDragStop();
          if (view) {
            element.off('mouseover', view.updateFromPointerHandler);
            angular.element($window).off('resize', view.updateCoordinates);
          }
        });

        function initView() {
          view = new sgScrollView(element, type);

          // Compute coordinates of view element; recompute it on window resize
          angular.element($window).on('resize', view.updateCoordinates);

          if (type != 'monthly')
            // Scroll to the day start hour defined in the user's defaults
            Preferences.ready().then(function() {
              var time, hourCell, quartersOffset;
              if (Preferences.defaults.SOGoDayStartTime) {
                time = Preferences.defaults.SOGoDayStartTime.split(':');
                hourCell = document.getElementById('hour' + parseInt(time[0]));
                quartersOffset = parseInt(time[1]) * view.quarterHeight;
                view.element.scrollTop = hourCell.offsetTop + quartersOffset;
              }
            });
        }

        function onDragStart() {
          if (view) {
            element.on('mouseover', view.updateFromPointerHandler);
            view.updateCoordinates();
            view.updateFromPointerHandler();
          }
        }

        function onDragEnd() {
          element.off('mouseover', view.updateFromPointerHandler);
          Calendar.$view = null;
        }

        /**
         * sgScrollView
         */
        function sgScrollView($element, type) {
          this.$element = $element;
          this.element = $element[0];
          this.type = type;
          this.quarterHeight = this.getQuarterHeight();
          this.scrollStep = 6 * this.quarterHeight;
          this.dayNumbers = this.getDayNumbers();
          this.maxX = this.getMaxColumns();

          this.updateCoordinates();
        }

        sgScrollView.prototype = {


          getQuarterHeight: function() {
            var hour0, hour23, height = null;

            hour0 = document.getElementById('hour0');
            hour23 = document.getElementById('hour23');
            if (hour0 && hour23)
              height = ((hour23.offsetTop - hour0.offsetTop) / (23 * 4));

            return height;
          },


          getDayDimensions: function(viewLeft) {
            var width, height, leftOffset, topOffset, nodes, domRect, tileHeader;

            height = width = leftOffset = topOffset = 0;
            nodes = this.element.getElementsByClassName('day');

            if (nodes.length > 0) {
              domRect = nodes[0].getBoundingClientRect();
              height = domRect.height;
              width = domRect.width;
              leftOffset = domRect.left - viewLeft;
              tileHeader = nodes[0].getElementsByClassName('sg-calendar-tile-header');
              if (tileHeader.length > 0)
                topOffset = tileHeader[0].clientHeight;
            }

            return { height: height, width: width, offset: { left: leftOffset, top: topOffset } };
          },


          getDayNumbers: function() {
            var viewType = null, isMultiColumn, days, total, sum;

            if (this.element.attributes['sg-view'])
              viewType = this.element.attributes['sg-view'].value;
            isMultiColumn = (viewType == 'multicolumndayview');
            days = this.element.getElementsByTagName('sg-calendar-day');

            return _.map(days, function(el, index) {
              if (isMultiColumn)
                return index;
              else
                return parseInt(el.attributes['sg-day-number'].value);
            });
          },


          getMaxColumns: function() {
            var mdGridList, max = 0;

            if (this.type == 'monthly') {
              mdGridList = this.element.getElementsByTagName('md-grid-list')[0];
              max = parseInt(mdGridList.attributes['md-cols'].value) - 1;
            }
            else {
              max = this.element.getElementsByClassName('day').length - 1;
            }

            return max;
          },

          // View has been resized;
          // Compute the view's origins (x, y), a day's dimensions and left margin.
          updateCoordinates: function() {
            var domRect, dayDimensions;

            domRect = this.element.getBoundingClientRect();
            dayDimensions = this.getDayDimensions(domRect.left);

            angular.extend(this, {
              coordinates: {
                x: domRect.left,
                y: domRect.top
              },
              dayHeight: dayDimensions.height,
              dayWidth: dayDimensions.width,
              daysOffset: dayDimensions.offset.left,
              topOffset: dayDimensions.offset.top
            });
          },


          // From SOGoScrollController.updateFromPointerHandler
          updateFromPointerHandler: function() {
            var scrollStep, pointerHandler, pointerCoordinates, now, scrollY, minY, delta;

            pointerHandler = Component.$ghost.pointerHandler;
            if (this.coordinates && pointerHandler) {
              scrollStep = this.scrollStep;
              pointerCoordinates = pointerHandler.getContainerBasedCoordinates(this);

              if (pointerCoordinates) {
                // Pointer is inside view; Adjust scrollbar if necessary
                Calendar.$view = this;
                now = new Date().getTime();
                if (!this.lastScroll || now > this.lastScroll + 100) {
                  this.lastScroll = now;
                  scrollY = pointerCoordinates.y - scrollStep;
                  if (scrollY < 0) {
                    minY = -this.element.scrollTop;
                    if (scrollY < minY)
                      scrollY = minY;
                    this.element.scrollTop += scrollY;
                  }
                  else {
                    scrollY = pointerCoordinates.y + scrollStep;
                    delta = scrollY - this.element.clientHeight;
                    if (delta > 0) {
                      this.element.scrollTop += delta;
                    }
                  }
                }
              }
            }
          }


        };
      }
    };
  }

  sgCalendarScrollViewController.$inject = ['$scope'];
  function sgCalendarScrollViewController($scope) {
    // Expose the view type to the controller
    // See sgCalendarGhost directive
    this.type = $scope.type;
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarScrollView', sgCalendarScrollView);
})();
