/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarMonthEvent - An event block to be displayed in a month
   * @memberof SOGo.Common
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @ngInject
   * @example:

   <sg-calendar-month-event
       ng-repeat="block in blocks[day]"
       sg-block="block"/>
  */
  function sgCalendarMonthEvent() {
    return {
      restrict: 'E',
      scope: {
        block: '=sgBlock',
        clickBlock: '&sgClick'
      },
      replace: true,
      template: [
        '<div class="sg-event"',
        //    Add a class while dragging
        '     ng-class="{\'sg-event--dragging\': block.dragging}"',
        '     ng-click="clickBlock({clickEvent: $event, clickComponent: block.component})">',
        '  <span class="secondary" ng-if="!block.component.c_isallday">{{ block.starthour }}</span>',
        '  {{ block.component.summary }}',
        '  <span class="icons">',
        //   Component is reccurent
        '    <md-icon ng-if="block.component.occurrenceId" class="material-icons icon-repeat"></md-icon>',
        //   Component has an alarm
        '    <md-icon ng-if="block.component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        //   Component is confidential
        '    <md-icon ng-if="block.component.c_classification == 1" class="material-icons icon-visibility-off"></md-icon>',
        //   Component is private
        '    <md-icon ng-if="block.component.c_classification == 2" class="material-icons icon-vpn-key"></md-icon>',
        '  </span>',
        '</div>'
      ].join(''),
      link: link
    };

    function link(scope, iElement, attrs) {
      if (scope.block.component)
        iElement.addClass('bg-folder' + scope.block.component.pid);
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarMonthEvent', sgCalendarMonthEvent);
})();
