/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Gravatar - A service to build the Gravatar URL for an email address
   * @memberof SOGo.Common
   * @param {string} email
   * @param {number} [size] - the size of the image
   * @param {string} alternate avatar to use (none, identicon, monsterid, wavatar, retro)
   * @ngInject
   */
  function Gravatar() {
    return function(email, size, alternate_avatar, options) {
      var x, y, hash, s = size, a = alternate_avatar;
      if (!email) {
        return '';
      }
      x = email.indexOf('<');
      if (x >= 0) {
        y = email.indexOf('>', x);
        if (y > x)
          email = email.substring(x+1,y);
      }
      if (!size) {
        s = 48; // default to 48 pixels
      }
      hash = email.toLowerCase().md5();

      if (!a || a == "none") {
        if (options && options.no_404)
          alternate_avatar = "mm"; // mystery man alternative
        else
          alternate_avatar = "404";
      }

      return 'https://www.gravatar.com/avatar/' + hash + '?s=' + s + '&d=' + alternate_avatar;
    };
  }

  angular
    .module('SOGo.Common')
    .factory('Gravatar', Gravatar);
})();
