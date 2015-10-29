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
    vm.deleteOccurrence = deleteOccurrence;
    vm.deleteAllOccurrences = deleteAllOccurrences;
    vm.viewRawSource = viewRawSource;

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

    function deleteOccurrence() {
      vm.component.remove(true).then(function() {
        $rootScope.$broadcast('calendars:list');
        $mdDialog.hide();
      });
    }

    function deleteAllOccurrences() {
      vm.component.remove().then(function() {
        $rootScope.$broadcast('calendars:list');
        $mdDialog.hide();
      });
    }

    function viewRawSource($event) {
      Calendar.$$resource.post(vm.component.pid + '/' + vm.component.id, "raw").then(function(data) {
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: $event,
          clickOutsideToClose: true,
          escapeToClose: true,
          template: [
            '<md-dialog flex="80" flex-sm="100" aria-label="' + l('View Raw Source') + '">',
            '  <md-dialog-content class="md-dialog-content">',
            '    <pre>',
            data,
            '    </pre>',
            '  </md-dialog-content>',
            '  <div class="md-actions">',
            '    <md-button ng-click="close()">' + l('Close') + '</md-button>',
            '  </div>',
            '</md-dialog>'
          ].join(''),
          controller: ComponentRawSourceDialogController
        });

        /**
         * @ngInject
         */
        ComponentRawSourceDialogController.$inject = ['scope', '$mdDialog'];
        function ComponentRawSourceDialogController(scope, $mdDialog) {
          scope.close = function() {
            $mdDialog.hide();
          };
        }
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
    //vm.searchText = null;
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

    $scope.$watch('editor.component.start', function(newStartDate, oldStartDate) {
      if (vm.component.type == 'appointment') {
        vm.component.end = new Date(vm.component.start);
        vm.component.end.addMinutes(vm.component.delta);
        vm.component.freebusy = vm.component.updateFreeBusyCoverage();
        vm.attendeesEditor.days = getDays();
      }
    });

    $scope.$watch('editor.component.end', function(newEndDate, oldEndDate) {
        if (newEndDate.getDate() !== oldEndDate.getDate() ||
            newEndDate.getMonth() !== oldEndDate.getMonth() ||
            newEndDate.getFullYear() !== oldEndDate.getFullYear())
          vm.component.end.addMinutes(oldEndDate.getHours() * 60 + oldEndDate.getMinutes());

      if (newEndDate <= vm.component.start) {
        vm.component.end = oldEndDate;
      }
      else {
        vm.component.delta = Math.floor((Math.abs(vm.component.end - vm.component.start)/1000)/60);
        vm.component.freebusy = vm.component.updateFreeBusyCoverage();
        vm.attendeesEditor.days = getDays();
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
