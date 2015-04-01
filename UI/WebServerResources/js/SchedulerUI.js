/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.SchedulerUI module */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);
  angular.module('SOGo.ContactsUI', []);

  angular.module('SOGo.SchedulerUI', ['ngSanitize', 'ui.router', 'vs-repeat', 'SOGo.Common', 'SOGo.UI', 'SOGo.UIDesktop', 'SOGo.ContactsUI'])

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

    .config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
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
            stateCalendars: ['sgCalendar', function(Calendar) {
              return Calendar.$calendars || Calendar.$findAll(window.calendarsData);
            }]
          }
        })
        .state('calendars.view', {
          url: '/{view:(?:day|week)}/:day',
          views: {
            calendarView: {
              templateUrl: function($stateParams) {
                // UI/Templates/SchedulerUI/UIxCalDayView.wox or
                // UI/Templates/SchedulerUI/UIxCalWeekView.wox
                return $stateParams.view + 'view?day=' + $stateParams.day;
              },
              controller: 'CalendarController',
              controllerAs: 'calendar'
            }
          },
          resolve: {
            stateEventsBlocks: ['$stateParams', 'sgComponent', function($stateParams, Component) {
              return Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate());
            }]
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
      });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/calendar');
    }])

    .run(function($rootScope) {
      $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
        console.error(event, current, previous, rejection)
      })
    })

    .controller('CalendarsController', ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$log', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgSettings', 'sgCalendar', 'stateCalendars', function($scope, $rootScope, $stateParams, $state, $timeout, $log, focus, encodeUriFilter, Dialog, Settings, Calendar, stateCalendars) {
      this.activeUser = Settings.activeUser;
      this.list = stateCalendars;

      // Dispatch the event named 'calendars:list' when a calendar is activated or deactivated or
      // when the color of a calendar is changed
      $scope.$watch(angular.bind(this, function() {
        return _.map(this.list, function(o) { return _.pick(o, ['id', 'active', 'color']) });
      }), function(newList, oldList) {
        // Identify which calendar has changed
        var ids = _.pluck(_.filter(newList, function(o, i) { return !_.isEqual(o, oldList[i]); }), 'id');
        if (ids.length > 0) {
          $log.debug(ids.join(', ') + ' changed');
          _.each(ids, function(id) {
            var calendar = _.find(stateCalendars, function(o) { return o.id == id });
            calendar.$setActivation().then(function() {
              $scope.$broadcast('calendars:list');
            });
          });
        }
      }, true); // compare for object equality
    }])
  
    .controller('CalendarListController', ['$scope', '$rootScope', '$timeout', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgSettings', 'sgCalendar', 'sgComponent', function($scope, $rootScope, $timeout, focus, encodeUriFilter, Dialog, Settings, Calendar, Component) {
      // Scope variables
      this.component = Component;
      this.componentType = null;

      // Switch between components tabs
      this.selectComponentType = angular.bind(this, function(type, options) {
        console.debug("selectComponentType " + type);
        if (options && options.reload || this.componentType != type) {
          // TODO: save user settings (Calendar.SelectedList)
          Component.$filter(type);
          this.componentType = type;
        }
      });

      // Refresh current list when the list of calendars is modified
      $scope.$on('calendars:list', angular.bind(this, function() {
        Component.$filter(this.componentType);
      }));

      // Initialization
      // TODO: should reflect last state userSettings -> Calendar -> SelectedList
      this.selectedList = 0;
      this.selectComponentType('events');
    }])

    .controller('CalendarController', ['$scope', '$state', '$stateParams', '$timeout', '$interval', '$log', 'sgFocus', 'sgCalendar', 'sgComponent', 'stateEventsBlocks', function($scope, $state, $stateParams, $timeout, $interval, $log, focus, Calendar, Component, stateEventsBlocks) {
      // Scope variables
      this.blocks = stateEventsBlocks;

      // Change calendar's view
      this.changeView = function($event) {
        var date = angular.element($event.currentTarget).attr('date');
        $state.go('calendars.view', { view: $stateParams.view, day: date });
      };

      // Refresh current view when the list of calendars is modified
      $scope.$on('calendars:list', angular.bind(this, function() {
        var ctrl = this;
        Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate()).then(function(data) {
          ctrl.blocks = data;
        });
      }));
    }]);

})();
