/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  angular
    .module('angularFileUpload')
    .decorator('FileUploader', FileUploaderDecorator)
    .decorator('FileDrop', FileDropDecorator);

  /**
   * Set XSRF header if the cookie exists.
   * Solution based on the following discussion:
   * https://github.com/nervgh/angular-file-upload/issues/360
   *
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

  /**
   * Fixed bug causing nv-file-over (over-class) not resetting when leaving element.
   * Solution based on this unmerged pull request:
   * https://github.com/nervgh/angular-file-upload/pull/643
   *
   * @ngInject
   */
  FileDropDecorator.$inject = ['$delegate', '$timeout'];
  function FileDropDecorator($delegate, $timeout) {
    $delegate.prototype.onDragOver = function(event) {
      var transfer = this._getTransfer(event);
      if (!this._haveFiles(transfer.types)) return;
      transfer.dropEffect = 'copy';
      this._preventAndStop(event);
      angular.forEach(this.uploader._directives.over, this._addOverClass, this);
      $timeout.cancel(this.onDragLeaveTimer);
    };
    $delegate.prototype.onDragLeave = function(event) {
      var that = this;
      $timeout.cancel(this.onDragLeaveTimer);
      this.onDragLeaveTimer = $timeout(function() {
        that._preventAndStop(event);
        angular.forEach(that.uploader._directives.over, that._removeOverClass, that);
      }, 50);
    };
    return $delegate;
  }
})();
