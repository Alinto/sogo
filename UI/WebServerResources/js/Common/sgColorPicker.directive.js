/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgColorPicker - Color picker widget
   * @restrict element
   * @ngInject
   * @example:

     <sg-color-picker ng-model="properties.calendar.color"></sg-color-picker>
  */
  function sgColorPicker() {
    return {
      restrict: 'E',
      require: 'ngModel',
      template: [
        '  <md-button class="md-icon-button"',
        '             label:aria-label="Options"',
        '             ng-click="$ctrl.showPicker($event)">',
        '    <md-icon>format_color_fill</md-icon>',
        '  </md-button>'
      ].join(''),
      controller: sgColorPickerController,
      controllerAs: '$ctrl'
    };
  }

  /**
   * @ngInject
   */
  sgColorPickerController.$inject = ['$scope', '$element', '$mdPanel', 'sgColors'];
  function sgColorPickerController($scope, $element, $mdPanel, sgColors) {
    var $ctrl, ngModelController, color;

    this.$onInit = function() {
      $ctrl = this;
      ngModelController = $element.controller('ngModel');
    };

    this.$postLink = function() {
      this.buttonIcon = $element.find('md-icon');
      ngModelController.$render = function() {
        updateColor(ngModelController.$viewValue);
      };
    };

    function updateColor(newColor) {
      color = newColor;
      $ctrl.buttonIcon.css('color', color);
    }

    this.showPicker = function($event) {
      var panelPosition = $mdPanel.newPanelPosition()
          .relativeTo($ctrl.buttonIcon)
          .addPanelPosition(
            $mdPanel.xPosition.ALIGN_START,
            $mdPanel.yPosition.ALIGN_TOPS
          );

      var panelAnimation = $mdPanel.newPanelAnimation()
          .openFrom($ctrl.buttonIcon)
          .duration(100)
          .withAnimation($mdPanel.animation.FADE);

      // Build grid with 7 colors per row
      var columns = [];
      var column = '';
      for (var i = 0; i < sgColors.selection.length; i++) {
        var currentColor = sgColors.selection[i];
        var currentContrastColor = contrast(currentColor);
        var selected = (currentColor == color);
        if (i % 7 === 0) {
          if (column.length) columns.push(column);
          column = '';
        }
        column += '<span ';
        if (selected)
          column += 'class="selected" ';
        column += 'style="background-color: ' + currentColor + '" ng-click="$menuCtrl.setColor($event, \'' + currentColor + '\')">';
        if (selected)
          column += '<md-icon class="icon-check" style="color: ' + currentContrastColor + '"></md-icon>';
        column += '</span>';
      }

      var config = {
        attachTo: angular.element(document.body),
        bindToController: true,
        controller: MenuController,
        controllerAs: '$menuCtrl',
        position: panelPosition,
        animation: panelAnimation,
        targetEvent: $event,
        template: [
          '<div class="sg-color-picker-panel" md-whiteframe="3">',
          '  <div>' + columns.join('</div><div>') + '</div>',
          '</div>'
        ].join(''),
        trapFocus: true,
        clickOutsideToClose: true,
        escapeToClose: true,
        focusOnOpen: true
      };

      $mdPanel.open(config)
        .then(function(panelRef) {
          // Automatically close panel when clicking inside of it
          panelRef.panelEl.one('click', function() {
            panelRef.close();
          });
        });

      MenuController.$inject = ['mdPanelRef', '$state', '$mdDialog', 'User'];
      function MenuController(mdPanelRef, $state, $mdDialog, User) {
        var $menuCtrl = this;

        this.setColor = function(event, color) {
          if (event) {
            _.forEach(event.currentTarget.parentElement.children, function(tile) {
              tile.classList.remove('selected');
            });
            event.currentTarget.classList.add('selected');
          }
          // Update scope value and ng-model
          updateColor(color);
          ngModelController.$setViewValue(color);
        };
      }
    };
  }

  angular
    .module('SOGo.Common')
    .directive('sgColorPicker', sgColorPicker);
})();
