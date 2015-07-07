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
  sgSearchPreTransclude.$inject = ['$parse'];
  function sgSearchPreTransclude($parse) {
    return {
      restrict: 'A',
      controller: 'sgSearchController',
      controllerAs: '$sgSearchController',
      priority: 1001,
      compile: compile
    };

    function compile(tElement, tAttr) {
      var mdInputEl = tElement.find('md-input-container'),
          inputEl = tElement.find('input'),
          selectEl = tElement.find('md-select');

      inputEl.attr('ng-model', '$sgSearchController.searchText');
      inputEl.attr('ng-model-options', '$sgSearchController.searchTextOptions');
      inputEl.attr('ng-change', '$sgSearchController.onChange()');
      if (selectEl) {
        selectEl.attr('ng-model', '$sgSearchController.searchField');
        selectEl.attr('ng-change', '$sgSearchController.onChange()');
      }

      return function postLink(scope, iElement, iAttr, controller) {
        // Associate callback to controller
        controller.doSearch = $parse(iElement.attr('sg-search'));
      }
    }
  }

  function sgSearch() {
    return {
      restrict: 'A',
      priority: 1000,
      transclude: true,
      compile: compile
    };

    function compile(tElement, tAttr) {
      return function postLink(scope, iElement, iAttr, controller, transclude) {
        transclude(function(clone) {
          iElement.append(clone);
        });
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
    this.searchText = null;

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
      if (this.searchText != null) {
        if (this.searchText != this.previous.searchText || this.searchField != this.previous.searchField) {
          if (this.searchText.length > 2 || this.searchText.length == 0) {
            // doSearch is the compiled expression of the sg-search attribute
            this.doSearch($scope, { searchText: this.searchText, searchField: this.searchField });
          }
          this.previous = { searchText: this.searchText, searchField: this.searchField };
        }
      }
    };
  }

  angular
    .module('SOGo.Common')
    .controller('sgSearchController', sgSearchController)
    .directive('sgSearch', sgSearchPreTransclude)
    .directive('sgSearch', sgSearch);
})();
