/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgAutogrow - A directive to conditionally grow a textarea depending on its content.
   *   This directive is an alternative to the autogrow feature of the md-input component.
   *   It fixes the scroll jumping issue described in #3070.
   *
   *    - https://github.com/angular/material/issues/3070
   *    - https://material.angularjs.org/latest/api/directive/mdInput
   *
   *   The drawback of this directive is that it requires to set md-no-autogrow.
   * @memberof SOGo.Common
   * @ngInject
   * @example:

     <textarea rows="9" md-no-autogrow sg-autogrow="!isPopup" />
  */
  sgAutogrow.$inject = ['$document', '$timeout'];
  function sgAutogrow($document, $timeout) {
    return {
      restrict: 'A',
      scope: {
        autogrow: '=sgAutogrow'
      },
      link: function(scope, elem, attr) {
        if (!scope.autogrow) return;

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
            content = textarea.value.encodeEntities();
            content = content.replace(/\n/g, '<br>');
            hiddenDiv.innerHTML = content + '<br style="line-height: 3px;">';
            hiddenDiv.style.visibility = 'hidden';
            hiddenDiv.style.display = 'block';
            textarea.style.height = hiddenDiv.offsetHeight + 'px';
            hiddenDiv.style.visibility = 'visible';
            hiddenDiv.style.display = 'none';
          });
        }

        elem.on('keyup', AutoGrowTextArea);
        elem.on('paste', AutoGrowTextArea);

        var deregisterWatcher = scope.$watch(function() {
          return elem[0].value;
        }, function(content) {
          if (content) {
            AutoGrowTextArea();
            deregisterWatcher(); // watch once
          }
        });
      }
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgAutogrow', sgAutogrow);
})();
