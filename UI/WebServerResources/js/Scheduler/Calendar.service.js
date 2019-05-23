/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Calendar
   * @constructor
   * @param {object} futureCalendarData - either an object literal or a promise
   */
  function Calendar(futureCalendarData) {
    // Data is immediately available
    this.init(futureCalendarData);
    if (this.name && !this.id) {
      // Create a new calendar on the server
      var newCalendarData = Calendar.$$resource.create('createFolder', this.name);
      this.$unwrap(newCalendarData);
    }
  }

  /**
   * @memberof Calendar
   * @desc The factory we'll use to register with Angular
   * @returns the Calendar constructor
   */
  Calendar.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Preferences', 'Component', 'Acl', function($q, $timeout, $log, Settings, Resource, Preferences, Component, Acl) {
    angular.extend(Calendar, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Calendar', Settings.activeUser()),
      $Preferences: Preferences,
      $Component: Component,
      $$Acl: Acl,
      activeUser: Settings.activeUser(),
      $view: null
    });

    return Calendar; // return constructor
  }];

  /**
   * @module SOGo.SchedulerUI
   * @desc Factory registration of Calendar in Angular module.
   */
  try {
    angular.module('SOGo.SchedulerUI');
  }
  catch(e) {
    angular.module('SOGo.SchedulerUI', ['SOGo.Common']);
  }
  angular.module('SOGo.SchedulerUI')
    .value('CalendarSettings', {
      EventDragDayLength:          24 * 4,   // hour quarters
      EventDragHorizontalOffset:   3,        // pixels
      ConflictHTTPErrorCode:       409
    })
    .factory('Calendar', Calendar.$factory);

  /**
   * @memberof Calendar
   * @desc Return the default calendar id according to the user's defaults.
   * @returns a calendar id
   */
  Calendar.$defaultCalendar = function() {
    var defaultCalendar = Calendar.$Preferences.defaults.SOGoDefaultCalendar,
        calendar;

    if (defaultCalendar == 'first') {
      calendar = _.find(Calendar.$findAll(null, true), function(calendar) {
        return calendar.active;
      });
      if (calendar)
        return calendar.id;
    }

    return 'personal';
  };

  /**
   * @memberof Calendar
   * @desc Add a new calendar to the static list of calendars
   * @param {Calendar} calendar - an Calendar object instance
   */
  Calendar.$add = function(calendar) {
    // Insert new calendar at proper index
    var list, sibling;

    if (calendar.isWebCalendar)
      list = this.$webcalendars;
    else if (calendar.isSubscription)
      list = this.$subscriptions;
    else
      list = this.$calendars;

    sibling = _.findIndex(list, function(o, i) {
      return (calendar.id == 'personal' ||
              (o.id != 'personal' && o.name.localeCompare(calendar.name) > 0));
    });
    if (sibling < 0)
      list.push(calendar);
    else
      list.splice(sibling, 0, calendar);

    if (Calendar.$Preferences.settings.Calendar.FoldersOrder)
      // Save list order
      Calendar.saveFoldersOrder(_.flatMap(Calendar.$findAll(), 'id'));
    // Refresh list of calendars to fetch links associated to new calendar
    Calendar.$reloadAll();
  };

  /**
   * @memberof Calendar
   * @desc Set or get the list of calendars. Will instanciate a new Calendar object for each item.
   * @param {object[]} [data] - the metadata of the calendars
   * @param {bool} [writable] - if true, returns only the list of writable calendars
   * @returns the list of calendars
   */
  Calendar.$findAll = function(data, writable) {
    var _this = this;
    if (data) {
      this.$calendars = [];
      this.$subscriptions = [];
      this.$webcalendars = [];
      // Instanciate Calendar objects
      angular.forEach(data, function(o, i) {
        var calendar = new Calendar(o);
        if (calendar.isWebCalendar)
          _this.$webcalendars.push(calendar);
        else if (calendar.isSubscription)
          _this.$subscriptions.push(calendar);
        else
          _this.$calendars.push(calendar);
      });
    }
    else if (angular.isUndefined(this.$calendars)) {
      this.$calendars = [];
      this.$subscriptions = [];
      this.$webcalendars = [];
      return Calendar.$$resource.fetch('calendarslist').then(function(data) {
        return Calendar.$findAll(data.calendars, writable);
      });
    }

    if (writable) {
      return _.union(this.$calendars, _.filter(this.$subscriptions, function(calendar) {
        return calendar.isOwned || calendar.acls.objectCreator;
      }));
    }

    return _.union(this.$calendars, this.$subscriptions, this.$webcalendars);
  };

  /**
   * @memberof Calendar
   * @desc Reload the list of known calendars.
   */
  Calendar.$reloadAll = function() {
    var _this = this;

    Calendar.$$resource.fetch('calendarslist').then(function(data) {
      _.forEach(data.calendars, function(calendarData) {
        var group, calendar;

        if (calendarData.isWebCalendar)
          group = _this.$webcalendars;
        else if (calendarData.owner != Calendar.activeUser.login)
          group = _this.$subscriptions;
        else
          group = _this.$calendars;

        calendar = _.find(group, function(o) { return o.id == calendarData.id; });
        if (calendar)
          calendar.init(calendarData);
      });
    });
  };

  /**
   * @memberof Calendar
   * @desc Find a calendar among local instances (personal calendars, subscriptions and Web calendars).
   * @param {string} id - the calendar ID
   * @returns an object literal of the matching Calendar instance
   */
  Calendar.$get = function(id) {
    var calendar;

    calendar = _.find(Calendar.$calendars, function(o) { return o.id == id; });
    if (!calendar)
      calendar = _.find(Calendar.$subscriptions, function(o) { return o.id == id; });
    if (!calendar)
      calendar = _.find(Calendar.$webcalendars, function(o) { return o.id == id; });

    return calendar;
  };

  /**
   * @memberof Calendar
   * @desc Find a calendar among local instances (personal calendars, subscriptions and Web calendars).
   * @param {string} id - the calendar ID
   * @returns an object literal of the matching Calendar instance
   */
  Calendar.$getIndex = function(id) {
    var i;

    i = _.indexOf(_.map(Calendar.$calendars, 'id'), id);
    if (i < 0)
      i = _.indexOf(_.map(Calendar.$subscriptions, 'id'), id);
    if (i < 0)
      i = _.indexOf(_.map(Calendar.$webcalendars, 'id'), id);

    return i;
  };

  /**
   * @memberOf Calendar
   * @desc Subscribe to another user's calendar and add it to the list of calendars.
   * @param {string} uid - user id
   * @param {string} path - path of folder for specified user
   * @returns a promise of the HTTP query result
   */
  Calendar.$subscribe = function(uid, path) {
    var _this = this;
    return Calendar.$$resource.userResource(uid).fetch(path, 'subscribe').then(function(calendarData) {
      var calendar = new Calendar(angular.extend({ active: 1 }, calendarData));
      if (!_.find(_this.$subscriptions, function(o) {
        return o.id == calendarData.id;
      })) {
        Calendar.$add(calendar);
      }
      return calendar;
    });
  };

  /**
   * @memberOf Calendar
   * @desc Subscribe to a remote Web calendar
   * @param {string} url - URL of .ics file
   * @returns a promise of the HTTP query result
   */
  Calendar.$addWebCalendar = function(url) {
    var _this = this,
        d = Calendar.$q.defer();

    if (_.find(_this.$webcalendars, function(o) {
        return o.urls.webCalendarURL == url;
    })) {
      // Already subscribed
      d.reject();
    }
    else {
      Calendar.$$resource.post(null, 'addWebCalendar', { url: url }).then(function(calendarData) {
        angular.extend(calendarData, {
          isWebCalendar: true,
          isEditable: true,
          isRemote: false,
          owner: Calendar.activeUser.login,
          urls: { webCalendarURL: url }
        });
        var calendar = new Calendar(calendarData);
        Calendar.$$resource.fetch(calendar.id, 'reload').then(function(data) {
          // TODO: show a toast of the reload status
          Calendar.$log.debug(JSON.stringify(data, undefined, 2));
          Calendar.$add(calendar);
          d.resolve();
        }, function(response) {
          if (response.status == 401) {
            // Web calendar requires authentication
            d.resolve(calendar);
          }
          else {
            d.reject();
          }
        });
      }, d.reject);
    }

    return d.promise;
  };

  /**
   * @function reloadWebCalendars
   * @memberof Calendar
   * @desc Reload all Web calendars
   * @return a promise combining the results of all HTTP operations
   */
  Calendar.reloadWebCalendars = function() {
    var promises = [];

    _.forEach(this.$webcalendars, function(calendar) {
      var promise = Calendar.$$resource.fetch(calendar.id, 'reload');
      promise.then(function(data) {
        calendar.$error = false;
      }, function(response) {
        calendar.$error = l(response.statusText);
      });
      promises.push(promise);
    });

    return Calendar.$q.all(promises);
  };

  /**
   * @function $deleteComponents
   * @memberof Calendar
   * @desc Delete multiple components from calendar.
   * @return a promise of the HTTP operation
   */
  Calendar.$deleteComponents = function(components) {
    var _this = this, calendars = {}, promises = [];

    _.forEach(components, function(component) {
      if (!angular.isDefined(calendars[component.pid]))
        calendars[component.pid] = [];
      calendars[component.pid].push(component.id);
    });

    _.forEach(calendars, function(uids, pid) {
      promises.push(Calendar.$$resource.post(pid, 'batchDelete', {uids: uids}));
    });

    return Calendar.$q.all(promises);
  };

  /**
   * @function saveFoldersActivation
   * @memberof Calendar
   * @desc Save to the user's settings the activation state of the calendars
   * @param {string[]} folders - the folders IDs
   * @returns a promise of the HTTP operation
   */
  Calendar.saveFoldersActivation = function(ids) {
    var request = {};

    _.forEach(ids, function(id) {
      var calendar = Calendar.$get(id);
      request[calendar.id] = calendar.active;
    });

    return Calendar.$$resource.post(null, 'saveFoldersActivation', request);
  };

  /**
   * @function saveFoldersOrder
   * @desc Save to the user's settings the current calendars order.
   * @param {string[]} folders - the folders IDs
   * @returns a promise of the HTTP operation
   */
  Calendar.saveFoldersOrder = function(folders) {
    return this.$$resource.post(null, 'saveFoldersOrder', { folders: folders }).then(function() {
      Calendar.$Preferences.settings.Calendar.FoldersOrder = folders;
      if (!folders)
        // Calendars order was reset; reload list
        return Calendar.$$resource.fetch('calendarslist').then(function(data) {
          return Calendar.$findAll(data.calendars);
        });
    });
  };

  /**
   * @function init
   * @memberof Calendar.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of calendar
   */
  Calendar.prototype.init = function(data) {
    this.color = this.color || '#AAAAAA';
    this.active = 1;
    angular.extend(this, data);
    if (this.id) {
      this.$acl = new Calendar.$$Acl('Calendar/' + this.id);
    }
    // Add 'isOwned' and 'isSubscription' attributes based on active user (TODO: add it server-side?)
    this.isOwned = Calendar.activeUser.isSuperUser || this.owner == Calendar.activeUser.login;
    this.isSubscription = !this.isRemote && this.owner != Calendar.activeUser.login;
    if (angular.isUndefined(this.$shadowData) || !this.$shadowData.id) {
      // Make a copy of the data for an eventual reset
      this.$shadowData = this.$omit();
    }
  };

  /**
   * @function $id
   * @memberof Calendar.prototype
   * @desc Resolve the calendar id.
   * @returns a promise of the calendar id
   */
  Calendar.prototype.$id = function() {
    var _this = this;

    if (this.id) {
      // Object already unwrapped
      return Calendar.$q.when(this.id);
    }
    else {
      // Wait until object is unwrapped
      return this.$futureCalendarData.then(function(calendar) {
        if (calendar.id)
          return calendar.id;
        else
          return Calendar.$q.reject();
      });
    }
  };

  /**
   * @function getClassName
   * @memberof Calendar.prototype
   * @desc Return the calendar CSS class name based on its ID.
   * @returns a string representing the foreground CSS class name
   */
  Calendar.prototype.getClassName = function(base) {
    if (angular.isUndefined(base))
      base = 'fg';
    return base + '-folder' + this.id;
  };

  /**
   * @function $rename
   * @memberof Calendar.prototype
   * @desc Rename the calendar and keep the list sorted
   * @param {string} name - the new name
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$rename = function() {
    var _this = this,
        i,
        calendars;

    if (this.name == this.$shadowData.name) {
      // Name hasn't changed
      return Calendar.$q.when();
    }

    if (this.isWebCalendar)
      calendars = Calendar.$webcalendars;
    else if (this.isSubscription)
      calendars = Calendar.$subscriptions;
    else
      calendars = Calendar.$calendars;

    i = _.indexOf(_.map(calendars, 'id'), this.id);
    if (i > -1) {
      return this.$save().then(function() {
        calendars.splice(i, 1);
        Calendar.$add(_this);
      });
    }
    else {
      return Calendar.$q.reject();
    }
  };

  /**
   * @function $delete
   * @memberof Calendar.prototype
   * @desc Delete the calendar from the server and the static list of calendars.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$delete = function() {
    var _this = this,
        list,
        promise;

    if (this.isSubscription) {
      promise = Calendar.$$resource.fetch(this.id, 'unsubscribe');
      list = Calendar.$subscriptions;
    }
    else {
      promise = Calendar.$$resource.remove(this.id);
      if (this.isWebCalendar)
        list = Calendar.$webcalendars;
      else
        list = Calendar.$calendars;
    }

    return promise.then(function() {
      var i = _.indexOf(_.map(list, 'id'), _this.id);
      list.splice(i, 1);
    });
  };

  /**
   * @function $reset
   * @memberof Calendar.prototype
   * @desc Reset the original state the calendar's data.
   */
  Calendar.prototype.$reset = function() {
    var _this = this;
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        delete _this[key];
      }
    });
    angular.extend(this, this.$shadowData);
    this.$shadowData = this.$omit();
  };

  /**
   * @function $save
   * @memberof Calendar.prototype
   * @desc Save the calendar properties to the server.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$save = function() {
    var _this = this,
        d = Calendar.$q.defer();

    Calendar.$$resource.save(this.id, this.$omit()).then(function(data) {
      // Make a copy of the data for an eventual reset
      _this.$shadowData = _this.$omit();
      return d.resolve(data);
    }, function(data) {
      // Restore previous version
      _this.$reset();
      return d.reject(data);
    });

    return d.promise;
  };

  /**
   * @function setCredentials
   * @memberof Calendar.prototype
   * @desc Set the credentials for a Web calendar that requires authentication
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.setCredentials = function(username, password) {
    var _this = this,
        d = Calendar.$q.defer();

    Calendar.$$resource.post(this.id, 'set-credentials', { username: username, password: password }).then(function() {
      Calendar.$$resource.fetch(_this.id, 'reload').then(function(data) {
        Calendar.$add(_this);
        d.resolve();
      }, function(response) {
        if (response.status == 401) {
          // Authentication failed
          d.reject(l('Wrong username or password.'));
        }
        else {
          d.reject(response.statusText);
        }
      });
    }, d.reject);

    return d.promise;
  };

  /**
   * @function export
   * @memberof Calendar.prototype
   * @desc Export the calendar
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.export = function() {
    var options, resource, ownerPaths, realOwnerId, path, index;

    options = {
      type: 'application/octet-stream',
      filename: this.name + '.ics'
    };

    if (this.isSubscription) {
      index = this.urls.webDavICSURL.indexOf('/dav/');
      ownerPaths = this.urls.webDavICSURL.substring(index + 5).split(/\//);
      realOwnerId = ownerPaths[0];
      resource = Calendar.$$resource.userResource(realOwnerId);
      path = ownerPaths.splice(ownerPaths.length - 2).join('/');
    }
    else {
      resource = Calendar.$$resource;
      path = this.id + '.ics';
    }

    return resource.open(path, 'export', null, options);
  };

  /**
   * @function $setActivation
   * @memberof Calendar.prototype
   * @desc Either activate or deactivate the calendar.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$setActivation = function() {
    return Calendar.$$resource.fetch(this.id, (this.active?'':'de') + 'activateFolder');
  };

  /**
   * @function $getComponent
   * @memberof Calendar.prototype
   * @desc Fetch a component attributes from the server.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$getComponent = function(componentId, recurrenceId) {
    return Calendar.$Component.$find(this.id, componentId, recurrenceId);
  };

  /**
   * @function $unwrap
   * @memberof Calendar.prototype
   * @desc Unwrap a promise
   * @param {promise} futureCalendarData - a promise of the Calendar's data
   */
  Calendar.prototype.$unwrap = function(futureCalendarData) {
    var _this = this;

    // Expose and resolve the promise
    this.$futureCalendarData = futureCalendarData.then(function(data) {
      return Calendar.$timeout(function() {
        // Extend Calendar instance with received data
        _this.init(data);
        return _this;
      });
    }, function(data) {
      _this.isError = true;
      if (angular.isObject(data)) {
        Calendar.$timeout(function() {
          angular.extend(_this, data);
        });
      }
    });
  };

  /**
   * @function $omit
   * @memberof Calendar.prototype
   * @desc Return a sanitized object used to send to the server.
   * @return an object literal copy of the Calendar instance
   */
  Calendar.prototype.$omit = function() {
    var calendar = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' &&
          key[0] != '$') {
        calendar[key] = angular.copy(value);
      }
    });
    return calendar;
  };
})();
