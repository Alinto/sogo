/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgFolderStylesheet - Add CSS stylesheet for a folder's color (addressbook or calendar)
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {object} ngModel - the object literal describing the folder (an Addressbook or Calendar instance)
   * @example:

    <sg-folder-stylesheet
         ng-repeat="calendar in calendars.list"
         ng-model="calendar" />
  */
  function sgFolderStylesheet() {
    return {
      restrict: 'E',
      require: 'ngModel',
      scope: {
        ngModel: '='
      },
      replace: true,
      bindToController: true,
      controller: sgFolderStylesheetController,
      controllerAs: 'cssCtrl',
      template: [
        '<style type="text/css">',
        /* Background color */
        '  .bg-folder{{ cssCtrl.ngModel.id }} {',
        '    background-color: {{ cssCtrl.ngModel.color }} !important;',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        '  .sg-event.bg-folder{{ cssCtrl.ngModel.id }} md-icon {',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        // Set the contrast color of toolbar icons except the one of the background
        '  md-toolbar.bg-folder{{ cssCtrl.ngModel.id }} md-icon:not(.sg-icon-toolbar-bg) {',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        // Set the contrast color of input labels
        '  .bg-folder{{ cssCtrl.ngModel.id }} label,',
        '  .bg-folder{{ cssCtrl.ngModel.id }} .md-input {',
        '    color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '    opacity: 0.8;',
        '  }',
        /* Foreground color */
        '  .fg-folder{{ cssCtrl.ngModel.id }},',
        '  .sg-event.fg-folder{{ cssCtrl.ngModel.id }} md-icon {',
        '    color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        /* Border color */
        '  .bdr-folder{{ cssCtrl.ngModel.id }} {',
        '    border-color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        '  .contrast-bdr-folder{{ cssCtrl.ngModel.id }} {',
        '    border-color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        /* Checkbox color */
        '  .checkbox-folder{{ cssCtrl.ngModel.id }} .md-icon {',
        '    background-color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        '  .checkbox-folder{{ cssCtrl.ngModel.id }}.md-checked .md-icon:after {',
        '    border-color: {{ cssCtrl.contrast(cssCtrl.ngModel.color) }} !important;',
        '  }',
        /* Switch color */
        '  .md-switch-folder{{ cssCtrl.ngModel.id }}.md-checked .md-thumb {',
        '    background-color: {{ cssCtrl.ngModel.color }} !important;',
        '  }',
        '  .md-switch-folder{{ cssCtrl.ngModel.id }}.md-checked .md-bar {',
        '    background-color: {{ cssCtrl.transparent(cssCtrl.ngModel.color, "0.5") }} !important;',
        '  }',
        '  .md-switch-folder{{ cssCtrl.ngModel.id }} .md-bar {',
        '    background-color: {{ cssCtrl.transparent(cssCtrl.ngModel.color, "0.3") }} !important;',
        '  }',
        '</style>'
      ].join('')
    };

    function sgFolderStylesheetController() {
      var vm = this;

      vm.contrast = contrast; // defined in Common/utils.js
      vm.transparent = function(hex, ratio) {
        var color = hexToRgb(hex);

        return ['rgba(' + color.r, color.g, color.b, ratio + ')'].join(',');
      };
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgFolderStylesheet', sgFolderStylesheet);
})();
