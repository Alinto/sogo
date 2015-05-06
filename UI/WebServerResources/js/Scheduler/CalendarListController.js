/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  CalendarListController.$inject = ['$scope', '$rootScope', '$timeout', '$state', 'sgFocus', 'encodeUriFilter', 'Dialog', 'sgSettings', 'Calendar', 'Component', '$mdSidenav'];
  function CalendarListController($scope, $rootScope, $timeout, $state, focus, encodeUriFilter, Dialog, Settings, Calendar, Component, $mdSidenav) {
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
  }
  
  angular
    .module('SOGo.SchedulerUI')  
    .controller('CalendarListController', CalendarListController);
})();
