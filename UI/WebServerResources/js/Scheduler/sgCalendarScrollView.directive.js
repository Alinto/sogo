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
        var view, scrollView, type, lastScroll, days, deregisterDragStart, deregisterDragStop;

        view = null;
        scrollView = element[0];
        type = scope.type; // multiday, multiday-allday, monthly, unknown?
        lastScroll = 0;
        days = null;

        // Listen to dragstart and dragend events
        deregisterDragStart = $rootScope.$on('calendar:dragstart', onDragStart);
        deregisterDragStop = $rootScope.$on('calendar:dragend', onDragEnd);

        // Update the "view" object literal once the Angular template has been transformed
        $timeout(initView);

        // Deregister listeners when destroying the view
        scope.$on('$destroy', function() {
          deregisterDragStart();
          deregisterDragStop();
          element.off('mouseover', updateFromPointerHandler);
          angular.element($window).off('resize', updateCoordinates);
        });

        function initView() {
          var quarterHeight;

          // Quarter height doesn't change if window is resize; compute it only once
          quarterHeight = getQuarterHeight();

          view = {
            type: type,
            quarterHeight: quarterHeight,
            scrollStep: 6 * quarterHeight,
            dayNumbers: getDayNumbers(),
            maxX: getMaxColumns(),

            // Expose a reference of the view element
            element: scrollView
          };

          // Compute coordinates of view element; recompute it on window resize
          angular.element($window).on('resize', updateCoordinates);
          updateCoordinates();

          if (type != 'monthly')
            // Scroll to the day start hour defined in the user's defaults
            Preferences.ready().then(function() {
              var time, hourCell, quartersOffset;
              if (Preferences.defaults.SOGoDayStartTime) {
                time = Preferences.defaults.SOGoDayStartTime.split(':');
                hourCell = document.getElementById('hour' + parseInt(time[0]));
                quartersOffset = parseInt(time[1]) * quarterHeight;
                scrollView.scrollTop = hourCell.offsetTop + quartersOffset;
              }
            });
        }

        function getQuarterHeight() {
          var hour0, hour23, height = null;

          hour0 = document.getElementById('hour0');
          hour23 = document.getElementById('hour23');
          if (hour0 && hour23)
            height = ((hour23.offsetTop - hour0.offsetTop) / (23 * 4));

          return height;
        }

        function getDayDimensions(viewLeft) {
          var width, height, leftOffset, topOffset, nodes, domRect, tileHeader;

          height = width = leftOffset = topOffset = 0;
          nodes = scrollView.getElementsByClassName('day');

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
        }

        function getDayNumbers() {
          var viewType = null, isMultiColumn, days, total, sum;

          if (scrollView.attributes['sg-view'])
            viewType = scrollView.attributes['sg-view'].value;
          isMultiColumn = (viewType == 'multicolumndayview');
          days = scrollView.getElementsByTagName('sg-calendar-day');

          return _.map(days, function(element, index) {
            if (isMultiColumn)
              return index;
            else
              return parseInt(element.attributes['sg-day-number'].value);
          });
        }

        function getMaxColumns() {
          var mdGridList, max = 0;

          if (type == 'monthly') {
            mdGridList = scrollView.getElementsByTagName('md-grid-list')[0];
            max = parseInt(mdGridList.attributes['md-cols'].value) - 1;
          }
          else {
            max = scrollView.getElementsByClassName('day').length - 1;
          }

          return max;
        }

        // View has been resized;
        // Compute the view's origins (x, y), a day's dimensions and left margin.
        function updateCoordinates() {
          var domRect, dayDimensions;

          domRect = scrollView.getBoundingClientRect();
          dayDimensions = getDayDimensions(domRect.left);

          angular.extend(view, {
            coordinates: {
              x: domRect.left,
              y: domRect.top
            },
            dayHeight: dayDimensions.height,
            dayWidth: dayDimensions.width,
            daysOffset: dayDimensions.offset.left,
            topOffset: dayDimensions.offset.top
          });
        }

        function onDragStart() {
          element.on('mouseover', updateFromPointerHandler);
          updateFromPointerHandler();
        }

        function onDragEnd() {
          element.off('mouseover', updateFromPointerHandler);
          Calendar.$view = null;
        }

        // From SOGoScrollController.updateFromPointerHandler
        function updateFromPointerHandler() {
          var scrollStep, pointerHandler, pointerCoordinates, now, scrollY, minY, delta;

          pointerHandler = Component.$ghost.pointerHandler;
          if (view && pointerHandler) {
            scrollStep = view.scrollStep;
            pointerCoordinates = pointerHandler.getContainerBasedCoordinates(view);

            if (pointerCoordinates) {
              // Pointer is inside view; Adjust scrollbar if necessary
              Calendar.$view = view;
              now = new Date().getTime();
              if (!lastScroll || now > lastScroll + 100) {
                lastScroll = now;
                scrollY = pointerCoordinates.y - scrollStep;
                if (scrollY < 0) {
                  minY = -scrollView.scrollTop;
                  if (scrollY < minY)
                    scrollY = minY;
                  scrollView.scrollTop += scrollY;
                }
                else {
                  scrollY = pointerCoordinates.y + scrollStep;
                  delta = scrollY - scrollView.clientHeight;
                  if (delta > 0) {
                    scrollView.scrollTop += delta;
                  }
                }
              }
            }
          }
        }
      }
    };
  }

  sgCalendarScrollViewController.$inject = ['$scope'];
  function sgCalendarScrollViewController($scope) {
    // Expose the view type to the controller
    // See sgCalendarDayBlockGhost
    this.type = $scope.type;
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarScrollView', sgCalendarScrollView);
})();
