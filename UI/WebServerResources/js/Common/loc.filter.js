/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * loc - A simple filter to return the localized version of a string.
 * @memberof SOGo.Common
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
