/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarListController.$inject = ['$rootScope', '$scope', '$q', '$timeout', '$state', '$mdDialog', 'sgHotkeys', 'sgFocus', 'Dialog', 'Preferences', 'CalendarSettings', 'Calendar', 'Component', 'Alarm'];
  function CalendarListController($rootScope, $scope, $q, $timeout, $state, $mdDialog, sgHotkeys, focus, Dialog, Preferences, CalendarSettings, Calendar, Component, Alarm) {
    var vm = this, hotkeys = [], type, sortLabels;

    sortLabels = {
      title: 'Title',
      location: 'Location',
      calendarName: 'Calendar',
      start: 'Start',
      priority: 'Priority',
      category: 'Category',
      status: 'Status',
      events: {
        end: 'End'
      },
      tasks: {
        end: 'Due Date'
      }
    };

    vm.component = Component;
    vm.componentType = 'events';
    vm.selectedList = 0;
    vm.selectComponentType = selectComponentType;
    vm.unselectComponents = unselectComponents;
    vm.selectAll = selectAll;
    vm.searchMode = searchMode;
    vm.toggleComponentSelection = toggleComponentSelection;
    vm.confirmDeleteSelectedComponents = confirmDeleteSelectedComponents;
    vm.openEvent = openEvent;
    vm.openTask = openTask;
    vm.newComponent = newComponent;
    vm.filter = filter;
    vm.filteredBy = filteredBy;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
    vm.reload = reload;
    vm.cancelSearch = cancelSearch;
    vm.mode = { search: false, multiple: 0 };


    this.$onInit = function() {
      _registerHotkeys(hotkeys);

      // Select list based on user's settings
      type = 'events';
      if (Preferences.settings.Calendar.SelectedList == 'tasksListView') {
        vm.selectedList = 1;
        type = 'tasks';
      }
      selectComponentType(type, { reload: true }); // fetch events/tasks lists

      // Refresh current list when the list of calendars is modified
      $rootScope.$on('calendars:list', function() {
        Component.$filter(vm.componentType, { reload: true });
      });

      // Update the component being dragged
      $rootScope.$on('calendar:dragend', updateComponentFromGhost);

      $scope.$on('$destroy', function() {
        // Deregister hotkeys
        _.forEach(hotkeys, function(key) {
          sgHotkeys.deregisterHotkey(key);
        });
      });
    };


    function _registerHotkeys(keys) {
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_search'),
        description: l('Search'),
        callback: searchMode
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_create_event'),
        description: l('Create a new event'),
        callback: newComponent,
        args: 'appointment'
      }));
      keys.push(sgHotkeys.createHotkey({
        key: l('hotkey_create_task'),
        description: l('Create a new task'),
        callback: newComponent,
        args: 'task'
      }));

      // Register the hotkeys
      _.forEach(keys, function(key) {
        sgHotkeys.registerHotkey(key);
      });
    }

    // Switch between components tabs
    function selectComponentType(type, options) {
      if (options && options.reload || vm.componentType != type) {
        if (angular.isUndefined(Component['$' + type]))
          Component.$filter(type);
        vm.unselectComponents();
        vm.componentType = type;
        Component.saveSelectedList(type);
      }
    }

    function unselectComponents() {
      _.forEach(Component['$' + vm.componentType], function(component) {
        component.selected = false;
      });
      vm.mode.multiple = 0;
    }

    function selectAll() {
      _.forEach(Component['$' + vm.componentType], function(component) {
        component.selected = true;
      });
      vm.mode.multiple = Component['$' + vm.componentType].length;
    }

    function toggleComponentSelection($event, component) {
      component.selected = !component.selected;
      vm.mode.multiple += component.selected? 1 : -1;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function searchMode() {
      vm.mode.search = true;
      focus('search');
    }

    function confirmDeleteSelectedComponents() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected components?'),
                     { ok: l('Delete') })
        .then(function() {
          // User confirmed the deletion
          var components = _.filter(Component['$' + vm.componentType], function(component) {
            return component.selected;
          });
          Calendar.$deleteComponents(components).then(function() {
            vm.mode.multiple = 0;
            $rootScope.$emit('calendars:list');
          });
        });
    }

    function openEvent($event, event) {
      openComponent($event, event, 'appointment');
    }

    function openTask($event, task) {
      openComponent($event, task, 'task');
    }

    function openComponent($event, component, type) {
      if (component.viewable) {
        var promise = $q.when();

        // Load component before opening dialog
        if (angular.isUndefined(component.$futureComponentData)) {
          component = Calendar.$get(component.pid).$getComponent(component.id, component.occurrenceId);
          promise = component.$futureComponentData;
        }

        promise.then(function() {
          // UI/Templates/SchedulerUI/UIxAppointmentViewTemplate.wox or
          // UI/Templates/SchedulerUI/UIxTaskViewTemplate.wox
          var templateUrl = 'UIx' + type.capitalize() + 'ViewTemplate';
          $mdDialog.show({
            parent: angular.element(document.body),
            targetEvent: $event,
            clickOutsideToClose: true,
            escapeToClose: true,
            templateUrl: templateUrl,
            controller: 'ComponentController',
            controllerAs: 'editor',
            locals: {
              stateComponent: component
            }
          });
        });
      }
    }

    function newComponent($event, type, baseComponent) {
      var component;

      if (baseComponent) {
        component = baseComponent;
        component.initAttendees();
        component.$attendees.updateFreeBusy();
      }
      else {
        component = new Component({ pid: Calendar.$defaultCalendar(), type: type });
      }

      // UI/Templates/SchedulerUI/UIxAppointmentEditorTemplate.wox or
      // UI/Templates/SchedulerUI/UIxTaskEditorTemplate.wox
      var templateUrl = 'UIx' + type.capitalize() + 'EditorTemplate';
      return $mdDialog.show({
        parent: angular.element(document.body),
        targetEvent: $event,
        clickOutsideToClose: true,
        escapeToClose: true,
        templateUrl: templateUrl,
        controller: 'ComponentEditorController',
        controllerAs: 'editor',
        locals: {
          stateComponent: component
        }
      });
    }

    // Adjust component or create new component through drag'n'drop
    function updateComponentFromGhost($event) {
      var component, pointerHandler, coordinates, delta, params, calendarNumber, activeCalendars;

      component = Component.$ghost.component;
      pointerHandler = Component.$ghost.pointerHandler;

      if (component.isNew) {
        coordinates = pointerHandler.currentEventCoordinates;
        component.summary = '';
        if (component.isAllDay)
          coordinates.duration -= 96;
        component.setDelta(coordinates.duration * 15);
        newComponent(null, 'appointment', component)
          .catch()
          .finally(function() {
            $timeout(function() {
              Component.$resetGhost();
            });
          });
      }
      else {
        delta = pointerHandler.currentEventCoordinates.getDelta(pointerHandler.originalEventCoordinates);
        params = {
          days: delta.dayNumber,
          start: delta.start * 15,
          duration: delta.duration * 15
        };
        if (pointerHandler.originalCalendar && delta.dayNumber !== 0) {
          // The day number actually represents the destination calendar among the active calendars
          calendarNumber = pointerHandler.currentEventCoordinates.dayNumber;
          activeCalendars = _.filter(Calendar.$findAll(), { active: 1 });
          params.destination = activeCalendars[calendarNumber].id;
          params.days = 0;
        }
        if (component.isException || !component.occurrenceId)
          // Component is an exception to a recurrence or is not recurrent;
          // Immediately perform the adjustments
          component.$adjust(params).then(function() {
            $rootScope.$emit('calendars:list');
            Alarm.getAlarms();
          }, function(response) {
            onComponentAdjustError(response, component, params);
          }).finally(function() {
            $timeout(function() {
              Component.$resetGhost();
            });
          });
        else if (component.occurrenceId) {
          $mdDialog.show({
            clickOutsideToClose: true,
            escapeToClose: true,
            locals: {
              component: component,
              params: params
            },
            template: [
              '<md-dialog flex="50" sm-flex="80" xs-flex="90">',
              '  <md-dialog-content class="md-dialog-content">',
              '    <p>' + l('editRepeatingItem') + '</p>',
              '  </md-dialog-content>',
              '  <md-dialog-actions>',
              '    <md-button ng-click="updateThisOccurrence()">' + l('button_thisOccurrenceOnly') + '</md-button>',
              '    <md-button ng-click="updateAllOccurrences()">' + l('button_allOccurrences') + '</md-button>',
              '  </md-dialog-actions>',
              '</md-dialog>'
            ].join(''),
            controller: RecurrentComponentDialogController
          }).then(function() {
            $rootScope.$emit('calendars:list');
          }, function() {
            // Cancel
          }).finally(function() {
            $timeout(function() {
              Component.$resetGhost();
            });
          });
        }
      }

      /**
       * @ngInject
       */
      RecurrentComponentDialogController.$inject = ['$scope', '$mdDialog', 'component', 'params'];
      function RecurrentComponentDialogController($scope, $mdDialog, component, params) {
        $scope.updateThisOccurrence = function() {
          component.$adjust(params).then($mdDialog.hide, function(response) {
            $mdDialog.cancel().then(function() {
              onComponentAdjustError(response, component, params);
            }, function() {
              // Cancel
            });
          });
        };
        $scope.updateAllOccurrences = function() {
          delete component.occurrenceId;
          component.$adjust(params).then($mdDialog.hide, function(response) {
            $mdDialog.cancel().then(function() {
              onComponentAdjustError(response, component, params);
            }, function() {
              // Cancel
            });
          });
        };
      }

      function onComponentAdjustError(response, component, params) {
        if (response.status == CalendarSettings.ConflictHTTPErrorCode &&
            response.data && response.data.message && angular.isObject(response.data.message)) {
          $mdDialog.show({
            parent: angular.element(document.body),
            clickOutsideToClose: false,
            escapeToClose: false,
            templateUrl: 'UIxAttendeeConflictDialog',
            controller: AttendeeConflictDialogController,
            controllerAs: '$AttendeeConflictDialogController',
            locals: {
              component: component,
              params: params,
              conflictError: response.data.message
            }
          }).then(function() {
            $rootScope.$emit('calendars:list');
          }, function() {
            // Cancel
          });
        }
      }

      /**
       * @ngInject
       */
      AttendeeConflictDialogController.$inject = ['$scope', '$mdDialog', 'component', 'params', 'conflictError'];
      function AttendeeConflictDialogController($scope, $mdDialog, component, params, conflictError) {
        var vm = this;

        vm.conflictError = conflictError;
        vm.cancel = $mdDialog.cancel;
        vm.save = save;

        function save() {
          component.$adjust(angular.extend({ ignoreConflicts: true }, params)).then($mdDialog.hide);
        }
      }
    }

    function filter(filterpopup) {
      if (filterpopup) {
        Component.$filter(vm.componentType, { filterpopup: filterpopup });
      }
      else {
        return Component['$query' + vm.componentType.capitalize()].filterpopup;
      }
    }

    function filteredBy(filterpopup) {
      return Component['$query' + vm.componentType.capitalize()].filterpopup == filterpopup;
    }

    function sort(field) {
      if (field) {
        Component.$filter(vm.componentType, { sort: field });
      }
      else {
        var sort = Component['$query' + vm.componentType.capitalize()].sort;
        return sortLabels[sort] || sortLabels[vm.componentType][sort];
      }
    }

    function sortedBy(field) {
      return Component['$query' + vm.componentType.capitalize()].sort == field;
    }

    this.ascending = function() {
      return Component['$query' + vm.componentType.capitalize()].asc;
    };

    function reload() {
      Component.$loaded = Component.STATUS.LOADING; // Show progress indicator
      Calendar.reloadWebCalendars().finally(function() {
        $rootScope.$emit('calendars:list');
      });
    }

    function cancelSearch() {
      vm.mode.search = false;
      Component.$filter(vm.componentType, { value: '' });
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .controller('CalendarListController', CalendarListController);
})();
