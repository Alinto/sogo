/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  ComponentController.$inject = ['$rootScope', '$mdDialog', 'Calendar', 'AddressBook', 'Alarm', 'stateComponent'];
  function ComponentController($rootScope, $mdDialog, Calendar, AddressBook, Alarm, stateComponent) {
    var vm = this, component;

    vm.component = stateComponent;
    vm.close = close;
    vm.cardFilter = cardFilter;
    vm.edit = edit;
    vm.editAllOccurrences = editAllOccurrences;
    vm.reply = reply;
    vm.replyAllOccurrences = replyAllOccurrences;

    // Load all attributes of component
    if (angular.isUndefined(vm.component.$futureComponentData)) {
      component = Calendar.$get(vm.component.c_folder).$getComponent(vm.component.c_name, vm.component.c_recurrence_id);
      component.$futureComponentData.then(function() {
        vm.component = component;
        vm.organizer = [vm.component.organizer];
      });
    }

    function close() {
      $mdDialog.hide();
    }

    // Autocomplete cards for attendees
    function cardFilter($query) {
      AddressBook.$filterAll($query);
      return AddressBook.$cards;
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

    function editAllOccurrences() {
      component = Calendar.$get(vm.component.pid).$getComponent(vm.component.id);
      component.$futureComponentData.then(function() {
        vm.component = component;
        edit();
      });
    }

    function reply(component) {
      var c = component || vm.component;

      c.$reply().then(function() {
        $rootScope.$broadcast('calendars:list');
        $mdDialog.hide();
        Alarm.getAlarms();
      });
    }

    function replyAllOccurrences() {
      // Retrieve master event
      component = Calendar.$get(vm.component.pid).$getComponent(vm.component.id);
      component.$futureComponentData.then(function() {
        // Propagate the participant status and alarm to the master event
        component.reply = vm.component.reply;
        component.delegatedTo = vm.component.delegatedTo;
        component.$hasAlarm = vm.component.$hasAlarm;
        component.alarm = vm.component.alarm;
        // Send reply to the server
        reply(component);
      });
    }
  }

  /**
   * @ngInject
   */
  ComponentEditorController.$inject = ['$rootScope', '$scope', '$log', '$timeout', '$mdDialog', 'User', 'Calendar', 'Component', 'AddressBook', 'Card', 'Alarm', 'stateComponent'];
  function ComponentEditorController($rootScope, $scope, $log, $timeout, $mdDialog, User, Calendar, Component, AddressBook, Card, Alarm, stateComponent) {
    var vm = this, component;

    vm.calendars = Calendar.$calendars;
    vm.component = stateComponent;
    vm.categories = {};
    vm.showRecurrenceEditor = vm.component.$hasCustomRepeat;
    vm.toggleRecurrenceEditor = toggleRecurrenceEditor;
    vm.showAttendeesEditor = angular.isDefined(vm.component.attendees);
    vm.toggleAttendeesEditor = toggleAttendeesEditor;
    vm.cardFilter = cardFilter;
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
    }

    function toggleRecurrenceEditor() {
      vm.showRecurrenceEditor = !vm.showRecurrenceEditor;
      vm.component.$hasCustomRepeat = vm.showRecurrenceEditor;
    }

    function toggleAttendeesEditor() {
      vm.showAttendeesEditor = !vm.showAttendeesEditor;
    }

    // Autocomplete cards for attendees
    function cardFilter($query) {
      AddressBook.$filterAll($query);
      return AddressBook.$cards;
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
            $rootScope.$broadcast('calendars:list');
            $mdDialog.hide();
            Alarm.getAlarms();
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
