/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgAutogrow - A directive to automatically grow a textarea depending on its content.
   *   This directive is an alternative to the autogrow feature of the md-input component.
   *   It fixes the scroll jumping issue described in #3070.
   *
   *    - https://github.com/angular/material/issues/3070
   *    - https://material.angularjs.org/latest/api/directive/mdInput
   *
   *   The drawback of this simple fix is that it won't shrink the textarea but only
   *   increase its height. It also requires to set md-no-autogrow.
   * @memberof SOGo.Common
   * @ngInject
   * @example:

     <textarea rows="9" md-no-autogrow sg-autogrow />
  */
  sgAutogrow.$inject = ['$timeout'];
  function sgAutogrow($timeout) {
    return {
      restrict: 'A',
      link: function(scope, elem, attr) {
        var textarea = elem[0];

        function AutoGrowTextArea() {
          $timeout(function() {
            if (textarea.clientHeight < textarea.scrollHeight) {
              textarea.style.height = textarea.scrollHeight + 'px';
              if (textarea.clientHeight < textarea.scrollHeight) {
                textarea.style.height = (textarea.scrollHeight * 2 - textarea.clientHeight) + 'px';
              }
            }
          });
        }

        textarea.style.overflow = 'hidden';

        elem.on('keyup', AutoGrowTextArea);
        elem.on('paste', AutoGrowTextArea);

        AutoGrowTextArea();
      }
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgAutogrow', sgAutogrow);
})();
