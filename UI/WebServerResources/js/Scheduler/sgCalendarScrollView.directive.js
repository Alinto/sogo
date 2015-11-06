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
  sgCalendarScrollView.$inject = ['$rootScope', '$window', '$document', '$q', '$timeout', '$mdGesture', 'Calendar', 'Component'];
  function sgCalendarScrollView($rootScope, $window, $document, $q, $timeout, $mdGesture, Calendar, Component) {
    return {
      restrict: 'A',
      scope: {
        type: '@sgCalendarScrollView'
      },
      controller: sgCalendarScrollViewController,
      link: function(scope, element, attrs, controller) {
        var view, scrollView, type, lastScroll, deregisterDragStart, deregisterDragStop;

        scrollView = element[0];
        type = scope.type; // multiday, multiday-allday, monthly, unknown?
        lastScroll = 0;

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
            maxX: getMaxColumns(),

            // Expose a reference of the view element
            element: scrollView
          };

          // Compute coordinates of view element; recompute it on window resize
          angular.element($window).on('resize', updateCoordinates);
          updateCoordinates();
        }

        function getQuarterHeight() {
          var hour0, hour23, height;

          hour0 = document.getElementById('hour0');
          hour23 = document.getElementById('hour23');
          height = ((hour23.offsetTop - hour0.offsetTop) / (23 * 4));

          return height;
        }

        function getDayWidth(viewLeft) {
          var width, offset, nodes, domRect;

          width = 0;
          offset = 0;
          nodes = scrollView.getElementsByClassName('day0');

          if (nodes.length > 0) {
            domRect = nodes[0].getBoundingClientRect();
            width = domRect.width;
            offset = domRect.left - viewLeft;
          }

          return [width, offset];
        }

        function getMaxColumns() {
          var max = 0;

          //if (type == 'multiday') {
            max = scrollView.getElementsByClassName('day').length - 1;
          //}

          return max;
        }

        // View has been resized;
        // Compute the view's origins (x, y), a day's width (dayWidth) and the left margin (daysOffset).
        function updateCoordinates() {
          var domRect, dayWidth;

          domRect = scrollView.getBoundingClientRect();
          dayWidth = getDayWidth(domRect.left);

          angular.extend(view, {
            coordinates: {
              x: domRect.left,
              y: domRect.top
            },
            dayWidth: dayWidth[0],
            daysOffset: dayWidth[1]
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

          scrollStep = view.scrollStep;
          pointerHandler = Component.$ghost.pointerHandler;
          if (pointerHandler) {
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
