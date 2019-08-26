/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /*
   * sgFreebusyDay - A representation of the freebusy data for an attendee for one day.
   * @memberof SOGo.SchedulerUI
   * @restrict element
   * @param {string} sgDay - the day string
   * @param {object} sgAttendees - the Attendees object instance of the component
   * @param {object} sgAttendee - the object representing the attendee
   *
   * @example:

   <sg-freebusy-day
     ng-repeat="currentAttendee in component.attendees"
     sg-day="day.getDayString"
     sg-attendees="component.$attendees"
     sg-attendee="currentAttendee" />
  */
  function sgFreebusyDay() {
    return {
      restrict: 'E',
      require: '^^sgFreebusy',
      bindToController: {
        day: '=sgDay',
        attendees: '=sgAttendees',
        attendee: '=sgAttendee'
      },
      replace: true,
      template: function(tElement, tAttrs) {
        var template = [
          '<md-list-item>'
        ];
        for (var hour = 0; hour < 24; hour++) {
          template.push('  <div class="hour">');
          for (var quarter = 0; quarter < 4; quarter++) {
            template.push('    <div class="quarter">');
            template.push('      <div class="busy ng-hide"></div>');
            template.push('    </div>');
          }
          template.push('  </div>');
        }
        template.push('  <md-divider><!-- divider --></md-divider>');
        template.push('</md-list-item>');

        return template.join('');
      },
      link: postLink,
      controller: sgFreebusyDayController,
      controllerAs: '$ctrl'
    };

    function postLink(scope, element, attrs, parentController) {
      scope.parentController = parentController;
    }
  }

  /**
   * @ngInject
   */
  sgFreebusyDayController.$inject = ['$scope', '$element'];
  function sgFreebusyDayController($scope, $element) {
    var $ctrl = this;

    this.$postLink = function () {
      var hours = [], quarters = [], busys = [], parentControllerOnUpdate;

      this.parentController = $scope.parentController;
      parentControllerOnUpdate = this.parentController.onUpdate;

      _.forEach($element.find('div'), function(div) {
        if (div.className.startsWith('hour')) hours.push(div);
        else if (div.className.startsWith('quarter')) quarters.push(div);
        else if (div.className.startsWith('busy')) busys.push(div);
      });

      this.parentController.onUpdate = function () {
        var freebusys = $ctrl.attendee.freebusy[$ctrl.day];

        if (!$ctrl.attendee.uid) {
          _.forEach(hours, function(div) {
            div.classList.add('sg-no-freebusy');
          });
        }

        for (var hour = 0; hour < 24; hour++) {
          for (var quarter = 0; quarter < 4; quarter++) {
            var index = hour * 4 + quarter;
            if ($ctrl.coversFreebusy(hour, quarter)) {
              quarters[index].classList.add('event');
            } else {
              quarters[index].classList.remove('event');
            }
            if (freebusys[hour][quarter]) {
              busys[index].classList.remove('ng-hide');
            } else {
              busys[index].classList.add('ng-hide');
            }
          }
        }

        // Call original method on parent controller
        angular.bind($ctrl.parentController, parentControllerOnUpdate)();
      };
    };

    this.coversFreebusy = function (hour, quarter) {
      return $ctrl.attendees.coversFreeBusy($ctrl.day, hour, quarter);
    };
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgFreebusyDay', sgFreebusyDay);
})();
