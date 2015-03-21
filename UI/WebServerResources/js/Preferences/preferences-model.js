/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';
  
  /**
   * @name Preferences
   * @constructor
   */
  function Preferences() {
    var _this = this;

    this.defaults = {};
    this.settings = {};

    this.mailboxes = Preferences.$Mailbox.$find({ id: 0 });
    
    Preferences.$$resource.fetch("jsonDefaults").then(function(data) {
      Preferences.$timeout(function() {

        // We swap $key -> _$key to avoid an Angular bug (https://github.com/angular/angular.js/issues/6266)
        var labels = _.object(_.map(data.SOGoMailLabelsColors, function(value, key) {
          if (key.charAt(0) == '$')
            return ['_' + key, value];
          return [key, value];
        }));
        
        data.SOGoMailLabelsColors = labels;
        
        angular.extend(_this.defaults, data);
      });
    });
    Preferences.$$resource.fetch("jsonSettings").then(function(data) {
      Preferences.$timeout(function() {
        angular.extend(_this.settings, data);
      });
    });
  }
  
  /**
   * @memberof Preferences
   * @desc The factory we'll use to register with Angular
   * @returns the Preferences constructor
   */
  Preferences.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'sgResource', 'sgMailbox', function($q, $timeout, $log, Settings, Resource, Mailbox) {
    angular.extend(Preferences, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL, Settings.activeUser),
      activeUser: Settings.activeUser,
      $Mailbox: Mailbox
    });

    return Preferences; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.PreferencesUI')
    .factory('sgPreferences', Preferences.$factory);

  /**
   * @function $save
   * @memberof Preferences.prototype
   * @desc Save the preferences to the server.
   */
  Preferences.prototype.$save = function() {
    var _this = this;
    console.debug("save in model...");
    
    return Preferences.$$resource.save("Preferences",
                                       this.$omit(),
                                       undefined)
      .then(function(data) {
        // Make a copy of the data for an eventual reset
        //_this.$shadowData = _this.$omit(true);
        return data;
      });
  };

  /**
   * @function $omit
   * @memberof Preferences.prototype
   * @desc Return a sanitized object used to send to the server.
   * @param {Boolean} [deep] - make a deep copy if true
   * @return an object literal copy of the Preferences instance
   */
  Preferences.prototype.$omit = function(deep) {
    var preferences = {};
    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        if (deep)
          preferences[key] = angular.copy(value);
        else
          preferences[key] = value;
      }
    });

    // We swap _$key -> $key to avoid an Angular bug (https://github.com/angular/angular.js/issues/6266)
    var labels = _.object(_.map(preferences.defaults.SOGoMailLabelsColors, function(value, key) {
      if (key.charAt(0) == '_' && key.charAt(1) == '$')
        return [key.substring(1), value];
      return [key, value];
    }));
    
    preferences.defaults.SOGoMailLabelsColors = labels;
    
    return preferences;
  };
  
})();
