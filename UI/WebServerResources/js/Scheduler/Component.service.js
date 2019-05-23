/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Component
   * @constructor
   * @param {object} futureComponentData - either an object literal or a promise
   */
  function Component(futureComponentData) {
    // Data is immediately available
    if (typeof futureComponentData.then !== 'function') {
      this.init(futureComponentData);
      if (this.pid && !this.id) {
        // Prepare for the creation of a new component;
        // Get UID from the server.
        var newComponentData = Component.$$resource.newguid(this.pid);
        this.$unwrap(newComponentData);
        this.isNew = true;
      }
    }
    else {
      // The promise will be unwrapped first
      this.$unwrap(futureComponentData);
    }
  }

  /**
   * @memberof Component
   * @desc The factory we'll use to register with Angular
   * @returns the Component constructor
   */
  Component.$factory = ['$q', '$timeout', '$log', '$rootScope', 'sgSettings', 'sgComponent_STATUS', 'Attendees', 'Preferences', 'User', 'Card', 'Resource', function($q, $timeout, $log, $rootScope, Settings, Component_STATUS, Attendees, Preferences, User, Card, Resource) {
    angular.extend(Component, {
      STATUS: Component_STATUS,
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $rootScope: $rootScope,
      $settings: Settings,
      $User: User,
      $Preferences: Preferences,
      $Attendees: Attendees,
      $Card: Card,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Calendar', Settings.activeUser()),
      timeFormat: "%H:%M",
      // Filter parameters common to events and tasks
      $query: { value: '', search: 'title_Category_Location' },
      // Filter paramaters specific to events
      $queryEvents: { sort: 'start', asc: 1, filterpopup: 'view_next7' },
      // Filter parameters specific to tasks
      $queryTasks: { sort: 'status', asc: 1, filterpopup: 'view_incomplete' },
      $refreshTimeout: null,
      $ghost: {}
    });
    // Initialize filter parameters from user's settings
    if (Preferences.settings.Calendar.EventsFilterState)
      Component.$queryEvents.filterpopup = Preferences.settings.Calendar.EventsFilterState;
    if (Preferences.settings.Calendar.TasksFilterState)
      Component.$queryTasks.filterpopup = Preferences.settings.Calendar.TasksFilterState;
    if (Preferences.settings.Calendar.EventsSortingState) {
      Component.$queryEvents.sort = Preferences.settings.Calendar.EventsSortingState[0];
      Component.$queryEvents.asc = parseInt(Preferences.settings.Calendar.EventsSortingState[1]);
    }
    if (Preferences.settings.Calendar.TasksSortingState) {
      Component.$queryTasks.sort = Preferences.settings.Calendar.TasksSortingState[0];
      Component.$queryTasks.asc = parseInt(Preferences.settings.Calendar.TasksSortingState[1]);
    }
    Component.$queryTasks.show_completed = parseInt(Preferences.settings.ShowCompletedTasks);
    // Initialize categories from user's defaults
    Component.$categories = Preferences.defaults.SOGoCalendarCategoriesColors;
    // Initialize time format from user's defaults
    if (Preferences.defaults.SOGoTimeFormat) {
      Component.timeFormat = Preferences.defaults.SOGoTimeFormat;
    }

    return Component; // return constructor
  }];

  /**
   * @module SOGo.SchedulerUI
   * @desc Factory registration of Component in Angular module.
   */
  try {
    angular.module('SOGo.SchedulerUI');
  }
  catch(e) {
    angular.module('SOGo.SchedulerUI', ['SOGo.Common']);
  }
  angular.module('SOGo.SchedulerUI')
    .constant('sgComponent_STATUS', {
      NOT_LOADED:      0,
      DELAYED_LOADING: 1,
      LOADING:         2,
      LOADED:          3,
      DELAYED_MS:      300
    })
    .factory('Component', Component.$factory);

  /**
   * @function $selectedCount
   * @memberof Component
   * @desc Return the number of events or tasks selected by the user.
   * @returns the number of selected events or tasks
   */
  Component.$selectedCount = function() {
    var count;

    count = 0;
    if (Component.$events) {
      count += (_.filter(Component.$events, function(event) { return event.selected; })).length;
    }
    if (Component.$tasks) {
      count += (_.filter(Component.$tasks, function(task) { return task.selected; })).length;
    }
    return count;
  };

  /**
   * @function $startRefreshTimeout
   * @memberof Component
   * @desc Starts the refresh timeout for the current selected list (events or tasks) and
   * current view.
   */
  Component.$startRefreshTimeout = function(type) {
    if (Component.$refreshTimeout)
      Component.$timeout.cancel(Component.$refreshTimeout);

    // Restart the refresh timer, if needed
    var refreshViewCheck = Component.$Preferences.defaults.SOGoRefreshViewCheck;
    if (refreshViewCheck && refreshViewCheck != 'manually') {
      var f = angular.bind(Component.$rootScope, Component.$rootScope.$emit, 'calendars:list');
      Component.$refreshTimeout = Component.$timeout(f, refreshViewCheck.timeInterval()*1000);
    }
  };

  /**
   * @function $isLoading
   * @memberof Component
   * @returns true if the components list is still being retrieved from server after a specific delay
   * @see sgMessage_STATUS
   */
  Component.$isLoading = function() {
    return Component.$loaded == Component.STATUS.LOADING;
  };

  /**
   * @function $filter
   * @memberof Component
   * @desc Search for components matching some criterias
   * @param {string} type - either 'events' or 'tasks'
   * @param {object} [options] - additional options to the query
   * @returns a collection of Components instances
   */
  Component.$filter = function(type, options) {
    var _this = this,
        now = new Date(),
        day = now.getDate(),
        month = now.getMonth() + 1,
        year = now.getFullYear(),
        queryKey = '$query' + type.capitalize(),
        params = {
          day: '' + year + (month < 10?'0':'') + month + (day < 10?'0':'') + day,
        },
        futureComponentData,
        dirty = false,
        otherType;

    Component.$startRefreshTimeout(type);

    angular.extend(this.$query, params);

    if (options) {
      _.forEach(_.keys(options), function(key) {
        // Query parameters common to events and tasks are compared
        dirty |= (_this.$query[key] && options[key] != Component.$query[key]);
        if (key == 'reload' && options[key])
          dirty = true;
        // Update either the common parameters or the type-specific parameters
        else if (angular.isDefined(_this.$query[key]))
          _this.$query[key] = options[key];
        else
          _this[queryKey][key] = options[key];
      });
    }

    // Perform query with both common and type-specific parameters
    futureComponentData = this.$$resource.fetch(null, type + 'list',
                                                angular.extend(this[queryKey], this.$query));

    // Invalidate cached results of other type if $query has changed
    if (dirty) {
      otherType = (type == 'tasks')? '$events' : '$tasks';
      delete Component[otherType];
      Component.$log.debug('force reload of ' + otherType);
    }

    return this.$unwrapCollection(type, futureComponentData);
  };

  /**
   * @function $find
   * @desc Fetch a component from a specific calendar.
   * @param {string} calendarId - the calendar ID
   * @param {string} componentId - the component ID
   * @param {string} [occurrenceId] - the component ID
   * @see {@link Calendar.$getComponent}
   */
  Component.$find = function(calendarId, componentId, occurrenceId) {
    var futureComponentData, path = [calendarId, encodeURIComponent(componentId)];

    if (occurrenceId)
      path.push(occurrenceId);

    futureComponentData = this.$$resource.fetch(path.join('/'), 'view');

    return new Component(futureComponentData);
  };

  /**
   * @function filterCategories
   * @desc Search for categories matching some criterias
   * @param {string} search - the search string to match
   * @returns a collection of strings
   */
  Component.filterCategories = function(query) {
    var re = new RegExp(query, 'i');
    return _.filter(_.keys(Component.$categories), function(category) {
      return category.search(re) != -1;
    });
  };

  /**
   * @function saveSelectedList
   * @desc Save to the user's settings the currently selected list.
   * @param {string} componentType - either "events" or "tasks"
   * @returns a promise of the HTTP operation
   */
  Component.saveSelectedList = function(componentType) {
    return this.$$resource.post(null, 'saveSelectedList', { list: componentType + 'ListView' });
  };

  /**
   * @function $eventsBlocksForView
   * @desc Events blocks for a specific week
   * @param {string} view - Either 'day' or 'week'
   * @param {Date} type - Date of any day of the desired period
   * @returns a promise of a collection of objects describing the events blocks
   */
  Component.$eventsBlocksForView = function(view, date) {
    var firstDayOfWeek, viewAction, startDate, endDate, params;

    firstDayOfWeek = Component.$Preferences.defaults.SOGoFirstDayOfWeek;
    if (view == 'day') {
      viewAction = 'dayView';
      startDate = endDate = date;
    }
    else if (view == 'multicolumnday') {
      viewAction = 'multicolumndayView';
      startDate = endDate = date;
    }
    else if (view == 'week') {
      viewAction = 'weekView';
      startDate = date.beginOfWeek(firstDayOfWeek);
      endDate = new Date();
      endDate.setTime(startDate.getTime());
      endDate.addDays(6);
    }
    else if (view == 'month') {
      viewAction = 'monthView';
      startDate = date;
      startDate.setDate(1);
      startDate = startDate.beginOfWeek(firstDayOfWeek);
      endDate = new Date();
      endDate.setTime(date.getTime());
      endDate.setMonth(endDate.getMonth() + 1);
      endDate.addDays(-1);
      endDate = endDate.endOfWeek(firstDayOfWeek);
    }
    return this.$eventsBlocks(viewAction, startDate, endDate);
  };

  /**
   * @function $eventsBlocks
   * @desc Events blocks for a specific view and period
   * @param {string} view - Either 'day', 'multicolumnday', 'week' or 'month'
   * @param {Date} startDate - period's start date
   * @param {Date} endDate - period's end date
   * @returns a promise of a collection of objects describing the events blocks
   */
  Component.$eventsBlocks = function(view, startDate, endDate) {
    var params, futureComponentData, i, j, dayDates = [], dayNumbers = [],
        deferred = Component.$q.defer();

    params = { view: view.toLowerCase(), sd: startDate.getDayString(), ed: endDate.getDayString() };
    futureComponentData = this.$$resource.fetch(null, 'eventsblocks', params);
    futureComponentData.then(function(views) {
      var reduceComponent, associateComponent;

      reduceComponent = function(objects, eventData, i) {
        var componentData = _.zipObject(this.eventsFields, eventData),
            start = new Date(componentData.c_startdate * 1000),
            component;
        componentData.hour = start.getHourString();
        componentData.blocks = [];
        component = new Component(componentData);
        objects.push(component);
        return objects;
      };

      associateComponent = function(block) {
        this[block.nbr].blocks.push(block); // Associate block to component
        block.component = this[block.nbr];  // Associate component to block
        block.isFirst = (this[block.nbr].blocks.length == 1);
      };

      Component.$views = [];
      Component.$timeout(function() {
        _.forEach(views, function(data, viewIndex) {
          var components = [], blocks = {}, allDayBlocks = {}, viewData;

          // Change some attributes names
          data.eventsFields.splice(_.indexOf(data.eventsFields, 'c_folder'),        1, 'pid');
          data.eventsFields.splice(_.indexOf(data.eventsFields, 'c_name'),          1, 'id');
          data.eventsFields.splice(_.indexOf(data.eventsFields, 'c_recurrence_id'), 1, 'occurrenceId');
          data.eventsFields.splice(_.indexOf(data.eventsFields, 'c_title'),         1, 'summary');

          // Instantiate Component objects
          _.reduce(data.events, _.bind(reduceComponent, data), components);

          // Associate Component objects to blocks positions
          _.forEach(_.flatten(data.blocks), _.bind(associateComponent, components));

          // Associate Component objects to all-day blocks positions
          _.forEach(_.flatten(data.allDayBlocks), _.bind(associateComponent, components));

          // Build array of dates
          if (dayDates.length === 0) {
            dayDates = _.flatMap(data.days, 'date');
            dayNumbers = _.flatMap(data.days, 'number');
          }

          // Convert array of blocks to an object literal with date strings as keys
          for (i = 0; i < data.blocks.length; i++) {
            for (j = 0; j < data.blocks[i].length; j++) {
              data.blocks[i][j].dayIndex = i + (viewIndex * data.blocks.length);
              data.blocks[i][j].dayNumber = dayNumbers[i];
            }
            blocks[dayDates[i]] = data.blocks[i];
          }

          // Convert array of all-day blocks to object with days as keys
          for (i = 0; i < data.allDayBlocks.length; i++) {
            for (j = 0; j < data.allDayBlocks[i].length; j++) {
              data.allDayBlocks[i][j].dayIndex = i + (viewIndex * data.allDayBlocks.length);
              data.allDayBlocks[i][j].dayNumber = dayNumbers[i];
            }
            allDayBlocks[dayDates[i]] = data.allDayBlocks[i];
          }

          // "blocks" is now an object literal with the following structure:
          // { day: [
          //    { start: number,
          //      length: number,
          //      siblings: number,
          //      realSiblings: number,
          //      position: number,
          //      nbr: number,
          //      component: Component },
          //    .. ],
          //  .. }
          //
          // Where day is a string with format YYYYMMDD

          Component.$log.debug('blocks ready (' + _.flatten(data.blocks).length + ')');
          Component.$log.debug('all day blocks ready (' + _.flatten(data.allDayBlocks).length + ')');

          // Save the blocks to the object model
          viewData = { blocks: blocks, allDayBlocks: allDayBlocks };
          if (data.id && data.calendarName) {
            // The multicolumnday view also includes calendar information
            viewData.id = data.id;
            viewData.calendarName = data.calendarName;
          }
          Component.$views.push(viewData);
        });

        deferred.resolve(Component.$views);
      });
    }, deferred.reject);

    return deferred.promise;
  };

  /**
   * @function $unwrapCollection
   * @desc Unwrap a promise and instanciate new Component objects using received data.
   * @param {string} type - either 'events' or 'tasks'
   * @param {promise} futureComponentData - a promise of the components' metadata
   * @returns a promise of the HTTP operation
   */
  Component.$unwrapCollection = function(type, futureComponentData) {
    var _this = this,
        components = [];

    // Components list is not loaded yet
    Component.$loaded = Component.STATUS.DELAYED_LOADING;
    Component.$timeout(function() {
      if (Component.$loaded != Component.STATUS.LOADED)
        Component.$loaded = Component.STATUS.LOADING;
    }, Component.STATUS.DELAYED_MS);

    return futureComponentData.then(function(data) {
      return Component.$timeout(function() {
        var fields = _.invokeMap(data.fields, 'toLowerCase');
          fields.splice(_.indexOf(fields, 'c_folder'), 1, 'pid');
          fields.splice(_.indexOf(fields, 'c_name'), 1, 'id');
          fields.splice(_.indexOf(fields, 'c_recurrence_id'), 1, 'occurrenceId');

        // Instanciate Component objects

        if (type == 'events') {
          _.forEach(data[type], function(monthData, month) {
            _.forEach(monthData.days, function(dayData, day) {
              _.forEach(dayData.events, function(componentData, i) {
                var data = _.zipObject(fields, componentData), component;
                component = new Component(data);
                dayData.events[i] = component;
              });
            });
          });
          components = data[type];
        }
        else if (type == 'tasks') {
          _.reduce(data[type], function(components, componentData, i) {
            var data = _.zipObject(fields, componentData), component;
            component = new Component(data);
            components.push(component);
            return components;
          }, components);
        }

        Component.$log.debug('list of ' + type + ' ready (' + components.length + ')');

        // Save the list of components to the object model
        Component['$' + type] = components;

        Component.$loaded = Component.STATUS.LOADED;

        return components;
      });
    });
  };

  /**
   * @function $resetGhost
   * @desc Prepare the ghost object for the next drag by resetting appropriate attributes
   */
  Component.$resetGhost = function() {
    this.$ghost.pointerHandler = null;
    this.$ghost.component = null;
    this.$ghost.startHour = null;
    this.$ghost.endHour = null;
  };

  /**
   * @function $parseDate
   * @desc Parse a date string with format YYYY-MM-DDTHH:MM
   * @param {string} dateString - the string representing the date
   * @param {object} [options] - additional options (use {no_time: true} to ignore the time)
   * @returns a date object
   */
  Component.$parseDate = function(dateString, options) {
    var date, time;

    date = dateString.substring(0,10).split('-');

    if (options && options.no_time)
      return new Date(parseInt(date[0]), parseInt(date[1]) - 1, parseInt(date[2]));

    time = dateString.substring(11,16).split(':');

    return new Date(parseInt(date[0]), parseInt(date[1]) - 1, parseInt(date[2]),
                    parseInt(time[0]), parseInt(time[1]), 0, 0);
    };

  /**
   * @function init
   * @memberof Component.prototype
   * @desc Extend instance with required attributes and new data.
   * @param {object} data - attributes of component
   */
  Component.prototype.init = function(data) {
    var _this = this;

    this.categories = [];
    this.repeat = {};
    this.alarm = { action: 'display', quantity: 5, unit: 'MINUTES', reference: 'BEFORE', relation: 'START' };
    this.status = 'not-specified';
    this.delta = 60;
    angular.extend(this, data);

    if (this.component == 'vevent')
      this.type = 'appointment';
    else if (this.component == 'vtodo')
      this.type = 'task';

    if (this.startDate) {
      if (angular.isString(this.startDate))
        // Ex: 2015-10-25T22:34:51+00:00
        this.start = Component.$parseDate(this.startDate);
      else
        // Date object
        this.start = this.startDate;
    }
    else if (this.type == 'appointment') {
      this.start = new Date();
      this.start.setMinutes(Math.round(this.start.getMinutes()/15)*15);
    }

    if (this.endDate) {
      this.end = Component.$parseDate(this.endDate);
      this.delta = this.start.minutesTo(this.end);
    }
    else if (this.type == 'appointment') {
      this.setDelta(this.delta);
    }

    if (this.dueDate)
      this.due = Component.$parseDate(this.dueDate);

    if (this.completedDate)
      this.completed = Component.$parseDate(this.completedDate);
    else if (this.type == 'task')
      this.completed = new Date();

    if (this.c_category) {
      // c_category is only defined in list mode (when calling $filter)
      // Filter out categories for which there's no associated color
      this.categories = _.invokeMap(_.filter(this.c_category, function(name) {
        return Component.$Preferences.defaults.SOGoCalendarCategoriesColors[name];
      }), 'asCSSIdentifier');
    }

    // Parse recurrence rule definition and initialize default values
    this.$isRecurrent = angular.isDefined(data.repeat);
    if (this.repeat.days) {
      var byDayMask = _.find(this.repeat.days, function(o) {
        return angular.isDefined(o.occurrence);
      });
      if (byDayMask) {
        if (this.repeat.frequency == 'yearly')
          this.repeat.year = { byday: true };
        this.repeat.month = {
          type: 'byday',
          occurrence: byDayMask.occurrence.toString(),
          day: byDayMask.day
        };
      }
    }
    else {
      this.repeat.days = [];
    }
    if (this.repeat.dates) {
      this.repeat.frequency = 'custom';
      _.forEach(this.repeat.dates, function(rdate, i, rdates) {
        if (angular.isString(rdate))
          // Ex: 2015-10-25T22:34:51+00:00
          rdates[i] = Component.$parseDate(rdate);
      });
    }
    else if (angular.isUndefined(this.repeat.frequency))
      this.repeat.frequency = 'never';
    if (angular.isUndefined(this.repeat.interval))
      this.repeat.interval = 1;
    if (angular.isUndefined(this.repeat.monthdays))
      // TODO: initialize this.repeat.monthdays with month day of start date
      this.repeat.monthdays = [];
    else if (this.repeat.monthdays.length > 0)
      this.repeat.month = { type: 'bymonthday' };
    if (angular.isUndefined(this.repeat.month))
      this.repeat.month = {};
    if (angular.isUndefined(this.repeat.month.occurrence))
      angular.extend(this.repeat.month, { occurrence: '1', day: 'SU' });
    if (angular.isUndefined(this.repeat.months))
      // TODO: initialize this.repeat.months with month of start date
      this.repeat.months = [];
    if (angular.isUndefined(this.repeat.year))
      this.repeat.year = {};
    if (this.repeat.count)
      this.repeat.end = 'count';
    else if (this.repeat.until) {
      this.repeat.end = 'until';
      if (angular.isString(this.repeat.until))
        this.repeat.until = Component.$parseDate(this.repeat.until, { no_time: true });
    }
    else
      this.repeat.end = 'never';
    this.$hasCustomRepeat = this.hasCustomRepeat();

    if (this.isNew) {
      // Set default values
      var type = (this.type == 'appointment')? 'Events' : 'Tasks';

      // Set default classification
      this.classification = Component.$Preferences.defaults['SOGoCalendar' + type + 'DefaultClassification'].toLowerCase();

      // Set default alarm
      var units = { M: 'MINUTES', H: 'HOURS', D: 'DAYS', W: 'WEEKS' };
      var match = /-PT?([0-9]+)([MHDW])/.exec(Component.$Preferences.defaults.SOGoCalendarDefaultReminder);
      if (match) {
        this.$hasAlarm = true;
        this.alarm.quantity = parseInt(match[1]);
        this.alarm.unit = units[match[2]];
      }

      // Set notitifications
      this.sendAppointmentNotifications = Component.$Preferences.defaults.SOGoAppointmentSendEMailNotifications;
    }
    else if (angular.isUndefined(data.$hasAlarm)) {
      this.$hasAlarm = angular.isDefined(data.alarm);
    }

    // Allow the component to be moved to a different calendar
    this.destinationCalendar = this.pid;

    // if (this.organizer && this.organizer.email) {
    //   this.organizer.$image = Component.$gravatar(this.organizer.email, 32);
    // }

    this.selected = false;
  };

  /**
   * @function init
   * @memberof Component.prototype
   * @desc Extend instance with required attributes and new data.
   * @param {object} data - attributes of component
   */
  Component.prototype.initAttendees = function() {
    this.$attendees = new Component.$Attendees(this);
  };


  /**
   * @function hasCustomRepeat
   * @memberof Component.prototype
   * @desc Check if the component has a custom recurrence rule.
   * @returns true if the recurrence rule requires the full recurrence editor
   */
  Component.prototype.hasCustomRepeat = function() {
    var b = angular.isUndefined(this.occurrenceId) &&
        angular.isDefined(this.repeat) &&
        (this.repeat.interval > 1 ||
         angular.isDefined(this.repeat.days) && this.repeat.days.length > 0 ||
         angular.isDefined(this.repeat.monthdays) && this.repeat.monthdays.length > 0 ||
         angular.isDefined(this.repeat.months) && this.repeat.months.length > 0 ||
         angular.isDefined(this.repeat.month) && angular.isDefined(this.repeat.month.type) ||
         angular.isDefined(this.repeat.dates) && this.repeat.dates.length > 0);
    return b;
  };

  /**
   * @function isEditable
   * @memberof Component.prototype
   * @desc Check if the component is editable and not an occurrence of a recurrent component
   * @returns true or false
   */
  Component.prototype.isEditable = function() {
    return (!this.occurrenceId && !this.isReadOnly);
  };

  /**
   * @function isEditableOccurrence
   * @memberof Component.prototype
   * @desc Check if the component is editable and an occurrence of a recurrent component
   * @returns true or false
   */
  Component.prototype.isEditableOccurrence = function() {
    return (this.occurrenceId && !this.isReadOnly);
  };

  /**
   * @function isInvitation
   * @memberof Component.prototype
   * @desc Check if the component an invitation and not an occurrence of a recurrent component
   * @returns true or false
   */
  Component.prototype.isInvitation = function() {
    return (!this.occurrenceId && this.userHasRSVP);
  };

  /**
   * @function isInvitationOccurrence
   * @memberof Component.prototype
   * @desc Check if the component an invitation and an occurrence of a recurrent component
   * @returns true or false
   */
  Component.prototype.isInvitationOccurrence = function() {
    return (this.occurrenceId && this.userHasRSVP);
  };

  /**
   * @function showPercentComplete
   * @memberof Component.prototype
   * @desc Check if the percent completion should be displayed with respect to the
   *       component's type and status.
   * @returns true if the percent completion should be displayed
   */
  Component.prototype.showPercentComplete = function() {
    return (this.type == 'task' &&
            this.percentComplete > 0 &&
            this.status != 'cancelled');
  };

  /**
   * @function enablePercentComplete
   * @memberof Component.prototype
   * @desc Check if the percent completion should be enabled with respect to the
   *       component's type and status.
   * @returns true if the percent completion should be displayed
   */
  Component.prototype.enablePercentComplete = function() {
    return (this.type == 'task' &&
            this.status != 'not-specified' &&
            this.status != 'cancelled');
  };

  /**
   * @function markAsCompleted
   * @memberof Component.prototype
   * @desc Mark the task as completed.
   * @returns a promise of the HTTP operation
   */
  Component.prototype.markAsCompleted = function() {
    var _this = this, dlp;
    if (this.type == 'task') {
      dlp = Component.$Preferences.$mdDateLocaleProvider;
      this.percentComplete = 100;
      this.completed = new Date();
      this.completed.$dateFormat = Component.$Preferences.defaults.SOGoLongDateFormat;
      this.status = 'completed';
      this.localizedCompletedDate = dlp.formatDate(this.completed);
      this.localizedCompletedTime = dlp.formatTime(this.completed);
      return this.$save().catch(function() {
        _this.$reset();
      });
    }
    else {
      return Component.$q.reject('Only tasks can be mark as completed');
    }
  };

  /**
   * @function setDelta
   * @memberof Component.prototype
   * @desc Set the end time to the specified number of minutes after the start time.
   * @param {number} delta - the number of minutes
   */
  Component.prototype.setDelta = function(delta) {
    this.delta = delta;
    this.end = new Date(this.start.getTime());
    this.end.setMinutes(Math.round(this.end.getMinutes()/15)*15);
    this.end.addMinutes(this.delta);
  };

  /**
   * @function getClassName
   * @memberof Component.prototype
   * @desc Return the component CSS class name based on its container (calendar) ID.
   * @param {string} [base] - the prefix to add to the class name (defaults to "fg")
   * @returns a string representing the foreground CSS class name
   */
  Component.prototype.getClassName = function(base) {
    if (angular.isUndefined(base))
      base = 'fg';
    return base + '-folder' + (this.destinationCalendar || this.c_folder || this.pid);
  };

  /**
   * @function canRemindAttendeesByEmail
   * @memberof Component.prototype
   * @desc Verify if the component's reminder must be send by email and if it has at least one attendee.
   * @returns true if attendees can receive a reminder by email
   */
  Component.prototype.canRemindAttendeesByEmail = function() {
    return this.alarm.action == 'email' &&
      !this.isReadOnly &&
      this.attendees && this.attendees.length > 0;
  };

  /**
   * @function addAttachUrl
   * @memberof Component.prototype
   * @desc Add a new attach URL if not already defined
   * @param {string} attachUrl - the URL
   * @returns the number of values in the list of attach URLs
   */
  Component.prototype.addAttachUrl = function(attachUrl) {
    if (angular.isUndefined(this.attachUrls)) {
      this.attachUrls = [{value: attachUrl}];
    }
    else {
      for (var i = 0; i < this.attachUrls.length; i++) {
        if (this.attachUrls[i].value == attachUrl) {
          break;
        }
      }
      if (i == this.attachUrls.length)
        this.attachUrls.push({value: attachUrl});
    }
    return this.attachUrls.length - 1;
  };

  /**
   * @function deleteAttachUrl
   * @memberof Component.prototype
   * @desc Remove an attach URL
   * @param {number} index - the URL index in the list of attach URLs
   */
  Component.prototype.deleteAttachUrl = function(index) {
    if (index > -1 && this.attachUrls.length > index) {
      this.attachUrls.splice(index, 1);
    }
  };

  /**
   * @function $addDueDate
   * @memberof Component.prototype
   * @desc Add a due date
   */
  Component.prototype.$addDueDate = function() {
    this.due = new Date();
    this.due.setMinutes(Math.round(this.due.getMinutes()/15)*15);
    this.dueDate = this.due.toISOString();
  };

  /**
   * @function $deleteDueDate
   * @memberof Component.prototype
   * @desc Delete a due date
   */
  Component.prototype.$deleteDueDate = function() {
    delete this.due;
    delete this.dueDate;
  };

  /**
   * @function $addStartDate
   * @memberof Component.prototype
   * @desc Add a start date
   */
  Component.prototype.$addStartDate = function() {
    this.start = new Date();
    this.start.setMinutes(Math.round(this.start.getMinutes()/15)*15);
  };

  /**
   * @function $deleteStartDate
   * @memberof Component.prototype
   * @desc Delete a start date
   */
  Component.prototype.$deleteStartDate = function() {
    delete this.start;
    delete this.startDate;
  };

  /**
   * @function $addRecurrenceDate
   * @memberof Component.prototype
   * @desc Add a start date
   */
  Component.prototype.$addRecurrenceDate = function() {
    var now = new Date();
    now.setMinutes(Math.round(now.getMinutes()/15)*15);

    if (angular.isUndefined(this.repeat.dates))
      this.repeat = { frequency: 'custom', dates: [] };
    this.repeat.dates.push(now);
  };

  /**
   * @function $deleteRecurrenceDate
   * @memberof Component.prototype
   * @desc Delete a recurrence date
   */
  Component.prototype.$deleteRecurrenceDate = function(index) {
    if (index > -1 && this.repeat && this.repeat.dates && this.repeat.dates.length > index) {
      this.repeat.dates.splice(index, 1);
    }
  };

  /**
   * @function $reset
   * @memberof Component.prototype
   * @desc Reset the original state the component's data.
   */
  Component.prototype.$reset = function() {
    var _this = this;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        delete _this[key];
      }
    });
    this.init(this.$shadowData);
    this.$shadowData = this.$omit();
  };

  /**
   * @function $reply
   * @memberof Component.prototype
   * @desc Reply to an invitation.
   * @returns a promise of the HTTP operation
   */
  Component.prototype.$reply = function() {
    var _this = this, data, path = [this.pid, encodeURIComponent(this.id)];

    if (this.occurrenceId)
      path.push(this.occurrenceId);

    data = {
      reply: this.reply,
      delegatedTo: this.delegatedTo,
      alarm: this.$hasAlarm? this.alarm : {}
    };

    return Component.$$resource.save(path.join('/'), data, { action: 'rsvpAppointment' })
      .then(function(data) {
        // Make a copy of the data for an eventual reset
        _this.$shadowData = _this.$omit();
        return data;
      });
  };

  /**
   * @function $adjust
   * @memberof Component.prototype
   * @desc Adjust the start, day, and/or duration of the component
   * @returns a promise of the HTTP operation
   */
  Component.prototype.$adjust = function(params) {
    var path = [this.pid, encodeURIComponent(this.id)];

    if (_.every(_.values(params), function(v) { return v === 0; }))
      // No changes
      return Component.$q.when();

    if (this.occurrenceId)
      path.push(this.occurrenceId);

    Component.$log.debug('adjust ' + path.join('/') + ' ' + JSON.stringify(params));

    return Component.$$resource.save(path.join('/'), params, { action: 'adjust' });
  };

  /**
   * @function $save
   * @memberof Component.prototype
   * @desc Save the component to the server.
   * @param {object} extraAttributes - additional attributes to send to the server
   */
  Component.prototype.$save = function(extraAttributes) {
    var _this = this, options, path, component, date, dlp;

    component = this.$omit();
    dlp = Component.$Preferences.$mdDateLocaleProvider;

    // Format dates and times
    component.startDate = component.start ? component.start.format(dlp, '%Y-%m-%d') : '';
    component.startTime = component.start ? component.start.format(dlp, '%H:%M') : '';
    component.endDate = component.end ? component.end.format(dlp, '%Y-%m-%d') : '';
    component.endTime = component.end ? component.end.format(dlp, '%H:%M') : '';
    component.dueDate = component.due ? component.due.format(dlp, '%Y-%m-%d') : '';
    component.dueTime = component.due ? component.due.format(dlp, '%H:%M') : '';
    component.completedDate = component.completed ? component.completed.format(dlp, '%Y-%m-%d') : '';

    // Update recurrence definition depending on selections
    if (this.hasCustomRepeat()) {
      if (this.repeat.frequency == 'monthly' && this.repeat.month.type && this.repeat.month.type == 'byday' && this.repeat.month.day != 'relative' ||
          this.repeat.frequency == 'yearly' && this.repeat.year.byday) {
        // BYDAY mask for a monthly or yearly recurrence
        delete component.repeat.monthdays;
        component.repeat.days = [{ day: this.repeat.month.day, occurrence: this.repeat.month.occurrence.toString() }];
      }
      else if ((this.repeat.frequency == 'monthly' || this.repeat.frequency == 'yearly') &&
               this.repeat.month.type) {
        // montly recurrence by month days or yearly by month
        delete component.repeat.days;
        if (this.repeat.month.day == 'relative')
          component.repeat.monthdays = [this.repeat.month.occurrence];
      }
      else if (this.repeat.frequency == 'custom' && this.repeat.dates) {
        _.forEach(component.repeat.dates, function(rdate, i, rdates) {
          rdates[i] = {
            date: rdate.format(dlp, '%Y-%m-%d'),
            time: rdate.format(dlp, '%H:%M')
          };
        });
      }
    }
    else if (this.repeat.frequency && this.repeat.frequency != 'never') {
      component.repeat = { frequency: this.repeat.frequency };
    }
    if (component.startDate && this.repeat.frequency && this.repeat.frequency != 'never') {
      if (this.repeat.end == 'until' && this.repeat.until)
        component.repeat.until = this.repeat.until.stringWithSeparator('-');
      else if (this.repeat.end == 'count' && this.repeat.count)
        component.repeat.count = this.repeat.count;
      else {
        delete component.repeat.until;
        delete component.repeat.count;
      }
    }
    else {
      delete component.repeat;
    }

    // Check status
    if (this.status == 'not-specified')
      delete component.status;
    else if (this.status != 'completed')
      delete component.completedDate;

    // Verify alarm
    if ((component.startDate || component.dueDate) && this.$hasAlarm) {
      if (this.alarm.action && this.alarm.action == 'email' &&
          !(this.attendees && this.attendees.length > 0)) {
        // No attendees; email reminder must be sent to organizer only
        component.alarm.attendees = 0;
        component.alarm.organizer = 1;
      }
    }
    else {
      component.alarm = {};
    }

    // Build URL
    path = [this.pid, encodeURIComponent(this.id)];

    if (this.isNew)
      options = { action: 'saveAs' + this.type.capitalize() };

    if (this.occurrenceId)
      path.push(this.occurrenceId);

    angular.extend(component, extraAttributes);

    return Component.$$resource.save(path.join('/'), component, options)
      .then(function(data) {
        // Make a copy of the data for an eventual reset
        _this.$shadowData = _this.$omit();
        return data;
      });
  };

  /**
   * @function $delete
   * @memberof Component.prototype
   * @desc Delete the component from the server.
   * @param {boolean} occurrenceOnly - delete this occurrence only
   */
  Component.prototype.remove = function(occurrenceOnly) {
    var _this = this, path = [this.pid, encodeURIComponent(this.id)];

    if (occurrenceOnly && this.occurrenceId)
      path.push(this.occurrenceId);

    return Component.$$resource.remove(path.join('/'));
  };

  /**
   * @function $unwrap
   * @memberof Component.prototype
   * @desc Unwrap a promise.
   * @param {promise} futureComponentData - a promise of some of the Component's data
   */
  Component.prototype.$unwrap = function(futureComponentData) {
    var _this = this;

    // Expose the promise
    this.$futureComponentData = futureComponentData;

    // Resolve the promise
    this.$futureComponentData.then(function(data) {
      _this.init(data);
      // Make a copy of the data for an eventual reset
      _this.$shadowData = _this.$omit();
    }, function(data) {
      angular.extend(_this, data);
      _this.isError = true;
      Component.$log.error(_this.error);
    });
  };

  /**
   * @function $omit
   * @memberof Component.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Component instance
   */
  Component.prototype.$omit = function() {
    var component = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          (key == '$hasAlarm' || key[0] != '$') &&
          key != 'blocks') {
        component[key] = angular.copy(value);
      }
    });

    return component;
  };

  /**
   * @function repeatDescription
   * @memberof Component.prototype
   * @desc Return a localized description of the recurrence definition
   * @return a localized string
   */
  Component.prototype.repeatDescription = function() {
    var localizedString = null;
    if (this.repeat)
      localizedString = l('repeat_' + this.repeat.frequency.toUpperCase());

    return localizedString;
  };

  /**
   * @function alarmDescription
   * @memberof Component.prototype
   * @desc Return a localized description of the reminder definition
   * @return a localized string
   */
  Component.prototype.alarmDescription = function() {
    var key, localizedString = null;
    if (this.alarm) {
      key = ['reminder', this.alarm.quantity];
      if (this.alarm.quantity > 0)
        key.push(this.alarm.unit.toUpperCase(), this.alarm.reference.toUpperCase());
      key = key.join('_');
      localizedString = l(key);
      if (key === localizedString)
        // No localized string for this reminder definition
        localizedString = [this.alarm.quantity,
                           l('reminder_' + this.alarm.unit.toUpperCase()),
                           l('reminder_' + this.alarm.reference.toUpperCase())].join(' ');
    }

    return localizedString;
  };

  /**
   * @function copyTo
   * @memberof Component.prototype
   * @desc Copy an event to a calendar
   * @param {string} calendar - a target calendar UID
   * @returns a promise of the HTTP operation
   */
  Component.prototype.copyTo = function(calendar) {
    return Component.$$resource.post(this.pid + '/' + encodeURIComponent(this.id), 'copy', {destination: calendar});
  };

  /**
   * @function moveTo
   * @memberof Component.prototype
   * @desc Move an event to a calendar
   * @param {string} calendar - a target calendar UID
   * @returns a promise of the HTTP operation
   */
  Component.prototype.moveTo = function(calendar) {
    return Component.$$resource.post(this.pid + '/' + encodeURIComponent(this.id), 'move', {destination: calendar});
  };

  Component.prototype.toString = function() {
    return '[Component ' + this.id + ']';
  };


})();
