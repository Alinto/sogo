/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarListController.$inject = ['$scope', '$rootScope', '$timeout', '$state', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Preferences', 'Calendar', 'Component', '$mdSidenav'];
  function CalendarListController($scope, $rootScope, $timeout, $state, focus, encodeUriFilter, Dialog, Settings, Preferences, Calendar, Component, $mdSidenav) {
    var vm = this;

    vm.component = Component;
    vm.componentType = 'events';
    vm.selectedList = 0;
    vm.selectComponentType = selectComponentType;
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

    function newComponent() {
      var type = 'appointment';

      if (vm.componentType == 'tasks')
        type = 'task';

      $state.go('calendars.newComponent', { calendarId: 'personal', componentType: type });
    }

    function filter(filterpopup) {
      Component.$filter(vm.componentType, options);
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
