/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  function range() {
    return function(n) {
      var res = [];
      for (var i = 0; i < n; i++) {
        res.push(i);
      }
      return res;
    };
  }

  angular.module('SOGo.Common')
    .filter('range', range);
})();
