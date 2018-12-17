/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgCalendarPrintStylesheet - Add CSS stylesheet to fix printing of calendars
   * @memberof SOGo.SchedulerUI
   * @restrict attribute
   * @param {string} sgCalendarView - the name of the calendar view
   * @param {string} sgPageSize - the desired page size (letter, legal, etc)
   * @param {string} sgOrientation - the page orientation
   * @param {boolean} sgWorkingHoursOnly - hide off-working hours
   * @example:

    <sg-calendar-print-stylesheet
      sg-calendar-view="calendarView"
      sg-page-size="pageSize"
      sg-orientation="orientation"
      sg-working-hours-only="workingHoursOnly" />
  */
  function sgCalendarPrintStylesheet() {
    return {
      restrict: 'E',
      scope: {
        calendarView: '<sgCalendarView',
        pageSize: '<sgPageSize',
        orientation: '<sgOrientation',
        workingHoursOnly: '<sgWorkingHoursOnly',
      },
      replace: true,
      bindToController: true,
      controller: sgPrintStylesheetController,
      controllerAs: '$ctrl',
      template: [
        '<style type="text/css">',
        '  @page {',
        '    size: {{ $ctrl.pageSize }} {{ $ctrl.orientation }};',
        '    margin: 0;',
        '  }',
        '  @media print {',
        '    body {',
        '      padding: {{ $ctrl.pageMargin }};',
        '    }',
        '    [ui-view=calendars] .view-list {',
        '      height: {{ $ctrl.viewportHeight }};',
        '      overflow: hidden;',
        '    }',
        '    [ui-view=calendars] .calendarView {',
        '      transform: translateY(-{{ $ctrl.clipTop }});', // hide non-working hours at the top
        '      height: {{ $ctrl.viewHeight }};',
        '      position: relative;',
        '      overflow: hidden;', // hide non-working hours at the bottom
        '    }',
        '    [ui-view=calendars] .allDaysView {',
        '      max-height: {{ $ctrl.hourHeight }}{{ $ctrl.units }} !important;', // limit size of all-day cells
        '    }',
        '    [ui-view=calendars] .hours .hour,',
        '    [ui-view=calendars] .days .day .clickableHourCell {',
        '      min-height: {{ $ctrl.hourHeight }}{{ $ctrl.units }};',
        '      max-height: {{ $ctrl.hourHeight }}{{ $ctrl.units }};',
        '    }',
        '    {{ $ctrl.eventsPositions() }}',
        '  }',
        '</style>'
      ].join('\n')
    };
  }

  /**
   * @ngInject
   */
  sgPrintStylesheetController.$inject = ['$scope', 'Preferences'];
  function sgPrintStylesheetController($scope, Preferences) {
    var vm = this;
    var sizes = {
      portrait: {
        letter: [8.5, 11, 'in'],
        legal:  [8.5, 14, 'in'],
        a4:     [210, 297, 'mm']
      },
      landscape: {
        letter: [11, 8.5, 'in'],
        legal:  [14, 8.5, 'in'],
        a4:     [297, 210, 'mm']
      }
    };
    var margins = {
      letter: [0.4, 2.1],
      legal: [0.4, 2.1],
      a4: [10, 30]
    };

    this.$onInit = function() {
      $scope.$watchGroup([function() { return vm.pageSize; }, function() { return vm.workingHoursOnly; }], angular.bind(this, function() {
        var time;
        var size = sizes[this.orientation][this.pageSize];
        this.units = size[2];
        this.pageMargin = margins[this.pageSize][0] + this.units;
        this.viewportHeight = (size[1] - 2 * margins[this.pageSize][0]).toString() + this.units;
        this.hideHoursStart = 0;
        this.hideHoursEnd = 24;
        this.totalHours = 24;
        this.clipTop = 0;

        if (this.calendarView === 'month') {
          this.viewHeight = (size[1] - (3 * margins[this.pageSize][0])).toString() + this.units;
        }
        else {
          // Day-based views
          if (this.workingHoursOnly) {
            if (Preferences.defaults.SOGoDayEndTime) {
              time = Preferences.defaults.SOGoDayEndTime.split(':');
              this.hideHoursEnd = parseInt(time[0]);
              this.totalHours = this.hideHoursEnd;
            }
            if (Preferences.defaults.SOGoDayStartTime) {
              time = Preferences.defaults.SOGoDayStartTime.split(':');
              this.hideHoursStart = parseInt(time[0]);
              this.totalHours -= this.hideHoursStart;
            }
          }
          this.hourHeight = (size[1] - 2 * margins[this.pageSize][0] - margins[this.pageSize][1]) / this.totalHours;
          this.clipTop = (this.hourHeight * this.hideHoursStart).toString() + this.units;
          this.viewHeight = (this.hideHoursEnd * this.hourHeight).toString() + this.units;
        }
      }));
    };

    this.eventsPositions = function() {
      var i = 0, j;
      var css = [];

      if (this.calendarView === 'month') {
        css.push('[ui-view=calendars] .monthView md-grid-list { min-height: ' + this.viewHeight + '; }');
      }
      else {
        while (i <= 96) { // number of 15-minutes blocks in a day
          if (i <= (4 * this.hideHoursStart)) {
            j = (4 * this.hideHoursStart) - i;
            css.push('[ui-view=calendars] .sg-event.starts' + i +
                     ' .text { margin-top: ' + (this.hourHeight/4*j) + this.units + '; }');
          }
          css.push('[ui-view=calendars] .sg-event.starts' + i + ' { top: ' + (this.hourHeight/4*i) + this.units + '; }');
          css.push('[ui-view=calendars] .sg-event.lasts' + i + ' { height: ' + (this.hourHeight/4*i) + this.units + '; }');
          i++;
        }
      }
      return css.join('\n');
    };
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarPrintStylesheet', sgCalendarPrintStylesheet);
})();
