/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  encodeUri.$inject = ['$window'];
  function encodeUri($window) {
    return $window.encodeURIComponent;
  }

  angular.module('SOGo.Common')
    .filter('encodeUri', encodeUri);
})();
