/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.SchedulerUI module */

(function() {
  'use strict';

  angular.module('SOGo.ContactsUI', []);

  angular.module('SOGo.SchedulerUI', ['ngSanitize', 'ui.router', 'ct.ui.router.extras.sticky', 'ct.ui.router.extras.previous', 'vs-repeat', 'SOGo.Common', 'SOGo.ContactsUI'])

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
      })
      .state('calendars.newComponent', {
        url: '/:calendarId/{componentType:(?:appointment|task)}/new',
        views: {
          componentEditor: {
            templateUrl: 'UIxAppointmentEditorTemplate',
            controller: 'ComponentController',
            controllerAs: 'editor'
          }
        },
        resolve: {
          stateComponent: stateNewComponent
        }
      })
      .state('calendars.component', {
        url: '/:calendarId/event/:componentId',
        views: {
          componentEditor: {
            templateUrl: 'UIxAppointmentEditorTemplate',
            controller: 'ComponentController',
            controllerAs: 'editor'
          }
        },
        // onEnter: ['$mdSidenav', function($mdSidenav) {
        //   $mdSidenav('right').open()
        //     .then(function() {
        //       console.debug("toggle RIGHT is done");
        //     });
        // }],
        resolve: {
          stateComponent: stateComponent
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
  stateNewComponent.$inject = ['$stateParams', 'Component'];
  function stateNewComponent($stateParams, Component) {
    var component = new Component({ pid: $stateParams.calendarId, type: $stateParams.componentType });
    return component;
  }

  /**
   * @ngInject
   */
  stateComponent.$inject = ['$q', '$stateParams', 'Calendar'];
  function stateComponent($q, $stateParams, Calendar) {
    var component = Calendar.$get($stateParams.calendarId).$getComponent($stateParams.componentId);

    return $q(function(resolve, reject) {
      component.$futureComponentData.then(function() {
        resolve(component);
      }, reject);
    });
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
