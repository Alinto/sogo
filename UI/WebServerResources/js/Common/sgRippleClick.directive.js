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

        scope.$on('$destroy', function() {
          element.off('click', listener);
        });

        function listener(event) {
          var coordinates;

          if (element[0].hasAttribute('disabled')) {
            return;
          }

          if (event.pageX && event.pageY) {
            // Event is a mouse click
            coordinates = { left: event.pageX, top: event.pageY };
          }
          else {
            // Event is a form submit; target is the submit button
            coordinates = event.target.getBoundingClientRect();
          }

          if (content.classList.contains('ng-hide')) {
            // Show ripple
            angular.element(container).css({ 'overflow': 'hidden', 'position': 'relative' });
            angular.element(content).css({ top: container.scrollTop + 'px' });
            $timeout(function() {
              // Wait until next digest for CSS animation to work
              ripple.css({
	        'top': (coordinates.top - container.offsetTop + container.scrollTop) + 'px',
	        'left': (coordinates.left - container.offsetLeft) + 'px',
	        'height': '400vmin',
	        'width': '400vmin'
	      });
              // Show ripple content
              content.classList.remove('ng-hide');
            });
          }
          else {
            // Hide ripple layer
            ripple.css({
              'top': (coordinates.top - container.offsetTop + container.scrollTop) + 'px',
	      'left': (coordinates.left - container.offsetLeft) + 'px',
              'height': '0px',
              'width': '0px'
            });
            // Hide ripple content
            content.classList.add('ng-hide');
            // Restore overflow of container once the animation is completed
            $timeout(function() {
              angular.element(container).css({ 'overflow': '', 'position': '' });
            }, 800);
          }
        }
      };
    }
  }
})();
