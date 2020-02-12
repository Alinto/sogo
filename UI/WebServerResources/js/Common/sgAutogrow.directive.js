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
  sgAutogrow.$inject = ['$document', '$timeout'];
  function sgAutogrow($document, $timeout) {
    return {
      restrict: 'A',
      link: function(scope, elem, attr) {
        var textarea = elem[0];
        var hiddenDiv = $document[0].createElement('div');
        var content = null;

        hiddenDiv.classList.add('md-input');
        hiddenDiv.classList.add('plain-text');
        hiddenDiv.style.display = 'none';
        hiddenDiv.style.whiteSpace = 'pre-wrap';
        hiddenDiv.style.wordWrap = 'break-word';
        textarea.parentNode.appendChild(hiddenDiv);

        textarea.style.resize = 'none';
        textarea.style.overflow = 'hidden';

        function AutoGrowTextArea() {
          $timeout(function() {
            content = textarea.value;
            content = content.replace(/\n/g, '<br>');
            hiddenDiv.innerHTML = content + '<br style="line-height: 3px;">';
            hiddenDiv.style.visibility = 'hidden';
            hiddenDiv.style.display = 'block';
            textarea.style.height = hiddenDiv.offsetHeight + 'px';
            console.debug('resize to ' + hiddenDiv.offsetHeight + 'px');
            hiddenDiv.style.visibility = 'visible';
            hiddenDiv.style.display = 'none';
          });
        }

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
