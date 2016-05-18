/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgTransformOnBlur - A directive to extend md-chips so the text of the input
   * field is converted to a chip when the field is loosing focus.
   *
   * See issue on github:
   *
   *   https://github.com/angular/material/issues/3364
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
  function sgTransformOnBlur() {
    return {
      link: link,
      require: 'mdChips', // Extends the original mdChips directive
      restrict: 'A'
    };

    function link(scope, element, attributes, mdChipsCtrl) {
      mdChipsCtrl.onInputBlur = function() {
        this.inputHasFocus = false;

        // ADDED CODE
        var chipBuffer = this.getChipBuffer();
        if ((this.hasAutocomplete && this.requireMatch) || !chipBuffer || chipBuffer === "") return;
        this.appendChip(chipBuffer);
        this.resetChipBuffer();
        // - EOF - ADDED CODE
      };
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgTransformOnBlur', sgTransformOnBlur);
})();
