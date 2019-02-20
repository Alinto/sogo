/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Attendees
   * @constructor
   * @param {object} component - a Component object instance
   */
  function Attendees(component) {
    this.component = component;
    if (this.component.attendees) {
      _.forEach(this.component.attendees, function(attendee) {
        attendee.image = Attendees.$gravatar(attendee.email, 32);
      });
    }
    this.workDaysOnly = true;
    this.slotStartTimeLimit = new Date();
    this.slotStartTimeLimit.setMinutes(0);
    this.slotStartTimeLimit.setHours(Attendees.dayStartHour);
    this.slotEndTimeLimit = new Date();
    this.slotEndTimeLimit.setMinutes(0);
    this.slotEndTimeLimit.setHours(Attendees.dayEndHour);
    this.$days = [];
    this.updateFreeBusyCoverage();
    this.updateFreeBusy();
  }

  /**
   * @memberof Attendees
   * @desc The factory we'll use to register with Angular
   * @returns the Attendees constructor
   */
  Attendees.$factory = ['$q', '$timeout', '$log', 'sgSettings', 'Attendees_ROLES', 'Preferences', 'User', 'Card', 'Gravatar', 'Resource', function($q, $timeout, $log, Settings, ROLES, Preferences, User, Card, Gravatar, Resource) {
    angular.extend(Attendees, {
      $q: $q,
      $timeout: $timeout,
      $log: $log,
      $settings: Settings,
      $User: User,
      $Preferences: Preferences,
      $Card: Card,
      $gravatar: Gravatar,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Calendar', Settings.activeUser()),
      ROLES: ROLES
    });

    Attendees.dayStartHour = parseInt(Preferences.defaults.SOGoDayStartTime.split(':')[0]);
    Attendees.dayEndHour = parseInt(Preferences.defaults.SOGoDayEndTime.split(':')[0]);

    return Attendees; // return constructor
  }];

  /**
   * @module SOGo.SchedulerUI
   * @desc Factory registration of Attendees in Angular module.
   */
  try {
    angular.module('SOGo.SchedulerUI');
  }
  catch(e) {
    angular.module('SOGo.SchedulerUI', ['SOGo.Common']);
  }
  angular.module('SOGo.SchedulerUI')
    .constant('Attendees_ROLES', {
      REQ_PARTICIPANT: 'req-participant',
      OPT_PARTICIPANT: 'opt-participant',
      NON_PARTICIPANT: 'non-participant',
      CHAIR: 'chair'
    })
    .factory('Attendees', Attendees.$factory);

  /**
   * @function timeToQuarters
   * @memberof Attendees
   * @param {date} dateTime - a Date object instance
   * @desc Return the number of quarters matching the time
   * @returns the number of quarters
   */
  Attendees.timeToQuarters = function(dateTime) {
    return dateTime.getHours() * 4 + Math.ceil(dateTime.getMinutes()/15);
  };

  /**
   * @function getLength
   * @memberof Attendees.prototype
   * @returns the number of attendees
   */
  Attendees.prototype.getLength = function() {
    return this.component.attendees ? this.component.attendees.length : 0;
  };

  /**
   * @function initOrganizer
   * @memberof Attendees.prototype
   * @desc Extend instance with organizer including her freebusy information.
   * @param {object} calendar - Calendar instance associated to current component
   */
  Attendees.prototype.initOrganizer = function(calendar) {
    var _this = this, promise;
    if (calendar && calendar.isSubscription) {
      promise = Attendees.$User.$filter(calendar.owner).then(function(results) {
        var owner = results[0];
        _this.component.organizer = {
          uid: owner.uid,
          name: owner.cn,
          email: owner.c_email
        };
      });
    }
    else {
      this.component.organizer = {
        uid: Attendees.$settings.activeUser('login'),
        name: Attendees.$settings.activeUser('identification'),
        email: Attendees.$settings.activeUser('email')
      };
      promise = Attendees.$q.when();
    }
    // Fetch organizer's freebusy
    promise.then(function() {
      _this.updateFreeBusyAttendee(_this.component.organizer);
    });
  };

  /**
   * @function add
   * @memberof Attendees.prototype
   * @desc Add an attendee and fetch his freebusy info.
   * @param {Object} card - an Card object instance to be added to the attendees list
   */
  Attendees.prototype.add = function(card, options) {
    var _this = this, attendee, list, url, params;
    if (card) {
      if (!this.component.attendees || (options && options.organizerCalendar)) {
        // No attendee yet; initialize the organizer
        this.initOrganizer(options? options.organizerCalendar : undefined);
      }
      if (card.$isList({expandable: true})) {
        // Decompose list members
        list = Attendees.$Card.$find(card.container, card.c_name);
        list.$id().then(function(listId) {
          _.forEach(list.refs, function(ref) {
            attendee = {
              name: ref.c_cn,
              email: ref.$preferredEmail(options? options.partial : undefined),
              role: Attendees.ROLES.REQ_PARTICIPANT,
              partstat: 'needs-action',
              uid: ref.c_uid,
              $avatarIcon: 'person',
            };
            if (!_.find(_this.component.attendees, function(o) {
              return o.email == attendee.email;
            })) {
              // Contact is not already an attendee, add it
              attendee.image = Attendees.$gravatar(attendee.email, 32);
              if (_this.component.attendees)
                _this.component.attendees.push(attendee);
              else
                _this.component.attendees = [attendee];
              _this.updateFreeBusyAttendee(attendee);
            }
          });
        });
      }
      else {
        // Single contact
        attendee = {
          uid: card.c_uid,
          domain: card.c_domain,
          isMSExchange: card.ismsexchange,
          name: card.c_cn,
          email: card.$preferredEmail(),
          role: Attendees.ROLES.REQ_PARTICIPANT,
          partstat: 'needs-action',
          $avatarIcon: card.$avatarIcon
        };
        if (!_.find(this.attendees, function(o) {
          return o.email == attendee.email;
        })) {
          attendee.image = Attendees.$gravatar(attendee.email, 32);
          if (this.component.attendees)
            this.component.attendees.push(attendee);
          else
            this.component.attendees = [attendee];
          this.updateFreeBusyAttendee(attendee);
        }
      }
    }
  };

  /**
   * @function nextRole
   * @memberof Attendees.prototype
   * @desc Switch the attendee to the next participation role.
   * @param {Object} attendee - the attendee definition
   */
  Attendees.prototype.nextRole = function(attendee) {
    var roles = _.values(Attendees.ROLES);
    var index = _.findIndex(roles, function(role) {
      return attendee.role === role;
    });
    attendee.role = roles[++index % 4];
  };

  /**
   * @function hasAttendee
   * @memberof Attendees.prototype
   * @desc Verify if one of the email addresses of a Card instance matches an attendee.
   * @param {Object} card - an Card object instance
   * @returns true if the Card matches an attendee
   */
  Attendees.prototype.hasAttendee = function(card) {
    var attendee = _.find(this.component.attendees, function(attendee) {
      return _.find(card.emails, function(email) {
        return email.value == attendee.email;
      });
    });
    return angular.isDefined(attendee);
  };

  /**
   * @function remove
   * @memberof Attendees.prototype
   * @desc Remove an attendee from the component.
   * @param {Object} attendee - an object literal defining an attendee
   */
  Attendees.prototype.remove = function(attendee) {
    var index = _.findIndex(this.component.attendees, function(currentAttendee) {
      return currentAttendee.email == attendee.email;
    });
    this.component.attendees.splice(index, 1);
  };

  /**
   * @function updateFreeBusyCoverage
   * @memberof Attendees.prototype
   * @desc Build a 15-minute-based representation of the component's period.
   * @returns an object literal hashed by days and hours and arrays of four 1's and 0's
   */
  Attendees.prototype.updateFreeBusyCoverage = function() {
    var _this = this, freebusy = {};
    var roundedStart, roundedEnd, startQuarter, endQuarter;

    if (this.component.start && this.component.end) {
      roundedStart = new Date(this.component.start.getTime());
      roundedEnd = new Date(this.component.end.getTime());
      if (this.component.isAllDay) {
        roundedStart.setHours(Attendees.dayStartHour);
        roundedStart.setMinutes(0);
        roundedEnd.setHours(Attendees.dayEndHour);
        roundedEnd.setMinutes(0);
        startQuarter = endQuarter = 0;
      }
      else {
        startQuarter = parseInt(roundedStart.getMinutes()/15 + 0.5);
        endQuarter = parseInt(roundedEnd.getMinutes()/15 + 0.5);
      }
      roundedStart.setMinutes(15*startQuarter);
      roundedEnd.setMinutes(15*endQuarter);

      _.forEach(roundedStart.daysUpTo(roundedEnd), function(date, index) {
        var currentDay = date.getDate(),
            dayKey = date.getDayString(),
            hourKey;
        if (dayKey === roundedStart.getDayString()) {
          hourKey = date.getHours().toString();
          freebusy[dayKey] = {};
          freebusy[dayKey][hourKey] = [];
          while (startQuarter > 0) {
            freebusy[dayKey][hourKey].push(0);
            startQuarter--;
          }
        }
        else {
          date = date.beginOfDay();
          freebusy[dayKey] = {};
        }
        while (date.getTime() < roundedEnd.getTime() &&
               date.getDate() == currentDay) {
          hourKey = date.getHours().toString();
          if (angular.isUndefined(freebusy[dayKey][hourKey]))
            freebusy[dayKey][hourKey] = [];
          freebusy[dayKey][hourKey].push(1);
          date.addMinutes(15);
        }
      });
      this.freebusy = freebusy;
    }
  };

  /**
   * @function coversFreeBusy
   * @memberof Attendees.prototype
   * @desc Check if a specific quarter matches the component's period.
   * @returns true if the quarter covers the component's period
   */
  Attendees.prototype.coversFreeBusy = function(day, hour, quarter) {
    var b = (this.freebusy &&
             angular.isDefined(this.freebusy[day]) &&
             angular.isDefined(this.freebusy[day][hour]) &&
             this.freebusy[day][hour][quarter] == 1);
    return b;
  };

  /**
   * @function getDays
   * @memberof Attendees.prototype
   * @desc Define a period of one week before and one week after the component's period or a reference date.
   * @param refDate - a Date object
   * @returns an array of objects representing the days
   */
  Attendees.prototype.getDays = function(refDate) {
    var _this = this, sd, ed, formatFcn;

    if (refDate) {
      sd = refDate;
      ed = new Date(refDate.getTime());
      ed.addMinutes(this.component.delta);
    }
    else {
      sd = this.component.start;
      ed = this.component.end;
    }

    if (this.$days.length === 0 ||
        _.findIndex(this.$days, ['getDayString', sd.getDayString()]) < 0 ||
        _.findIndex(this.$days, ['getDayString', ed.getDayString()]) < 0) {
      sd = sd.beginOfDay().addDays(-7);
      ed = ed.beginOfDay().addDays(7);
      formatFcn = Attendees.$Preferences.$mdDateLocaleProvider.formatDate;
      this.$days.splice(0, this.$days.length);
      _.forEach(sd.daysUpTo(ed), function(date) {
        date.$dateFormat = Attendees.$Preferences.defaults.SOGoLongDateFormat;
        _this.$days.push({
          stringWithSeparator: formatFcn(date),
          getDayString: date.getDayString()
        });
      });
    }

    return this.$days;
  };

  /**
   * @function updateFreeBusy
   * @memberof Attendees.prototype
   * @desc Fetch the freebusy information of the organizer and all attendees.
   * @returns a promise of the all HTTP operations
   */
  Attendees.prototype.updateFreeBusy = function(refDate) {
    var _this = this, promises = [];

    if (this.getLength() > 0) {
      if (this.component.organizer) {
        promises.push(this.updateFreeBusyAttendee(this.component.organizer, refDate));
      }
      _.forEach(_.filter(this.component.attendees, 'uid'), function(attendee) {
        promises.push(_this.updateFreeBusyAttendee(attendee, refDate));
      });
    }

    return Attendees.$q.all(promises);
  };

  /**
   * @function updateFreeBusyAttendee
   * @memberof Attendees.prototype
   * @desc Update the freebusy information for the component's period for a specific attendee.
   * @param {Object} card - an Card object instance of the attendee
   * @returns a promise of the HTTP operation if the information was not cached
   */
  Attendees.prototype.updateFreeBusyAttendee = function(attendee, refDate) {
    var promise, resource, uid, sd, ed, params, days;

    if (attendee.uid) {
      uid = attendee.uid;
      if (attendee.domain)
        uid += '@' + attendee.domain;
      days = _.map(this.getDays(refDate), 'getDayString');
      params =
        {
          sday: days[0],
          eday: days[days.length - 1]
        };

      if (attendee.isMSExchange) {
        // Attendee is not a local user, but her freebusy data is available from an external MS Exchange server;
        // we query /SOGo/so/<login_user>/freebusy.ifb/ajaxRead?uid=<uid>
        resource = Attendees.$$resource.userResource();
        params.uid = uid;
      }
      else {
        // Attendee is a user;
        // web query /SOGo/so/<uid>/freebusy.ifb/ajaxRead
        resource = Attendees.$$resource.userResource(uid);
      }

      if (angular.isUndefined(attendee.freebusy))
        attendee.freebusy = {};

      if (_.intersection(_.keys(attendee.freebusy), days).length !== days.length) {
        // Fetch FreeBusy information
        promise = resource.fetch('freebusy.ifb', 'ajaxRead', params).then(function(data) {
          _.forEach(days, function(day) {
            var hour;

            if (angular.isUndefined(attendee.freebusy[day]))
              attendee.freebusy[day] = {};

            if (angular.isUndefined(data[day]))
              data[day] = {};

            for (var i = 0; i <= 23; i++) {
              hour = i.toString();
              if (data[day][hour])
                attendee.freebusy[day][hour] = [
                  data[day][hour]["0"],
                  data[day][hour]["15"],
                  data[day][hour]["30"],
                  data[day][hour]["45"]
                ];
              else
                attendee.freebusy[day][hour] = [0, 0, 0, 0];
            }
          });
        });
      }
      else {
        promise = Attendees.$q.when();
      }

      return promise;
    }
  };


  /**
   * @function forwardFindDate
   * @memberof Attendees.prototype
   * @desc Find the next slot for which all attendees are available whitin the reference day
   * @param {date} currentStart - the reference day
   * @returns a date object or null if no slot were found
   */
  Attendees.prototype.forwardFindDate = function(currentStart) {
    var foundDate = null;
    var maxOffset = this.endLimit - this.duration;
    var offset = 0;

    if (this.firstStep) {
      offset = Math.floor(this.start.getHours() * 4 + this.start.getMinutes() / 15) + 1;
      this.firstStep = false;
    }
    else {
      offset = this.currentEntries.indexOf(0);
    }
    if (offset > -1 && offset < this.startLimit) {
      offset = this.startLimit;
    }

    while (!foundDate && offset > -1 && offset <= maxOffset) {
      var testDuration = 0;
      while (this.currentEntries[offset] === 0 && testDuration < this.duration) {
        testDuration++;
        offset++;
      }
      if (testDuration == this.duration) {
        foundDate = new Date();
        var foundTime = (currentStart.getTime() + (offset - testDuration) * 900000);
        foundDate.setTime(foundTime);
      }
      else {
        offset = this.currentEntries.indexOf(0, offset + 1);
      }
    }

    return foundDate;
  };

  /**
   * @function forwardAdjustCurrentStart
   * @memberof Attendees.prototype
   * @desc Adjust a date to the next non-weekend day
   * @param {date} currentStart - the reference day
   */
  Attendees.prototype.forwardAdjustCurrentStart = function (currentStart) {
    var day = currentStart.getDay();
    if (day === 0) {
      currentStart.addDays(1);
    }
    else if (day === 6) {
      currentStart.addDays(2);
    }
  };

  /**
   * @function backwardFindDate
   * @memberof Attendees.prototype
   * @desc Find the previous slot for which all attendees are available whitin the reference day
   * @param {date} currentStart - the reference day
   * @returns a date object or null if no slot were found
   */
  Attendees.prototype.backwardFindDate = function (currentStart) {
    var foundDate = null;
    var maxOffset = this.endLimit - this.duration;
    var offset;
    if (this.firstStep) {
      offset = Math.floor(this.start.getHours() * 4 + this.start.getMinutes() / 15) - 1;
      this.firstStep = false;
    }
    else {
      offset = this.currentEntries.lastIndexOf(0);
    }
    if (offset > maxOffset) {
      offset = maxOffset;
    }
    while (!foundDate && offset >= this.startLimit) {
      var testDuration = 0;
      var testOffset = offset;
      while (this.currentEntries[testOffset] === 0 && testDuration < this.duration) {
        testDuration++;
        testOffset++;
      }
      if (testDuration == this.duration) {
        foundDate = new Date();
        var foundTime = (currentStart.getTime() + offset * 900000);
        foundDate.setTime(foundTime);
      }
      else {
        offset = this.currentEntries.lastIndexOf(0, offset - 1);
      }
    }
    Attendees.$log.debug(['found = ' + foundDate, offset]);
    return foundDate;
  };

  /**
   * @function backwardAdjustCurrentStart
   * @memberof Attendees.prototype
   * @desc Adjust a date to the previous non-weekend day
   * @param {date} currentStart - the reference day
   */
  Attendees.prototype.backwardAdjustCurrentStart = function (currentStart) {
    var day = currentStart.getDay();
    if (day == 0) {
      currentStart.addDays(-2);
    }
    else if (day == 6) {
      currentStart.addDays(-1);
    }
  };

  /**
   * @function findSlot
   * @memberof Attendees.prototype
   * @desc Find the next or previous slot when all attendees are available.
   * @param {number} direction - the search direction (1 or -1)
   */
  Attendees.prototype.findSlot = function(direction) {
    var _this = this, currentStart;

    this.direction = direction;
    this.firstStep = true;

    if (direction > 0) {
      this.findDate = this.forwardFindDate;
      this.adjustCurrentStart = this.forwardAdjustCurrentStart;
    }
    else {
      this.findDate = this.backwardFindDate;
      this.adjustCurrentStart = this.backwardAdjustCurrentStart;
    }

    if (this.component.isAllDay) {
      // Event lasts all day within limits
      this.start = this.component.start.clone();
      this.start.setHours(Attendees.dayStartHour);
      this.start.setMinutes(0);
      this.start.setSeconds(0);

      this.end = this.component.end.clone();
      this.end.setHours(Attendees.dayEndHour);
      this.end.setMinutes(0);
      this.end.setSeconds(0);

      this.startLimit = Attendees.dayStartHour * 4; // from user's defaults
      this.endLimit = Attendees.dayEndHour * 4; // from user's defaults

      this.duration = (Attendees.dayEndHour - Attendees.dayStartHour) * 4;
    }
    else {
      // Event can be outside limits
      this.start = this.component.start;
      this.end = this.component.end;

      this.startLimit = Attendees.timeToQuarters(this.slotStartTimeLimit); // from time picker
      this.endLimit = Attendees.timeToQuarters(this.slotEndTimeLimit); // from time picker

      this.duration = Math.ceil((this.end.getTime() - this.start.getTime()) / 900000);
    }

    currentStart = this.component.start.clone();
    currentStart.setHours(0, 0, 0, 0);

    if (this.workDaysOnly) {
      this.adjustCurrentStart(currentStart);
    }

    // Start a recursive search
    return this.step(currentStart).then(function (foundDate) {
      _this.component.start = new Date(foundDate.getTime());
      _this.component.end = new Date(_this.component.start.getTime());
      _this.component.end.addMinutes(_this.component.delta);
      _this.updateFreeBusyCoverage();
      return foundDate;
    });
  };

  /**
   * @function mergeFreebusy
   * @memberof Attendees.prototype
   * @desc Merge freebusy information of organizer and all attendees for a referene date.
   * @param {date) start - the reference date
   */
  Attendees.prototype.mergeFreebusy = function(start) {
    var _this = this;
    var startDay = start.getDayString();

    return this.updateFreeBusy(start).then(function () {
      var i, j, attendee, attendeeEntries;
      _this.currentEntries = _.flatMap(_this.component.organizer.freebusy[startDay]);
      for (i = 0; i < _this.component.attendees.length; i++) {
        attendee = _this.component.attendees[i];
        if (attendee.role !== Attendees.ROLES.NON_PARTICIPANT) {
          attendeeEntries = _.flatMap(attendee.freebusy[startDay]);
          for (j = 0; j < _this.currentEntries.length; j++) {
            _this.currentEntries[j] += attendeeEntries[j];
          }
        }
      }
    });
  };

  /**
   * @function step
   * @memberof Attendees.prototype
   * @desc Recursively search for the next available slot, one day a the time.
   * @param {date) currentStart - the starting day
   */
  Attendees.prototype.step = function(currentStart) {
    var _this = this;
    // var currentStartDay = currentStart.getDayString();
    return this.mergeFreebusy(currentStart).then(function () {
      var foundDate = _this.findDate(currentStart);
      if (foundDate) {
        return foundDate;
      }
      else {
        currentStart.addDays(_this.direction > 0 ? 1 : -1);
        currentStart.setHours(0, 0, 0, 0);
        if (_this.workDaysOnly) {
          _this.adjustCurrentStart(currentStart);
        }
        return _this.step(currentStart);
      }
    });
  };

})();
