/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  function loc() {
    return l;
  }

  angular.module('SOGo.Common')
    .filter('loc', loc);
})();
