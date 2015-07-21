/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  ComponentController.$inject = ['$mdDialog', 'Calendar', 'stateComponent'];
  function ComponentController($mdDialog, Calendar, stateComponent) {
    var vm = this, component;

    vm.component = stateComponent;
    vm.close = close;
    vm.edit = edit;

    // Load all attributes of component
    if (angular.isUndefined(vm.component.$futureComponentData)) {
      component = Calendar.$get(vm.component.c_folder).$getComponent(vm.component.c_name);
      component.$futureComponentData.then(function() {
        vm.component = component;
      });
    }

    function close() {
      $mdDialog.hide();
    }

    function edit() {
      var type = (vm.component.component == 'vevent')? 'Appointment':'Task';
      $mdDialog.hide().then(function() {
        // UI/Templates/SchedulerUI/UIxAppointmentEditorTemplate.wox or
        // UI/Templates/SchedulerUI/UIxTaskEditorTemplate.wox
        var templateUrl = 'UIx' + type + 'EditorTemplate';
        $mdDialog.show({
          parent: angular.element(document.body),
          clickOutsideToClose: true,
          escapeToClose: true,
          templateUrl: templateUrl,
          controller: 'ComponentEditorController',
          controllerAs: 'editor',
          locals: {
            stateComponent: vm.component
          }
        });
      });
    }
  }

  /**
   * @ngInject
   */
  ComponentEditorController.$inject = ['$scope', '$log', '$timeout', '$mdDialog', 'User', 'Calendar', 'Component', 'AddressBook', 'Card', 'stateComponent'];
  function ComponentEditorController($scope, $log, $timeout, $mdDialog, User, Calendar, Component, AddressBook, Card, stateComponent) {
    var vm = this, component;

    vm.calendars = Calendar.$calendars;
    vm.component = stateComponent;
    vm.categories = {};
    vm.showRecurrenceEditor = vm.component.$hasCustomRepeat;
    vm.toggleRecurrenceEditor = toggleRecurrenceEditor;
    vm.showAttendeesEditor = angular.isDefined(vm.component.attendees);
    vm.toggleAttendeesEditor = toggleAttendeesEditor;
    vm.cardFilter = cardFilter;
    vm.cardResults = [];
    vm.addAttendee = addAttendee;
    vm.addAttachUrl = addAttachUrl;
    vm.cancel = cancel;
    vm.save = save;
    vm.attendeesEditor = {
      startDate: vm.component.startDate,
      endDate: vm.component.endDate,
      days: getDays(),
      hours: getHours()
    };

    $scope.$watch('editor.component.startDate', function(newStartDate, oldStartDate) {
      if (newStartDate) {
        $timeout(function() {
          vm.component.start = new Date(newStartDate.substring(0,10) + ' ' + newStartDate.substring(11,16));
          vm.component.freebusy = vm.component.updateFreeBusyCoverage();
          vm.attendeesEditor.days = getDays();
        });
      }
    });

    $scope.$watch('editor.component.endDate', function(newEndDate, oldEndDate) {
      if (newEndDate) {
        $timeout(function() {
          vm.component.end = new Date(newEndDate.substring(0,10) + ' ' + newEndDate.substring(11,16));
          vm.component.freebusy = vm.component.updateFreeBusyCoverage();
          vm.attendeesEditor.days = getDays();
        });
      }
    });

    function addAttachUrl() {
      var i = vm.component.addAttachUrl('');
      focus('attachUrl_' + i);
    };

    function toggleRecurrenceEditor() {
      vm.showRecurrenceEditor = !vm.showRecurrenceEditor;
      vm.component.$hasCustomRepeat = vm.showRecurrenceEditor;
    }

    function toggleAttendeesEditor() {
      vm.showAttendeesEditor = !vm.showAttendeesEditor;
    }

    // Autocomplete cards for attendees
    function cardFilter($query) {
      var index, indexResult, card;
      if ($query) {
        AddressBook.$filterAll($query).then(function(results) {
          // Remove cards that no longer match the search query
          for (index = vm.cardResults.length - 1; index >= 0; index--) {
            card = vm.cardResults[index];
            indexResult = _.findIndex(results, function(result) {
              return _.find(card.emails, function(data) {
                return _.find(result.emails, function(resultData) {
                  return resultData.value == data.value;
                });
              });
            });
            if (indexResult >= 0)
              results.splice(indexResult, 1);
            else
              vm.cardResults.splice(index, 1);
          }
          _.each(results, function(card) {
            // Add cards matching the search query but not already in the list of attendees
            if (!vm.component.hasAttendee(card))
              vm.cardResults.push(card);
          });
        });
      }
      return vm.cardResults;
    }

    function addAttendee(card) {
      if (angular.isString(card)) {
        // User pressed "Enter" in search field, adding a non-matching card
        if (card.isValidEmail()) {
          vm.component.addAttendee(new Card({ emails: [{ value: card }] }));
          vm.searchText = '';
        }
      }
      else {
        vm.component.addAttendee(card);
      }
    }

    function save(form) {
      if (form.$valid) {
        vm.component.$save()
          .then(function(data) {
            $scope.$emit('calendars:list');
            $mdDialog.hide();
          }, function(data, status) {
            $log.debug('failed');
          });
      }
    }

    function cancel() {
      vm.component.$reset();
      if (vm.component.isNew) {
        // Cancelling the creation of a component
        vm.component = null;
      }
      $mdDialog.hide();
    }

    function getDays() {
      var days = [];

      if (vm.component.start && vm.component.end)
        days = vm.component.start.daysUpTo(vm.component.end);

      return _.map(days, function(date) {
        return { stringWithSeparator: date.stringWithSeparator(),
                 getDayString: date.getDayString() };
      });
    }

    function getHours() {
      var hours = [];
      for (var i = 0; i <= 23; i++) {
        //hours.push(Component.timeFormat.formatTime(i, 0));
        hours.push(i.toString());
      }
      return hours;
    }
  }

  angular
    .module('SOGo.SchedulerUI')  
    .controller('ComponentController', ComponentController)
    .controller('ComponentEditorController', ComponentEditorController);
})();
