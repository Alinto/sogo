/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint loopfunc: true */
  'use strict';

  /**
   * @name Preferences
   * @constructor
   */
  function Preferences() {
    var _this = this, defaultsElement, settingsElement, data;

    this.nextAlarm = null;
    this.nextInboxPoll = null;
    this.currentToast = Preferences.$q.when(true); // Show only one toast at a time (see https://github.com/angular/material/issues/2799)
    this.lastUid = null;
    this.notifications = {};

    this.defaults = {};
    this.settings = {Mail: {}};

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

      // We convert our date objects into real date, otherwise we'll have strings
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
            angular.isString(data.Vacation.autoReplyEmailAddresses) &&
            data.Vacation.autoReplyEmailAddresses.length)
          data.Vacation.autoReplyEmailAddresses = data.Vacation.autoReplyEmailAddresses.split(/, */);
      } else
        data.Vacation = {};

      if ((angular.isUndefined(data.Vacation.autoReplyEmailAddresses) ||
          data.Vacation.autoReplyEmailAddresses.length == 0) &&
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

      if (data.Forward) {
        if (angular.isString(data.Forward.forwardAddress))
          data.Forward.forwardAddress = data.Forward.forwardAddress.split(/, */);
        else if (!angular.isArray(data.Forward.forwardAddress))
          data.Forward.forwardAddress = [];
      }

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
        var re = /^((([a-zA-Z]|[^\x00-\x7F]){2,}|[0-9]{1,4})([ .,]+|[/-])){2}(([a-zA-Z]|[^\x00-\x7F]){3,}|[0-9]{1,4})$/;
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
  Preferences.$factory = ['$window', '$document', '$q', '$timeout', '$log', '$state', '$mdDateLocale', '$mdToast', 'sgSettings', 'Gravatar', 'Resource', 'User', function($window, $document, $q, $timeout, $log, $state, $mdDateLocaleProvider, $mdToast, Settings, Gravatar, Resource, User) {
    angular.extend(Preferences, {
      $window: $window,
      $document: $document,
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $state: $state,
      $mdDateLocaleProvider: $mdDateLocaleProvider,
      $toast: $mdToast,
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
   * @function hasActiveExternalSieveScripts
   * @memberof Preferences.prototype
   * @desc Check if the user has an external Sieve script enabled.
   */
  Preferences.prototype.hasActiveExternalSieveScripts = function(value) {
    var _this = this;

    if (typeof value !== 'undefined') {
      this.defaults.hasActiveExternalSieveScripts = value;
    }
    else if (typeof this.defaults.hasActiveExternalSieveScripts !== 'undefined') {
      return this.defaults.hasActiveExternalSieveScripts;
    }
    else {
      // Fetch information from server
      this.defaults.hasActiveExternalSieveScripts = false; // default until we receive an answer
      Preferences.$$resource.quietFetch('activeExternalSieveScripts')
        .then(function() {
          _this.defaults.hasActiveExternalSieveScripts = true;
        }, function(response) {
          _this.defaults.hasActiveExternalSieveScripts = false;
          if (response.status === 404) {
            return Preferences.$q.resolve(true);
          }
        });
    }
  };

  /**
   * @function supportsNotifications
   * @memberof Preferences.prototype
   * @desc Check if the browser supports the Notifications API
   * @returns true if the browser is compatible
   * @see {@link https://notifications.spec.whatwg.org/|Notifications API}
   */
  Preferences.prototype.supportsNotifications = function () {
    if (typeof Notification === 'undefined') {
      Preferences.$log.warn("Notifications are not available for your browser.");
      return false;
    }
    return true;
  };

  /**
   * @function authorizeNotifications
   * @memberof Preferences.prototype
   * @desc Request authorization to send notifications
   */
  Preferences.prototype.authorizeNotifications = function () {
    if (this.supportsNotifications()) {
      Notification.requestPermission(function (permission) {
        return permission;
      });
    }
  };

  /**
   * @function createNotification
   * @memberof Preferences.prototype
   * @desc Display a HTML5 notification
   * @param {string} id - a unique identifier
   * @param {string} title
   * @param {object} config - parameters of the notification (body, icon, onClick)
   */
  Preferences.prototype.createNotification = function (id, title, config) {
    var _this = this,
        params = _.pick(config, ['body', 'icon']);
    if (this.supportsNotifications ()) {
      params.tag = id;
      params.lang = '';
      params.dir = 'auto';
      this.notifications[id] = new Notification(title, params);
      this.notifications[id].onclick = function () {
        config.onClick();
        _this.notifications[id].close();
      };
    }
  };

  /**
   * @function viewInboxMessage
   * @memberof Preferences.prototype
   * @desc Go to the specified message of the main account's inbox
   * @param {string} uid - the message UID
   */
  Preferences.prototype.viewInboxMessage = function(uid) {
    if (Preferences.$state.get('mail.account')) {
      // Currently in Mail module -- view message
      Preferences.$state.go('mail.account.mailbox.message', { accountId: 0, mailboxId: 'INBOX', messageId: uid });
    }
    else {
      // On a different module -- reload page
      Preferences.$window.location = Preferences.$$resource.path('Mail', 'view#!/Mail/0/INBOX/' + uid);
    }
  };

  /**
   * @function pollInbox
   * @memberof Preferences.prototype
   * @desc Poll server for new messages in main account's inbox, display notifications or toasts
   */
  Preferences.prototype.pollInbox = function() {
    var _this = this, params;

    params = {
      sortingAttributes: {
        sort: 'arrival',
        asc: 0,
        noHeaders: 0,
        dry: 1
      },
      filters: [
        {
          searchBy: 'flags',
          searchInput: 'unseen'
        }
      ]
    };

    if (this.nextInboxPoll)
      Preferences.$timeout.cancel(this.nextInboxPoll);

    if (this.inboxSyncToken)
      params.syncToken = this.inboxSyncToken;

    Preferences.$$resource.post('Mail', '0/folderINBOX/changes', params).then(function(data) {
      if (data.syncToken) {
        _this.inboxSyncToken = data.syncToken;
        Preferences.$log.debug("New syncToken is " + _this.inboxSyncToken);
      }

      if (angular.isDefined(data.headers) && data.headers.length > 0) {
        var uidHeaderIndex = data.headers[0].indexOf('uid');
        var isReadHeaderIndex = data.headers[0].indexOf('isRead');
        var fromHeaderIndex = data.headers[0].indexOf('From');
        var subjectHeaderIndex = data.headers[0].indexOf('Subject');
        var i;
        var showToast = function() {
          var _this = this;
          return Preferences.$toast.show(this)
            .then(function(response) {
              if (response === 'ok') {
                _this.viewInboxMessage(_this.locals.uid);
              }
            });
        };
        for (i = 1; i < data.headers.length; i++) {
          var headers = data.headers[i],
              uid = headers[uidHeaderIndex],
              id, href, toast;
          if (!headers[isReadHeaderIndex]) {
            // New unseen message
            Preferences.$log.debug('Show notification for message ' + uid);
            if (_this.defaults.SOGoDesktopNotifications) {
              id = 'mail-inbox-' + uid;
              href = Preferences.$state.href('mail.account.mailbox.message', { accountId: 0, mailboxId: 'INBOX', messageId: uid });
              _this.createNotification(id, headers[subjectHeaderIndex], {
                body: headers[fromHeaderIndex][0].name || headers[fromHeaderIndex][0].email,
                icon: '/SOGo.woa/WebServerResources/img/email-256px.png',
                onClick: angular.bind(_this, _this.viewInboxMessage, uid)
              });
            }
            else {
              toast = {
                locals: {
                  uid: uid,
                  title: headers[subjectHeaderIndex],
                  body: headers[fromHeaderIndex][0].name || headers[fromHeaderIndex][0].email
                },
                template: [
                  '<md-toast role="alert">',
                  '  <div class="md-toast-content">',
                  '    <div layout="row" layout-align="start center" flex>',
                  '      <md-icon class="md-primary md-hue-1">email</md-icon>',
                  '      <div class="sg-padded--left">',
                  '        <span md-truncate ng-bind="title"></span>',
                  '        <div class="sg-hint" md-truncate ng-bind="body"></div>',
                  '      </div>',
                  '      <div flex></div>',
                  '      <md-button ng-click="close()">',
                  l('View'),
                  '      </md-button>',
                  '    </div>',
                  '  </div>',
                  '</md-toast>'
                ].join(''),
                position: 'top right',
                hideDelay: 5000,
                controller: toastController,
                viewInboxMessage: _this.viewInboxMessage
              };
              _this.currentToast = _this.currentToast.then(angular.bind(toast, showToast));
            }
          }
        }
      }
    }).finally(function () {
      var refreshViewCheck = _this.defaults.SOGoRefreshViewCheck;
      if (refreshViewCheck && refreshViewCheck != 'manually')
        _this.nextInboxPoll = Preferences.$timeout(angular.bind(_this, _this.pollInbox), refreshViewCheck.timeInterval()*1000);
    });

    /**
     * @ngInject
     */
    toastController.$inject = ['scope', '$mdToast', 'title', 'body'];
    function toastController (scope, $mdToast, title, body) {
      scope.title = title;
      scope.body = body;
      scope.close = function() {
        $mdToast.hide('ok');
      };
    }
  };

  /**
   * @function getAlarms
   * @memberof Preferences.prototype
   * @desc Fetch the list of alarms from the server and schedule the last one
   */
  Preferences.prototype.getAlarms = function() {
    var _this = this;
    var now = new Date();
    var browserTime = Math.floor(now.getTime()/1000);

    Preferences.$$resource.fetch('Calendar', 'alarmslist?browserTime=' + browserTime).then(function(data) {
      var alarms = data.alarms.sort(function reverseSortByAlarmTime(a, b) {
        var x = parseInt(a[2]);
        var y = parseInt(b[2]);
        return (y - x);
      });
      if (alarms.length > 0) {
        var next = alarms.pop();
        var now = new Date();
        var utc = Math.floor(now.getTime()/1000);
        var url = next[0] + '/' + next[1];
        var alarmTime = parseInt(next[2]);
        var delay = alarmTime;
        if (alarmTime > 0) delay -= utc;
        var d = new Date(alarmTime*1000);
        //console.log ("now = " + now.toUTCString());
        //console.log ("next event " + url + " in " + delay + " seconds (on " + d.toUTCString() + ")");

        var f = angular.bind(_this, _this.showAlarm, url);

        if (_this.nextAlarm)
          Preferences.$timeout.cancel(_this.nextAlarm);

        _this.nextAlarm = Preferences.$timeout(f, delay*1000);
      }
    });
  };

  /**
   * @function showAlarm
   * @memberof Preferences.prototype
   * @desc Show the latest alarm using a notification and a toast
   * @param url The URL of the calendar component for snoozing
   */
  Preferences.prototype.showAlarm = function(url) {
    var _this = this;

    Preferences.$$resource.fetch('Calendar/' + url, '?resetAlarm=yes').then(function(data) {
      var today = new Date().beginOfDay(),
          day = data.startDate.split(/T/)[0].asDate(),
          period = [],
          id;
      if (day.getTime() != today.getTime() || data.localizedStartDate != data.localizedEndDate) {
        period.push(data.localizedStartDate);
      }
      if (!data.isAllDay) {
        period.push(data.localizedStartTime);
        period.push('-');
      }
      if (data.localizedStartDate != data.localizedEndDate) {
        period.push(data.localizedEndDate);
      }
      if (!data.isAllDay) {
        period.push(data.localizedEndTime);
      }
      if (_this.defaults.SOGoDesktopNotifications) {
        id = 'calendar-' + data.id;
        _this.createNotification(id, data.summary, {
          body: period.join(' '),
          icon: '/SOGo.woa/WebServerResources/img/event-256px.png',
          onClick: function () {
            if (Preferences.$state.get('calendars.view')) {
              // Currently in Calendar module -- go to event's day
              Preferences.$state.go('calendars.view', { view: 'day', day: day.getDayString()});
            }
            else {
              // On a different module -- reload page
              Preferences.$window.location = Preferences.$$resource.path('Calendar', 'view#!/calendar/day/' + day.getDayString());
            }
          }
        });
      }
      _this.currentToast = _this.currentToast.then(function () {
        return Preferences.$toast.show({
          position: 'top right',
          hideDelay: 0,
          template: [
            '<md-toast>',
            '  <div class="md-toast-content">',
            '    <div layout="column" layout="start end">',
            '      <p class="sg-padded--top">{{ summary }}</p>',
            '      <div layout="row" layout-align="start center">',
            '        <md-input-container>',
            '          <label style="color: white">{{ "Snooze for " | loc }}</label>',
            '          <md-select ng-model="reminder">',
            '           <md-option value="5">',
            l('5 minutes'),
            '           </md-option>',
            '           <md-option value="10">',
            l('10 minutes'),
            '           </md-option>',
            '           <md-option value="15">',
            l('15 minutes'),
            '           </md-option>',
            '           <md-option value="30">',
            l('30 minutes'),
            '           </md-option>',
            '           <md-option value="45">',
            l('45 minutes'),
            '           </md-option>',
            '           <md-option value="60">',
            l('1 hour'),
            '           </md-option>',
            '           <md-option value="1440">',
            l('1 day'),
            '           </md-option>',
            '         </md-select>',
            '        </md-input-container>',
            '        <md-button ng-click="snooze()">',
            l('Snooze'),
            '        </md-button>',
            '        <md-button ng-click="close()">',
            l('Close'),
            '        </md-button>',
            '      </div>',
            '    </div>',
            '  </div>',
            '</md-toast>'
          ].join(''),
          locals: {
            url: url
          },
          controller: AlarmController
        });
      });

        /**
       * @ngInject
       */
      AlarmController.$inject = ['scope', 'url'];
      function AlarmController(scope, url) {
        scope.summary = data.summary;
        scope.reminder = '10';
        scope.close = function() {
          Preferences.$toast.hide();
        };
        scope.snooze = function() {
          Preferences.$$resource.fetch('Calendar/' + url, 'view?snoozeAlarm=' + scope.reminder);
          Preferences.$toast.hide();
        };
      }
    });
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

    // Don't push locale definition
    delete preferences.defaults.locale;

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

    // See Account.prototype.$omit
    _.forEach(preferences.defaults.AuxiliaryMailAccounts, function (account) {
      var identities = [];
      _.forEach(account.identities, function (identity) {
        if (!identity.isReadOnly)
          identities.push(_.pick(identity, ['email', 'fullName', 'replyTo', 'signature', 'isDefault']));
      });
      account.identities = identities;
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
        preferences.defaults.Vacation.autoReplyEmailAddresses = _.compact(preferences.defaults.Vacation.autoReplyEmailAddresses);
      else
        preferences.defaults.Vacation.autoReplyEmailAddresses = [];
    }

    if (preferences.defaults.Forward && preferences.defaults.Forward.forwardAddress)
      preferences.defaults.Forward.forwardAddress = _.compact(preferences.defaults.Forward.forwardAddress);

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
