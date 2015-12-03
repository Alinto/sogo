/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgPlaceholder - A directive for dynamic placeholder
   * @memberof SOGo.Common
   * @ngInject
   * @example:

     <input type="text"
            sg-placeholder="this_is_a_variable" />
  */
  function sgPlaceholder() {
    return {
      restrict: 'A',
      scope: {
        placeholder: '=sgPlaceholder'
      },
      link: function(scope, elem, attr) {
        scope.$watch('placeholder',function() {
          elem[0].placeholder = scope.placeholder;
        });
      }
    };
  }
  
  angular
    .module('SOGo.Common')
    .directive('sgPlaceholder', sgPlaceholder);
})();
