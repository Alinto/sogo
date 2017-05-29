/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgZoomableImage - Show the image fullscreen when clicking on the image inside the container.
   * @memberof SOGo.MailerUI
   * @restrict attribute
   * @ngInject
   * @example:

   <div sg-zoomable-image="$index">
     <md-card>
       <img src="foo.png">
     </md-card>
   </div>
  */
  function sgZoomableImage() {
    return {
      restrict: 'A',
      bindToController: {
        partIndex: '=sgZoomableImage'
      },
      controller: sgZoomableImageController
    };

    function link(scope, iElement, attrs, ctrl) {
      var parentNode = iElement.parent(),
          imgElement, showImage, toggleClass;

      imgElement = iElement.find('img');

      toggleClass = function(event) {
        if (event.target.tagName == 'IMG')
          parentNode.toggleClass('sg-zoom');
      };

      showImage = function(event) {
        if (event.target.tagName == 'IMG')
          ctrl.showGallery(event, imgElement[0].src);
      };

      if (imgElement.length)
        ctrl.addImage(imgElement[0].src);

      iElement.on('click', showImage);
    }
  }

  /**
   * @ngInject
   */
  sgZoomableImageController.$inject = ['$element', 'ImageGallery'];
  function sgZoomableImageController($element, ImageGallery) {
    var $ctrl = this;

    this.$postLink = function() {
      ImageGallery.registerImage($element);
      $element.on('click', this.showImage);
    };

    this.showImage = function($event) {
      if ($event.target.tagName == 'IMG')
        ImageGallery.showGallery($event, $ctrl.partIndex);
    };
  }

  angular
    .module('SOGo.MailerUI')
    .directive('sgZoomableImage', sgZoomableImage);
})();
