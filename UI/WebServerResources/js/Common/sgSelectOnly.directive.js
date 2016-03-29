/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgSelectOnly - A directive that restricts an autocomplete field to its selectable values.
   * @memberof SOGo.Common
   * @ngInject
   * @example:

   <md-autocomplete
     md-items="timezone in timeZones"
     ng-required="true"
     sg-select-only>
  */
  function sgSelectOnly() {
    return {
      link: postLink,
      require: 'mdAutocomplete',
      restrict: 'A'
    };

    function postLink(scope, element, attrs, autoComplete) {
      function getInput() {
        return element.find('input').eq(0);
      }

      // We need to wait for the autocomplete directive to be compiled
      var listener = scope.$watch(getInput, function (input) {
        var ngModel;

        if (input.length) {
          listener(); // self release
          ngModel = input.controller('ngModel');
          input.on('blur', function () {
            if (!autoComplete.scope.selectedItem) {
              scope.$applyAsync(ngModel.$setValidity('required', false));
            }
          });
        }
      });
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgSelectOnly', sgSelectOnly);
})();
