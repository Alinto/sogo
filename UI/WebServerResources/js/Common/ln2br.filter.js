/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * ln2br - A filter to convert line feeds and carriage returns to html line breaks
 * @memberof SOGo.Common
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  function ln2br() {
    return function(text) {
      return text ? String(text).replace(/\r?\n/gm, '<br>') : undefined;
    };
  }

  angular.module('SOGo.Common')
    .filter('ln2br', ln2br);
})();
