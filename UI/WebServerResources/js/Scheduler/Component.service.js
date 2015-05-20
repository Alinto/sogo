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
  Component.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', function($q, $timeout, $log, Settings, Resource) {
    angular.extend(Component, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.baseURL, Settings.activeUser),
      $categories: window.UserDefaults.SOGoCalendarCategoriesColors
    });

    return Component; // return constructor
  }];

  /**
   * @module SOGo.SchedulerUI
   * @desc Factory registration of Component in Angular module.
   */
  angular.module('SOGo.SchedulerUI')
    .factory('Component', Component.$factory);

  /**
   * @function $filter
   * @memberof Component.prototype
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
        defaultParams = {
          search: 'title_Category_Location',
          day: '' + year + (month < 10?'0':'') + month + (day < 10?'0':'') + day,
          filterpopup: 'view_thismonth'
        };

    if (angular.isUndefined(this.$filterOptions))
      this.$filterOptions = defaultParams;
    if (options)
      angular.extend(this.$filterOptions, options);

    var futureComponentData = this.$$resource.fetch(null, type + 'list', this.$filterOptions);

    return this.$unwrapCollection(type, futureComponentData);
  };

  /**
   * @function $find
   * @desc Fetch a component from a specific calendar.
   * @param {string} calendarId - the calendar ID
   * @param {string} componentId - the component ID
   * @see {@link Calendar.$getComponent}
   */
  Component.$find = function(calendarId, componentId) {
    var futureComponentData = this.$$resource.fetch([calendarId, componentId].join('/'), 'view');

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
   * @function $eventsBlocksForView
   * @desc Events blocks for a specific week
   * @param {string} view - Either 'day' or 'week'
   * @param {Date} type - Date of any day of the desired period
   * @returns a promise of a collection of objects describing the events blocks
   */
  Component.$eventsBlocksForView = function(view, date) {
    var viewAction, startDate, endDate, params;

    if (view == 'day') {
      viewAction = 'dayView';
      startDate = endDate = date;
    }
    else if (view == 'week') {
      viewAction = 'weekView';
      startDate = date.beginOfWeek();
      endDate = new Date();
      endDate.setTime(startDate.getTime());
      endDate.addDays(6);
    }
    else if (view == 'month') {
      viewAction = 'monthView';
      startDate = date;
      startDate.setDate(1);
      startDate = startDate.beginOfWeek();
      endDate = new Date();
      endDate.setTime(startDate.getTime());
      endDate.setMonth(endDate.getMonth() + 1);
      endDate.addDays(-1);
      endDate = endDate.endOfWeek();
    }
    return this.$eventsBlocks(viewAction, startDate, endDate);
  };

  /**
   * @function $eventsBlocks
   * @desc Events blocks for a specific view and period
   * @param {string} view - Either 'day' or 'week'
   * @param {Date} startDate - period's start date
   * @param {Date} endDate - period's end date
   * @returns a promise of a collection of objects describing the events blocks
   */
  Component.$eventsBlocks = function(view, startDate, endDate) {
    var params, futureComponentData, i,
        deferred = Component.$q.defer();

    params = { view: view.toLowerCase(), sd: startDate.getDayString(), ed: endDate.getDayString() };
    Component.$log.debug('eventsblocks ' + JSON.stringify(params, undefined, 2));
    futureComponentData = this.$$resource.fetch(null, 'eventsblocks', params);
    futureComponentData.then(function(data) {
      Component.$timeout(function() {
        var components = [], blocks = {};

        // Instantiate Component objects
        _.reduce(data.events, function(objects, eventData, i) {
          var componentData = _.object(data.eventsFields, eventData),
              start = new Date(componentData.c_startdate * 1000);
          componentData.hour = start.getHourString();
          objects.push(new Component(componentData));
          return objects;
        }, components);

        // Associate Component objects to blocks positions
        _.each(_.flatten(data.blocks), function(block) {
          block.component = components[block.nbr];
        });

        // Convert array of blocks to object with days as keys
        for (i = 0; i < data.blocks.length; i++) {
          blocks[startDate.getDayString()] = data.blocks[i];
          startDate.addDays(1);
        }

        Component.$log.debug('blocks ready (' + _.keys(blocks).length + ')');

        // Save the blocks to the object model
        Component.$blocks = blocks;

        deferred.resolve(blocks);
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
        deferred = Component.$q.defer(),
        components = [];

    futureComponentData.then(function(data) {
      Component.$timeout(function() {
        var fields = _.invoke(data.fields, 'toLowerCase');

        // Instanciate Component objects
        _.reduce(data[type], function(components, componentData, i) {
          var data = _.object(fields, componentData);
          components.push(new Component(data));
          return components;
        }, components);

        Component.$log.debug('list of ' + type + ' ready (' + components.length + ')');

        // Save the list of components to the object model
        Component['$' + type] = components;

        deferred.resolve(components);
      });
    }, function(data) {
      deferred.reject();
    });

    return deferred.promise;
  };

  /**
   * @function init
   * @memberof Component.prototype
   * @desc Extend instance with required attributes and new data.
   * @param {object} data - attributes of component
   */
  Component.prototype.init = function(data) {
    this.categories = [];
    this.repeat = {};
    angular.extend(this, data);

    // Parse recurrence rule definition and initialize default values
    if (this.repeat.days) {
      var byDayMask = _.find(this.repeat.days, function(o) {
        return angular.isDefined(o.occurrence);
      });
      if (byDayMask)
        if (this.repeat.frequency == 'yearly')
          this.repeat.year = { byday: true };
        this.repeat.month = {
          type: 'byday',
          occurrence: byDayMask.occurrence.toString(),
          day: byDayMask.day
        };
    }
    else {
      this.repeat.days = [];
    }
    if (angular.isUndefined(this.repeat.interval))
      this.repeat.interval = 1;
    if (angular.isUndefined(this.repeat.month))
      this.repeat.month = { occurrence: '1', day: 'SU', type: 'bymonthday' };
    if (angular.isUndefined(this.repeat.monthdays))
      this.repeat.monthdays = [];
    if (angular.isUndefined(this.repeat.months))
      this.repeat.months = [];
    if (angular.isUndefined(this.repeat.year))
      this.repeat.year = {};
    if (this.repeat.count)
      this.repeat.end = 'count';
    else if (this.repeat.until) {
      this.repeat.end = 'until';
      this.repeat.until = this.repeat.until.substring(0,10).asDate();
    }
    else
      this.repeat.end = 'never';
    this.$hasCustomRepeat = this.hasCustomRepeat();

    // Allow the event to be moved to a different calendar
    this.destinationCalendar = this.pid;
  };

  Component.prototype.hasCustomRepeat = function() {
    var b = angular.isDefined(this.repeat) &&
        (this.repeat.interval > 1 ||
         this.repeat.days && this.repeat.days.length > 0 ||
         this.repeat.monthdays && this.repeat.monthdays.length > 0 ||
         this.repeat.months && this.repeat.months.length > 0);
    return b;
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
    return base + '-folder' + (this.pid || this.c_folder);
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
    angular.extend(this, this.$shadowData);
    this.$shadowData = this.$omit(true);
  };

  /**
   * @function $save
   * @memberof Component.prototype
   * @desc Save the component to the server.
   */
  Component.prototype.$save = function() {
    var _this = this, options;

    if (this.isNew)
      options = { action: 'saveAs' + this.type.capitalize() };

    return Component.$$resource.save([this.pid, this.id].join('/'), this.$omit(), options)
      .then(function(data) {
        // Make a copy of the data for an eventual reset
        _this.$shadowData = _this.$omit(true);
        return data;
      });
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
    var component = {}, date;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        component[key] = angular.copy(value);
      }
    });

    // Format times
    component.startTime = component.startDate ? formatTime(component.startDate) : '';
    component.endTime   = component.endDate   ? formatTime(component.endDate)   : '';

    // Update recurrence definition depending on selections
    if (this.$hasCustomRepeat) {
      if (this.repeat.frequency == 'monthly' && this.repeat.month.type && this.repeat.month.type == 'byday'
          || this.repeat.frequency == 'yearly' && this.repeat.year.byday) {
        // BYDAY mask for a monthly or yearly recurrence
        delete component.repeat.monthdays;
        component.repeat.days = [{ day: this.repeat.month.day, occurrence: this.repeat.month.occurrence.toString() }];
      }
      else if (this.repeat.month.type) {
        // montly recurrence by month days or yearly by month
        delete component.repeat.days;
      }
    }
    else {
      component.repeat = { frequency: this.repeat.frequency };
    }
    if (this.repeat.end == 'until' && this.repeat.until)
      component.repeat.until = this.repeat.until.stringWithSeparator('-');
    else if (this.repeat.end == 'count' && this.repeat.count)
      component.repeat.count = this.repeat.count;
    else {
      delete component.repeat.until;
      delete component.repeat.count;
    }

    function formatTime(dateString) {
      // YYYY-MM-DDTHH:MM-05:00
      var date = new Date(dateString.substring(0,10) + ' ' + dateString.substring(11,16)),
          hours = date.getHours(),
          minutes = date.getMinutes();

      if (hours < 10) hours = '0' + hours;
      if (minutes < 10) minutes = '0' + minutes;

      return hours + ':' + minutes;
    }

    return component;
  };

})();
