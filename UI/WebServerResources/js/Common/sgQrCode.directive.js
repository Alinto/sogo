/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true, newcap: false */
  'use strict';

  /**
   * sgQrCode - Build a otpauth URI and generate a QR Code for the provided secret.
   * @see {@link https://davidshimjs.github.io/qrcodejs/|QRCode.js}
   * @memberof SOGo.Common
   * @example:
     <sg-qr-code text="secret"/>
  */
  sgQrCode.$inject = ['sgSettings'];
  function sgQrCode(Settings) {
    return {
      restrict: 'E',
      scope: {
        text: '@',
        width: '@',
        height: '@'
      },
      link: link
    };

    function link(scope, element, attrs) {
      var width = parseInt(scope.width) || 256,
          height = parseInt(scope.height) || width,
          // See https://github.com/google/google-authenticator/wiki/Key-Uri-Format
          uri = 'otpauth://totp/SOGo:' + Settings.activeUser('email') + '?secret=' + scope.text.replace(/=+$/, '') + '&issuer=SOGo';
      new QRCode(element[0], {
        text: uri,
        width: width,
        height: height
      });
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgQrCode', sgQrCode);
})();
