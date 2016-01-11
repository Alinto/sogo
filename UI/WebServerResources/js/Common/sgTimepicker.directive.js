(function() {
  'use strict';

  angular
    .module('SOGo.Common')
    .directive('sgTimePane', timePaneDirective);
  
  function timePaneDirective() {
    return {
      template: [
        '<div class="sg-time-pane">',
        '  <div class="hours-pane">',
        '    <div ng-repeat="hoursBigLine in hours" layout="row" layout-sm="column">',
        '      <div ng-repeat="hoursLine in hoursBigLine" layout="row" class="hours">',
        '          <md-button class="hourBtn md-fab md-mini" ng-repeat="hour in hoursLine" id="{{hour.id}}"',
        '                     ng-click="hourClickHandler(hour.displayName)">{{hour.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="min5" ng-show="is5min()">',
        '    <div layout="row" layout-sm="column">',
        '      <div ng-repeat="minutesLine in min5" layout="row">',
        '        <md-button class="minuteBtn md-fab md-mini" ng-repeat="minute in minutesLine" id="{{minute.id}}"',
        '                   ng-click="minuteClickHandler(minute.displayName)">{{minute.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div class="sg-time-scroll-mask" ng-hide="is5min()">',
        '    <div class="min1" layout="row" layout-sm="column" layout-wrap>',
        '      <div ng-repeat="minutesLine in min1" layout="row" layout-align="space-around center" flex="50">',
        '        <md-button class="minuteBtn md-fab md-mini" ng-repeat="minute in minutesLine" id="{{minute.id}}"',
        '                   ng-click="minuteClickHandler(minute.displayName)">{{minute.displayName}}</md-button>',
        '      </div>',
        '    </div>',
        '  </div>',
        '  <div flex layout="row" layout-align="center center" class="toggle-pane">',
        '    <md-button class="toggleBtn md-fab md-mini" ng-bind="getToggleBtnLbl()" ng-click="toggleManual5min()"></md-button>',
        '  </div>',
        '</div>'
      ].join(''),
      scope: {},
      require: ['ngModel', 'sgTimePane'],
      controller: TimePaneCtrl,
      controllerAs: 'ctrl',
      bindToController: true,
      link: function(scope, element, attrs, controllers) {
        var ngModelCtrl = controllers[0];
        var sgTimePaneCtrl = controllers[1];
        var timePaneElement = element;
        sgTimePaneCtrl.configureNgModel(ngModelCtrl, sgTimePaneCtrl, timePaneElement);
      }
    };
  }

  /** Class applied to the selected hour or minute cell/. */
  var SELECTED_TIME_CLASS = 'md-bg';

  /** Class applied to the focused hour or minute cell/. */
  var FOCUSED_TIME_CLASS = 'md-focus';

  /** Next identifier for calendar instance. */
  var nextTimePaneUniqueId = 0;

  function TimePaneCtrl($element, $attrs, $scope, $animate, $q, $mdConstant,
                        $mdTheming, $$mdDateUtil, $mdDateLocale, $mdInkRipple, $mdUtil) {
    var m;
    this.$scope = $scope;
    this.$element = $element;
    this.timePaneElement = $element[0].querySelector('.sg-time-pane');
    this.$animate = $animate;
    this.$q = $q;
    this.$mdInkRipple = $mdInkRipple;
    this.$mdUtil = $mdUtil;
    this.keyCode = $mdConstant.KEY_CODE;
    this.dateUtil = $$mdDateUtil;
    this.id = nextTimePaneUniqueId++;
    this.ngModelCtrl = null;
    this.selectedTime = null;
    this.displayTime = null;
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
      //remove leading ':'
      var val = displayVal.substr(1);
      var updated = new Date(self.displayTime);
      updated.setMinutes(Number(val));
      self.setNgModelValue(updated, 'minutes');
    };
    $scope.minuteClickHandler = this.minuteClickHandler;

    this.attachTimePaneEventListeners();
  }
  TimePaneCtrl.$inject = ["$element", "$attrs", "$scope", "$animate", "$q", "$mdConstant", "$mdTheming", "$$mdDateUtil", "$mdDateLocale", "$mdInkRipple", "$mdUtil"];

  TimePaneCtrl.prototype.configureNgModel = function(ngModelCtrl, sgTimePaneCtrl, timePaneElement) {
    this.ngModelCtrl = ngModelCtrl;

    var self = this;
    ngModelCtrl.$render = function() {
      self.changeSelectedTime(self.ngModelCtrl.$viewValue, sgTimePaneCtrl, timePaneElement);
    };
  };

  /**
   * Change the selected date in the time (ngModel value has already been changed).
   */
  TimePaneCtrl.prototype.changeSelectedTime = function(date, sgTimePaneCtrl, timePaneElement) {
    var self = this;
    var previousSelectedTime = this.selectedTime;
    this.selectedTime = date;
    this.changeDisplayTime(date).then(function() {

      // Remove the selected class from the previously selected date, if any.
      if (previousSelectedTime) {
        var prevH = previousSelectedTime.getHours();
        var prevHCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+prevH);
        if (prevHCell) {
          prevHCell.classList.remove(SELECTED_TIME_CLASS);
          prevHCell.setAttribute('aria-selected', 'false');
        }
        var prevM = previousSelectedTime.getMinutes();
        var prevMCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute-'+prevM);
        if (prevMCell) {
          prevMCell.classList.remove(SELECTED_TIME_CLASS);
          prevMCell.setAttribute('aria-selected', 'false');
        }
        var prevM5Cell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute5-'+prevM);
        if (prevM5Cell) {
          prevM5Cell.classList.remove(SELECTED_TIME_CLASS);
          prevM5Cell.setAttribute('aria-selected', 'false');
        }
      }

      // Apply the select class to the new selected date if it is set.
      if (date) {
        var newH = date.getHours();
        var mCell, hCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+newH);
        if (hCell) {
          hCell.classList.add(SELECTED_TIME_CLASS);
          hCell.setAttribute('aria-selected', 'true');
        }
        var newM = date.getMinutes();
        if (newM % 5 === 0) {
          sgTimePaneCtrl.$scope.show5min = true;
          mCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute5-'+newM);
          if (mCell) {
            mCell.classList.add(SELECTED_TIME_CLASS);
            mCell.setAttribute('aria-selected', 'true');
          }
        }
        else {
          sgTimePaneCtrl.$scope.show5min = false;
        }
        mCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-minute-'+newM);
        if (mCell) {
          mCell.classList.add(SELECTED_TIME_CLASS);
          mCell.setAttribute('aria-selected', 'true');
        }

      }
    });
  };

  TimePaneCtrl.prototype.changeDisplayTime = function(date) {
    var d = new Date(date);
    if (!this.isInitialized) {
      this.buildInitialTimePaneDisplay();
      return this.$q.when();
    }
    if (!this.dateUtil.isValidDate(d)) {
      return this.$q.when();
    }

    this.displayTime = d;

    return this.$q.when();
  };
  TimePaneCtrl.prototype.buildInitialTimePaneDisplay = function() {
    this.displayTime = this.selectedTime || this.today;
    this.isInitialized = true;
  };

  TimePaneCtrl.prototype.attachTimePaneEventListeners = function() {
    // Keyboard interaction.
    this.$element.on('keydown', angular.bind(this, this.handleKeyEvent));
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
   * Sets the ng-model value for the time pane and emits a change event.
   * @param {Date} date
   */
  TimePaneCtrl.prototype.setNgModelValue = function(date, mode) {
    this.$scope.$emit('sg-time-pane-change', {date:date, changed:mode});
    this.ngModelCtrl.$setViewValue(date);
    this.ngModelCtrl.$render();
  };

  /**
   * Focus the cell corresponding to the given date.
   * @param {Date=} opt_date
   */
  TimePaneCtrl.prototype.focus = function(opt_date, sgTimePaneCtrl) {
    var date = opt_date || this.selectedTime || this.today;

    var previousFocus = this.timePaneElement.querySelector('.md-focus');
    if (previousFocus) {
      previousFocus.classList.remove(FOCUSED_TIME_CLASS);
    }

    if (date) {
      var newH = date.getHours();
      var hCell = document.getElementById('tp-'+sgTimePaneCtrl.id+'-hour-'+newH);
      if (hCell) {
        hCell.classList.add(FOCUSED_TIME_CLASS);
        hCell.focus();
      }
    }
  };
})();

