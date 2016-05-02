/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * Set XSRF header if the cookie exists.
   * Solution based on the following discussion:
   * https://github.com/nervgh/angular-file-upload/issues/360
   */
  angular
    .module('angularFileUpload')
    .decorator('FileUploader', FileUploaderDecorator);

  /**
   * @ngInject
   */
  FileUploaderDecorator.$inject = ['$delegate', '$cookies'];
  function FileUploaderDecorator($delegate, $cookies) {
    $delegate.prototype.onBeforeUploadItem = function(item) {
      var token = $cookies.get('XSRF-TOKEN');
      if (token)
        item.headers = {'X-XSRF-TOKEN': token};
    };
    return $delegate;
  }
})();
