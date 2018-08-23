(function() {
  'use strict';

  /**
   * This section is inspired from angular-material/src/components/datepicker/js/calendar.js
   */

  angular
    .module('SOGo.Common')
    .directive('sgTimePane', timePaneDirective);

  function timePaneDirective() {
    return {
      template: [
        '<div class="sg-time-pane">',
        '  <div class="hours-pane">',
        '    <div ng-repeat="hoursBigLine in hours" layout="row" layout-xs="column">',
        '      <div ng-repeat="hoursLine in hoursBigLine" layout="row" class="hours">',
        '          <md-button class="hourBtn sg-time-selection-indicator" id="{{hour.id}}"',
        '                     md-no-ink',
        '                     ng-repeat="hour in hoursLine"',
        '                     ng-click="hourClickHandler(hour.displayName)">{{hour.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="min5" ng-show="is5min()">',
        '    <div layout="row" layout-xs="column">',
        '      <div ng-repeat="minutesLine in min5" layout="row">',
        '        <md-button class="minuteBtn sg-time-selection-indicator" id="{{minute.id}}"',
        '                   md-no-ink',
        '                   ng-repeat="minute in minutesLine"',
        '                   ng-click="minuteClickHandler(minute.displayName)">{{minute.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="sg-time-scroll-mask" ng-hide="is5min()">',
        '    <div class="min1" layout="row" layout-xs="column" layout-wrap>',
        '      <div ng-repeat="minutesLine in min1" layout="row" layout-align="space-around center">',
        '        <md-button class="minuteBtn sg-time-selection-indicator" id="{{minute.id}}"',
        '                   md-no-ink',
        '                   ng-repeat="minute in minutesLine"',
        '                   ng-click="minuteClickHandler(minute.displayName)">{{minute.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div flex layout="row" layout-align="center center" md-colors="::{background: \'default-background-200\'}">',
        '    <md-button class="toggleBtn md-fab md-mini" ng-bind="getToggleBtnLbl()" ng-click="toggleManual5min()"></md-button>',
        '  </div>',
        '</div>'
      ].join(''),
      scope: {},
      require: ['ngModel', 'sgTimePane', '?^mdInputContainer'],
      controller: TimePaneCtrl,
      controllerAs: 'ctrl',
      bindToController: true,
      link: function(scope, element, attrs, controllers) {
        var ngModelCtrl = controllers[0];
        var sgTimePaneCtrl = controllers[1];

        var mdInputContainer = controllers[2];
        if (mdInputContainer) {
          throw Error('sg-timepicker should not be placed inside md-input-container.');
        }

        sgTimePaneCtrl.configureNgModel(ngModelCtrl, sgTimePaneCtrl);
      }
    };
  }

  /** Next identifier for calendar instance. */
  var nextUniqueId = 0;

  /**
   * Controller for the sgTimePane component.
   * @ngInject @constructor
   */
  TimePaneCtrl.$inject = ['$element', '$scope', '$$mdDateUtil', '$mdUtil',
                          '$mdConstant', '$mdTheming', '$$rAF', '$attrs', '$mdDateLocale'];
  function TimePaneCtrl($element, $scope, $$mdDateUtil, $mdUtil,
                        $mdConstant, $mdTheming, $$rAF, $attrs, $mdDateLocale) {

    var m;

    $mdTheming($element);

    /** @final {!angular.JQLite} */
    this.$element = $element;

    /** @final {!angular.Scope} */
    this.$scope = $scope;

    /** @final */
    this.dateUtil = $$mdDateUtil;

    /** @final */
    this.$mdUtil = $mdUtil;

    /** @final */
    this.keyCode = $mdConstant.KEY_CODE;

    /** @final */
    this.$$rAF = $$rAF;

    this.timePaneElement = $element[0].querySelector('.sg-time-pane');

    // this.$q = $q;

    /** @type {!angular.NgModelController} */
    this.ngModelCtrl = null;

    /** @type {String} Class applied to the selected hour or minute cell. */
    this.SELECTED_TIME_CLASS = 'sg-time-selected';

    /** @type {String} Class applied to the focused hour or minute cell. */
    this.FOCUSED_TIME_CLASS = 'md-focus';

    /** @final {number} Unique ID for this time pane instance. */
    this.id = nextUniqueId++;

    /**
     * The date that is currently focused or showing in the calendar. This will initially be set
     * to the ng-model value if set, otherwise to today. It will be updated as the user navigates
     * to other months. The cell corresponding to the displayDate does not necesarily always have
     * focus in the document (such as for cases when the user is scrolling the calendar).
     * @type {Date}
     */
    this.displayTime = null;

    /**
     * The selected date. Keep track of this separately from the ng-model value so that we
     * can know, when the ng-model value changes, what the previous value was before it's updated
     * in the component's UI.
     *
     * @type {Date}
     */
    this.selectedTime = null;

    /**
     * Used to toggle initialize the root element in the next digest.
     * @type {Boolean}
     */
    this.isInitialized = false;

    $scope.hours=[];
    $scope.hours[0]=[];
    $scope.hours[0][0]=[];
    $scope.hours[0][1]=[];
    $scope.hours[1]=[];
    $scope.hours[1][0]=[];
    $scope.hours[1][1]=[];
    for(var i=0; i<6; i++){
      $scope.hours[0][0][i] = {id:'tp-'+this.id+'-hour-'+i, displayName:i<10?"0"+i:""+i, selected:false};
      $scope.hours[0][1][i] = {id:'tp-'+this.id+'-hour-'+(i+6),displayName:(i+6)<10?"0"+(i+6):""+(i+6), selected:false};
      $scope.hours[1][0][i] = {id:'tp-'+this.id+'-hour-'+(i+12), displayName:""+(i+12), selected:false};
      $scope.hours[1][1][i] = {id:'tp-'+this.id+'-hour-'+(i+18), displayName:""+(i+18), selected:false};
    }

    $scope.min5=[];
    $scope.min5[0]=[];
    $scope.min5[1]=[];
    for(i=0; i<6; i++){
      m=i*5;
      $scope.min5[0][i] = {id:'tp-'+this.id+'-minute5-'+m, displayName:m<10?":0"+m:":"+m, selected:true};
      $scope.min5[1][i] = {id:'tp-'+this.id+'-minute5-'+(m+30), displayName:":"+(m+30), selected:false};
    }

    $scope.min1=[];
    for(i=0; i<12; i++){
      $scope.min1[i]=[];
      for(var ii=0; ii<5; ii++){
        m=i*5 + ii;
        $scope.min1[i][ii] = {id:'tp-'+this.id+'-minute-'+m, displayName:m<10?":0"+m:":"+m, selected:true};
      }
    }

    $scope.show5min = true;
    $scope.getToggleBtnLbl = function() {
      return ($scope.is5min()) ? '>>' : '<<';
    };
    $scope.toggleManual5min = function() {
      $scope.manual5min = !$scope.is5min();
    };
    $scope.is5min = function() {
      if ($scope.manual5min === true || $scope.manual5min === false) {
        return $scope.manual5min;
      }
      else {
        return $scope.show5min;
      }
    };

    // Unless the user specifies so, the calendar should not be a tab stop.
    // This is necessary because ngAria might add a tabindex to anything with an ng-model
    // (based on whether or not the user has turned that particular feature on/off).
    if (!$attrs.tabindex) {
      $element.attr('tabindex', '-1');
    }

    var self = this;

    this.hourClickHandler = function(displayVal) {
      var updated = new Date(self.displayTime);
      updated.setHours(Number(displayVal));
      self.setNgModelValue(updated, 'hours');
    };
    $scope.hourClickHandler = this.hourClickHandler;

    this.minuteClickHandler = function(displayVal) {
      // Remove leading ':'
      var val = displayVal.substr(1);
      var updated = new Date(self.displayTime);
      updated.setMinutes(Number(val));
      self.setNgModelValue(updated, 'minutes');
    };
    $scope.minuteClickHandler = this.minuteClickHandler;

    var boundKeyHandler = angular.bind(this, this.handleKeyEvent);

    // Bind the keydown handler to the body, in order to handle cases where the focused
    // element gets removed from the DOM and stops propagating click events.
    angular.element(document.body).on('keydown', boundKeyHandler);

    $scope.$on('$destroy', function() {
      angular.element(document.body).off('keydown', boundKeyHandler);
    });
  }

  /**
   * Sets up the controller's reference to ngModelController.
   * @param {!angular.NgModelController} ngModelCtrl
   */
  TimePaneCtrl.prototype.configureNgModel = function(ngModelCtrl, sgTimePaneCtrl) {
    var self = this;

    // self.displayTime = new Date(self.$viewValue);

    self.ngModelCtrl = ngModelCtrl;

    self.$mdUtil.nextTick(function() {
      self.isInitialized = true;
    });

    ngModelCtrl.$render = function() {
      var date = this.$viewValue;
      self.$mdUtil.nextTick(function() {
        self.changeSelectedTime(date, sgTimePaneCtrl);
      });
    };
  };

  /**
   * Change the selected date in the time (ngModel value has already been changed).
   */
  TimePaneCtrl.prototype.changeSelectedTime = function(date, sgTimePaneCtrl) {
    var self = this;
    var previousSelectedTime = this.selectedTime;

    this.selectedTime = date;
    this.displayTime = new Date(date);

    // Remove the selected class from the previously selected date, if any.
    if (previousSelectedTime) {
      var prevH = previousSelectedTime.getHours();
      var prevHCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+prevH);
      if (prevHCell) {
        prevHCell.classList.remove(this.SELECTED_TIME_CLASS);
        prevHCell.setAttribute('aria-selected', 'false');
      }
      var prevM = previousSelectedTime.getMinutes();
      var prevMCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute-'+prevM);
      if (prevMCell) {
        prevMCell.classList.remove(this.SELECTED_TIME_CLASS);
        prevMCell.setAttribute('aria-selected', 'false');
      }
      var prevM5Cell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute5-'+prevM);
      if (prevM5Cell) {
        prevM5Cell.classList.remove(this.SELECTED_TIME_CLASS);
        prevM5Cell.setAttribute('aria-selected', 'false');
      }
    }

    // Apply the select class to the new selected date if it is set.
    if (date) {
      var newH = date.getHours();
      var mCell, hCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+newH);
      if (hCell) {
        hCell.classList.add(this.SELECTED_TIME_CLASS);
        hCell.setAttribute('aria-selected', 'true');
      }
      var newM = date.getMinutes();
      if (newM % 5 === 0) {
        sgTimePaneCtrl.$scope.show5min = true;
        mCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute5-'+newM);
        if (mCell) {
          mCell.classList.add(this.SELECTED_TIME_CLASS);
          mCell.setAttribute('aria-selected', 'true');
        }
      }
      else {
        sgTimePaneCtrl.$scope.show5min = false;
      }
      mCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute-'+newM);
      if (mCell) {
        mCell.classList.add(this.SELECTED_TIME_CLASS);
        mCell.setAttribute('aria-selected', 'true');
      }
    }
  };

  /**
   * Sets the ng-model value for the time pane and emits a change event.
   * @param {Date} date
   */
  TimePaneCtrl.prototype.setNgModelValue = function(date, mode) {
    this.$scope.$emit('sg-time-pane-change', { date: date, changed: mode });
    this.ngModelCtrl.$setViewValue(date);
    this.ngModelCtrl.$render();
    return date;
  };


  /*** User input handling ***/

  /**
   * Handles a key event in the calendar with the appropriate action. The action will either
   * be to select the focused date or to navigate to focus a new date.
   * @param {KeyboardEvent} event
   */
  TimePaneCtrl.prototype.handleKeyEvent = function(event) {
    var self = this;
    this.$scope.$apply(function() {
      // Capture escape and emit back up so that a wrapping component
      // (such as a time-picker) can decide to close.
      if (event.which == self.keyCode.ESCAPE || event.which == self.keyCode.TAB) {
        self.$scope.$emit('md-time-pane-close');

        if (event.which == self.keyCode.TAB) {
          event.preventDefault();
        }

        return;
      }

      // Remaining key events fall into two categories: selection and navigation.
      // Start by checking if this is a selection event.
      if (event.which === self.keyCode.ENTER) {
        self.setNgModelValue(self.displayTime, 'enter');
        event.preventDefault();
        return;
      }

      // Selection isn't occuring, so the key event is either navigation or nothing.
      /*var date = self.getFocusDateFromKeyEvent(event);
        if (date) {
        event.preventDefault();
        event.stopPropagation();

        // Since this is a keyboard interaction, actually give the newly focused date keyboard
        // focus after the been brought into view.
        self.changeDisplayTime(date).then(function () {
        self.focus(date);
        });
        }*/
    });
  };

  /**
   * Focus the cell corresponding to the given date.
   * @param {Date=} opt_date The date to be focused.
   */
  TimePaneCtrl.prototype.focus = function(opt_date, sgTimePaneCtrl) {
    var date = opt_date || this.selectedTime || this.today;

    var previousFocus = this.timePaneElement.querySelector('.md-focus');
    if (previousFocus) {
      previousFocus.classList.remove(this.FOCUSED_TIME_CLASS);
    }

    if (date) {
      var newH = date.getHours();
      var hCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+newH);
      if (hCell) {
        hCell.classList.add(this.FOCUSED_TIME_CLASS);
        hCell.focus();
      }
    }
  };
})();

