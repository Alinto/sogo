/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.SchedulerUI module */

(function() {
  'use strict';

  angular.module('SOGo.SchedulerUI', ['ngCookies', 'ui.router', 'angularFileUpload', 'ck', 'SOGo.Common', 'SOGo.PreferencesUI', 'SOGo.ContactsUI', 'SOGo.MailerUI', 'as.sortable'])
    .config(configure)
    .run(runBlock);

  /**
   * @ngInject
   */
  configure.$inject = ['$stateProvider', '$urlRouterProvider'];
  function configure($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('calendars', {
        url: '/calendar',
        views: {
          calendars: {
            templateUrl: 'UIxCalMainView', // UI/Templates/SchedulerUI/UIxCalMainView.wox
            controller: 'CalendarsController',
            controllerAs: 'app'
          }
        },
        resolve: {
          stateCalendars: stateCalendars
        }
      })
      .state('calendars.view', {
        url: '/{view:(?:day|week|month|multicolumnday)}/:day',
        //sticky: true,
        //deepStateRedirect: true,
        views: {
          calendarView: {
            templateUrl: function($stateParams) {
              // UI/Templates/SchedulerUI/UIxCalDayView.wox or
              // UI/Templates/SchedulerUI/UIxCalWeekView.wox or
              // UI/Templates/SchedulerUI/UIxCalMonthView.wox or
              // UI/Templates/SchedulerUI/UIxCalMulticolumnDayView.wox
              return $stateParams.view + 'view?day=' + $stateParams.day;
            },
            controller: 'CalendarController',
            controllerAs: 'calendar'
          }
        },
        resolve: {
          stateEventsBlocks: stateEventsBlocks
        }
      });

    $urlRouterProvider.when('/calendar/day', function() {
      // If no date is specified, show today
      var now = new Date();
      return '/calendar/day/' + now.getDayString();
    });
    $urlRouterProvider.when('/calendar/multicolumnday', function() {
      // If no date is specified, show today
      var now = new Date();
      return '/calendar/multicolumnday/' + now.getDayString();
    });
    $urlRouterProvider.when('/calendar/week', function() {
      // If no date is specified, show today's week
      var now = new Date();
      return '/calendar/week/' + now.getDayString();
    });
    $urlRouterProvider.when('/calendar/month', function() {
      // If no date is specified, show today's month
      var now = new Date();
      return '/calendar/month/' + now.getDayString();
    });

    // If none of the above states are matched, use this as the fallback.
    // runBlock will also act as a fallback by looking at user's settings
    $urlRouterProvider.otherwise('/calendar');
  }

  /**
   * @ngInject
   */
  stateCalendars.$inject = ['Calendar'];
  function stateCalendars(Calendar) {
    return Calendar.$calendars || Calendar.$findAll(window.calendarsData);
  }

  /**
   * @ngInject
   */
  stateEventsBlocks.$inject = ['$stateParams', 'Component', 'Calendar'];
  function stateEventsBlocks($stateParams, Component, Calendar) {
    // See CalendarController.js
    return Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate())
      .then(function(views) {
        _.forEach(views, function(view) {
          if (view.id) {
            // Note: this can't be done in Component service since it would make Component dependent on
            // the Calendar service and create a circular dependency
            view.calendar = new Calendar({ id: view.id, name: view.calendarName });
          }
        });
        return views;
      });
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope', '$log', '$location', '$state', 'Preferences'];
  function runBlock($rootScope, $log, $location, $state, Preferences) {
    $rootScope.$on('$stateChangeError', function(event, toState, toParams, fromState, fromParams, error) {
      $log.error(error);
      $state.go('calendar');
    });
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      $log.error(event, current, previous, rejection);
    });
    if ($location.url().length === 0) {
      // Restore user's last view
      var url = '/calendar/',
          view = /(.+)view/.exec(Preferences.settings.Calendar.View);
      if (view)
        url += view[1];
      else
        url += 'week';
      // Append today's date or next enabled weekday
      var now = new Date();
      if (Preferences.defaults.SOGoCalendarWeekdays) {
        var weekDays = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
        var weekDay = weekDays[now.getDay()];
        while (Preferences.defaults.SOGoCalendarWeekdays.indexOf(weekDay) < 0) {
          now.addDays(1);
          weekDay = weekDays[now.getDay()];
        }
      }
      url += '/' + now.getDayString();
      $location.replace().url(url);
    }
  }

})();
