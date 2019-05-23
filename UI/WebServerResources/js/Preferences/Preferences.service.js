/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Preferences
   * @constructor
   */
  function Preferences() {
    var _this = this, defaultsElement, settingsElement, data;

    this.defaults = {};
    this.settings = {};

    defaultsElement = Preferences.$document[0].getElementById('UserDefaults');
    if (defaultsElement) {
      try {
        data = angular.fromJson(defaultsElement.textContent || defaultsElement.innerHTML);
      } catch (e) {
        Preferences.$log.error("Can't parse user's defaults: " + e.message);
        data = {};
      }

      // Split mail labels keys and values
      data.SOGoMailLabelsColorsKeys = [];
      data.SOGoMailLabelsColorsValues = [];
      _.forEach(data.SOGoMailLabelsColors, function (value, key) {
        data.SOGoMailLabelsColorsKeys.push(key);
        data.SOGoMailLabelsColorsValues.push(value); // value is an array of the user-defined name and color
        if (key.charAt(0) == '$') {
          Object.defineProperty(data.SOGoMailLabelsColors, '_' + key,
                                Object.getOwnPropertyDescriptor(data.SOGoMailLabelsColors, key));
          delete data.SOGoMailLabelsColors[key];
        }
      });

      _.forEach(data.SOGoSieveFilters, function(filter) {
        _.forEach(filter.actions, function(action) {
          if (action.method == 'addflag' &&
              action.argument.charAt(0) == '$')
            action.argument = '_' + action.argument;
        });
      });

      if (data.SOGoRememberLastModule)
        data.SOGoLoginModule = "Last";

      // Mail editor autosave is a number of minutes or 0 if disabled
      data.SOGoMailAutoSave = parseInt(data.SOGoMailAutoSave) || 0;

      data.SOGoMailComposeWindowEnabled = angular.isDefined(data.SOGoMailComposeWindow);

      // Specify a base font size for HTML messages when SOGoMailComposeFontSize is not zero
      data.SOGoMailComposeFontSizeEnabled = parseInt(data.SOGoMailComposeFontSize) > 0;

      if (window.CKEDITOR && data.SOGoMailComposeFontSizeEnabled) {
        // HTML editor is enabled; set user's preferred font size
        window.CKEDITOR.config.fontSize_defaultLabel = data.SOGoMailComposeFontSize;
        window.CKEDITOR.addCss('.cke_editable { font-size: ' + data.SOGoMailComposeFontSize + 'px; }');
      }

      _.forEach(data.AuxiliaryMailAccounts, function (mailAccount) {
        if (isNaN(parseInt(mailAccount.port)))
          mailAccount.port = null;
      });

      // We convert our list of autoReplyEmailAddresses/forwardAddress into a string.
      // We also convert our date objects into real date, otherwise we'll have strings
      // or undefined values and the md-datepicker does NOT like this.
      if (data.Vacation) {
        if (data.Vacation.startDate)
          data.Vacation.startDate = new Date(parseInt(data.Vacation.startDate) * 1000);
        else {
          data.Vacation.startDateEnabled = 0;
          data.Vacation.startDate = new Date();
          data.Vacation.startDate = data.Vacation.startDate.beginOfDay();
          data.Vacation.startDate.addDays(1);
        }
        if (data.Vacation.endDate)
          data.Vacation.endDate = new Date(parseInt(data.Vacation.endDate) * 1000);
        else {
          data.Vacation.endDateEnabled = 0;
          data.Vacation.endDate = new Date(data.Vacation.startDate.getTime());
          data.Vacation.endDate.addDays(1);
        }
        if (data.Vacation.autoReplyEmailAddresses &&
            angular.isArray(data.Vacation.autoReplyEmailAddresses) &&
            data.Vacation.autoReplyEmailAddresses.length)
          data.Vacation.autoReplyEmailAddresses = data.Vacation.autoReplyEmailAddresses.join(",");
        else
          delete data.Vacation.autoReplyEmailAddresses;
      } else
        data.Vacation = {};

      if (angular.isUndefined(data.Vacation.autoReplyEmailAddresses) &&
          angular.isDefined(window.defaultEmailAddresses))
        data.Vacation.autoReplyEmailAddresses = window.defaultEmailAddresses;

      if (angular.isUndefined(data.Vacation.daysBetweenResponse))
        data.Vacation.daysBetweenResponse = 7;

      if (angular.isUndefined(data.Vacation.startDate)) {
        data.Vacation.startDateEnabled = 0;
        data.Vacation.startDate = new Date();
      }

      if (angular.isUndefined(data.Vacation.endDate)) {
        data.Vacation.endDateEnabled = 0;
        data.Vacation.endDate = new Date();
      }

      if (data.Forward && data.Forward.forwardAddress &&
          angular.isArray(data.Forward.forwardAddress))
        data.Forward.forwardAddress = data.Forward.forwardAddress.join(",");

      // Split calendar categories colors keys and values
      if (angular.isUndefined(data.SOGoCalendarCategories))
        data.SOGoCalendarCategories = [];
      data.SOGoCalendarCategoriesColorsValues = [];
      _.forEach(data.SOGoCalendarCategories, function (value) {
        data.SOGoCalendarCategoriesColorsValues.push(data.SOGoCalendarCategoriesColors[value]);
      });

      if (angular.isUndefined(data.SOGoContactsCategories))
        data.SOGoContactsCategories = [];
      else
        data.SOGoContactsCategories = _.compact(data.SOGoContactsCategories);

      angular.extend(_this.defaults, data);

      // Configure date locale
      _this.$mdDateLocaleProvider = Preferences.$mdDateLocaleProvider;
      angular.extend(_this.$mdDateLocaleProvider, data.locale);
      angular.extend(_this.$mdDateLocaleProvider, {
        firstDayOfWeek: data.SOGoFirstDayOfWeek,
        firstWeekOfYear: data.SOGoFirstWeekOfYear
      });
      _this.$mdDateLocaleProvider.firstDayOfWeek = parseInt(data.SOGoFirstDayOfWeek);
      _this.$mdDateLocaleProvider.weekNumberFormatter = function(weekNumber) {
        return l('Week %d', weekNumber);
      };
      _this.$mdDateLocaleProvider.msgCalendar = l('Calendar');
      _this.$mdDateLocaleProvider.msgOpenCalendar = l('Open Calendar');
      _this.$mdDateLocaleProvider.parseDate = function(dateString) {
        return dateString? dateString.parseDate(_this.$mdDateLocaleProvider, _this.defaults.SOGoShortDateFormat) : new Date(NaN);
      };
      _this.$mdDateLocaleProvider.formatDate = function(date) {
        return date? date.format(_this.$mdDateLocaleProvider, date.$dateFormat || _this.defaults.SOGoShortDateFormat) : '';
      };
      _this.$mdDateLocaleProvider.parseTime = function(timeString) {
        return timeString? timeString.parseDate(_this.$mdDateLocaleProvider, _this.defaults.SOGoTimeFormat) : new Date(NaN);
      };
      _this.$mdDateLocaleProvider.formatTime = function(date) {
        return date? date.format(_this.$mdDateLocaleProvider, _this.defaults.SOGoTimeFormat) : '';
      };
      _this.$mdDateLocaleProvider.isDateComplete = function(dateString) {
        dateString = dateString.trim();
        // The default function of Angular Material doesn't handle non-latin characters.
        // This one does.
        var re = /^((([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})$/;
        return re.test(dateString);
      };
    }

    settingsElement = Preferences.$document[0].getElementById('UserSettings');
    if (settingsElement) {
      try {
        data = angular.fromJson(settingsElement.textContent || settingsElement.innerHTML);
      } catch (e) {
        Preferences.$log.error("Can't parse user's settings: " + e.message);
        data = {};
      }

      // We convert our PreventInvitationsWhitelist hash into a array of user
      if (data.Calendar) {
        if (data.Calendar.PreventInvitationsWhitelist) {
          data.Calendar.PreventInvitationsWhitelist = _.map(data.Calendar.PreventInvitationsWhitelist, function(value, key) {
            var match = /^(.+)\s<(\S+)>$/.exec(value),
                user = new Preferences.$User({uid: key, cn: match[1], c_email: match[2]});
            if (!user.$$image)
              user.$$image = _this.avatar(user.c_email, 32, {no_404: true});
            return user;
          });
        }
        else
          data.Calendar.PreventInvitationsWhitelist = [];
      }

      angular.extend(_this.settings, data);
    }
  }

  /**
   * @memberof Preferences
   * @desc The factory we'll use to register with Angular
   * @returns the Preferences constructor
   */
  Preferences.$factory = ['$document', '$q', '$timeout', '$log', '$mdDateLocale', 'sgSettings', 'Gravatar', 'Resource', 'User', function($document, $q, $timeout, $log, $mdDateLocaleProvider, Settings, Gravatar, Resource, User) {
    angular.extend(Preferences, {
      $document: $document,
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $mdDateLocaleProvider: $mdDateLocaleProvider,
      $gravatar: Gravatar,
      $$resource: new Resource(Settings.activeUser('folderURL'), Settings.activeUser()),
      $resourcesURL: Settings.resourcesURL(),
      $User: User
    });

    return new Preferences(); // return unique instance
  }];

  /* Initialize module if necessary */
  try {
    angular.module('SOGo.PreferencesUI');
  }
  catch(e) {
    angular.module('SOGo.PreferencesUI', ['SOGo.Common']);
  }

  /* Factory registration in Angular module */
  angular.module('SOGo.PreferencesUI')
    .factory('Preferences', Preferences.$factory);

  /**
   * @function ready
   * @memberof Preferences.prototype
   * @desc Combine promises used to load user's defaults and settings.
   * @return a combined promise
   */
  Preferences.prototype.ready = function() {
    Preferences.$log.warn('Preferences.ready is deprecated -- access settings/defaults directly.');
    return Preferences.$q.when(true);
  };

  /**
   * @function avatar
   * @memberof Preferences.prototype
   * @desc Get the avatar URL associated to an email address
   * @return a combined promise
   */
  Preferences.prototype.avatar = function(email, size, options) {
    var _this = this;
    var alternate_avatar = _this.defaults.SOGoAlternateAvatar, url;
    if (_this.defaults.SOGoGravatarEnabled)
      url = Preferences.$gravatar(email, size, alternate_avatar, options);
    else
      url = [Preferences.$resourcesURL, 'img', 'ic_person_grey_24px.svg'].join('/');
    if (options && options.dstObject && options.dstAttr)
      options.dstObject[options.dstAttr] = url;
    return url;
  };

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
    var preferences, labels, whitelist;

    preferences = {};
    whitelist = {};

    angular.forEach(this, function(value, key) {
      if (key != 'constructor' && key[0] != '$') {
        if (deep)
          preferences[key] = angular.copy(value);
        else
          preferences[key] = value;
      }
    });

    // Merge back mail labels keys and values
    preferences.defaults.SOGoMailLabelsColors = {};
    _.forEach(preferences.defaults.SOGoMailLabelsColorsKeys, function(key, i) {
      preferences.defaults.SOGoMailLabelsColors[key] = preferences.defaults.SOGoMailLabelsColorsValues[i];
    });
    delete preferences.defaults.SOGoMailLabelsColorsKeys;
    delete preferences.defaults.SOGoMailLabelsColorsValues;

    _.forEach(preferences.defaults.SOGoSieveFilters, function(filter) {
      _.forEach(filter.actions, function(action) {
        if (action.method == 'addflag' &&
            action.argument.charAt(0) == '_' &&
            action.argument.charAt(1) == '$')
          action.argument = action.argument.substring(1);
      });
    });

    if (!preferences.defaults.SOGoMailComposeWindowEnabled)
      delete preferences.defaults.SOGoMailComposeWindow;
    delete preferences.defaults.SOGoMailComposeWindowEnabled;

    if (!preferences.defaults.SOGoMailComposeFontSizeEnabled)
      preferences.defaults.SOGoMailComposeFontSize = 0;
    delete preferences.defaults.SOGoMailComposeFontSizeEnabled;

    if (preferences.defaults.Vacation) {
      if (preferences.defaults.Vacation.startDateEnabled)
        preferences.defaults.Vacation.startDate = preferences.defaults.Vacation.startDate.getTime()/1000;
      else {
        delete preferences.defaults.Vacation.startDateEnabled;
        preferences.defaults.Vacation.startDate = 0;
      }
      if (preferences.defaults.Vacation.endDateEnabled)
        preferences.defaults.Vacation.endDate = preferences.defaults.Vacation.endDate.getTime()/1000;
      else {
        delete preferences.defaults.Vacation.endDateEnabled;
        preferences.defaults.Vacation.endDate = 0;
      }

      if (preferences.defaults.Vacation.autoReplyEmailAddresses)
        preferences.defaults.Vacation.autoReplyEmailAddresses = _.filter(preferences.defaults.Vacation.autoReplyEmailAddresses.split(","), function(v) { return v.length; });
      else
        preferences.defaults.Vacation.autoReplyEmailAddresses = [];
    }

    if (preferences.defaults.Forward && preferences.defaults.Forward.forwardAddress)
      preferences.defaults.Forward.forwardAddress = preferences.defaults.Forward.forwardAddress.split(",");

    // Merge back calendar categories colors keys and values
    preferences.defaults.SOGoCalendarCategoriesColors = {};
    _.forEach(preferences.defaults.SOGoCalendarCategories, function(key, i) {
      preferences.defaults.SOGoCalendarCategoriesColors[key] = preferences.defaults.SOGoCalendarCategoriesColorsValues[i];
    });
    delete preferences.defaults.SOGoCalendarCategoriesColorsValues;

    if (preferences.settings.Calendar && preferences.settings.Calendar.PreventInvitationsWhitelist) {
      _.forEach(preferences.settings.Calendar.PreventInvitationsWhitelist, function(user) {
        whitelist[user.uid] = user.$shortFormat();
      });
      preferences.settings.Calendar.PreventInvitationsWhitelist = whitelist;
    }

    return preferences;
  };

})();
