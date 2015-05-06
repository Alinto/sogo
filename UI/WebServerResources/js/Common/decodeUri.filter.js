/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  decodeUri.$inject = ['$window'];
  function decodeUri($window) {
    return $window.decodeURIComponent;
  }

  angular.module('SOGo.Common')
    .filter('decodeUri', decodeUri);
})();
