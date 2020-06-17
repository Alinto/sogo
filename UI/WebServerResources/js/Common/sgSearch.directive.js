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
     <md-select multiple>
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
          optionEl = tElement.find('md-option'),
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
        var compiledButtonEl = iElement.find('button'), selectedOption;

        // Retrive the form and input names to check the form's validity in the controller
        controller.formName = iElement.attr('name');
        controller.inputName = inputEl.attr('name');

        // Associate the sg-allow-dot parameter (boolean) to the controller
        controller.allowDot = $parse(iElement.attr('sg-allow-dot'))(scope);

        // Associate the sg-search-fields parameter (array) to the controller
        controller.fields = $parse(iElement.attr('sg-search-fields'))(scope);

        // Associate callback to controller
        controller.doSearch = $parse(iElement.attr('sg-search'));

        // Initialize searchField model to first selected option
        selectedOption = _.find(optionEl, function (el) {
          return el.getAttribute('selected');
        });
        if (selectedOption) {
          controller.searchField = selectedOption.getAttribute('value');
        }

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
    var vm = this;

    // Controller variables
    vm.searchText = null;

    // Model options
    vm.searchTextOptions = {
      updateOn: 'default blur',
      debounce: {
        default: 300,
        blur: 0
      }
    };

    if ($element.attr('sg-search-fields')) {
      var waitforFieldsOnce = $scope.$watch(vm.fields, function(value) {
        // Select all fields by default
        vm.searchField = _.clone(vm.fields);
        waitforFieldsOnce();
      });
    }

    // Method to call on data changes
    vm.onChange = function() {
      var form = $scope[vm.formName],
          input = form[vm.inputName],
          rawSearchText = input.$viewValue;

      if (vm.allowDot && rawSearchText == '.' || form.$valid && rawSearchText) {
        if (rawSearchText == '.')
          // Ignore the minlength constraint when using the dot operator
          input.$setValidity('minlength', true);

        // doSearch is the compiled expression of the sg-search attribute
        vm.doSearch($scope, { searchText: rawSearchText, searchField: vm.searchField });
      }
    };

    // Reset input field when cancelling the search
    vm.cancelSearch = function() {
      vm.searchText = null;
    };
  }

  angular
    .module('SOGo.Common')
    .controller('sgSearchController', sgSearchController)
    .directive('sgSearch', sgSearchPreTransclude)
    .directive('sgSearch', sgSearch);
})();
