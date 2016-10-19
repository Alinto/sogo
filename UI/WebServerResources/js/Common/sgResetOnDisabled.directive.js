/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgResetOnDisabled - A directive to reset any error of a datepicker when marked
   *                     as disabled.
   * @memberof SOGo.Common
   * @ngInject
   * @example:

   <md-datepicker
     ng-model="myDate"
     ng-disabled="!myDateEnabled"
     sg-reset-on-disabled>
  */
  function sgResetOnDisabled() {
    return {
      link: postLink,
      require: 'mdDatepicker',
      restrict: 'A'
    };

    function postLink(scope, element, attrs, datepickerCtrl) {
      function getInput() {
        return element.find('input').eq(0);
      }

      // We need to wait for the datepicker directive to be compiled
      var listener = scope.$watch(getInput, function (input) {
        var ngModel;

        if (input.length) {
          listener(); // self release
          datepickerCtrl.$scope.$watch('ctrl.isDisabled', function(isDisabled) {
            if (isDisabled)
              if (datepickerCtrl.ngModelCtrl.$invalid)
                // Trigger the event that will reset the errors and the model value
                datepickerCtrl.$scope.$emit('md-calendar-change', datepickerCtrl.date);
          });
        }
      });
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgResetOnDisabled', sgResetOnDisabled);
})();
