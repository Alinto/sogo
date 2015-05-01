/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for SOGo.SchedulerUI module */

(function() {
  'use strict';

  angular.module('SOGo.Common', []);
  angular.module('SOGo.ContactsUI', []);

  angular.module('SOGo.SchedulerUI', ['ngSanitize', 'ui.router', 'ct.ui.router.extras.sticky', 'ct.ui.router.extras.previous', 'vs-repeat', 'SOGo.Common', 'SOGo.UI', 'SOGo.UIDesktop', 'SOGo.ContactsUI'])

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
            stateEventsBlocks: ['$stateParams', 'sgComponent', function($stateParams, Component) {
              return Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate());
            }]
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
            stateComponent: ['$stateParams', 'sgComponent', function($stateParams, Component) {
              var component = new Component({ pid: $stateParams.calendarId, type: $stateParams.componentType });
              return component;
            }]
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
          resolve: {
            stateComponent: ['$stateParams', 'sgCalendar', function($stateParams, Calendar) {
              return Calendar.$get($stateParams.calendarId).$getComponent($stateParams.componentId);
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
      })
      $urlRouterProvider.when('/calendar/month', function() {
        // If no date is specified, show today's month
        var now = new Date();
        return '/calendar/month/' + now.getDayString();
      });

      // if none of the above states are matched, use this as the fallback
      $urlRouterProvider.otherwise('/calendar');
    }])

    .run(function($rootScope) {
      $rootScope.$on('$routeChangeError', function(event, current, previous, rejection) {
        console.error(event, current, previous, rejection)
      })
    })


    .controller('CalendarsController', ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$q', '$mdDialog', '$log', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgSettings', 'sgCalendar', 'sgUser', 'stateCalendars', function($scope, $rootScope, $stateParams, $state, $timeout, $q, $mdDialog, $log, focus, encodeUriFilter, Dialog, Settings, Calendar, User, stateCalendars) {
      var vm = this;

      vm.activeUser = Settings.activeUser;
      vm.service = Calendar;

      // Dispatch the event named 'calendars:list' when a calendar is activated or deactivated or
      // when the color of a calendar is changed
      $scope.$watch(
        function() {
          return _.union(
            _.map(Calendar.$calendars, function(o) { return _.pick(o, ['id', 'active', 'color']) }),
            _.map(Calendar.$subscriptions, function(o) { return _.pick(o, ['id', 'active', 'color']) }),
            _.map(Calendar.$webcalendars, function(o) { return _.pick(o, ['id', 'active', 'color']) })
          );
        },
        function(newList, oldList) {
          // Identify which calendar has changed
          var ids = _.pluck(_.filter(newList, function(o, i) { return !_.isEqual(o, oldList[i]); }), 'id');
          if (ids.length > 0) {
            $log.debug(ids.join(', ') + ' changed');
            _.each(ids, function(id) {
              var calendar = Calendar.$get(id);
              calendar.$setActivation().then(function() {
                $scope.$broadcast('calendars:list');
              });
            });
          }
        },
        true // compare for object equality
      );

      vm.newCalendar = function(ev) {
        Dialog.prompt(l('New calendar'), l('Name of the Calendar'))
          .then(function(name) {
            var calendar = new Calendar(
              {
                name: name,
                isEditable: true,
                isRemote: false,
                owner: UserLogin
              }
            );
            Calendar.$add(calendar);
          });
      };

      vm.addWebCalendar = function() {
        Dialog.prompt(l('Subscribe to a web calendar...'), l('URL of the Calendar'), {inputType: 'url'})
          .then(function(url) {
            Calendar.$addWebCalendar(url);
          });
      };

      vm.confirmDelete = function(folder) {
        if (folder.isSubscription) {
          // Unsubscribe without confirmation
          folder.$delete()
            .then(function() {
              $scope.$broadcast('calendars:list');
            }, function(data, status) {
              Dialog.alert(l('An error occured while deleting the addressbook "%{0}".', folder.name),
                           l(data.error));
            });
        }
        else {
          Dialog.confirm(l('Warning'), l('Are you sure you want to delete the addressbook <em>%{0}</em>?', folder.name))
            .then(function() {
              folder.$delete()
                .then(function() {
                  $scope.$broadcast('calendars:list');
                }, function(data, status) {
                  Dialog.alert(l('An error occured while deleting the addressbook "%{0}".', folder.name),
                               l(data.error));
                });
            });
        }
      };

      vm.share = function(calendar) {
        $mdDialog.show({
          templateUrl: calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: CalendarACLController,
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: calendar.$acl.$users(),
            User: User,
            stateCalendar: calendar
          }
        });
        function CalendarACLController($scope, $mdDialog, usersWithACL, User, stateCalendar) {
          $scope.users = usersWithACL; // ACL users
          $scope.stateCalendar = stateCalendar;
          $scope.userToAdd = '';
          $scope.searchText = '';
          $scope.userFilter = function($query) {
            return User.$filter($query);
          };
          $scope.closeModal = function() {
            stateCalendar.$acl.$resetUsersRights(); // cancel changes
            $mdDialog.hide();
          };
          $scope.saveModal = function() {
            stateCalendar.$acl.$saveUsersRights().then(function() {
              $mdDialog.hide();
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured please try again.'));
            });
          };
          $scope.confirmChange = function(user) {
            var confirmation = user.$confirmRights();
            if (confirmation) {
              Dialog.confirm(l('Warning'), confirmation).then(function(res) {
                if (!res)
                  user.$resetRights(true);
              });
            }
          };
          $scope.removeUser = function(user) {
            stateCalendar.$acl.$removeUser(user.uid).then(function() {
              if (user.uid == $scope.selectedUser.uid) {
                $scope.selectedUser = null;
              }
            }, function(data, status) {
              Dialog.alert(l('Warning'), l('An error occured please try again.'))
            });
          };
          $scope.addUser = function(data) {            
            stateCalendar.$acl.$addUser(data).then(function() {
              $scope.userToAdd = '';
              $scope.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          };
          $scope.selectUser = function(user) {
            // Check if it is a different user
            if ($scope.selectedUser != user) {
              $scope.selectedUser = user;
              $scope.selectedUser.$rights();
            }
          };
        };
      };

      // Callback of sgSubscribe directive
      vm.subscribeToFolder = function(calendarData) {
        $log.debug('subscribeToFolder ' + calendarData.owner + calendarData.name);
        Calendar.$subscribe(calendarData.owner, calendarData.name).catch(function(data) {
          Dialog.alert(l('Warning'), l('An error occured please try again.'));
        });
      };
    }])
  
    .controller('CalendarListController', ['$scope', '$rootScope', '$timeout', '$state', 'sgFocus', 'encodeUriFilter', 'sgDialog', 'sgSettings', 'sgCalendar', 'sgComponent', '$mdSidenav', function($scope, $rootScope, $timeout, $state, focus, encodeUriFilter, Dialog, Settings, Calendar, Component, $mdSidenav) {
      var vm = this;

      vm.component = Component;
      vm.componentType = null;
      vm.selectComponentType = selectComponentType;
      vm.newComponent = newComponent;
      // TODO: should reflect last state userSettings -> Calendar -> SelectedList
      vm.selectedList = 0;
      vm.selectComponentType('events');

      // Switch between components tabs
      function selectComponentType(type, options) {
        if (options && options.reload || vm.componentType != type) {
          // TODO: save user settings (Calendar.SelectedList)
          Component.$filter(type);
          vm.componentType = type;
        }
      }

      function newComponent() {
        var type = 'appointment';

        if (vm.componentType == 'tasks')
          type = 'task';

        $state.go('calendars.newComponent', { calendarId: 'personal', componentType: type });
      }

      // Refresh current list when the list of calendars is modified
      $scope.$on('calendars:list', function() {
        Component.$filter(vm.componentType);
      });
    }])

    .controller('CalendarController', ['$scope', '$state', '$stateParams', '$timeout', '$interval', '$log', 'sgFocus', 'sgCalendar', 'sgComponent', 'stateEventsBlocks', function($scope, $state, $stateParams, $timeout, $interval, $log, focus, Calendar, Component, stateEventsBlocks) {
      var vm = this;

      vm.blocks = stateEventsBlocks;
      vm.changeView = changeView;

      // Refresh current view when the list of calendars is modified
      $scope.$on('calendars:list', function() {
        Component.$eventsBlocksForView($stateParams.view, $stateParams.day.asDate()).then(function(data) {
          vm.blocks = data;
        });
      });

      // Change calendar's view
      function changeView($event) {
        var date = angular.element($event.currentTarget).attr('date');
        $state.go('calendars.view', { view: $stateParams.view, day: date });
      }
    }])

    .controller('ComponentController', ['$scope', '$log', '$timeout', '$state', '$previousState', '$mdSidenav', '$mdDialog', 'sgCalendar', 'sgComponent', 'stateCalendars', 'stateComponent', function($scope, $log, $timeout, $state, $previousState, $mdSidenav, $mdDialog, Calendar, Component, stateCalendars, stateComponent) {
      var vm = this;

      vm.calendars = stateCalendars;
      vm.event = stateComponent;
      vm.categories = {};
      vm.editRecurrence = editRecurrence;
      vm.cancel = cancel;
      vm.save = save;

      // Open sidenav when loading the view;
      // Return to previous state when closing the sidenav.
      $scope.$on('$viewContentLoaded', function(event) {
        $timeout(function() {
          $mdSidenav('right').open()
            .then(function() {
              $scope.$watch($mdSidenav('right').isOpen, function(isOpen, wasOpen) {
                if (!isOpen) {
                  if ($previousState.get())
                    $previousState.go()
                  else
                    $state.go('calendars');
                }
              });
            });
        }, 100); // don't ask why
      });

      function editRecurrence($event) {
        $mdDialog.show({
          templateUrl: 'editRecurrence', // UI/Templates/SchedulerUI/UIxRecurrenceEditor.wox
          controller: RecurrenceController
        });
        function RecurrenceController() {
          
        }
      }

      function save(form) {
        if (form.$valid) {
          vm.event.$save()
            .then(function(data) {
              $scope.$emit('calendars:list');
              $mdSidenav('right').close();
            }, function(data, status) {
              $log.debug('failed');
            });
        }
      }

      function cancel() {
        vm.event.$reset();
        if (vm.event.isNew) {
          // Cancelling the creation of a component
          vm.event = null;
        }
        $mdSidenav('right').close();
      }
    }]);

})();
