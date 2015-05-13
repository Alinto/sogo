/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgCompile - Assign an expression to a DOM element and compile it.
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {object} sgCompile - the expression to compile
   * @ngInject
   * @example:

   <div sg-compile="part.content"><!-- msg --></div>
  */
  sgCompile.$inject = ['$compile'];
  function sgCompile($compile) {
    return {
      restrict: 'A',
      link: sgCompileLink
    };

    function sgCompileLink(scope, element, attrs) {
      var ensureCompileRunsOnce = scope.$watch(
        function(scope) {
          // Watch the sg-compile expression for changes
          return scope.$eval(attrs.sgCompile);
        },
        function(value) {
          // When the sg-compile expression changes, assign it into the current DOM
          element.html(value);
          
          // Compile the new DOM and link it to the current scope.
          // NOTE: we only compile .childNodes so that we don't get into infinite loop compiling ourselves
          $compile(element.contents())(scope);
          
          // Use un-watch feature to ensure compilation happens only once.
          ensureCompileRunsOnce();
        }
      );
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgCompile', sgCompile);
})();
