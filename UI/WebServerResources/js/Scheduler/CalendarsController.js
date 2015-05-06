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
    vm.subscribeToFolder = subscribeToFolder;

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

    function share(calendar) {
      $mdDialog.show({
        templateUrl: calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
        controller: CalendarACLController,
        clickOutsideToClose: true,
        escapeToClose: true,
        locals: {
          usersWithACL: calendar.$acl.$users(),
          User: User,
          folder: calendar
        }
      });
      /**
       * @ngInject
       */
      CalendarACLController.$inject = ['$scope', '$mdDialog', 'usersWithACL', 'User', 'folder'];
      function CalendarACLController($scope, $mdDialog, usersWithACL, User, folder) {
        $scope.users = usersWithACL; // ACL users
        $scope.folder = folder;
        $scope.selectedUser = null;
        $scope.userToAdd = '';
        $scope.searchText = '';
        $scope.userFilter = function($query) {
          return User.$filter($query);
        };
        $scope.closeModal = function() {
          folder.$acl.$resetUsersRights(); // cancel changes
          $mdDialog.hide();
        };
        $scope.saveModal = function() {
          folder.$acl.$saveUsersRights().then(function() {
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
          folder.$acl.$removeUser(user.uid).then(function() {
            if (user.uid == $scope.selectedUser.uid)
              $scope.selectedUser = null;
          }, function(data, status) {
            Dialog.alert(l('Warning'), l('An error occured please try again.'))
          });
        };
        $scope.addUser = function(data) {
          if (data) {
            folder.$acl.$addUser(data).then(function() {
              $scope.userToAdd = '';
              $scope.searchText = '';
            }, function(error) {
              Dialog.alert(l('Warning'), error);
            });
          }
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
