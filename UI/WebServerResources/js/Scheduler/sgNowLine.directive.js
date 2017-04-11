/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgNowLine - Now line to be displayed on top of current day
   * @restrict class
  */
  function sgNowLine() {
    return {
      restrict: 'C',
      require: '^^sgCalendarScrollView',
      link: link,
      controller: sgNowLineController
    };

    function link(scope, iElement, iAttr, sgCalendarScrollViewCtrl) {
      function _getDays() {
        return iElement.find('sg-calendar-day');
      }
      function _getView() {
        return sgCalendarScrollViewCtrl.quarterHeight;
      }

      // We need to wait for the view to be compiled
      var _unwatchView = scope.$watch(_getView, function(quarterHeight) {
        if (quarterHeight) {
          _unwatchView(); // self release
          scope.quarterHeight = quarterHeight;
          // We need to wait for the days to be compiled
          var _unwatchDays = scope.$watch(_getDays, function(days) {
            if (days.length) {
              _unwatchDays(); // self release
              scope.days = days;
              // Draw the line
              scope.updateLine();
            }
          });
        }
      });
    }
  }

  /**
   * @ngInject
   */
  sgNowLineController.$inject = ['$scope', '$element', '$timeout'];
  function sgNowLineController($scope, $element, $timeout) {
    var _this = this, updater,
        scrollViewCtrl = $element.controller('sgCalendarScrollView');

    $scope.nowDay = null;
    $scope.lineElement = null;
    $scope.updateLine = _updateLine;

    $scope.$on('$destroy', function() {
      if (updater)
        $timeout.cancel(updater);
    });


    function _updateLine(force) {
      var now = new Date(), // TODO: adjust to user's timezone
          nowDay = now.getDayString(),
          hours = now.getHours(),
          hourHeight = $scope.quarterHeight * 4,
          minutes = now.getMinutes(),
          minuteHeight = $scope.quarterHeight/15,
          position = parseInt(hours   * hourHeight   +
                              minutes * minuteHeight -
                              1);

      if (force || nowDay != $scope.nowDay) {
        if ($scope.lineElement)
          $scope.lineElement.remove();
        $scope.lineElement = _addLine(nowDay, $scope.days);
        $scope.nowDay = nowDay;
      }

      if ($scope.lineElement) {
        // Current day is displayed
        $scope.lineElement.css('top', position + "px");
        // Update line every minute
        updater = $timeout(angular.bind(_this, $scope.updateLine), 60000);
      }
    }

    function _addLine(nowDay, days) {
      var $lineElement = angular.element('<sg-now-line>');

      if (scrollViewCtrl.isMultiColumn) {
        // In multicolumn day view, the line must go over all columns
        if (days && days[0].attributes['sg-day'].value == nowDay)
          $element.append($lineElement);
      }
      else
        _.forEach(days, function(dayElement) {
          if (dayElement.attributes['sg-day'].value == nowDay) {
            angular.element(dayElement).find('div').eq(0).append($lineElement);
          }
        });

      return $lineElement;
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgNowLine', sgNowLine);
})();
