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
      angular.extend(this, futureComponentData);
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
  Component.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgResource', function($q, $timeout, $log, Settings, Resource) {
    angular.extend(Component, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.baseURL, Settings.activeUser)
    });

    return Component; // return constructor
  }];

  /**
   * @module SOGo.SchedulerUI
   * @desc Factory registration of Component in Angular module.
   */
  angular.module('SOGo.SchedulerUI')
  /* Factory registration in Angular module */
    .factory('sgComponent', Component.$factory);

  /**
   * @function $filter
   * @memberof Component.prototype
   * @desc Search for components matching some criterias
   * @param {string} type - Either 'events' or 'tasks'
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
   * @function $eventsBlocksForWeek
   * @memberof Component.prototype
   * @desc Events blocks for a specific week
   * @param {Date} type - Date of any day of the week
   * @returns a promise of a collection of Components instances
   */
  Component.$eventsBlocksForWeek = function(date) {
    var startDate, endDate, params, i,
        deferred = Component.$q.defer();
    
    startDate = date.beginOfWeek();
    endDate = new Date();
    endDate.setTime(startDate.getTime());
    endDate.addDays(6);

    params = { view: 'weekView', sd: startDate.getDayString(), ed: endDate.getDayString() };
    Component.$log.debug('eventsblocks ' + JSON.stringify(params, undefined, 2));

    var futureComponentData = this.$$resource.fetch(null, 'eventsblocks', params);
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
        for (i = 0; i < 7; i++) {
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
   * @function $unwrap
   * @memberof Comonent.prototype
   * @desc Unwrap a promise and instanciate new Component objects using received data.
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
   * @function $unwrap
   * @memberof Component.prototype
   * @desc Unwrap a promise. 
   * @param {promise} futureComponentData - a promise of some of the Component's data
   */
  Component.prototype.$unwrap = function(futureComponentData) {
    var _this = this,
        deferred = Component.$q.defer();

    // Expose the promise
    this.$futureComponentData = futureComponentData;

    // Resolve the promise
    this.$futureComponentData.then(function(data) {
      // Calling $timeout will force Angular to refresh the view
      Component.$timeout(function() {
        angular.extend(_this, data);
        deferred.resolve(_this);
      });
    }, function(data) {
      angular.extend(_this, data);
      _this.isError = true;
      Component.$log.error(_this.error);
      deferred.reject();
    });

    return deferred.promise;
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
      if (key != 'constructor' && key[0] != '$') {
        component[key] = value;
      }
    });

    return component;
  };

})();
