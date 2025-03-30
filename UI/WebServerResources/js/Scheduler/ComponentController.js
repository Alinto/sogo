/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @ngInject
   */
  ComponentController.$inject = ['$rootScope', '$scope', '$q', '$mdDialog', 'sgConstant', 'Preferences', 'Calendar', 'Component', 'AddressBook', 'Account', 'stateComponent'];
  function ComponentController($rootScope, $scope, $q, $mdDialog, sgConstant, Preferences, Calendar, Component, AddressBook, Account, stateComponent) {
    var vm = this, component;

    this.$onInit = function () {
      this.calendarService = Calendar;
      this.service = Component;
      this.component = stateComponent;
      this.isDeleting = false;

      // Put organizer in an array to display it as an mdChip
      this.organizer = [stateComponent.organizer];
    };

    this.close = function () {
      $mdDialog.hide();
    };

    this.changed = function (d) {
      console.log(d);
    };

    this.highPriority = function () {
      return (this.component &&
              this.component.priority &&
              this.component.priority < 5);
    };

    // Autocomplete cards for attendees
    this.cardFilter = function ($query) {
      return AddressBook.$filterAll($query);
    };

    this.newMessageWithAllRecipients = function ($event) {
      var recipients = _.map(this.component.attendees, function(attendee) {
        return attendee.name + " <" + attendee.email + ">";
      });
      _newMessage($event, recipients);
    };

    this.newMessageWithRecipient = function ($event, name, email) {
      _newMessage($event, [name + " <" + email + ">"]);
    };

    function _newMessage($event, recipients) {
      Account.$findAll().then(function(accounts) {
        var account = _.find(accounts, function(o) {
          if (o.id === 0)
            return o;
        }),
            onCompleteDeferred = $q.defer();

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
              onComplete: function (scope, element) {
                return onCompleteDeferred.resolve(element);
              },
              locals: {
                stateParent: $scope,
                stateAccount: account,
                stateMessage: message,
                onCompletePromise: function () {
                  return onCompleteDeferred.promise;
                }
              }
            });
          });
        });
      });

      $event.preventDefault();
      $event.stopPropagation();
    }

    this.edit = function () {
      var type = (this.component.component == 'vevent')? 'Appointment':'Task';
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
    };

    this.editAllOccurrences = function () {
      component = Calendar.$get(this.component.pid).$getComponent(this.component.id);
      component.$futureComponentData.then(function() {
        vm.component = component;
        vm.edit();
      });
    };

    this.reply = function (component) {
      var c = component || this.component;

      c.$reply().then(function() {
        $rootScope.$emit('calendars:list');
        Preferences.getAlarms();
        $mdDialog.hide();
      });
    };

    this.replyAllOccurrences = function () {
      // Retrieve master event
      component = Calendar.$get(this.component.pid).$getComponent(this.component.id);
      component.$futureComponentData.then(function() {
        // Propagate the participant status, classification and alarm to the master event
        component.reply = vm.component.reply;
        component.delegatedTo = vm.component.delegatedTo;
        component.$hasAlarm = vm.component.$hasAlarm;
        component.classification = vm.component.classification;
        component.alarm = vm.component.alarm;
        // Send reply to the server
        vm.reply(component);
      });
    };

    this.deleteOccurrence = function () {
      if (!this.isDeleting) {
        this.isDeleting = true;
        this.component.remove(true).then(function() {
          $rootScope.$emit('calendars:list');
          $mdDialog.hide();
          vm.isDeleting = false;
        });
      }
    };

    this.deleteAllOccurrences = function () {
      if (!this.isDeleting) {
        this.isDeleting = true;
        this.component.remove().then(function () {
          $rootScope.$emit('calendars:list');
          $mdDialog.hide();
          vm.isDeleting = false;
        });
      }
      
    };

    this.toggleRawSource = function ($event) {
      Calendar.$$resource.post(this.component.pid + '/' + this.component.id, "raw").then(function(data) {
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
    };

    this.copySelectedComponent = function (calendar) {
      this.component.copyTo(calendar).then(function() {
        $mdDialog.hide();
        $rootScope.$emit('calendars:list');
      });
    };

    this.moveSelectedComponent = function (calendar) {
      this.component.moveTo(calendar).then(function() {
        $mdDialog.hide();
        $rootScope.$emit('calendars:list');
      });
    };
  }

  /**
   * @ngInject
   */
  ComponentEditorController.$inject = ['$rootScope', '$scope', '$q', '$log', '$timeout', '$window', '$element', '$mdDialog', '$mdToast', 'sgFocus', 'User', 'CalendarSettings', 'Calendar', 'Component', 'Attendees', 'AddressBook', 'Card', 'Preferences', 'stateComponent'];
  function ComponentEditorController($rootScope, $scope, $q, $log, $timeout, $window, $element, $mdDialog, $mdToast, focus, User, CalendarSettings, Calendar, Component, Attendees, AddressBook, Card, Preferences, stateComponent) {
    var vm = this, component, oldStartDate, oldEndDate, oldDueDate, dayStartTime, dayEndTime;

    this.$onInit = function () {
      this.service = Calendar;
      this.component = stateComponent;
      this.categories = {};
      this.showRecurrenceEditor = this.component.$hasCustomRepeat;
      this.showAttendeesEditor = this.component.attendees && this.component.attendees.length;
      this.isFullscreen = (typeof screen.orientation !== 'undefined' && screen.orientation && 'portrait-primary' == screen.orientation.type);
      this.originalModalCancel = $mdDialog.cancel;
      this.preferences = Preferences;

      if (this.component.type == 'appointment') {
        this.component.initAttendees();
        this.attendeeConflictError = false;
        this.attendeesEditor = {
          days: this.component.$attendees.$days,
          hours: getHours(),
          containerElement: $element[0].querySelector('#freebusy')
        };
      }

      if (this.component.start) {
        oldStartDate = new Date(this.component.start.getTime());
        this.startTime = new Date(this.component.start.getTime());
      }
      if (this.component.end) {
        oldEndDate = new Date(this.component.end.getTime());
        this.endTime = new Date(this.component.end.getTime());
      }
      if (this.component.due) {
        oldDueDate = new Date(this.component.due.getTime());
        this.dueTime = new Date(this.component.due.getTime());
      }

      if (this.component.attendees)
        $timeout(scrollToStart);

      dayStartTime = parseInt(Preferences.defaults.SOGoDayStartTime);
      dayEndTime = parseInt(Preferences.defaults.SOGoDayEndTime);

      this.originalHash = this.hash(this.component);
      $mdDialog.cancel = function () {
        if (vm.originalHash === vm.hash(vm.component)  || confirm(l('You have modified data unsaved. Do you want to close popup and loose data ?'))) {
          $mdDialog.cancel = vm.originalModalCancel;
          return vm.originalModalCancel();
        }
      };
    };

    this.hash = function (data) {
      var hash = 0, i, chr, edata, json;
      edata = {
        repeat: data.repeat,
        pid: data.pid,
        destinationCalendar: data.destinationCalendar,
        classification: data.classification,
        categories: data.categories,
        alarm: data.alarm,
        summary: data.summary,
        status: data.status,
        organizer: data.organizer,
        location: data.location,
        isAllDay: data.isAllDay,
        comment: data.comment,
        attendees: data.attendees
      };
      if (edata.organizer && edata.organizer.freebusy) {
        edata.organizer.freebusy = {};
      }
      if (edata.attendees) {
        for (i = 0; i < edata.attendees.length; i++) {
          edata.attendees[i].freebusy = {};
        }
      }
      json = JSON.stringify(edata);

      if (json.length === 0) return hash;
      for (i = 0; i < json.length; i++) {
        chr = json.charCodeAt(i);
        hash = ((hash << 5) - hash) + chr;
        hash |= 0;
      }

      return hash;
    }

    this.addAttachUrl = function () {
      var i = this.component.addAttachUrl('');
      focus('attachUrl_' + i);
    };

    this.addJitsiUrl = function () {
      var jitsiBaseUrl = "https://meet.jit.si";
      var jitsiRoomPrefix = "SOGo_meeting/";
      if(this.preferences.defaults && this.preferences.defaults.SOGoCalendarJitsiBaseUrl)
        jitsiBaseUrl = this.preferences.defaults.SOGoCalendarJitsiBaseUrl;
      if(this.preferences.defaults && this.preferences.defaults.SOGoCalendarJitsiRoomPrefix)
        jitsiRoomPrefix = this.preferences.defaults.SOGoCalendarJitsiRoomPrefix;
      var jitsiUrl = jitsiBaseUrl + "/" + jitsiRoomPrefix + crypto.randomUUID();
      var i = this.component.addAttachUrl(jitsiUrl);
      focus('attachUrl_' + i);
    };

    this.toggleRecurrenceEditor = function () {
      this.showRecurrenceEditor = !this.showRecurrenceEditor;
      this.component.$hasCustomRepeat = this.showRecurrenceEditor;
    };

    this.toggleAttendeesEditor = function () {
      this.showAttendeesEditor = !this.showAttendeesEditor;
    };

    this.recurrenceMonthDaysAreRequired = function () {
      return this.component &&
        this.component.repeat.frequency == 'monthly' &&
        this.component.repeat.month.type == 'bymonthday';
    };

    this.changeFrequency = function () {
      if (this.component.repeat.frequency == 'custom')
        this.showRecurrenceEditor = true;
    };

    this.destinationCalendars = function () {
      if (this.component && this.component.isNew)
        // New component, return all writable calendars
        return Calendar.$findAll(null, true);
      else if (this.component && this.component.isErasable)
        // Movable component, return all writable calendars including current one
        return Calendar.$findAll(null, true, this.component.pid);
      else
        // Component can't be moved
        return [Calendar.$get(this.component.pid)];
    };

    this.changeCalendar = function () {
      var updateRequired = (this.component.attendees && this.component.attendees.length > 0);
      if (updateRequired)
        this.component.$attendees.initOrganizer(Calendar.$get(this.component.destinationCalendar));
    };

    this.toggleFullscreen = function() {
      vm.isFullscreen = !vm.isFullscreen;
    }

    // Autocomplete cards for attendees
    this.cardFilter = function ($query) {
      return AddressBook.$filterAll($query);
    };

    this.addAttendee = function (card, partial) {
      var initOrganizer = (!this.component.attendees || this.component.attendees.length === 0),
          destinationCalendar = Calendar.$get(this.component.destinationCalendar),
          options = initOrganizer? { organizerCalendar: destinationCalendar } : {},
          promises = [];
      var i, address;
      if (partial) options.partial = partial;

      function createCard(str) {
        var match = str.match(String.emailRE),
            email = match[0],
            name = str.replace(new RegExp(" *<?" + email + ">? *"), '');
        vm.showAttendeesEditor |= initOrganizer;
        vm.searchText = '';
        return vm.cardFilter(email).then(function (cards) {
          if (cards.length) {
            return cards[0];
          } else {
            return new Card({ c_cn: _.trim(name, ' "'), emails: [{ value: email }] });
          }
        }).catch(function (err) {
          // Server error
          return new Card({ c_cn: _.trim(name, ' "'), emails: [{ value: email }] });
        });
      }

      function addCard(newCard) {
        if (!vm.component.$attendees.hasAttendee(newCard))
          return vm.component.$attendees.add(newCard, options);
      }

      if (angular.isString(card)) {
        // User pressed "Enter" in search field, adding a non-matching card
        // Examples that are handled:
        //   Smith, John <john@smith.com>
        //   <john@appleseed.com>;<foo@bar.com>
        //   foo@bar.com abc@xyz.com
        address = '';
        for (i = 0; i < card.length; i++) {
          if ((card.charCodeAt(i) ==  9 ||   // tab
               card.charCodeAt(i) == 32 ||   // space
               card.charCodeAt(i) == 44 ||   // ,
               card.charCodeAt(i) == 59) &&  // ;
              String.emailRE.test(address)) {
            promises.push(createCard(address).then(addCard));
            address = '';
          }
          else {
            address += card.charAt(i);
          }
        }
        if (address && String.emailRE.test(address)) {
          promises.push(createCard(address).then(addCard));
        }
      }
      else if (angular.isDefined(card)) {
        if (!this.component.$attendees.hasAttendee(card))
          promises.push(this.component.$attendees.add(card, options));
        this.showAttendeesEditor |= initOrganizer;
      }

      if (_.has(this.component, '$attendees'))
        $timeout(scrollToStart);

      return $q.all(promises);
    };

    function scrollToStart() {
      var dayElement, scrollLeft;
      if (!vm.attendeesEditor.containerElement) {
        vm.attendeesEditor.containerElement = $element[0].querySelector('#freebusy');
      }
      dayElement = $element[0].querySelector('#freebusy_day_' + vm.component.start.getDayString());
      if (vm.attendeesEditor.containerElement && dayElement) {
        scrollLeft = dayElement.offsetLeft - vm.attendeesEditor.containerElement.offsetLeft;
        vm.attendeesEditor.containerElement.scrollLeft = scrollLeft;
      }
    }

    this.expandAttendee = function (attendee) {
      if (attendee.members.length > 0) {
        this.component.$attendees.remove(attendee);
        _.forEach(attendee.members, function (member) {
          vm.component.$attendees.add(member);
        });
      }
    };

    this.removeAttendee = function (attendee, form) {
      this.component.$attendees.remove(attendee);
      if (this.component.$attendees.getLength() === 0) {
        this.showAttendeesEditor = false;
        this.component.$attendees.remove(this.component.organizer);
      }
      form.$setDirty();
    };

    this.defaultIconForAttendee = function (attendee) {
      if (attendee.isGroup) {
        return 'group';
      } else if (attendee.isResource) {
        return 'meeting_room';
      } else {
        return 'person';
      }
    };

    this.nextSlot = function () {
      findSlot(1);
    };

    this.previousSlot = function () {
      findSlot(-1);
    };

    function findSlot(direction) {
      vm.adjustStartTime();
      vm.adjustEndTime();
      vm.component.$attendees.findSlot(direction).then(function () {
        vm.startTime = new Date(vm.component.start.getTime());
        vm.endTime = new Date(vm.component.end.getTime());
      }).catch(function (err) {
        vm.component.start = new Date(vm.component.start.getTime() + 1); // trigger update in sgFreeBusy
        $timeout(scrollToStart);
        $mdToast.show({
          template: [
            '<md-toast>',
            '  <div class="md-toast-content">',
            '    <md-icon class="md-warn md-hue-1">error_outline</md-icon>',
            '    <span flex>' + err + '</span>',
            '  </div>',
            '</md-toast>'
          ].join(''),
          hideDelay: 5000,
          position: sgConstant.toastPosition
        });
      }).finally(function () {
        $timeout(scrollToStart);
      });
    }

    this.priorityLevel = function () {
      if (this.component && this.component.priority) {
        if (this.component.priority > 5)
          return l('low');                   // 6-7-8-9
        else if (this.component.priority > 4)
          return l('normal');                // 5
        else
          return l('high');                  // 1-2-3-4
      }
    };

    this.changeAlarmRelation = function (form) {
      if (form.alarmRelation) {
        if (this.component.type == 'task' && this.component.$hasAlarm &&
            (this.component.start || this.component.due) &&
            ((!this.component.start && this.component.alarm.relation == 'START') ||
             (!this.component.due   && this.component.alarm.relation == 'END'))) {
          form.alarmRelation.$setValidity('alarm', false);
        }
        else {
          form.alarmRelation.$setValidity('alarm', true);
        }
      }
    };

    this.onAlarmChange = function (form) {
      if (this.component.type !== 'task') {
        return;
      }
      if (!this.component.start && this.component.alarm.relation == 'START') {
        this.component.alarm.relation = 'END';
      } else if (!this.component.due && this.component.alarm.relation == 'END') {
        this.component.alarm.relation = 'START';
      }
      this.changeAlarmRelation(form);
    };

    this.save = function (form, options) {
      this.adjustStartTime();
      this.adjustEndTime();
      this.changeAlarmRelation(form);
      this.addAttendee(this.searchText).then(function () {
        vm.adjustStartTime();
        if (form.$valid) {
          vm.component.$save(options)
            .then(function(data) {
              $rootScope.$emit('calendars:list');
              Preferences.getAlarms();
              $mdDialog.cancel = vm.originalModalCancel;
              $mdDialog.hide();
            }, function(response) {
              vm.allowResubmit(form);

              if (response.status == CalendarSettings.ConflictHTTPErrorCode) {
                vm.attendeeConflictError = _.isObject(response.data.message) ? response.data.message : { reject: response.data.message };
              } else {
                vm.edit(form);
              }
            });
        }
      });
    };

    this.reset = function (form) {
      this.component.$reset();
      form.$setPristine();
    };

    this.cancel = function (form) {
      if (vm.originalHash === vm.hash(vm.component) || confirm(l('You have modified data unsaved. Do you want to close popup and loose data ?'))) {
        $mdDialog.cancel = vm.originalModalCancel;
      } else {
        return;
      }

      $mdDialog.hide();
      
      this.reset(form);
      if (this.component.isNew) {
        // Cancelling the creation of a component
        this.component = null;
      }
      $mdDialog.hide();
    };

    this.edit = function (form) {
      this.attendeeConflictError = false;
      form.$setPristine();
      form.$setDirty();
    };

    this.allowResubmit = function (form) {
      form.$setPristine();
      form.$setDirty();
    };

    function getHours() {
      var hours = [];
      for (var i = 0; i <= 23; i++) {
        hours.push(i.toString());
      }
      return hours;
    }

    this.addStartDate = function (form) {
      this.component.$addStartDate();
      oldStartDate = new Date(this.component.start.getTime());
      this.startTime = new Date(this.component.start.getTime());
      if (!this.component.due) {
        this.component.alarm.relation = 'START';
      }
      this.changeAlarmRelation(form);
      form.$setDirty();
    };

    this.removeStartDate = function (form) {
      this.component.$deleteStartDate();
      if (this.component.due) {
        this.component.alarm.relation = 'END';
      }
      this.changeAlarmRelation(form);
      form.$setDirty();
    };

    this.addDueDate = function (form) {
      this.component.$addDueDate();
      oldDueDate = new Date(this.component.due.getTime());
      this.dueTime = new Date(this.component.due.getTime());
      if (!this.component.start) {
        this.component.alarm.relation = 'END';
      }
      this.changeAlarmRelation(form);
      form.$setDirty();
    };

    this.removeDueDate = function (form) {
      this.component.$deleteDueDate();
      if (this.component.start) {
        this.component.alarm.relation = 'START';
      }
      this.changeAlarmRelation(form);
      form.$setDirty();
    };

    this.adjustAllDay = function () {
      if (!this.component.isAllDay) {
        this.component.start.setHours(dayStartTime);
        this.component.start.setMinutes(0);
        this.startTime = new Date(this.component.start.getTime());
        oldStartDate = new Date(this.component.start.getTime());
        this.component.end.setHours(dayEndTime);
        this.component.end.setMinutes(0);
        this.endTime = new Date(this.component.end.getTime());
        oldEndDate = new Date(this.component.end.getTime());
        this.component.delta = this.component.start.minutesTo(this.component.end);
      }
      this.component.$attendees.updateFreeBusyCoverage();
    };

    this.adjustStartTime = function () {
      var delta;
      if (this.component.start && this.startTime) {
        // Update the component start date
        this.component.start.setHours(this.startTime.getHours());
        this.component.start.setMinutes(this.startTime.getMinutes());
        // Preserve the delta between the start and end dates
        delta = oldStartDate.valueOf() - this.component.start.valueOf();
        if (delta !== 0) {
          oldStartDate = new Date(this.component.start.getTime());
          if (this.component.type === 'appointment') {
            this.component.end = new Date(this.component.start.getTime());
            this.component.end.addMinutes(this.component.delta);
            this.endTime = new Date(this.component.end.getTime());
            oldEndDate = new Date(this.component.end.getTime());
          }
          updateFreeBusy();
        }
      }
    };

    this.adjustEndTime = function () {
      var delta;
      if (this.component.end && this.endTime) {
        // Update the component end date
        this.component.end.setHours(this.endTime.getHours());
        this.component.end.setMinutes(this.endTime.getMinutes());
        // The end date must be after the start date
        delta = oldEndDate.valueOf() - this.component.end.valueOf();
        if (delta !== 0) {
          if (this.startTime) {
            // Update the component start date
            this.component.start.setHours(this.startTime.getHours());
            this.component.start.setMinutes(this.startTime.getMinutes());
          }
          delta = this.component.start.minutesTo(this.component.end);
          if (delta < 0) {
            this.component.end = new Date(oldEndDate.getTime());
            this.endTime = new Date(this.component.end.getTime());
          }
          else {
            this.component.delta = delta;
            oldEndDate = new Date(this.component.end.getTime());
          }
          updateFreeBusy();
        }
      }
    };

    this.adjustDueTime = function () {
      if (this.component.due && this.dueTime) {
        this.component.due.setHours(this.dueTime.getHours());
        this.component.due.setMinutes(this.dueTime.getMinutes());
        oldDueDate = new Date(this.component.due.getTime());
      }
    };

    function updateFreeBusy() {
      if (_.has(vm.component, '$attendees')) {
        vm.component.$attendees.updateFreeBusyCoverage();
        vm.component.$attendees.updateFreeBusy();
        $timeout(scrollToStart);
      }
    }
  }

  angular
    .module('SOGo.SchedulerUI')
    .controller('ComponentController', ComponentController)
    .controller('ComponentEditorController', ComponentEditorController);
})();
