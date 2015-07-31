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
  sgColorPicker.$inject = ['$parse'];
  function sgColorPicker($parse) {
    return {
      restrict: 'E',
      template: [
        '<md-menu>',
        '  <md-button class="sg-icon-button"',
        '             label:aria-label="Options"',
        '             ng-click="$mdOpenMenu()"',
        '             md-menu-origin="md-menu-origin">',
        '    <md-icon>color_lens</md-icon>',
        '  </md-button>',
        '  <md-menu-content class="md-padding" width="3">',
        '    <md-grid-list class="sg-color-picker" md-cols="7" md-row-height="1:1" md-gutter="0.5em">',
        '      <md-grid-tile ng-repeat="color in $sgColorPickerController.colors"',
        '                    ng-style="{ \'background-color\': color }"',
        '                    ng-click="$sgColorPickerController.select(color)"></md-grid-tile>',
        '    </md-grid-list>',
        '  </md-menu-content>',
        '</md-menu>'
      ].join(''),
      replace: true,
      bindToController: true,
      controller: sgColorPickerController,
      controllerAs: '$sgColorPickerController',
      link: link
    };

    function link(scope, iElement, iAttr, controller) {
      // Associate callback to controller
      controller.doSelect = $parse(iElement.attr('sg-on-select'));
    }
  }
  
  /**
   * @ngInject
   */
  sgColorPickerController.$inject = ['$scope', 'sgColors'];
  function sgColorPickerController($scope, sgColors) {
    var vm = this;

    vm.colors = sgColors.selection;
    vm.select = function(color) {
      vm.doSelect($scope, { color: color });
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgColorPicker', sgColorPicker);
})();
