/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgFolderStylesheet - Add CSS stylesheet for folder (addressbook or calendar)
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {object} ngModel - the object literal describing the folder (an Addressbook or Calendar instance)
   * @example:

    <div sg-folder-stylesheet="true"
         ng-repeat="calendar in calendars.list"
         ng-model="calendar" />
   </div>
  */
  function sgFolderStylesheet() {
    return {
      restrict: 'A',
      require: 'ngModel',
      scope: {
        ngModel: '='
      },
      bindToController: true,
      controller: sgFolderStylesheetController,
      controllerAs: 'cssCtrl',
      template: [
        '<style type="text/css">',
        /* Background color */
        '  .bg-folder{{ cssCtrl.ngModel.id }},',
        '  .bg-folder{{ cssCtrl.ngModel.id }} label,',
        '  .bg-folder{{ cssCtrl.ngModel.id }} .md-input,',
        '  .sg-event.bg-folder{{ cssCtrl.ngModel.id }} md-icon {',
        '    background-color: {{ cssCtrl.ngModel.color }} !important;',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        // Set the contrast color of toolbar icons except the one of the background
        '  md-toolbar.bg-folder{{ cssCtrl.ngModel.id }} md-icon:not(.sg-icon-toolbar-bg) {',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        // Set the contrast color of input labels
        '  .bg-folder{{ cssCtrl.ngModel.id }} label {',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '    opacity: 0.8;',
        '  }',
        /* Foreground color */
        '  .fg-folder{{ cssCtrl.ngModel.id }} {',
        '    color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        /* Border color */
        '  .bdr-folder{{ cssCtrl.ngModel.id }} {',
        '    border-color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        /* Checkbox color */
        '  .checkbox-folder{{ cssCtrl.ngModel.id }} .md-icon {',
        '    background-color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        '  .checkbox-folder{{ cssCtrl.ngModel.id }}.md-checked .md-icon:after {',
        '    border-color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        '</style>'
      ].join('')
    };

    function sgFolderStylesheetController() {
      var vm = this;

      vm.contrast = contrast;

      function hexToRgb(hex) {
        var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        return result ? {
          r: parseInt(result[1], 16),
          g: parseInt(result[2], 16),
          b: parseInt(result[3], 16)
        } : null;
      }

      // Respect contrast ratio recommendation from W3C:
      // http://www.w3.org/TR/WCAG20/#contrast-ratiodef
      function contrast(hex) {
        var color, c, l;

        color = hexToRgb(hex);
	c = [color.r / 255, color.g / 255, color.b / 255];

	for (var i = 0; i < c.length; ++i) {
	  if (c[i] <= 0.03928) {
	    c[i] = c[i] / 12.92;
	  }
          else {
	    c[i] = Math.pow((c[i] + 0.055) / 1.055, 2.4);
	  }
	}

	l = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];

	if (l > 0.179) {
          return 'black';
        }
        else {
          return 'white';
	}
      }
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgFolderStylesheet', sgFolderStylesheet);
})();
