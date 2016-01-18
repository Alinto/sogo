/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /*
   * sgSearch - Search within a list of items
   * @memberof SOGo.Common
   * @restrict attribute
   * @param {function} sgSearch - the function to call when performing a search.
   *        Two variables are available: searchField and searchText.
   * @example:

   <div sg-search="mailbox.$filter({ sort: 'date', asc: false }, [{ searchBy: searchField, searchInput: searchText }])">
     <md-button class="sg-icon-button"
                sg-search-cancel="ctrl.cancelSearch()">
       <md-icon>arrow_back</md-icon>
     </md-button>
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
          selectEl = tElement.find('md-select'),
          buttonEl = tElement.find('md-button');

      inputEl.attr('ng-model', '$sgSearchController.searchText');
      inputEl.attr('ng-model-options', '$sgSearchController.searchTextOptions');
      inputEl.attr('ng-change', '$sgSearchController.onChange()');
      if (selectEl) {
        selectEl.attr('ng-model', '$sgSearchController.searchField');
        selectEl.attr('ng-change', '$sgSearchController.onChange()');
      }
      if (buttonEl && buttonEl.attr('sg-search-cancel')) {
        buttonEl.attr('ng-click', buttonEl.attr('sg-search-cancel'));
        buttonEl.removeAttr('sg-search-cancel');
      }
      else {
        buttonEl = null;
      }

      return function postLink(scope, iElement, iAttr, controller) {
        var compiledButtonEl = iElement.find('button');

        // Associate callback to controller
        controller.doSearch = $parse(iElement.attr('sg-search'));

        // Reset the input field when cancelling the search
        if (buttonEl && compiledButtonEl) {
          compiledButtonEl.on('click', controller.cancelSearch);
        }
      };
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
      };
    }
  }

  /**
   * @ngInject
   */
  sgSearchController.$inject = ['$window', '$scope', '$element'];
  function sgSearchController($window, $scope, $element) {
    var vm = this, minLength;

    // Domain's defaults
    minLength = angular.isNumber($window.minimumSearchLength)? $window.minimumSearchLength : 2;

    // Controller variables
    vm.previous = { searchText: '', searchField: '' };
    vm.searchText = null;

    // Model options
    vm.searchTextOptions = {
      updateOn: 'default blur',
      debounce: {
        default: 300,
        blur: 0
      }
    };

    // Method to call on data changes
    vm.onChange = function() {
      if (typeof vm.searchText !== 'undefined' && vm.searchText !== null) {
        if (vm.searchText != vm.previous.searchText || vm.searchField != vm.previous.searchField) {
          if (vm.searchText.length > minLength || vm.searchText.length === 0 || vm.searchText == '.') {
            // doSearch is the compiled expression of the sg-search attribute
            vm.doSearch($scope, { searchText: vm.searchText, searchField: vm.searchField });
          }
          vm.previous = { searchText: vm.searchText, searchField: vm.searchField };
        }
      }
    };

    // Reset input field when cancelling the search
    vm.cancelSearch = function() {
      vm.previous = { searchText: '', searchField: '' };
      vm.searchText = null;
    };
  }

  angular
    .module('SOGo.Common')
    .controller('sgSearchController', sgSearchController)
    .directive('sgSearch', sgSearchPreTransclude)
    .directive('sgSearch', sgSearch);
})();
