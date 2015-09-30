/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function () {
  'use strict';

  /**
   * ensureTarget - A filter to set a blank target to all links.
   * @memberof SOGo.Common
   * @ngInject
   * @example:

   <div ng-bind-html="part.content | ensureTarget"><!-- msg --></div>
  */
  ensureTarget.$inject = ['$sce'];
  function ensureTarget($sce) {
    return function(element) {
      var tree = angular.element('<div>' + element + '</div>');
      tree.find('a').attr('target', '_blank');
      return $sce.trustAs('html', tree.html());
    };
  }

  angular.module('SOGo.Common')
    .filter('ensureTarget', ensureTarget);
})();
