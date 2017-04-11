/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgCategoryStylesheet - Add CSS stylesheet for a category's color
   * @memberof SOGo.SchedulerUI
   * @restrict attribute
   * @param {object} ngModel - the object literal describing the category
   * @example:

    <sg-category-stylesheet
         ng-repeat="category in categories"
         ng-model="category" />
  */
  function sgCategoryStylesheet() {
    return {
      restrict: 'E',
      require: 'ngModel',
      scope: {
        ngModel: '='
      },
      replace: true,
      template: [
        '<style type="text/css">',
        /* Background color */
        '  .bg-category{{ ngModel.id }} {',
        '    background-color: {{ ngModel.color }} !important;',
        '  }',
        /* Border color */
        '  .bdr-category{{ ngModel.id }} {',
        '    border-color: {{ ngModel.color }} !important;',
        '  }',
        '</style>'
      ].join('')
    };
  }

  angular
    .module('SOGo.SchedulerUI')
    .directive('sgCategoryStylesheet', sgCategoryStylesheet);
})();
