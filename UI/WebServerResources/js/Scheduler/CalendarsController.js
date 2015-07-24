/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarsController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$q', '$mdDialog', '$log', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Calendar', 'User', 'stateCalendars'];
  function CalendarsController($scope, $rootScope, $stateParams, $state, $timeout, $q, $mdDialog, $log, focus, encodeUriFilter, Dialog, Settings, Calendar, User, stateCalendars) {
    var vm = this;

    vm.activeUser = Settings.activeUser;
    vm.service = Calendar;
    vm.newCalendar = newCalendar;
    vm.addWebCalendar = addWebCalendar;
    vm.confirmDelete = confirmDelete;
    vm.share = share;
    vm.showLinks = showLinks;
    vm.showProperties = showProperties;
    vm.subscribeToFolder = subscribeToFolder;

    // Dispatch the event named 'calendars:list' when a calendar is activated or deactivated or
    // when the color of a calendar is changed
    $scope.$watch(
      function() {
        return _.union(
          _.map(Calendar.$calendars, function(o) { return _.pick(o, ['id', 'active', 'color']); }),
          _.map(Calendar.$subscriptions, function(o) { return _.pick(o, ['id', 'active', 'color']); }),
          _.map(Calendar.$webcalendars, function(o) { return _.pick(o, ['id', 'active', 'color']); })
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

    function newCalendar(ev) {
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
    }

    function addWebCalendar() {
      Dialog.prompt(l('Subscribe to a web calendar...'), l('URL of the Calendar'), {inputType: 'url'})
        .then(function(url) {
          Calendar.$addWebCalendar(url);
        });
    }

    function confirmDelete(folder) {
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
    }

    function showLinks(selectedFolder) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: selectedFolder.id + '/links',
        locals: {
        },
        controller: LinksDialogController
      });
      
      /**
       * @ngInject
       */
      LinksDialogController.$inject = ['scope', '$mdDialog'];
      function LinksDialogController(scope, $mdDialog) {
        scope.close = function() {
          $mdDialog.hide();
        };
      }
    }

    function showProperties(calendar) {
      $mdDialog.show({
        templateUrl: calendar.id + '/properties',
        controller: PropertiesDialogController,
        controllerAs: 'properties',
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          calendar: calendar
        }
      });
      
      /**
       * @ngInject
       */
      PropertiesDialogController.$inject = ['$mdDialog', 'calendar'];
      function PropertiesDialogController($mdDialog, calendar) {
        var vm = this;
        vm.calendar = calendar;

        vm.close = function() {
          $mdDialog.hide();
        };

        vm.saveProperties = function() {
          vm.calendar.$save();
          $mdDialog.hide();
        };
      }
    }

    function share(calendar) {
      calendar.$acl.$users().then(function() {
        $mdDialog.show({
          templateUrl: calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: CalendarACLController,
          controllerAs: 'acl',
          clickOutsideToClose: true,
          escapeToClose: true,
          locals: {
            usersWithACL: calendar.$acl.users,
            User: User,
            folder: calendar
          }
        });
      });

      /**
       * @ngInject
       */
      CalendarACLController.$inject = ['$mdDialog', 'usersWithACL', 'User', 'folder'];
      function CalendarACLController($mdDialog, usersWithACL, User, folder) {
        var vm = this;

        vm.users = usersWithACL; // ACL users
        vm.folder = folder;
        vm.selectedUser = null;
        vm.userToAdd = '';
        vm.searchText = '';
        vm.userFilter = userFilter;
        vm.closeModal = closeModal;
        vm.saveModal = saveModal;
        vm.confirmChange = confirmChange;
        vm.removeUser = removeUser;
        vm.addUser = addUser;
        vm.selectUser = selectUser;

        function userFilter($query) {
          return User.$filter($query, folder.$acl.users);
        }

        function closeModal() {
          folder.$acl.$resetUsersRights(); // cancel changes
          $mdDialog.hide();
        }

        function saveModal() {
          folder.$acl.$saveUsersRights().then(function() {
            $mdDialog.hide();
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        }

        function confirmChange(user) {
          var confirmation = user.$confirmRights();
          if (confirmation) {
            Dialog.confirm(l('Warning'), confirmation).catch(function() {
              user.$resetRights(true);
            });
          }
        }

        function removeUser(user) {
          folder.$acl.$removeUser(user.uid).then(function() {
            if (user.uid == vm.selectedUser.uid)
              vm.selectedUser = null;
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'));
          });
        }

        function addUser(data) {
          if (data) {
            folder.$acl.$addUser(data).then(function() {
              vm.userToAdd = '';
              vm.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
        }

        function selectUser(user) {
          // Check if it is a different user
          if (vm.selectedUser != user) {
            vm.selectedUser = user;
            vm.selectedUser.$rights();
          }
        }
      }
    }

    // Callback of sgSubscribe directive
    function subscribeToFolder(calendarData) {
      $log.debug('subscribeToFolder ' + calendarData.owner + calendarData.name);
      Calendar.$subscribe(calendarData.owner, calendarData.name).catch(function(data) {
        Dialog.alert(l('Warning'), l('An error occured please try again.'));
      });
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .controller('CalendarsController', CalendarsController);
})();
