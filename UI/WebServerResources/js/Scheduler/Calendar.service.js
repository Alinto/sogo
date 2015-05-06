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
      angular.extend(this, newCalendarData);
    }
    if (this.id) {
      this.$acl = new Calendar.$$Acl('Calendar/' + this.id);
    }
  }

  /**
   * @memberof Calendar
   * @desc The factory we'll use to register with Angular
   * @returns the Calendar constructor
   */
  Calendar.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Component', 'Acl', function($q, $timeout, $log, Settings, Resource, Component, Acl) {
    angular.extend(Calendar, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL + 'Calendar', Settings.activeUser),
      $Component: Component,
      $$Acl: Acl,
      activeUser: Settings.activeUser
    });

    return Calendar; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.SchedulerUI')
    .factory('Calendar', Calendar.$factory);

  /**
   * @memberof Calendar
   * @desc Add a new calendar to the static list of calendars
   * @param {Calendar} calendar - an Calendar object instance
   */
  Calendar.$add = function(calendar) {
    // Insert new calendar at proper index
    var list, sibling, i;

    if (calendar.isWebCalendar)
      list = this.$webcalendars;
    else if (calendar.isSubscription)
      list = this.$subscriptions;
    else
      list = this.$calendars;

    sibling = _.find(list, function(o) {
      return (o.id != 'personal'
              && o.name.localeCompare(calendar.name) === 1);
    });
    i = sibling ? _.indexOf(_.pluck(list, 'id'), sibling.id) : 1;
    list.splice(i, 0, calendar);
  };

  /**
   * @memberof Calendar
   * @desc Set or get the list of calendars. Will instanciate a new Calendar object for each item.
   * @param {object[]} [data] - the metadata of the calendars
   * @returns the list of calendars
   */
  Calendar.$findAll = function(data) {
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
    return this.$calendars;
  };

  /**
   * @memberof Calendar
   * @desc Find a calendar among local instances (personal calendars and subscriptions).
   * @param {string} id - the calendar ID
   * @returns an object literal of the matching Calendar instance
   */
  Calendar.$get = function(id) {
    var calendar;

    calendar = _.find(Calendar.$calendars, function(o) { return o.id == id });
    if (!calendar)
      calendar = _.find(Calendar.$subscriptions, function(o) { return o.id == id });
    if (!calendar)
      calendar = _.find(Calendar.$webcalendars, function(o) { return o.id == id });

    return calendar;
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
      var calendar = new Calendar(calendarData);
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
        Calendar.$add(calendar);
        Calendar.$$resource.fetch(calendar.id, 'reload').then(function(data) {
          // TODO: show a toast of the reload status
          Calendar.$log.debug(JSON.stringify(data, undefined, 2));
        });
        d.resolve();
      }, function() {
        d.reject();
      });
    }

    return d.promise;
  };

  /**
   * @function init
   * @memberof Calendar.prototype
   * @desc Extend instance with new data and compute additional attributes.
   * @param {object} data - attributes of calendar
   */
  Calendar.prototype.init = function(data) {
    angular.extend(this, data);
    // Add 'isOwned' and 'isSubscription' attributes based on active user (TODO: add it server-side?)
    this.isOwned = Calendar.activeUser.isSuperUser || this.owner == Calendar.activeUser.login;
    this.isSubscription = !this.isRemote && this.owner != Calendar.activeUser.login;
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
  Calendar.prototype.$rename = function(name) {
    var i = _.indexOf(_.pluck(Calendar.$calendars, 'id'), this.id);
    this.name = name;
    Calendar.$calendars.splice(i, 1);
    Calendar.$add(this);
    return this.$save();
  };

  /**
   * @function $delete
   * @memberof Calendar.prototype
   * @desc Delete the calendar from the server and the static list of calendars.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$delete = function() {
    var _this = this,
        d = Calendar.$q.defer(),
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

    promise.then(function() {
      var i = _.indexOf(_.pluck(list, 'id'), _this.id);
      list.splice(i, 1);
      d.resolve();
    }, function(data, status) {
      d.reject(data);
    });
    return d.promise;
  };

  /**
   * @function $save
   * @memberof Calendar.prototype
   * @desc Save the calendar properties to the server.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$save = function() {
    return Calendar.$$resource.save(this.id, this.$omit()).then(function(data) {
      return data;
    });
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
   * @desc Fetch the card attributes from the server.
   * @returns a promise of the HTTP operation
   */
  Calendar.prototype.$getComponent = function(componentId) {
    return Calendar.$Component.$find(this.id, componentId);
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
        calendar[key] = value;
      }
    });
    return calendar;
  };
})();
