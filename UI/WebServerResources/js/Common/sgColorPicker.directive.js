/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgColorPicker - Color picker widget
   * @restrict element
   * @param {function} sgOnSelect - the function to call when clicking on a color.
   *        One variable is available: color.
   * @ngInject
   * @example:

     <sg-color-picker sg-on-select="properties.calendar.color = color"></sg-color-picker>
  */
  function sgColorPicker() {
    return {
      restrict: 'E',
      require: 'ngModel',
      template: [
        '<md-menu>',
        '  <md-button class="md-icon-button"',
        '             label:aria-label="Options"',
        '             ng-style="{ \'background-color\': sgColor }"',
        '             ng-click="$mdOpenMenu()"',
        '             md-menu-origin="md-menu-origin">',
        '    <md-icon style="color: #fff">color_lens</md-icon>',
        '  </md-button>',
        '  <md-menu-content class="md-padding" width="3" style="min-height: 200px">',
        '    <md-grid-list class="sg-color-picker" md-cols="7" md-row-height="1:1" md-gutter="0.5em">',
        '      <md-grid-tile ng-repeat="color in ::sgColors track by $index"',
        '                    ng-style="{ \'background-color\': color }"',
        '                    ng-click="setColor(color)"></md-grid-tile>',
        '    </md-grid-list>',
        '  </md-menu-content>',
        '</md-menu>'
      ].join(''),
      replace: true,
      controller: sgColorPickerController,
      link: link
    };

    function link(scope, iElement, iAttr, ngModelController) {
      // Expose ng-model value to scope
      ngModelController.$render = function() {
        scope.sgColor = ngModelController.$viewValue;
      };
    }
  }
  
  /**
   * @ngInject
   */
  sgColorPickerController.$inject = ['$scope', '$element', 'sgColors'];
  function sgColorPickerController($scope, $element, sgColors) {
    var ngModelController = $element.controller('ngModel');

    $scope.sgColors = sgColors.selection;
    $scope.setColor = function(color) {
      // Update scope value and ng-model
      $scope.sgColor = color;
      ngModelController.$setViewValue(color);
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgColorPicker', sgColorPicker);
})();
