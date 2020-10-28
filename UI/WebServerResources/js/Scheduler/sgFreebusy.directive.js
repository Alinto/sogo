/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {

  /**
   * sgFreebusy - A directive that watches some attributes of a component. Any child component
   * should depends on this directive and extend the 'onUpdate' method instead of creating new
   * independent watchers.
   * @memberof SOGo.SchedulerUI
  */
  function sgFreebusy() {
    return {
      restrict: 'C',
      scope: {},
      bindToController: {
        component: '=sgComponent'
      },
      controller: sgFreebusyController
    };
  }

  /**
   * @ngInject
   */
  sgFreebusyController.$inject = ['$scope', '$element', '$q'];
  function sgFreebusyController($scope, $element, $q) {
    var $ctrl = this;

    this.$onInit = function () {
      var watchedAttrs = ['start', 'end', 'attendees'];

      $scope.$watch(
        function() {
          return $ctrl.component? {
            start: $ctrl.component.start,
            end: $ctrl.component.end,
            attendees: _.keys($ctrl.component.$attendees.$futureFreebusyData)
          } : null;
        },
        function(newAttrs, oldAttrs) {
          if (newAttrs && newAttrs.attendees && newAttrs.attendees.length) {
            // Attendees have changed
            $q.all(_.values($ctrl.component.$attendees.$futureFreebusyData)).then(function() {
              $ctrl.onUpdate();
            });
          }
        },
        true // compare for object equality
      );
    };


    this.onUpdate = function () {
      // console.debug('dates or attendees changed -- refresh freebusy');
    };
  }


  angular
    .module('SOGo.SchedulerUI')
    .directive('sgFreebusy', sgFreebusy);
})();
