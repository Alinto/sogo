/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  angular
    .module('SOGo.Common')
    .directive('sgCheckmark', sgCheckmarkDirective);

  /*
   * sgCheckmark - A checkmark to be used in a mdMenuItem
   * @memberof SOGo.Common
   * @restrict element
   *
   * @example:

     <md-menu>
       <md-button class="md-icon-button" aria-label="Sort"
                  ng-click="$mdMenu.open()">
         <md-icon>sort</md-icon>
       </md-button>
       <md-menu-content>
         <md-menu-item>
           <sg-checkmark
               aria-label="Descending Order"
               ng-model="ctrl.asc"
               ng-click="ctrl.filter()"
               sg-true-value="0"
               sg-false-value="1">Descending Order</sg-checkmark>
         </md-menu-item>            
       </md-menu-content>
     </md-menu>
  */
  sgCheckmarkDirective.$inject = ['$parse', '$mdAria', '$mdTheming', '$mdUtil'];
  function sgCheckmarkDirective($parse, $mdAria, $mdTheming, $mdUtil) {
    var CHECKED_CSS = 'sg-checked';

    return {
      restrict: 'E',
      replace: true,
      transclude: true,
      require: '?ngModel',
      //priority: 210, // Run before ngAria
      template: [
        '<button class="md-button sg-checkmark" type="button">',
        '  <md-icon>check</md-icon>',
        '  <span ng-transclude></span',
        '</button>'
      ].join(''),
      compile: compile
    };

    function compile(tElement, tAttrs) {

      // Attach a click handler in compile in order to immediately stop propagation
      // (especially for ng-click) when the checkmark is disabled.
      tElement.on('click', function(event) {
        if (this.hasAttribute('disabled')) {
          event.stopImmediatePropagation();
        }
      });

      return function postLink(scope, element, attr, ngModelCtrl) {
        // See https://github.com/angular/angular.js/commit/c90cefe16142d973a123e945fc9058e8a874c357
        var trueValue = parseConstantExpr($parse, scope, 'sgTrueValue', attr.sgTrueValue, true),
            falseValue = parseConstantExpr($parse, scope, 'sgFalseValue', attr.sgFalseValue, false);
        
        ngModelCtrl = ngModelCtrl || $mdUtil.fakeNgModel();
        $mdTheming(element);

        $mdAria.expectWithText(element, 'aria-label');

        element.on('click', listener);

        ngModelCtrl.$render = render;

        function parseConstantExpr($parse, context, name, expression, fallback) {
          var parseFn;
          if (angular.isDefined(expression)) {
            parseFn = $parse(expression);
            if (!parseFn.constant) {
              throw Error('Expected constant expression for `' + name + '`, but saw `' + expression + '`.');
            }
            return parseFn(context);
          }
          return fallback;
        }

        function listener(ev) {
          if (element[0].hasAttribute('disabled')) {
            return;
          }

          scope.$apply(function() {
            // Toggle the checkmark value
            var viewValue = ngModelCtrl.$viewValue == trueValue? falseValue : trueValue;

            ngModelCtrl.$setViewValue( viewValue, ev && ev.type);
            ngModelCtrl.$render();
          });
        }

        function render() {
          if (ngModelCtrl.$viewValue == trueValue)
            element.addClass(CHECKED_CSS);
          else
            element.removeClass(CHECKED_CSS);
        }
      };
    }
  }
})();
