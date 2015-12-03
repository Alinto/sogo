/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgEnter - A directive evaluated when the enter key is pressed
   * @memberof SOGo.Common
   * @ngInject
   * @example:

     <input type="text"
            sg-enter="save($index)" />
  */
  function sgEnter() {
    var ENTER_KEY = 13;
    return function(scope, element, attrs) {
      element.bind("keydown keypress", function(event) {
        if (event.which === ENTER_KEY) {
          scope.$apply(attrs.sgEnter);
          event.preventDefault();
        }
      });
    };
  }
  
  angular
    .module('SOGo.Common')
    .directive('sgEnter', sgEnter);
})();
