/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarListController.$inject = ['$scope', '$timeout', '$state', '$mdDialog', 'encodeUriFilter', 'Dialog', 'Preferences', 'Calendar', 'Component'];
  function CalendarListController($scope, $timeout, $state, $mdDialog, encodeUriFilter, Dialog, Preferences, Calendar, Component) {
    var vm = this;

    vm.component = Component;
    vm.componentType = 'events';
    vm.selectedList = 0;
    vm.selectComponentType = selectComponentType;
    vm.openEvent = openEvent;
    vm.openTask = openTask;
    vm.newComponent = newComponent;
    vm.filter = filter;
    vm.filteredBy = filteredBy;
    vm.sort = sort;
    vm.sortedBy = sortedBy;
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

    // Switch between components tabs
    function selectComponentType(type, options) {
      if (options && options.reload || vm.componentType != type) {
        // TODO: save user settings (Calendar.SelectedList)
        if (angular.isUndefined(Component['$' + type]))
          Component.$filter(type);
        vm.componentType = type;
      }
    }

    function openEvent($event, event) {
      openComponent($event, event, 'appointment');
    }

    function openTask($event, task) {
      openComponent($event, task, 'task');
    }

    function openComponent($event, component, type) {
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
        controllerAs: 'viewer',
        locals: {
          stateComponent: component
        }
      });
    }

    function newComponent($event) {
      var type = 'appointment', component;

      if (vm.componentType == 'tasks')
        type = 'task';
      component = new Component({ pid: 'personal', type: type });

      // UI/Templates/SchedulerUI/UIxAppointmentEditorTemplate.wox or
      // UI/Templates/SchedulerUI/UIxTaskEditorTemplate.wox
      var templateUrl = 'UIx' + type.capitalize() + 'EditorTemplate';
      $mdDialog.show({
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

    function cancelSearch() {
      vm.mode.search = false;
      Component.$filter(vm.componentType, { value: '' });
    }

    // Refresh current list when the list of calendars is modified
    $scope.$on('calendars:list', function() {
      Component.$filter(vm.componentType);
    });
  }
  
  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarListController', CalendarListController);
})();
