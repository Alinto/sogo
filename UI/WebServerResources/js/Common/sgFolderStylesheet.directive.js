/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
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
      template: [
        '<style type="text/css">',
        '  .bg-folder{{ ngModel.id }} {',
        '    background-color: {{ ngModel.color }} !important;',
        '  }',
        '  .fg-folder{{ ngModel.id }} {',
        '    color: {{ ngModel.color }} !important;',
        '  }',
        '  .checkbox-folder{{ ngModel.id }} .md-icon {',
        '    background-color: {{ ngModel.color }} !important;',
        '  }',
        '</style>'
      ].join('')
    }
  }

  angular
    .module('SOGo.Common')
    .directive('sgFolderStylesheet', sgFolderStylesheet);
})();
