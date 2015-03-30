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
    angular.extend(this, futureCalendarData);
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
  Calendar.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgResource', 'sgCard', 'sgAcl', function($q, $timeout, $log, Settings, Resource, Card, Acl) {
    angular.extend(Calendar, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL + 'Calendar', Settings.activeUser),
      $Card: Card,
      $$Acl: Acl,
      activeUser: Settings.activeUser
    });

    return Calendar; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.SchedulerUI')
    .factory('sgCalendar', Calendar.$factory);

  /**
   * @memberof Calendar
   * @desc Add a new calendar to the static list of calendars
   * @param {Calendar} calendar - an Calendar object instance
   */
  Calendar.$add = function(calendar) {
    // Insert new calendar at proper index
    var sibling, i;

    calendar.isOwned = this.activeUser.isSuperUser || calendar.owner == this.activeUser.login;
    calendar.isSubscription = calendar.owner != this.activeUser.login;
    sibling = _.find(this.$calendars, function(o) {
      return (o.isRemote
              || (!calendar.isSubscription && o.isSubscription)
              || (o.id != 'personal'
                  && o.isSubscription === calendar.isSubscription
                  && o.name.localeCompare(calendar.name) === 1));
    });
    i = sibling ? _.indexOf(_.pluck(this.$calendars, 'id'), sibling.id) : 1;
    this.$calendars.splice(i, 0, calendar);
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
      
      this.$calendars = data;
      // Instanciate Calendar objects
      angular.forEach(this.$calendars, function(o, i) {
        _this.$calendars[i] = new Calendar(o);
        // Add 'isOwned' and 'isSubscription' attributes based on active user (TODO: add it server-side?)
        // _this.$calendars[i].isSubscription = _this.$calendars[i].owner != _this.activeUser.login;
        // _this.$calendars[i].isOwned = _this.activeUser.isSuperUser
        //   || _this.$calendars[i].owner == _this.activeUser.login;
      });
    }
    return this.$calendars;
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
      if (!_.find(_this.$calendars, function(o) {
        return o.id == calendarData.id;
      })) {
        Calendar.$add(calendar);
      }
      return calendar;
    });
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
        promise;

    if (this.isSubscription)
      promise = Calendar.$$resource.fetch(this.id, 'unsubscribe');
    else
      promise = Calendar.$$resource.remove(this.id);

    promise.then(function() {
      var i = _.indexOf(_.pluck(Calendar.$calendars, 'id'), _this.id);
      Calendar.$calendars.splice(i, 1);
      d.resolve(true);
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
