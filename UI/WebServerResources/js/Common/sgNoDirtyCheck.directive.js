/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2 -*- */

(function() {
  'use strict';

  angular
    .module('SOGo.Common')
    .directive('sgNoDirtyCheck', sgNoDirtyCheck);

  /*
   * sgNoDirtyCheck - prevent input from affecting the form's pristine state.
   * @restrict attribute
  */
  function sgNoDirtyCheck() {
    return {
      restrict: 'A',
      require: 'ngModel',
      link: function (scope, elem, attrs, ngModelCtrl) {
        if (!ngModelCtrl) {
          return;
        }

        var clean = (ngModelCtrl.$pristine && !ngModelCtrl.$dirty);

        if (clean) {
          ngModelCtrl.$pristine = false;
          ngModelCtrl.$dirty = true;
        }
      }
    };
  }

})();
