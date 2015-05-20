/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  ComponentController.$inject = ['$scope', '$log', '$timeout', '$state', '$previousState', '$mdSidenav', '$mdDialog', 'Calendar', 'Component', 'stateCalendars', 'stateComponent'];
  function ComponentController($scope, $log, $timeout, $state, $previousState, $mdSidenav, $mdDialog, Calendar, Component, stateCalendars, stateComponent) {
    var vm = this;

    vm.calendars = stateCalendars;
    vm.event = stateComponent;
    vm.categories = {};
    vm.showRecurrenceEditor = vm.event.$hasCustomRepeat;
    vm.toggleRecurrenceEditor = toggleRecurrenceEditor;
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

    function toggleRecurrenceEditor() {
      vm.showRecurrenceEditor = !vm.showRecurrenceEditor;
      vm.event.$hasCustomRepeat = vm.showRecurrenceEditor;
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
  }

  angular
    .module('SOGo.SchedulerUI')  
    .controller('ComponentController', ComponentController);
})();
