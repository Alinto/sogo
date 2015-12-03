/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgZoomableImage - Toggle the 'sg-zoom' class when clicking on the image inside the container.
   * @memberof SOGo.MailerUI
   * @restrict attribute
   * @ngInject
   * @example:

   <div sg-zoomable-image="sg-zoomable-image">
     <md-card>
       <img src="foo.png">
     </md-card>
   </div>
  */
  function sgZoomableImage() {
    return {
      restrict: 'A',
      link: link
    };

    function link(scope, iElement, attrs, ctrl) {
      var parentNode = iElement.parent(),
          toggleClass;

      toggleClass = function(event) {
        if (event.target.tagName == 'IMG')
          parentNode.toggleClass('sg-zoom');
      };

      iElement.on('click', toggleClass);
    }
  }

  angular
    .module('SOGo.MailerUI')
    .directive('sgZoomableImage', sgZoomableImage);
})();
