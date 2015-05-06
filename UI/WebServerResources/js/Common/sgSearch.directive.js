/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /*
   * sgSearch - Search within a list of items
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {function} sgSearch - the function to call when performing a search.
   *        Two variables are available: searchField and searchText.
   * @example:

   <div sg-search="mailbox.$filter({ sort: 'date', asc: false }, [{ searchBy: searchField, searchInput: searchText }])">
     <md-input-container>
       <input name="search" type="search"/>
     </md-input-container>
     <md-select class="sg-toolbar-sort md-contrast-light">
       <md-option value="subject">Subject</md-option>
       <md-option value="sender">sender</md-option>
     </md-select>
   </div>
  */
  sgSearch.$inject = ['$compile'];
  function sgSearch($compile) {
    return {
      restrict: 'A',
      controller: 'sgSearchController',
      controllerAs: '$sgSearchController',
      // See http://stackoverflow.com/questions/19224028/add-directives-from-directive-in-angularjs
      // for reasons of using terminal and priority
      terminal: true,
      priority: 1000,
      scope: {
        doSearch: '&sgSearch'
      },
      compile: compile
    };

    function compile(tElement, tAttr) {
      var mdInputEl = tElement.find('md-input-container'),
          inputEl = tElement.find('input'),
          selectEl = tElement.find('md-select');

      inputEl.attr('ng-model', '$sgSearchController.searchText');
      inputEl.attr('ng-model-options', '$sgSearchController.searchTextOptions');
      if (selectEl) {
        selectEl.attr('ng-model', '$sgSearchController.searchField');
        selectEl.attr('ng-change', '$sgSearchController.onChange()');
      }

      return function postLink(scope, iElement, iAttr, controller) {
        $compile(mdInputEl)(scope);
        if (selectEl)
          $compile(selectEl)(scope);
        $compile(tElement.find('md-button'))(scope.$parent);

        scope.$watch('$sgSearchController.searchText', angular.bind(controller, controller.onChange));
      }
    }
  }

  /**
   * @ngInject
   */
  sgSearchController.$inject = ['$scope', '$element'];
  function sgSearchController($scope, $element) {
    // Controller variables
    this.previous = { searchText: '', searchField: '' };
    this.searchText = '';
    this.searchField = $element.find('md-option').attr('value'); // defaults to first option

    // Model options
    this.searchTextOptions = {
      updateOn: 'default blur',
      debounce: {
        default: 300,
        blur: 0
      }
    };

    // Method to call on data changes
    this.onChange = function(value) {
      if (typeof this.searchText != 'undefined') {
        if (this.searchText != this.previous.searchText || this.searchField != this.previous.searchField) {
          if (this.searchText.length > 2 || this.searchText.length == 0) {
            // See https://github.com/angular/angular.js/issues/7635
            // for why we need to use $scope here
            $scope.doSearch({ searchText: this.searchText, searchField: this.searchField });
          }
          this.previous = { searchText: this.searchText, searchField: this.searchField };
        }
      }
    };
  }

  angular
    .module('SOGo.Common')
    .controller('sgSearchController', sgSearchController)
    .directive('sgSearch', sgSearch);
})();
