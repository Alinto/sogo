/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgEscape - A directive evaluated when the escape key is pressed
   * @memberof SOGo.Common
   * @ngInject
   * @example:

     <input type="text"
            sg-escape="revertEditing($index)" />
   */
  function sgEscape() {
    var ESCAPE_KEY = 27;
    return function(scope, elem, attrs) {
      elem.bind('keydown', function(event) {
        if (event.keyCode === ESCAPE_KEY) {
          scope.$apply(attrs.sgEscape);
        }
      });
    };
  }
    
  angular
    .module('SOGo.Common')
    .directive('sgEscape', sgEscape);
})();
