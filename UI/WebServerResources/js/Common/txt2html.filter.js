/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

/**
 * txt2html - A filter to convert line feeds and carriage returns to html line breaks
 * @memberof SOGo.Common
 */
(function () {
  'use strict';

  /**
   * @ngInject
   */
  txt2html.$inject = ['linkyFilter'];
  function txt2html(linkyFilter) {
    return function(text) {
      // Linky will first sanitize the text; linefeeds are therefore encoded.
      return text ? String(linkyFilter(text, ' _blank', { rel: 'noopener' })).replace(/&#10;/gm, '<br>') : undefined;
    };
  }

  angular.module('SOGo.Common')
    .filter('txt2html', txt2html);
})();
