/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';
  
  /**
   * sgFocus - A service to set the focus on the element associated to a specific string
   * @memberof SOGo.Common
   * @param {string} name - the string identifier of the element
   * @see {@link SOGo.Common.sgFocusOn}
   * @ngInject
  */
  sgFocus.$inject = ['$rootScope', '$timeout'];
  function sgFocus($rootScope, $timeout) {
    return function(name) {
      $timeout(function() {
        $rootScope.$broadcast('sgFocusOn', name);
      });
    };
  }

  angular
    .module('SOGo.Common')
    .factory('sgFocus', sgFocus);
})();
