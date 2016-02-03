/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarListController.$inject = ['$rootScope', '$timeout', '$state', '$mdDialog', 'Dialog', 'Preferences', 'Calendar', 'Component'];
  function CalendarListController($rootScope, $timeout, $state, $mdDialog, Dialog, Preferences, Calendar, Component) {
    var vm = this;

    vm.component = Component;
    vm.componentType = 'events';
    vm.selectedList = 0;
    vm.selectComponentType = selectComponentType;
    vm.unselectComponents = unselectComponents;
    vm.selectAll = selectAll;
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
    vm.mode = { search: false };

    // Select list based on user's settings
    Preferences.ready().then(function() {
      var type = 'events';
      if (Preferences.settings.Calendar.SelectedList == 'tasksListView') {
        vm.selectedList = 1;
        type = 'tasks';
      }
      selectComponentType(type, { reload: true });
    });

    // Refresh current list when the list of calendars is modified
    $rootScope.$on('calendars:list', function() {
      Component.$filter(vm.componentType, { reload: true });
    });

    // Update the component being dragged
    $rootScope.$on('calendar:dragend', updateComponentFromGhost);

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
      _.each(Component['$' + vm.componentType], function(component) { component.selected = false; });
    }

    function selectAll() {
      _.each(Component['$' + vm.componentType], function(component) {
        component.selected = true;
      });
    }

    function toggleComponentSelection($event, component) {
      component.selected = !component.selected;
      $event.preventDefault();
      $event.stopPropagation();
    }

    function confirmDeleteSelectedComponents() {
      Dialog.confirm(l('Warning'),
                     l('Are you sure you want to delete the selected components?'))
        .then(function() {
          // User confirmed the deletion
          var components = _.filter(Component['$' + vm.componentType], function(component) { return component.selected; });
          Calendar.$deleteComponents(components);
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
      }
    }

    function newComponent($event, baseComponent) {
      var type = 'appointment', component;

      if (baseComponent) {
        component = baseComponent;
        type = baseComponent.type;
      }
      else {
        if (vm.componentType == 'tasks')
          type = 'task';
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
        newComponent(null, component).finally(function() {
          $timeout(function() {
            Component.$ghost.pointerHandler = null;
            Component.$ghost.component = null;
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
            $timeout(function() {
              Component.$ghost = {};
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
              '<md-dialog flex="50" md-flex="80" sm-flex="90">',
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
          }).finally(function() {
            $timeout(function() {
              Component.$ghost = {};
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
          component.$adjust(params).then($mdDialog.hide, $mdDialog.cancel);
        };
        $scope.updateAllOccurrences = function() {
          delete component.occurrenceId;
          component.$adjust(params).then($mdDialog.hide, $mdDialog.cancel);
        };
      }
    }

    function filter(filterpopup) {
      Component.$filter(vm.componentType, { filterpopup: filterpopup });
    }

    function filteredBy(filterpopup) {
      return Component['$query' + vm.componentType.capitalize()].filterpopup == filterpopup;
    }

    function sort(field) {
      Component.$filter(vm.componentType, { sort: field });
    }

    function sortedBy(field) {
      return Component['$query' + vm.componentType.capitalize()].sort == field;
    }

    function reload() {
      $rootScope.$emit('calendars:list');
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
