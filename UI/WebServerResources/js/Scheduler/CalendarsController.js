/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarsController.$inject = ['$scope', '$rootScope', '$stateParams', '$state', '$timeout', '$q', '$mdDialog', '$log', 'sgFocus', 'Dialog', 'sgSettings', 'Calendar', 'User', 'stateCalendars'];
  function CalendarsController($scope, $rootScope, $stateParams, $state, $timeout, $q, $mdDialog, $log, focus, Dialog, Settings, Calendar, User, stateCalendars) {
    var vm = this;

    vm.activeUser = Settings.activeUser;
    vm.service = Calendar;
    vm.newCalendar = newCalendar;
    vm.addWebCalendar = addWebCalendar;
    vm.confirmDelete = confirmDelete;
    vm.editFolder = editFolder;
    vm.revertEditing = revertEditing;
    vm.renameFolder = renameFolder;
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
            Dialog.alert(l('An error occured while deleting the calendar "%{0}".', folder.name),
                         l(data.error));
          });
      }
      else {
        Dialog.confirm(l('Warning'), l('Are you sure you want to delete the calendar <em>%{0}</em>?', folder.name))
          .then(function() {
            folder.$delete()
              .then(function() {
                $scope.$broadcast('calendars:list');
              }, function(data, status) {
                Dialog.alert(l('An error occured while deleting the calendar "%{0}".', folder.name),
                             l(data.error));
              });
          });
      }
    }

    function showLinks(calendar) {
      $mdDialog.show({
        parent: angular.element(document.body),
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: calendar.id + '/links',
        controller: LinksDialogController,
        controllerAs: 'links',
        locals: {
          calendar: calendar
        }
      });
      
      /**
       * @ngInject
       */
      LinksDialogController.$inject = ['$mdDialog', 'calendar'];
      function LinksDialogController($mdDialog, calendar) {
        var vm = this;
        vm.calendar = calendar;
        vm.close = close;

        function close() {
          $mdDialog.hide();
        }
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

        vm.calendar = new Calendar(calendar.$omit());
        vm.saveProperties = saveProperties;
        vm.close = close;

        function saveProperties() {
          vm.calendar.$save();
          // Refresh list instance
          calendar.init(vm.calendar.$omit());
          $mdDialog.hide();
        }

        function close() {
          $mdDialog.hide();
        }
      }
    }

    function editFolder(folder) {
      vm.calendarName = folder.name;
      vm.editMode = folder.id;
      focus('calendarName_' + folder.id);
    }

    function revertEditing(folder) {
      folder.$reset();
      vm.editMode = false;
    }

    function renameFolder(folder) {
      folder.$rename()
        .then(function(data) {
          vm.editMode = false;
        }, function(data, status) {
          Dialog.alert(l('Warning'), data);
        });
    }

    function share(calendar) {
      calendar.$acl.$users().then(function() {
        $mdDialog.show({
          templateUrl: calendar.id + '/UIxAclEditor', // UI/Templates/UIxAclEditor.wox
          controller: 'AclController', // from the ng module SOGo.Common
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
