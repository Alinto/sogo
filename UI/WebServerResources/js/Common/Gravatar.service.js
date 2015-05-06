/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Gravatar - A service to build the Gravatar URL for an email address
   * @memberof SOGo.Common
   * @param {string} email
   * @param {number} [size] - the size of the image
   * @ngInject
   */
  function Gravatar() {
    return function(email, size) {
      var hash, s = size;
      if (!email) {
        return '';
      }
      if (!size) {
        s = 48; // default to 48 pixels
      }
      hash = email.md5();

      return 'https://www.gravatar.com/avatar/' + hash + '?s=' + s + '&d=wavatar';
    }
  }

  angular
    .module('SOGo.Common')
    .factory('Gravatar', Gravatar);
})();
