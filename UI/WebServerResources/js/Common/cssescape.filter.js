/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
 (function () {
  'use strict';

  /**
   * @ngInject
   */
  cssEscape.$inject = ['$window'];
  function cssEscape($window) {
    return $window.CSS.escape;
  }

  angular.module('SOGo.Common')
    .filter('cssEscape', cssEscape);
})();
