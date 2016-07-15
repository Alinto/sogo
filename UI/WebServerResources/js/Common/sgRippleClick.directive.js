/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  angular
    .module('SOGo.Common')
    .directive('sgRippleClick', sgRippleClick);

  /*
   * sgRippleClick - A ripple effect to cover the parent element.
   * @memberof SOGo.Common
   * @restrict attribute
   *
   * @example:

     <md-dialog id="mailEditor">
       <md-button ng-click="editor.send()"
                sg-ripple-click="mailEditor">Send</md-button>
     </md-dialog>

  */
  sgRippleClick.$inject = ['$log', '$timeout'];
  function sgRippleClick($log, $timeout) {

    return {
      restrict: 'A',
      compile: compile
    };

    function compile(tElement, tAttrs) {

      return function postLink(scope, element, attr) {
        var ripple, content, container, containerId;

        // Lookup container element
        containerId = element.attr('sg-ripple-click');
        container = element[0].parentNode;
        while (container && container.id != containerId) {
          container = container.parentNode;
        }
        if (!container) {
          $log.error('No parent element found with id ' + containerId);
          return undefined;
        }

        // Lookup sg-ripple-content element
        content = container.querySelector('sg-ripple-content');
        if (!content) {
          $log.error('sg-ripple-content not found inside #' + containerId);
          return undefined;
        }

        // Lookup sg-ripple element
        ripple = container.querySelector('sg-ripple');
        if (ripple) {
          ripple = angular.element(ripple);
        }
        else {
          // If ripple layer doesn't exit, create it with the primary background color
          ripple = angular.element('<sg-ripple class="md-default-theme md-bg"></sg-ripple>');
          container.appendChild(ripple[0]);

          // Hide ripple content on initialization
          if (!content.classList.contains('ng-hide'))
            content.classList.add('ng-hide');
        }

        // Register listener
        element.on('click', listener);
        
        function listener(event) {
          if (element[0].hasAttribute('disabled')) {
            return;
          }

          if (content.classList.contains('ng-hide')) {
            // Show ripple
            angular.element(container).css({ 'overflow': 'hidden' });
            content.classList.remove('ng-hide');
            angular.element(content).css({ top: container.scrollTop + 'px' });
            ripple.css({
	      'top': (event.pageY - container.offsetTop + container.scrollTop) + 'px',
	      'left': (event.pageX - container.offsetLeft) + 'px',
	      'width': '400vmin',
	      'height': '400vmin'
	    });
          }
          else {
            // Hide ripple layer
            ripple.css({
              'top': (event.pageY - container.offsetTop + container.scrollTop) + 'px',
	      'left': (event.pageX - container.offsetLeft) + 'px',
              'height': '0px',
              'width': '0px'
            });
            // Hide ripple content
            content.classList.add('ng-hide');
            // Restore overflow of container once the animation is completed
            $timeout(function() {
              angular.element(container).css({ 'overflow': '' });
            }, 800);
          }
        }
      };
    }
  }
})();
