/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint loopfunc: true */
  'use strict';

  /**
   * sgTransformOnBlur - A directive to extend md-chips so the text of the input
   * field is converted to a chip when the field is loosing focus.
   *
   * See issues on github:
   *
   *    https://github.com/angular/material/issues/3364 (md-add-on-blur)
   *    https://github.com/angular/material/issues/9582
   *
   * Code is extracted from "MdChipsCtrl.prototype.onInputBlur" in controller:
   *
   *   angular-material/src/components/chips/js/chipsController.js
   *
   * @memberof SOGo.Common
   * @ngInject
   * @example:

   <md-chips ng-model="editor.message.editable.to"
             md-separator-keys="editor.recipientSeparatorKeys"
             md-transform-chip="editor.addRecipient($chip, 'to')"
             sg-transform-on-blur>
   */
  sgTransformOnBlur.$inject = ['$window', '$timeout'];
  function sgTransformOnBlur($window, $timeout) {
    return {
      link: link,
      require: 'mdChips', // Extends the original mdChips directive
      restrict: 'A'
    };

    function link(scope, element, attributes, mdChipsCtrl) {
      var mouseUpActions = [];

      mdChipsCtrl.onInputBlur = function() {
        var appendFcn;

        this.inputHasFocus = false;
        appendFcn = (function() {
          var chipBuffer = this.getChipBuffer().trim();

          // Update the custom chip validators.
          this.validateModel();

          var isModelValid = this.ngModelCtrl.$valid;

          if (this.userInputNgModelCtrl) {
            isModelValid &= this.userInputNgModelCtrl.$valid;
          }

          // Only append the chip and reset the chip buffer if the chips and input ngModel is valid.
          if (chipBuffer && isModelValid) {
            this.appendChip(chipBuffer);
            this.resetChipBuffer();
          }
        }).bind(this);

        if (this.autocompleteCtrl) {
          mouseUpActions.push(appendFcn);
          $window.addEventListener('click', function(event){
            while (mouseUpActions.length > 0) {
              // Trigger actions after some delay to give time to md-autocomple to clear the input field
              var action = mouseUpActions.splice(0,1)[0];
              $timeout(function(){
                $timeout(action);
              });
            }
          }, false);
        }
        else
          appendFcn();
      };
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgTransformOnBlur', sgTransformOnBlur);
})();
