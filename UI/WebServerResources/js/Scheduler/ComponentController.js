/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  ComponentController.$inject = ['$rootScope', '$mdDialog', 'Calendar', 'Component', 'AddressBook', 'Alarm', 'Account', 'stateComponent'];
  function ComponentController($rootScope, $mdDialog, Calendar, Component, AddressBook, Alarm, Account, stateComponent) {
    var vm = this, component;

    vm.calendarService = Calendar;
    vm.service = Component;
    vm.component = stateComponent;
    vm.close = close;
    vm.highPriority = highPriority;
    vm.cardFilter = cardFilter;
    vm.newMessageWithAllRecipients = newMessageWithAllRecipients;
    vm.newMessageWithRecipient = newMessageWithRecipient;
    vm.edit = edit;
    vm.editAllOccurrences = editAllOccurrences;
    vm.reply = reply;
    vm.replyAllOccurrences = replyAllOccurrences;
    vm.deleteOccurrence = deleteOccurrence;
    vm.deleteAllOccurrences = deleteAllOccurrences;
    vm.toggleRawSource = toggleRawSource;
    vm.copySelectedComponent = copySelectedComponent;
    vm.moveSelectedComponent = moveSelectedComponent;

    // Put organizer in an array to display it as an mdChip
    vm.organizer = [stateComponent.organizer];

    function close() {
      $mdDialog.hide();
    }

    function highPriority() {
      return (vm.component &&
              vm.component.priority &&
              vm.component.priority < 5);
    }

    // Autocomplete cards for attendees
    function cardFilter($query) {
      return AddressBook.$filterAll($query);
    }

    function newMessageWithAllRecipients($event) {
      var recipients = _.map(vm.component.attendees, function(attendee) {
        return attendee.name + " <" + attendee.email + ">";
      });
      _newMessage($event, recipients);
    }

    function newMessageWithRecipient($event, name, email) {
      _newMessage($event, [name + " <" + email + ">"]);
    }

    function _newMessage($event, recipients) {
      Account.$findAll().then(function(accounts) {
        var account = _.find(accounts, function(o) {
          if (o.id === 0)
            return o;
        });

        // We must initialize the Account with its mailbox
        // list before proceeding with message's creation
        account.$getMailboxes().then(function(mailboxes) {
          account.$newMessage().then(function(message) {
            angular.extend(message.editable, { to: recipients, subject: vm.component.summary });
            $mdDialog.show({
              parent: angular.element(document.body),
              targetEvent: $event,
              clickOutsideToClose: false,
              escapeToClose: false,
              templateUrl: '../Mail/UIxMailEditor',
              controller: 'MessageEditorController',
              controllerAs: 'editor',
              locals: {
                stateAccount: account,
                stateMessage: message
              }
            });
          });
        });
      });

      $event.preventDefault();
      $event.stopPropagation();
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
        $rootScope.$emit('calendars:list');
        Alarm.getAlarms();
        $mdDialog.hide();
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
        $rootScope.$emit('calendars:list');
        $mdDialog.hide();
      });
    }

    function deleteAllOccurrences() {
      vm.component.remove().then(function() {
        $rootScope.$emit('calendars:list');
        $mdDialog.hide();
      });
    }

    function toggleRawSource($event) {
      Calendar.$$resource.post(vm.component.pid + '/' + vm.component.id, "raw").then(function(data) {
        $mdDialog.hide();
        $mdDialog.show({
          parent: angular.element(document.body),
          targetEvent: $event,
          clickOutsideToClose: true,
          escapeToClose: true,
          template: [
            '<md-dialog flex="40" flex-sm="80" flex-xs="100" aria-label="' + l('View Raw Source') + '">',
            '  <md-dialog-content class="md-dialog-content">',
            '    <pre ng-bind-html="data"></pre>',
            '  </md-dialog-content>',
            '  <md-dialog-actions>',
            '    <md-button ng-click="close()">' + l('Close') + '</md-button>',
            '  </md-dialog-actions>',
            '</md-dialog>'
          ].join(''),
          controller: ComponentRawSourceDialogController,
          locals: { data: data }
        });

        /**
         * @ngInject
         */
        ComponentRawSourceDialogController.$inject = ['scope', '$mdDialog', 'data'];
        function ComponentRawSourceDialogController(scope, $mdDialog, data) {
          scope.data = data;
          scope.close = function() {
            $mdDialog.hide();
          };
        }
      });
    }

    function copySelectedComponent(calendar) {
      vm.component.copyTo(calendar).then(function() {
        $mdDialog.hide();
        $rootScope.$emit('calendars:list');
      });
    }

    function moveSelectedComponent(calendar) {
      vm.component.moveTo(calendar).then(function() {
        $mdDialog.hide();
        $rootScope.$emit('calendars:list');
      });
    }
  }

  /**
   * @ngInject
   */
  ComponentEditorController.$inject = ['$rootScope', '$scope', '$log', '$timeout', '$mdDialog', 'sgFocus', 'User', 'CalendarSettings', 'Calendar', 'Component', 'AddressBook', 'Card', 'Alarm', 'stateComponent'];
  function ComponentEditorController($rootScope, $scope, $log, $timeout, $mdDialog, focus, User, CalendarSettings, Calendar, Component, AddressBook, Card, Alarm, stateComponent) {
    var vm = this, component, oldStartDate, oldEndDate, oldDueDate;

    vm.service = Calendar;
    vm.component = stateComponent;
    vm.categories = {};
    vm.showRecurrenceEditor = vm.component.$hasCustomRepeat;
    vm.toggleRecurrenceEditor = toggleRecurrenceEditor;
    vm.recurrenceMonthDaysAreRequired = recurrenceMonthDaysAreRequired;
    vm.showAttendeesEditor = vm.component.attendees && vm.component.attendees.length;
    vm.toggleAttendeesEditor = toggleAttendeesEditor;
    //vm.searchText = null;
    vm.cardFilter = cardFilter;
    vm.addAttendee = addAttendee;
    vm.removeAttendee = removeAttendee;
    vm.addAttachUrl = addAttachUrl;
    vm.priorityLevel = priorityLevel;
    vm.reset = reset;
    vm.cancel = cancel;
    vm.edit = edit;
    vm.save = save;
    vm.attendeeConflictError = false;
    vm.attendeesEditor = {
      days: getDays(),
      hours: getHours()
    };
    vm.addStartDate = addStartDate;
    vm.addDueDate = addDueDate;

    // Synchronize start and end dates
    vm.adjustStartTime = adjustStartTime;
    vm.adjustEndTime = adjustEndTime;
    vm.adjustDueTime = adjustDueTime;

    if (vm.component.start)
      oldStartDate = new Date(vm.component.start.getTime());
    if (vm.component.end)
      oldEndDate = new Date(vm.component.end.getTime());
    if (vm.component.due)
      oldDueDate = new Date(vm.component.due.getTime());

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

    function recurrenceMonthDaysAreRequired() {
      return vm.component &&
        vm.component.repeat.frequency == 'monthly' &&
        vm.component.repeat.month.type == 'bymonthday';
    }

    // Autocomplete cards for attendees
    function cardFilter($query) {
      AddressBook.$filterAll($query);
      return AddressBook.$cards;
    }

    function addAttendee(card) {
      var automaticallyExapand = (!vm.component.attendees || vm.component.attendees.length === 0);
      if (angular.isString(card)) {
        // User pressed "Enter" in search field, adding a non-matching card
        if (card.isValidEmail()) {
          vm.component.addAttendee(new Card({ emails: [{ value: card }] }));
          vm.showAttendeesEditor |= automaticallyExapand;
          vm.searchText = '';
        }
      }
      else {
        vm.component.addAttendee(card);
        vm.showAttendeesEditor |= automaticallyExapand;
      }
    }

    function removeAttendee(attendee, form) {
      vm.component.deleteAttendee(attendee);
      if (vm.component.attendees.length === 0)
        vm.showAttendeesEditor = false;
      form.$setDirty();
    }

    function priorityLevel() {
      if (vm.component && vm.component.priority) {
        if (vm.component.priority > 5)
          return l('low');                   // 6-7-8-9
        else if (vm.component.priority > 4)
          return l('normal');                // 5
        else
          return l('high');                  // 1-2-3-4
      }
    }

    function save(form, options) {
      if (form.$valid) {
        vm.component.$save(options)
          .then(function(data) {
            $rootScope.$emit('calendars:list');
            Alarm.getAlarms();
            $mdDialog.hide();
          }, function(response) {
            if (response.status == CalendarSettings.ConflictHTTPErrorCode &&
                _.isObject(response.data.message))
              vm.attendeeConflictError = response.data.message;
            else
              edit(form);
          });
      }
    }

    function reset(form) {
      vm.component.$reset();
      form.$setPristine();
    }

    function cancel(form) {
      reset(form);
      if (vm.component.isNew) {
        // Cancelling the creation of a component
        vm.component = null;
      }
      $mdDialog.cancel();
    }

    function edit(form) {
      vm.attendeeConflictError = false;
      form.$setPristine();
      form.$setDirty();
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
        hours.push(i.toString());
      }
      return hours;
    }

    function addStartDate() {
      vm.component.$addStartDate();
      oldStartDate = new Date(vm.component.start.getTime());
    }

    function addDueDate() {
      vm.component.$addDueDate();
      oldDueDate = new Date(vm.component.due.getTime());
    }

    function adjustStartTime() {
      if (vm.component.start) {
        // Preserve the delta between the start and end dates
        var delta;
        delta = oldStartDate.valueOf() - vm.component.start.valueOf();
        if (delta !== 0) {
          oldStartDate = new Date(vm.component.start.getTime());
          if (vm.component.type === 'appointment') {
            vm.component.end = new Date(vm.component.start.getTime());
            vm.component.end.addMinutes(vm.component.delta);
            oldEndDate = new Date(vm.component.end.getTime());
          }
          updateFreeBusy();
        }
      }
    }

    function adjustEndTime() {
      if (vm.component.end) {
        // The end date must be after the start date
        var delta = oldEndDate.valueOf() - vm.component.end.valueOf();
        if (delta !== 0) {
          delta = vm.component.start.minutesTo(vm.component.end);
          if (delta < 0)
            vm.component.end = new Date(oldEndDate.getTime());
          else {
            vm.component.delta = delta;
            oldEndDate = new Date(vm.component.end.getTime());
          }
          updateFreeBusy();
        }
      }
    }

    function adjustDueTime() {
      oldDueDate = new Date(vm.component.due.getTime());
    }

    function updateFreeBusy() {
      vm.attendeesEditor.days = getDays();
      vm.component.updateFreeBusy();
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .controller('ComponentController', ComponentController)
    .controller('ComponentEditorController', ComponentEditorController);
})();
