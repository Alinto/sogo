/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';
  
  /**
   * sgFocus - A service to set the focus on the element associated to a specific string
   * @memberof SOGo.Common
   * @param {string} name - the string identifier of the element
   * @see {@link SOGo.Common.sgRippleClick}
   * @ngInject
  */
  sgRippleClick.$inject = ['$rootScope', '$timeout'];
  function sgRippleClick($rootScope, $timeout) {
    return function (containerName) {
      $timeout(function() {
        $rootScope.$broadcast('sgRippleDo', containerName);
      });
    };
  }

  angular
    .module('SOGo.Common')
    .factory('sgRippleClick', sgRippleClick);
})();