(function() {
  'use strict';
  
  angular.module('SOGo.Common')
    .directive('sgTimepicker', timePickerDirective);

  /**
   * @ngdoc directive
   * @name mdTimepicker
   * @module material.components.timepicker
   *
   * @param {Date} ng-model The component's model. Expects a JavaScript Date object.
   * @param {expression=} ng-change Expression evaluated when the model value changes.
   * @param {boolean=} disabled Whether the timepicker is disabled.
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
  function timePickerDirective() {
    return {
      template: [
        // Buttons are not in the tab order because users can open the hours pane via keyboard
        // interaction on the text input, and multiple tab stops for one component (picker)
        // may be confusing.
        '<md-button class="sg-timepicker-button md-icon-button" type="button" ',
        '           tabindex="-1" aria-hidden="true" ',
        '           ng-click="ctrl.openTimePane($event)">',
        '  <md-icon>access_time</md-icon>',
        '</md-button>',
        '<div class="md-default-theme sg-timepicker-input-container" ',
        '     ng-class="{\'sg-timepicker-focused\': ctrl.isFocused,',
        '                \'md-bdr\': ctrl.isFocused}">',
        '  <input class="sg-timepicker-input" aria-haspopup="true" ',
        '         ng-focus="ctrl.setFocused(true)" ng-blur="ctrl.setFocused(false)">',
        '  <md-button type="button" md-no-ink ',
        '             class="sg-timepicker-triangle-button md-icon-button" ',
        '             ng-click="ctrl.openTimePane($event)" ',
        '             aria-label="{{::ctrl.dateLocale.msgOpenCalendar}}">',
        '    <div class="sg-timepicker-expand-triangle"></div>',
        '  </md-button>',
        '</div>',
        // This pane will be detached from here and re-attached to the document body.
        '<div class="sg-timepicker-time-pane md-whiteframe-z1">',
        '  <div class="sg-timepicker-input-mask">',
        '    <div class="sg-timepicker-input-mask-opaque',
        '                md-default-theme md-background md-bg"></div>', // using mdColors
        '  </div>',
        '  <div class="sg-timepicker-time md-default-theme md-bg md-background">',
        '    <sg-time-pane role="dialog" aria-label="{{::ctrl.dateLocale.msgCalendar}}" ',
        '                  ng-model="ctrl.time" ng-if="ctrl.isTimeOpen"></sg-time-pane>',
        '  </div>',
        '</div>'
      ].join(''),
      require: ['ngModel', 'sgTimepicker'],
      scope: {
        placeholder: '@mdPlaceholder'
      },
      controller: TimePickerCtrl,
      controllerAs: 'ctrl',
      bindToController: true,
      link: function(scope, element, attr, controllers) {
        var ngModelCtrl = controllers[0];
        var mdTimePickerCtrl = controllers[1];

        mdTimePickerCtrl.configureNgModel(ngModelCtrl);
      }
    };
  }

  /** Additional offset for the input's `size` attribute, which is updated based on its content. */
  var EXTRA_INPUT_SIZE = 3;

  /** Class applied to the container if the date is invalid. */
  var INVALID_CLASS = 'sg-timepicker-invalid';

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
  var TIME_PANE_HEIGHT = { MIN5: { GTSM: 172 + 20, SM: 292 + 20 },
                           MIN1: { GTSM: 364 + 20, SM: 454 + 20 } };

  /**
   * Width of the calendar pane used to check if the pane is going outside the boundary of
   * the viewport. See calendar.scss for how $md-calendar-width is computed; an extra 20px is
   * also added to space the pane away from the exact edge of the screen.
   *
   *  This is computed statically now, but can be changed to be measured if the circumstances
   *  of calendar sizing are changed.
   */
  var TIME_PANE_WIDTH = { GTSM: 510 + 20, SM: 272 + 20 };

  /**
   * Controller for sg-timepicker.
   *
   * ngInject @constructor
   */
  TimePickerCtrl.$inject = ["$scope", "$element", "$attrs", "$compile", "$timeout", "$window",
                            "$mdConstant", "$mdMedia", "$mdTheming", "$mdUtil", "$mdDateLocale", "$$mdDateUtil", "$$rAF"];
  function TimePickerCtrl($scope, $element, $attrs, $compile, $timeout, $window,
                          $mdConstant, $mdMedia, $mdTheming, $mdUtil, $mdDateLocale, $$mdDateUtil, $$rAF) {
    /** @final */
    this.$compile = $compile;

    /** @final */
    this.$timeout = $timeout;

    /** @final */
    this.$window = $window;

    /** @final */
    this.dateLocale = $mdDateLocale;

    /** @final */
    this.dateUtil = $$mdDateUtil;

    /** @final */
    this.$mdConstant = $mdConstant;

    /** @final */
    this.$mdMedia = $mdMedia;

    /* @final */
    this.$mdUtil = $mdUtil;

    /** @final */
    this.$$rAF = $$rAF;

    /** @type {!angular.NgModelController} */
    this.ngModelCtrl = null;

    /** @type {HTMLInputElement} */
    this.inputElement = $element[0].querySelector('input');

    /** @type {HTMLElement} */
    this.inputContainer = $element[0].querySelector('.sg-timepicker-input-container');

    /** @final {!angular.JQLite} */
    this.ngInputElement = angular.element(this.inputElement);

    /** @type {HTMLElement} Floating time pane. */
    this.timePane = $element[0].querySelector('.sg-timepicker-time-pane');

    /** @type {HTMLElement} Time icon button. */
    this.timeButton = $element[0].querySelector('.sg-timepicker-button');

    /**
     * Element covering everything but the input in the top of the floating calendar pane.
     * @type {HTMLElement}
     */
    this.inputMask = $element[0].querySelector('.sg-timepicker-input-mask-opaque');

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

    /**
     * Element from which the calendar pane was opened. Keep track of this so that we can return
     * focus to it when the pane is closed.
     * @type {HTMLElement}
     */
    this.timePaneOpenedFrom = null;

    this.timePane.id = 'sg-time-pane' + $mdUtil.nextUid();

    $mdTheming($element);

    /** Pre-bound click handler is saved so that the event listener can be removed. */
    this.bodyClickHandler = angular.bind(this, this.handleBodyClick);

    /** Pre-bound resize handler so that the event listener can be removed. */
    this.windowResizeHandler = $mdUtil.debounce(angular.bind(this, this.closeTimePane), 100);

    // Unless the user specifies so, the datepicker should not be a tab stop.
    // This is necessary because ngAria might add a tabindex to anything with an ng-model
    // (based on whether or not the user has turned that particular feature on/off).
    if (!$attrs.tabindex) {
      $element.attr('tabindex', '-1');
    }

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
   * @param {!angular.NgModelController} ngModelCtrl
   */
  TimePickerCtrl.prototype.configureNgModel = function(ngModelCtrl) {
    this.ngModelCtrl = ngModelCtrl;

    var self = this;
    ngModelCtrl.$render = function() {
      var value = self.ngModelCtrl.$viewValue;

      if (value && !(value instanceof Date)) {
        throw Error('The ng-model for sg-timepicker must be a Date instance. ' +
                    'Currently the model is a: ' + (typeof value));
      }

      self.time = value;
      self.inputElement.value = self.dateLocale.formatTime(value);
      self.resizeInputElement();
      self.updateErrorState();
    };
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
    self.ngInputElement.on('input', self.$mdUtil.debounce(self.handleInputEvent,
                                                DEFAULT_DEBOUNCE_INTERVAL, self));
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
      var scope = this.$mdUtil.validateScope(this.$element) ? this.$element.scope() : null;
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
    this.timeButton.disabled = isDisabled;
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
    var arr = inputString.split(/[\.:]/);

    if (inputString === '') {
      this.ngModelCtrl.$setViewValue(null);
      this.time = null;
      this.inputContainer.classList.remove(INVALID_CLASS);
    }
    else if (arr.length < 2) {
      this.inputContainer.classList.toggle(INVALID_CLASS, inputString);
    }
    else {
      var h = Number(arr[0]);
      var m = Number(arr[1]);
      var newVal = new Date(this.time);
      if (h && h >= 0 && h <= 23 && m && m >= 0 && m <= 59 && angular.isDate(newVal)) {
        newVal.setHours(h);
        newVal.setMinutes(m);
        this.ngModelCtrl.$setViewValue(newVal);
        this.time = newVal;
        this.inputContainer.classList.remove(INVALID_CLASS);
      }
      else {
        this.inputContainer.classList.toggle(INVALID_CLASS, inputString);
      }
    }
  };

  /** Position and attach the floating calendar to the document. */
  TimePickerCtrl.prototype.attachTimePane = function() {
    var timePane = this.timePane;
    this.$element.addClass('sg-timepicker-open');
    this.$element.find('button').addClass('md-primary');

    var elementRect = this.inputContainer.getBoundingClientRect();
    var bodyRect = document.body.getBoundingClientRect();

    // Check to see if the calendar pane would go off the screen. If so, adjust position
    // accordingly to keep it within the viewport.
    var paneTop = elementRect.top - bodyRect.top;
    var paneLeft = elementRect.left - bodyRect.left;

    // If the right edge of the pane would be off the screen and shifting it left by the
    // difference would not go past the left edge of the screen.
    var paneWidth = this.$mdMedia('sm')? TIME_PANE_WIDTH.SM : TIME_PANE_WIDTH.GTSM;
    if (paneLeft + paneWidth > bodyRect.right &&
        bodyRect.right - paneWidth > 0) {
      paneLeft = bodyRect.right - paneWidth;
      timePane.classList.add('sg-timepicker-pos-adjusted');
    }
    timePane.style.left = paneLeft + 'px';

    // If the bottom edge of the pane would be off the screen and shifting it up by the
    // difference would not go past the top edge of the screen.
    var min = (typeof this.time == 'object' && this.time.getMinutes() % 5 === 0)? 'MIN5' : 'MIN1';
    var paneHeight = this.$mdMedia('sm')? TIME_PANE_HEIGHT[min].SM : TIME_PANE_HEIGHT[min].GTSM;
    if (paneTop + paneHeight > bodyRect.bottom &&
        bodyRect.bottom - paneHeight > 0) {
      paneTop = bodyRect.bottom - paneHeight;
      timePane.classList.add('sg-timepicker-pos-adjusted');
    }

    timePane.style.top = paneTop + 'px';
    document.body.appendChild(timePane);

    // The top of the calendar pane is a transparent box that shows the text input underneath.
    // Since the pane is floating, though, the page underneath the pane *adjacent* to the input is
    // also shown unless we cover it up. The inputMask does this by filling up the remaining space
    // based on the width of the input.
    this.inputMask.style.left = elementRect.width + 'px';

    // Add CSS class after one frame to trigger open animation.
    this.$$rAF(function() {
      timePane.classList.add('md-pane-open');
    });
  };

  /** Detach the floating time pane from the document. */
  TimePickerCtrl.prototype.detachTimePane = function() {
    this.$element.removeClass('sg-timepicker-open');
    this.$element.find('button').removeClass('md-primary');
    this.timePane.classList.remove('md-pane-open');
    this.timePane.classList.remove('md-timepicker-pos-adjusted');

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
      this.attachTimePane();
      //this.focusTime();

      // Because the time pane is attached directly to the body, it is possible that the
      // rest of the component (input, etc) is in a different scrolling container, such as
      // an md-content. This means that, if the container is scrolled, the pane would remain
      // stationary. To remedy this, we disable scrolling while the time pane is open, which
      // also matches the native behavior for things like `<select>` on Mac and Windows.
      this.$mdUtil.disableScrollAround(this.timePane);

      // Attach click listener inside of a timeout because, if this open call was triggered by a
      // click, we don't want it to be immediately propogated up to the body and handled.
      var self = this;
      this.$mdUtil.nextTick(function() {
        document.body.addEventListener('click', self.bodyClickHandler);
      }, false);

      window.addEventListener('resize', this.windowResizeHandler);
    }
  };

  /** Close the floating time pane. */
  TimePickerCtrl.prototype.closeTimePane = function() {
    if (this.isTimeOpen) {
      this.isTimeOpen = false;
      this.detachTimePane();
      this.timePaneOpenedFrom.focus();
      this.timePaneOpenedFrom = null;
      this.$mdUtil.enableScrolling();

      document.body.removeEventListener('click', this.bodyClickHandler);
      window.removeEventListener('resize', this.windowResizeHandler);
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
    this.isFocused = isFocused;
  };

  /**
   * Handles a click on the document body when the floating time pane is open.
   * Closes the floating time pane if the click is not inside of it.
   * @param {MouseEvent} event
   */
  TimePickerCtrl.prototype.handleBodyClick = function(event) {
    if (this.isTimeOpen) {
      // TODO(jelbourn): way want to also include the md-datepicker itself in this check.
      var isInTime = this.$mdUtil.getClosest(event.target, 'sg-time-pane');
      if (!isInTime) {
        this.closeTimePane();
      }

      this.$scope.$digest();
    }
  };
})();
