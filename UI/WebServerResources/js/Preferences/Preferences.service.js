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

        // We convert our list of autoReplyEmailAddresses/forwardAddress into a string.
        if (data.Vacation && data.Vacation.autoReplyEmailAddresses)
          data.Vacation.autoReplyEmailAddresses = data.Vacation.autoReplyEmailAddresses.join(",");

        if (data.Forward && data.Forward.forwardAddress)
          data.Forward.forwardAddress = data.Forward.forwardAddress.join(",");

        angular.extend(_this.defaults, data);
      });
    });

    Preferences.$$resource.fetch("jsonSettings").then(function(data) {
      Preferences.$timeout(function() {
        // We convert our PreventInvitationsWhitelist hash into a array of user
        if (data.Calendar && data.Calendar.PreventInvitationsWhitelist)
          data.Calendar.PreventInvitationsWhitelist = _.map(data.Calendar.PreventInvitationsWhitelist, function(value, key) {
            var match = /^(.+)\s<(\S+)>$/.exec(value);
            return new Preferences.$User({uid: key, cn: match[1], c_email: match[2]});
          });
        else
          data.Calendar.PreventInvitationsWhitelist = [];

        angular.extend(_this.settings, data);
      });
    });
  }

  /**
   * @memberof Preferences
   * @desc The factory we'll use to register with Angular
   * @returns the Preferences constructor
   */
  Preferences.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Resource', 'Mailbox', 'User', function($q, $timeout, $log, Settings, Resource, Mailbox, User) {
    angular.extend(Preferences, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $$resource: new Resource(Settings.activeUser.folderURL, Settings.activeUser),
      activeUser: Settings.activeUser,
      $Mailbox: Mailbox,
      $User: User
    });

    return Preferences; // return constructor
  }];

  /* Factory registration in Angular module */
  angular.module('SOGo.PreferencesUI')
    .factory('Preferences', Preferences.$factory);

  /**
   * @function $save
   * @memberof Preferences.prototype
   * @desc Save the preferences to the server.
   */
  Preferences.prototype.$save = function() {
    var _this = this;

    return Preferences.$$resource.save("Preferences", this.$omit(true))
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

    if (preferences.defaults.Vacation && preferences.defaults.Vacation.autoReplyEmailAddresses)
      preferences.defaults.Vacation.autoReplyEmailAddresses = preferences.defaults.Vacation.autoReplyEmailAddresses.split(",");

    if (preferences.defaults.Forward && preferences.defaults.Forward.forwardAddress)
      preferences.defaults.Forward.forwardAddress = preferences.defaults.Forward.forwardAddress.split(",");

    if (preferences.settings.Calendar && preferences.settings.Calendar.PreventInvitationsWhitelist) {
      var h = {};
      _.each(preferences.settings.Calendar.PreventInvitationsWhitelist, function(user) {
        h[user.uid] = user.$shortFormat();
      });
      preferences.settings.Calendar.PreventInvitationsWhitelist = h;
    }

    return preferences;
  };

})();
