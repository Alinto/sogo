/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgDatepickerReadonlyInput - A directive that disabled the input field of a datepicker.
   * @memberof SOGo.Common
   *
   * @example:

   <md-datepicker md-hide-icons="triangle"
                  md-open-on-focus="md-open-on-focus"
                  ng-model="selectedDate"
                  sg-datepicker-readonly-input>
  */
  function sgDatepickerReadonlyInput() {
    return {
      link: postLink,
      require: 'mdDatepicker',
      restrict: 'A'
    };

    function postLink(scope, element, attrs, datepickerCtrl) {
      function getInput() {
        return element.find('input').eq(0);
      }

      // We need to wait for the autocomplete directive to be compiled
      var listener = scope.$watch(getInput, function (input) {
        if (input.length) {
          listener(); // self release
          input.prop('disabled', true);
          input.parent().addClass('sg-datepicker-readonly-input-container');
        }
      });
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgDatepickerReadonlyInput', sgDatepickerReadonlyInput);
})();
