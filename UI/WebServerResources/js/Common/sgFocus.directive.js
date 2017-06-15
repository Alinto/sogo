/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgFocusOn - A directive that sets the focus on its element when the specified string is broadcasted
   * @memberof SOGo.Common
   * @see {@link SOGo.Common.sgFocus}
   * @ngInject
   * @example:

     <input type="text"
            sg-focus-on="username" />
   */
  function sgFocusOn() {
    return function(scope, elem, attr) {
      scope.$on('sgFocusOn', function(e, name) {
        if (name === attr.sgFocusOn) {
          elem[0].focus();
          if (typeof elem[0].select == 'function')
            elem[0].select();
        }
      });
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgFocusOn', sgFocusOn);
})();
