/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * range - A simple filter that will return an array of the size of its argument.
 * @memberof SOGo.Common
 */
(function () {
  'use strict';

  function range() {
    return function(n) {
      var res = [];
      for (var i = 0; i < parseInt(n); i++) {
        res.push(i);
      }
      return res;
    };
  }

  angular.module('SOGo.Common')
    .filter('range', range);
})();
