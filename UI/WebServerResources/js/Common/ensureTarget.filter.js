/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * @type {angular.Module}
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  function ensureTarget() {
    return function(element) {
      var tree = angular.element('<div>' + element + '</div>');
      tree.find('a').attr('target', '_blank');
      return angular.element('<div>').append(tree).html(); 
    };
  }

  angular.module('SOGo.Common')
    .filter('ensureTarget', ensureTarget);
})();
