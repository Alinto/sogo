/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCalendarListEvent - An event block to be displayed in a list
   * @memberof SOGo.SchedulerUI
   * @restrict element
   * @param {object} sgComponent - the Component object.
   * @param {function} sgClick - the function to call when clicking on the event.
   *        Two variables are available: clickEvent (the event that triggered the mouse click),
   *        and clickComponent (a Component object)
   *
   * @example:

  <sg-calendar-list-event
      ng-repeat="event in dayData.events"
      sg-component="event"
      sg-click="list.openEvent($event, clickComponent)" />
  */
  sgCalendarListEvent.$inject = ['CalendarSettings'];
  function sgCalendarListEvent(CalendarSettings) {
    return {
      restrict: 'E',
      scope: {
        component: '=sgComponent',
        clickComponent: '&sgClick'
      },
      replace: true,
      template: template,
      link: link
    };

    function template(tElem, tAttrs) {
      return [
        '<div class="sg-event"',
        '     ng-click="clickComponent({clickEvent: $event, clickComponent: component})">',
        //   Categories color stripes
        '    <div class="sg-category" ng-repeat="category in ::component.categories"',
        '         ng-class="::(\'bg-category\' + category)"',
        '         ng-style="::{ right: ($index * 3) + \'px\' }"></div>',
        //     Priority
        '      <span ng-show="::component.c_priority" class="sg-priority" ng-bind="::component.c_priority"></span>',
        //     Summary
        '      {{ ::component.c_title }}',
        '      <span class="icons">',
        //       Component is reccurent
        '        <md-icon ng-if="::component.occurrenceId" class="material-icons icon-repeat"></md-icon>',
        //       Component has an alarm
        '        <md-icon ng-if="::component.c_nextalarm" class="material-icons icon-alarm"></md-icon>',
        //       Component is confidential
        '        <md-icon ng-if="::component.c_classification == 2" class="material-icons icon-visibility-off"></md-icon>',
        //       Component is private
        '        <md-icon ng-if="::component.c_classification == 1" class="material-icons icon-vpn-key"></md-icon>',
        '      </span>',
        //     Time
        '      <div class="secondary" ng-if="::!component.c_isallday">',
        '        <md-icon>access_time</md-icon> {{::component.starthour}}',
        '      </div>',
        //     Location
        '      <div class="secondary" ng-if="::component.c_location">',
        '        <md-icon>place</md-icon> {{::component.c_location}}',
        '      </div>',
        '</div>'
      ].join('');
    }

    function link(scope, iElement, attrs) {
      /**
       * No data binding here since the view is completely redraw when
       * a change is detected.
       */

      if (scope.component.viewable)
        iElement.addClass('md-clickable');

      // Add class for user's participation state
      if (scope.component.userstate)
        iElement.addClass('sg-event--' + scope.component.userstate);

      // Set background color
      iElement.addClass('bg-folder' + scope.component.pid);
      iElement.addClass('contrast-bdr-folder' + scope.component.pid);

      // Add class for transparency
      if (scope.component.c_isopaque === 0)
        iElement.addClass('sg-event--transparent');

      // Add class for cancelled event
      if (scope.component.c_status === 0)
        iElement.addClass('sg-event--cancelled');
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCalendarListEvent', sgCalendarListEvent);
})();
