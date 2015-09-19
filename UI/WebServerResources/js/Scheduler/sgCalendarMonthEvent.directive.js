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
        '<div class="sg-event sg-draggable" ng-click="clickBlock({clickEvent: $event, clickComponent: block.component})">',
        '  <span ng-if="!block.component.c_isallday">{{ block.starthour }} - </span>',
        '  {{ block.component.c_title }}',
        '  <span class="icons">',
        '    <md-icon ng-if="block.component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        '    <md-icon ng-if="block.component.c_classification == 1" class="material-icons icon-visibility-off"></md-icon>',
        '    <md-icon ng-if="block.component.c_classification == 2" class="material-icons icon-vpn-key"></md-icon>',
        '  </span>',
        '  <div class="leftDragGrip"></div>',
        '  <div class="rightDragGrip"></div>',
        '</div>'
      ].join(''),
      link: link
    };

    function link(scope, iElement, attrs) {
      iElement.addClass('bg-folder' + scope.block.component.c_folder);
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarMonthEvent', sgCalendarMonthEvent);
})();
