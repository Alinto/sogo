/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.SchedulerUI module */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', []);
  angular.module('SOGo.MailerUI', []);
  angular.module('SOGo.PreferencesUI', []);

  angular.module('SOGo.SchedulerUI', ['ngSanitize', 'ui.router', 'ct.ui.router.extras.sticky', 'ct.ui.router.extras.previous', 'SOGo.Common', 'SOGo.ContactsUI', 'SOGo.MailerUI', 'SOGo.PreferencesUI'])

    .constant('sgSettings', {
      baseURL: ApplicationBaseURL,
      activeUser: {
        login: UserLogin,
        identification: UserIdentification,
        language: UserLanguage,
        folderURL: UserFolderURL,
        isSuperUser: IsSuperUser
      }
    })
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
            templateUrl: 'UIxCalMainFrame', // UI/Templates/SchedulerUI/UIxCalMainFrame.wox
            controller: 'CalendarsController',
            controllerAs: 'calendars'
          }
        },
        resolve: {
          stateCalendars: stateCalendars
        }
      })
      .state('calendars.view', {
        url: '/{view:(?:day|week|month)}/:day',
        sticky: true,
        deepStateRedirect: true,
        views: {
          calendarView: {
            templateUrl: function($stateParams) {
              // UI/Templates/SchedulerUI/UIxCalDayView.wox or
              // UI/Templates/SchedulerUI/UIxCalWeekView.wox or
              // UI/Templates/SchedulerUI/UIxCalMonthView.wox
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
    })
    $urlRouterProvider.when('/calendar/week', function() {
      // If no date is specified, show today's week
      var now = new Date();
      return '/calendar/week/' + now.getDayString();
    })
    $urlRouterProvider.when('/calendar/month', function() {
      // If no date is specified, show today's month
      var now = new Date();
      return '/calendar/month/' + now.getDayString();
    });

    // if none of the above states are matched, use this as the fallback
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
  stateEventsBlocks.$inject = ['$stateParams', 'Component'];
  function stateEventsBlocks($stateParams, Component) {
    return Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate());
  }

  /**
   * @ngInject
   */
  runBlock.$inject = ['$rootScope'];
  function runBlock($rootScope) {
    $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
      console.error(event, current, previous, rejection);
    });
  }

})();