(function() {
  'use strict';

  /**
   * This section is inspired from angular-material/src/components/datepicker/js/datepickerDirective.js
   */

  angular.module('SOGo.Common')
    .directive('sgTimepicker', timePickerDirective);

  /**
   * @ngdoc directive
   * @name mdTimepicker
   * @module material.components.timepicker
   *
   * @param {Date} ng-model The component's model. Expects a JavaScript Date object.
   * @param {expression=} ng-change Expression evaluated when the model value changes.
   * @param {String=} md-placeholder The time input placeholder value.
   * @param {boolean=} ng-disabled Whether the timepicker is disabled.
   * @param {boolean=} ng-required Whether a value is required for the timepicker.
   *
   * @description
   * `<sg-timepicker>` is a component used to select a single time.
   * For information on how to configure internationalization for the time picker,
   * see `$mdTimeLocaleProvider`.
   *
   * @usage
   * <hljs lang="html">
   *   <sg-timepicker ng-model="birthday"></sg-timepicker>
   * </hljs>
   *
   */

  timePickerDirective.$inject = ['$mdUtil', '$mdAria'];
  function timePickerDirective($mdUtil, $mdAria) {
    return {
      template: function(tElement, tAttrs) {
        // Buttons are not in the tab order because users can open the hours pane via keyboard
        // interaction on the text input, and multiple tab stops for one component (picker)
        // may be confusing.
        var ariaLabelValue = tAttrs.ariaLabel || tAttrs.mdPlaceholder;

        return [
          '<md-button class="sg-timepicker-button md-icon-button" type="button" ',
          '           tabindex="-1" aria-hidden="true" ',
          '           ng-click="ctrl.openTimePane($event)">',
          '  <md-icon class="sg-timepicker-icon">access_time</md-icon>',
          '</md-button>',
          '<div class="md-default-theme sg-timepicker-input-container" ',
          '     ng-class="{\'sg-timepicker-focused\': ctrl.isFocused}">',
          '  <input class="sg-timepicker-input" ',
          (ariaLabelValue ? 'aria-label="' + ariaLabelValue + '" ' : ''),
          '         aria-haspopup="true"',
          '         aria-expanded="{{ctrl.isTimeOpen}}" ',
          '         aria-owns="{{::ctrl.timePaneId}}"',
          '         ng-focus="ctrl.setFocused(true)" ng-blur="ctrl.setFocused(false)">',
          '  <md-button type="button" md-no-ink ',
          '             class="sg-timepicker-triangle-button md-icon-button" ',
          '             ng-click="ctrl.openTimePane($event)" ',
          '             aria-label="{{::ctrl.dateLocale.msgOpenCalendar}}">',
          '    <div class="sg-timepicker-expand-triangle"></div>',
          '  </md-button>',
          '</div>',
          // This pane will be detached from here and re-attached to the document body.
          '<div class="sg-timepicker-time-pane md-whiteframe-z1" id="{{::ctrl.timePaneId}}">',
          '  <div class="sg-timepicker-input-mask">',
          '    <div class="sg-timepicker-input-mask-opaque"></div>',
          // '                md-colors="::{\'box-shadow\': \'default-background-hue-1\'}"></div>', // using mdColors
          '  </div>',
          '  <div class="sg-timepicker-time">',
          '    <sg-time-pane role="dialog" aria-label="{{::ctrl.dateLocale.msgCalendar}}" ',
          '                  ng-model="ctrl.time" ng-if="ctrl.isTimeOpen"></sg-time-pane>',
          '  </div>',
          '</div>'
        ].join('');
      },
      require: ['ngModel', 'sgTimepicker', '?^form'],
      scope: {
        placeholder: '@mdPlaceholder'
      },
      controller: TimePickerCtrl,
      controllerAs: 'ctrl',
      bindToController: true,
      link: function(scope, element, attr, controllers) {
        var ngModelCtrl = controllers[0];
        var mdTimePickerCtrl = controllers[1];
        var parentForm = controllers[2];
        var mdNoAsterisk = $mdUtil.parseAttributeBoolean(attr.mdNoAsterisk);

        mdTimePickerCtrl.configureNgModel(ngModelCtrl);

        // TODO: shall we check ^mdInputContainer?
        if (parentForm) {
          // If invalid, highlights the input when the parent form is submitted.
          var parentSubmittedWatcher = scope.$watch(function() {
            return parentForm.$submitted;
          }, function(isSubmitted) {
            if (isSubmitted) {
              mdTimePickerCtrl.updateErrorState();
              parentSubmittedWatcher();
            }
          });
        }
      }
    };
  }

  /** Additional offset for the input's `size` attribute, which is updated based on its content. */
  var EXTRA_INPUT_SIZE = 3;

  /** Class applied to the container if the date is invalid. */
  var INVALID_CLASS = 'sg-timepicker-invalid';

  /** Class applied to the timepicker when it's open. */
  var OPEN_CLASS = 'sg-timepicker-open';

  /** Default time in ms to debounce input event by. */
  var DEFAULT_DEBOUNCE_INTERVAL = 500;

  /**
   * Height of the calendar pane used to check if the pane is going outside the boundary of
   * the viewport. See calendar.scss for how $md-calendar-height is computed; an extra 20px is
   * also added to space the pane away from the exact edge of the screen.
   *
   *  This is computed statically now, but can be changed to be measured if the circumstances
   *  of calendar sizing are changed.
   */
  var TIME_PANE_HEIGHT = { MIN5: { GTXS: 172 + 20, XS: 291 + 20 },
                           MIN1: { GTXS: 364 + 20, XS: 454 + 20 } };

  /**
   * Width of the calendar pane used to check if the pane is going outside the boundary of
   * the viewport. See calendar.scss for how $md-calendar-width is computed; an extra 20px is
   * also added to space the pane away from the exact edge of the screen.
   *
   *  This is computed statically now, but can be changed to be measured if the circumstances
   *  of calendar sizing are changed.
   */
  var TIME_PANE_WIDTH = { GTXS: 510 + 20, XS: 274 + 20 };

  /** Used for checking whether the current user agent is on iOS or Android. */
  var IS_MOBILE_REGEX = /ipad|iphone|ipod|android/i;

  /**
   * Controller for sg-timepicker.
   *
   * ngInject @constructor
   */
  TimePickerCtrl.$inject = ['$scope', '$element', '$attrs', '$window', '$mdConstant',
                            '$mdTheming', '$mdUtil', '$mdDateLocale', '$$mdDateUtil', '$$rAF',
                            '$mdMedia'];
  function TimePickerCtrl($scope, $element, $attrs, $window, $mdConstant,
                          $mdTheming, $mdUtil, $mdDateLocale, $$mdDateUtil, $$rAF,
                          $mdMedia) {
    /** @final */
    this.$window = $window;

    /** @final */
    this.dateLocale = $mdDateLocale;

    /** @final */
    this.dateUtil = $$mdDateUtil;

    /** @final */
    this.$mdConstant = $mdConstant;

    /* @final */
    this.$mdUtil = $mdUtil;

    /** @final */
    this.$$rAF = $$rAF;

    /** @final */
    this.$mdMedia = $mdMedia;

    /**
     * The root document element. This is used for attaching a top-level click handler to
     * close the calendar panel when a click outside said panel occurs. We use `documentElement`
     * instead of body because, when scrolling is disabled, some browsers consider the body element
     * to be completely off the screen and propagate events directly to the html element.
     * @type {!angular.JQLite}
     */
    this.documentElement = angular.element(document.documentElement);

    /** @type {!angular.NgModelController} */
    this.ngModelCtrl = null;

    /** @type {HTMLInputElement} */
    this.inputElement = $element[0].querySelector('input');

    /** @final {!angular.JQLite} */
    this.ngInputElement = angular.element(this.inputElement);

    /** @type {HTMLElement} */
    this.inputContainer = $element[0].querySelector('.sg-timepicker-input-container');

    /** @type {HTMLElement} Floating time pane. */
    this.timePane = $element[0].querySelector('.sg-timepicker-time-pane');

    /** @type {HTMLElement} Time icon button. */
    this.timeButton = $element[0].querySelector('.sg-timepicker-button');

    /**
     * Element covering everything but the input in the top of the floating calendar pane.
     * @type {HTMLElement}
     */
    this.inputMask = angular.element($element[0].querySelector('.sg-timepicker-input-mask-opaque'));

    /** @final {!angular.JQLite} */
    this.$element = $element;

    /** @final {!angular.Attributes} */
    this.$attrs = $attrs;

    /** @final {!angular.Scope} */
    this.$scope = $scope;

    /** @type {Date} */
    this.date = null;

    /** @type {boolean} */
    this.isFocused = false;

    /** @type {boolean} */
    this.isDisabled = false;
    this.setDisabled($element[0].disabled || angular.isString($attrs.disabled));

    /** @type {boolean} Whether the date-picker's calendar pane is open. */
    this.isTimeOpen = false;

    /** @type {boolean} Whether the calendar should open when the input is focused. */
    // this.openOnFocus = $attrs.hasOwnProperty('mdOpenOnFocus');

    /** @final */
    // this.mdInputContainer = null;

    /**
     * Element from which the calendar pane was opened. Keep track of this so that we can return
     * focus to it when the pane is closed.
     * @type {HTMLElement}
     */
    this.timePaneOpenedFrom = null;

    /** @type {String} Unique id for the time pane. */
    this.timePaneId = 'sg-time-pane' + $mdUtil.nextUid();

    /** Pre-bound click handler is saved so that the event listener can be removed. */
    this.bodyClickHandler = angular.bind(this, this.handleBodyClick);

    /**
     * Name of the event that will trigger a close. Necessary to sniff the browser, because
     * the resize event doesn't make sense on mobile and can have a negative impact since it
     * triggers whenever the browser zooms in on a focused input.
     */
    this.windowEventName = IS_MOBILE_REGEX.test(
      navigator.userAgent || navigator.vendor || window.opera
    ) ? 'orientationchange' : 'resize';

    /** Pre-bound close handler so that the event listener can be removed. */
    this.windowEventHandler = $mdUtil.debounce(angular.bind(this, this.closeTimePane), 100);

    /** Pre-bound handler for the window blur event. Allows for it to be removed later. */
    this.windowBlurHandler = angular.bind(this, this.handleWindowBlur);

    /** @type {Number} Extra margin for the left side of the floating calendar pane. */
    this.leftMargin = 20;

    /** @type {Number} Extra margin for the top of the floating calendar. Gets determined on the first open. */
    this.topMargin = null;

    // Unless the user specifies so, the timepicker should not be a tab stop.
    // This is necessary because ngAria might add a tabindex to anything with an ng-model
    // (based on whether or not the user has turned that particular feature on/off).
    if ($attrs.tabindex) {
      this.ngInputElement.attr('tabindex', $attrs.tabindex);
      $attrs.$set('tabindex', null);
    } else {
      $attrs.$set('tabindex', '-1');
    }

    $mdTheming($element);
    $mdTheming(angular.element(this.timePane));

    this.installPropertyInterceptors();
    this.attachChangeListeners();
    this.attachInteractionListeners();

    var self = this;

    $scope.$on('$destroy', function() {
      self.detachTimePane();
    });
  }

  /**
   * Sets up the controller's reference to ngModelController.
   * @param {!angular.NgModelController} ngModelCtrl Instance of the ngModel controller.
   */
  TimePickerCtrl.prototype.configureNgModel = function(ngModelCtrl) {
    this.ngModelCtrl = ngModelCtrl;

    var self = this;

    // Responds to external changes to the model value.
    self.ngModelCtrl.$formatters.push(function(value) {
      if (value && !(value instanceof Date)) {
        throw Error('The ng-model for sg-timepicker must be a Date instance. ' +
                    'Currently the model is a: ' + (typeof value));
      }

      self.time = value;
      self.inputElement.value = self.dateLocale.formatTime(value);
      self.resizeInputElement();
      self.updateErrorState();

      return value;
    });

    // Responds to external error state changes (e.g. ng-required based on another input).
    ngModelCtrl.$viewChangeListeners.unshift(angular.bind(this, this.updateErrorState));
  };

  /**
   * Attach event listeners for both the text input and the md-time.
   * Events are used instead of ng-model so that updates don't infinitely update the other
   * on a change. This should also be more performant than using a $watch.
   */
  TimePickerCtrl.prototype.attachChangeListeners = function() {
    var self = this;

    self.$scope.$on('sg-time-pane-change', function(event, data) {
      var time = new Date(data.date);
      self.ngModelCtrl.$setViewValue(time);
      self.time = time;
      self.inputElement.value = self.dateLocale.formatTime(time);
      if (data.changed == 'minutes') {
        self.closeTimePane();
      }
      self.resizeInputElement();
      self.inputContainer.classList.remove(INVALID_CLASS);
    });

    self.ngInputElement.on('input', angular.bind(self, self.resizeInputElement));

    var debounceInterval = angular.isDefined(this.debounceInterval) ?
        this.debounceInterval : DEFAULT_DEBOUNCE_INTERVAL;
    self.ngInputElement.on('input', self.$mdUtil.debounce(self.handleInputEvent,
                                                          debounceInterval, self));
  };

  /** Attach event listeners for user interaction. */
  TimePickerCtrl.prototype.attachInteractionListeners = function() {
    var self = this;
    var $scope = this.$scope;
    var keyCodes = this.$mdConstant.KEY_CODE;

    // Add event listener through angular so that we can triggerHandler in unit tests.
    self.ngInputElement.on('keydown', function(event) {
      if (event.altKey && event.keyCode == keyCodes.DOWN_ARROW) {
        self.openTimePane(event);
        $scope.$digest();
      }
    });

    $scope.$on('md-time-close', function() {
      self.closeTimePane();
    });
  };

  /**
   * Capture properties set to the time-picker and imperitively handle internal changes.
   * This is done to avoid setting up additional $watches.
   */
  TimePickerCtrl.prototype.installPropertyInterceptors = function() {
    var self = this;

    if (this.$attrs.ngDisabled) {
      // The expression is to be evaluated against the directive element's scope and not
      // the directive's isolate scope.
      var scope = this.$scope.$parent;

      if (scope) {
        scope.$watch(this.$attrs.ngDisabled, function(isDisabled) {
          self.setDisabled(isDisabled);
        });
      }
    }

    Object.defineProperty(this, 'placeholder', {
      get: function() { return self.inputElement.placeholder; },
      set: function(value) { self.inputElement.placeholder = value || ''; }
    });
  };

  /**
   * Sets whether the date-picker is disabled.
   * @param {boolean} isDisabled
   */
  TimePickerCtrl.prototype.setDisabled = function(isDisabled) {
    this.isDisabled = isDisabled;
    this.inputElement.disabled = isDisabled;

    if (this.timeButton) {
      this.timeButton.disabled = isDisabled;
    }
  };

  /**
   * Sets the custom ngModel.$error flags to be consumed by ngMessages. Flags are:
   *   - mindate: whether the selected date is before the minimum date.
   *   - maxdate: whether the selected flag is after the maximum date.
   *   - filtered: whether the selected date is allowed by the custom filtering function.
   *   - valid: whether the entered text input is a valid date
   *
   * The 'required' flag is handled automatically by ngModel.
   *
   * @param {Date=} opt_date Date to check. If not given, defaults to the datepicker's model value.
   */
  TimePickerCtrl.prototype.updateErrorState = function(opt_date) {
    var date = opt_date || this.date;

    // Clear any existing errors to get rid of anything that's no longer relevant.
    this.clearErrorState();

    if (!this.dateUtil.isValidDate(date)) {
      // The date is seen as "not a valid date" if there is *something* set
      // (i.e.., not null or undefined), but that something isn't a valid date.
      this.ngModelCtrl.$setValidity('valid', date === null);
    }

    // TODO(jelbourn): Change this to classList.toggle when we stop using PhantomJS in unit tests
    // because it doesn't conform to the DOMTokenList spec.
    // See https://github.com/ariya/phantomjs/issues/12782.
    if (!this.ngModelCtrl.$valid) {
      this.inputContainer.classList.add(INVALID_CLASS);
    }
  };

  /** Clears any error flags set by `updateErrorState`. */
  TimePickerCtrl.prototype.clearErrorState = function() {
    this.inputContainer.classList.remove(INVALID_CLASS);
    ['valid'].forEach(function(field) {
      this.ngModelCtrl.$setValidity(field, true);
    }, this);
  };

  /**
   * Resizes the input element based on the size of its content.
   */
  TimePickerCtrl.prototype.resizeInputElement = function() {
    this.inputElement.size = this.inputElement.value.length + EXTRA_INPUT_SIZE;
  };

  /**
   * Sets the model value if the user input is a valid time.
   * Adds an invalid class to the input element if not.
   */
  TimePickerCtrl.prototype.handleInputEvent = function(self) {
    var inputString = this.inputElement.value;
    var parsedTime = inputString ? this.dateLocale.parseTime(inputString) : null;

    // An input string is valid if it is either empty (representing no date)
    // or if it parses to a valid time that the user is allowed to select.
    var isValidInput = inputString === '' || this.dateUtil.isValidDate(parsedTime);

    // The datepicker's model is only updated when there is a valid input.
    if (isValidInput) {
      var updated = new Date(this.time);
      updated.setHours(parsedTime.getHours());
      updated.setMinutes(parsedTime.getMinutes());
      this.ngModelCtrl.$setViewValue(updated);
      this.time = updated;
    }

    this.updateErrorState(parsedTime);
  };

  /** Position and attach the floating calendar to the document. */
  TimePickerCtrl.prototype.attachTimePane = function() {
    var timePane = this.timePane;
    var body = document.body;

    timePane.style.transform = '';
    this.$element.addClass(OPEN_CLASS);
    // this.mdInputContainer && this.mdInputContainer.element.addClass(OPEN_CLASS);
    angular.element(body).addClass('md-datepicker-is-showing');

    var elementRect = this.inputContainer.getBoundingClientRect();
    var bodyRect = body.getBoundingClientRect();

    if (!this.topMargin || this.topMargin < 0) {
      this.topMargin = (this.inputMask.parent().prop('clientHeight') - this.ngInputElement.prop('clientHeight')) / 2;
    }

    // Check to see if the calendar pane would go off the screen. If so, adjust position
    // accordingly to keep it within the viewport.
    var paneTop = elementRect.top - bodyRect.top - this.topMargin;
    var paneLeft = elementRect.left - bodyRect.left - this.leftMargin;

    // If ng-material has disabled body scrolling (for example, if a dialog is open),
    // then it's possible that the already-scrolled body has a negative top/left. In this case,
    // we want to treat the "real" top as (0 - bodyRect.top). In a normal scrolling situation,
    // though, the top of the viewport should just be the body's scroll position.
    var viewportTop = (bodyRect.top < 0 && body.scrollTop === 0) ?
        -bodyRect.top :
        document.body.scrollTop;

    var viewportLeft = (bodyRect.left < 0 && body.scrollLeft === 0) ?
        -bodyRect.left :
        document.body.scrollLeft;

    var viewportBottom = viewportTop + this.$window.innerHeight;
    var viewportRight = viewportLeft + this.$window.innerWidth;

    // Creates an overlay with a hole the same size as element. We remove a pixel or two
    // on each end to make it overlap slightly. The overlay's background is added in
    // the theme in the form of a box-shadow with a huge spread.
    this.inputMask.css({
      position: 'absolute',
      left: this.leftMargin + 'px',
      top: this.topMargin + 'px',
      width: (elementRect.width - 1) + 'px',
      height: (elementRect.height - 2) + 'px'
    });

    // If the right edge of the pane would be off the screen and shifting it left by the
    // difference would not go past the left edge of the screen. If the time pane is too
    // big to fit on the screen at all, move it to the left of the screen and scale the entire
    // element down to fit.
    var paneWidth = this.$mdMedia('xs')? TIME_PANE_WIDTH.XS : TIME_PANE_WIDTH.GTXS;
    if (paneLeft + paneWidth > viewportRight) {
      if (viewportRight - paneWidth > 0) {
        paneLeft = viewportRight - paneWidth;
      } else {
        paneLeft = viewportLeft;
        var scale = this.$window.innerWidth / paneWidth;
        timePane.style.transform = 'scale(' + scale + ')';
      }

      timePane.classList.add('sg-timepicker-pos-adjusted');
    }

    // If the bottom edge of the pane would be off the screen and shifting it up by the
    // difference would not go past the top edge of the screen.
    var min = (typeof this.time == 'object' && this.time.getMinutes() % 5 === 0)? 'MIN5' : 'MIN1';
    var paneHeight = this.$mdMedia('xs')? TIME_PANE_HEIGHT[min].XS : TIME_PANE_HEIGHT[min].GTXS;
    if (paneTop + paneHeight > viewportBottom &&
        viewportBottom - paneHeight > viewportTop) {
      paneTop = viewportBottom - paneHeight;
      timePane.classList.add('sg-timepicker-pos-adjusted');
    }

    timePane.style.left = paneLeft + 'px';
    timePane.style.top = paneTop + 'px';
    document.body.appendChild(timePane);

    // Add CSS class after one frame to trigger open animation.
    this.$$rAF(function() {
      timePane.classList.add('md-pane-open');
    });
  };

  /** Detach the floating time pane from the document. */
  TimePickerCtrl.prototype.detachTimePane = function() {
    this.$element.removeClass(OPEN_CLASS);
    //this.mdInputContainer && this.mdInputContainer.element.removeClass(OPEN_CLASS);
    angular.element(document.body).removeClass('md-datepicker-is-showing');
    this.timePane.classList.remove('md-pane-open');
    this.timePane.classList.remove('md-timepicker-pos-adjusted');

    if (this.isTimeOpen) {
      this.$mdUtil.enableScrolling();
    }

    if (this.timePane.parentNode) {
      // Use native DOM removal because we do not want any of the angular state of this element
      // to be disposed.
      this.timePane.parentNode.removeChild(this.timePane);
    }
  };

  /**
   * Open the floating time pane.
   * @param {Event} event
   */
  TimePickerCtrl.prototype.openTimePane = function(event) {
    if (!this.isTimeOpen && !this.isDisabled) {
      this.isTimeOpen = true;
      this.timePaneOpenedFrom = event.target;

      // Because the time pane is attached directly to the body, it is possible that the
      // rest of the component (input, etc) is in a different scrolling container, such as
      // an md-content. This means that, if the container is scrolled, the pane would remain
      // stationary. To remedy this, we disable scrolling while the time pane is open, which
      // also matches the native behavior for things like `<select>` on Mac and Windows.
      this.$mdUtil.disableScrollAround(this.timePane);

      this.attachTimePane();
      //this.focusTime();
      this.evalAttr('ngFocus');

      // Attach click listener inside of a timeout because, if this open call was triggered by a
      // click, we don't want it to be immediately propogated up to the body and handled.
      var self = this;
      this.$mdUtil.nextTick(function() {
        // Use 'touchstart` in addition to click in order to work on iOS Safari, where click
        // events aren't propogated under most circumstances.
        // See http://www.quirksmode.org/blog/archives/2014/02/mouse_event_bub.html
        self.documentElement.on('click touchstart', self.bodyClickHandler);
      }, false);

      window.addEventListener(this.windowEventName, this.windowEventHandler);
    }
  };

  /** Close the floating time pane. */
  TimePickerCtrl.prototype.closeTimePane = function() {
    if (this.isTimeOpen) {
      var self = this;

      self.detachTimePane();
      self.ngModelCtrl.$setTouched();
      self.evalAttr('ngBlur');

      self.documentElement.off('click touchstart', self.bodyClickHandler);
      window.removeEventListener(self.windowEventName, self.windowEventHandler);

      self.timePaneOpenedFrom.focus();
      self.timePaneOpenedFrom = null;

      self.isTimeOpen = false;
    }
  };

  /** Gets the controller instance for the time in the floating pane. */
  TimePickerCtrl.prototype.getTimePaneCtrl = function() {
    return angular.element(this.timePane.querySelector('sg-time-pane')).controller('sgTimePane');
  };

  /** Focus the time in the floating pane. */
  TimePickerCtrl.prototype.focusTime = function() {
    // Use a timeout in order to allow the time to be rendered, as it is gated behind an ng-if.
    var self = this;
    this.$mdUtil.nextTick(function() {
      var ctrl = self.getTimePaneCtrl();
      self.getTimePaneCtrl().focus(null, ctrl);
    }, false);
  };

  /**
   * Sets whether the input is currently focused.
   * @param {boolean} isFocused
   */
  TimePickerCtrl.prototype.setFocused = function(isFocused) {
    if (!isFocused) {
      this.ngModelCtrl.$setTouched();
    }

    this.evalAttr(isFocused ? 'ngFocus' : 'ngBlur');

    this.isFocused = isFocused;
  };

  /**
   * Handles a click on the document body when the floating time pane is open.
   * Closes the floating time pane if the click is not inside of it.
   * @param {MouseEvent} event
   */
  TimePickerCtrl.prototype.handleBodyClick = function(event) {
    if (this.isTimeOpen) {
      var isInTime = this.$mdUtil.getClosest(event.target, 'sg-time-pane');

      if (!isInTime) {
        this.closeTimePane();
      }

      this.$scope.$digest();
    }
  };

  /**
   * Handles the event when the user navigates away from the current tab. Keeps track of
   * whether the input was focused when the event happened, in order to prevent the time pane
   * from re-opening.
   */
  TimePickerCtrl.prototype.handleWindowBlur = function() {
    this.inputFocusedOnWindowBlur = document.activeElement === this.inputElement;
  };

  /**
   * Evaluates an attribute expression against the parent scope.
   * @param {String} attr Name of the attribute to be evaluated.
   */
  TimePickerCtrl.prototype.evalAttr = function(attr) {
    if (this.$attrs[attr]) {
      this.$scope.$parent.$eval(this.$attrs[attr]);
    }
  };
})();
