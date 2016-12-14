/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * @name Alarm
   * @constructor
   */
  function Alarm() {
    this.currentAlarm = null;
  }

  /**
   * @name getAlarms
   * @desc Fetch the list of alarms from the server and use the last one
   */
  Alarm.getAlarms = function() {
    var _this = this;
    var now = new Date();
    var browserTime = Math.floor(now.getTime()/1000);

    this.$$resource.fetch('', 'alarmslist?browserTime=' + browserTime).then(function(data) {
      
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

        var f = angular.bind(_this, Alarm.showAlarm, url);

        if (_this.currentAlarm)
          _this.$timeout.cancel(_this.currentAlarm);

        _this.currentAlarm = _this.$timeout(f, delay*1000);
      }
    });
  };
  
  /**
   * @name showAlarm
   * @desc Show the latest alarm using a toast
   * @param url The URL of the calendar component for snoozing
   */
  Alarm.showAlarm = function(url) {
    var _this = this;

    this.$$resource.fetch(url, '?resetAlarm=yes').then(function(data) {
      _this.$toast.show({
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

      /**
       * @ngInject
       */
      AlarmController.$inject = ['scope', '$mdToast', 'url'];
      function AlarmController(scope, $mdToast, url) {
        scope.summary = data.summary;
        scope.reminder = '10';
        scope.close = function() {
          $mdToast.hide();
        };
        scope.snooze = function() {
          _this.$$resource.fetch(url, 'view?snoozeAlarm=' + scope.reminder);
          $mdToast.hide();
        };
      }
    });
  };

  /**
   * @memberof Alarm
   * @desc The factory we'll register as Alarm in the Angular module SOGo.Common
   * @ngInject
   */
  AlarmService.$inject = ['$timeout', 'sgSettings', 'Resource', '$mdToast'];
  function AlarmService($timeout, Settings, Resource, $mdToast) {
    angular.extend(Alarm, {
      $timeout: $timeout,
      $$resource: new Resource(Settings.activeUser('folderURL') + 'Calendar', Settings.activeUser()),
      $toast: $mdToast
    });

    return Alarm; // return constructor
  }

  /* Factory registration in Angular module */
  angular
    .module('SOGo.Common')
    .factory('Alarm', AlarmService);

})();
