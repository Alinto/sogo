/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgBlockToggle - expandable block, collapsed by default
   * @memberof SOGo.Common
   * @ngInject
   * @example:

   <sg-block-toggle>
     <md-list-item class="sg-button-toggle">
       <md-icon>warning</md-icon>
       <p flex>{{ message }}</p>
       <md-icon class="sg-icon-toggle">expand_more</md-icon>
     </md-list-item>
     <div class="sg-block-toggle">
       <!-- block's content -->
     </div>
  */
  sgBlockToggle.$inject = ['$mdUtil', '$animateCss', '$$rAF'];
  function sgBlockToggle($mdUtil, $animateCss, $$rAF) {
    return {
      link: link
    };

    function link($scope, $element) {
      var button = $element[0].querySelector('.sg-button-toggle'),
          icon = button.querySelector('.sg-icon-toggle'),
          icon_rotate_class = 'md-rotate-180-ccw',
          block = $element[0].querySelector('.sg-block-toggle'),
          isOpen = false;

      button.classList.add('md-clickable');
      angular.element(button).on('click', toggle);

      renderContent();

      function renderContent() {
        block.setAttribute('aria-hidden', !isOpen);
        block.setAttribute('aria-expanded', isOpen);
        if (!isOpen)
          block.style.visibility = 'hidden';
      }

      function toggle() {
        isOpen = !isOpen;
        if (isOpen)
          icon.classList.add(icon_rotate_class);
        else
          icon.classList.remove(icon_rotate_class);

        if (isOpen)
          block.style.visibility = 'visible';

        $$rAF(function() {
          var targetHeight = isOpen ? block.scrollHeight : 0;

          $animateCss(angular.element(block), {
            easing: 'cubic-bezier(0.35, 0, 0.25, 1)',
            to: { height: targetHeight + 'px' },
            duration: 0.75 // seconds
          }).start().then(function() {
            renderContent();
          });
        });
      }
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgBlockToggle', sgBlockToggle);
})();
