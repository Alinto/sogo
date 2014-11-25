/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for common UI services */

(function() {
  'use strict';

  /* Angular module instanciation */
  angular.module('SOGo.UICommon', [])
  
    .filter('encodeUri', function ($window) {
      return $window.encodeURIComponent;
    })

    .filter('decodeUri', function ($window) {
      return $window.decodeURIComponent;
    })

    .filter('loc', function () {
      return l;
    });

})();
