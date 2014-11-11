/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for common UI services */

(function() {
  'use strict';

  /**
   * @name Dialog
   * @constructor
   */
  function Dialog() {
  }

  /**
   * @name alert
   * @desc Show an alert dialog box with a single "OK" button
   * @param {string} title
   * @param {string} content
   */
  Dialog.alert = function(title, content) {
    this.$modal.open({
      template:
      '<h2 data-ng-bind-html="title"></h2>' +
        '<p data-ng-bind-html="content"></p>' +
        '<a class="button button-primary" ng-click="closeModal()">' + l('OK') + '</a>' +
        '<span class="close-reveal-modal" ng-click="closeModal()"><i class="icon-close"></i></span>',
      windowClass: 'small',
      controller: function($scope, $modalInstance) {
        $scope.title = title;
        $scope.content = content;
        $scope.closeModal = function() {
          $modalInstance.close();
        };
      }
    });
  };

  /**
   * @name confirm
   * @desc Show a confirmation dialog box with buttons "Cancel" and "OK"
   * @param {string} title
   * @param {string} content
   * @returns a promise that always resolves, but returns true only if the user user has clicked on the
   * 'OK' button
   */
  Dialog.confirm = function(title, content) {
    var d = this.$q.defer();
    this.$modal.open({
      template:
        '<h2 data-ng-bind-html="title"></h2>' +
        '<p data-ng-bind-html="content"></p>' +
        '<a class="button button-primary" ng-click="confirm()">' + l('OK') + '</a>' +
        '<a class="button button-secondary" ng-click="closeModal()">' + l('Cancel') + '</a>' +
        '<span class="close-reveal-modal" ng-click="closeModal()"><i class="icon-close"></i></span>',
      windowClass: 'small',
      controller: function($scope, $modalInstance) {
        $scope.title = title;
        $scope.content = content;
        $scope.closeModal = function() {
          $modalInstance.close();
          d.resolve(false);
        };
        $scope.confirm = function() {
          $modalInstance.close();
          d.resolve(true);
        };
      }
    });
    return d.promise;
  };

  Dialog.prompt = function(title, inputPlaceholder, options) {
    var o = options || {},
        d = this.$q.defer();
    this.$modal.open({
      template:
      '<h2 ng-bind-html="title"></h2>' +
        '<form><input type="' + (o.inputType || 'text')
        + '" placeholder="' + (inputPlaceholder || '') + '" ng-model="inputValue" /></form>' +
        '<a class="button button-primary" ng-click="confirm(inputValue)">' + l('OK') + '</a>' +
        '<a class="button button-secondary" ng-click="closeModal()">' + l('Cancel') + '</a>' +
        '<span class="close-reveal-modal" ng-click="closeModal()"><i class="icon-close"></i></span>',
      windowClass: 'small',

      controller: function($scope, $modalInstance) {
        $scope.title = title;
        $scope.inputValue = o.inputValue || '';
        $scope.closeModal = function() {
          $modalInstance.close();
          d.resolve(false);
        };
        $scope.confirm = function(value) {
          $modalInstance.close();
          d.resolve(value);
        };
      }
    });
    return d.promise;
  };

  /**
   * @memberof Dialog
   * @desc The factory we'll register as sgDialog in the Angular module SOGo.UIDesktop
   */
  Dialog.$factory = ['$modal', '$q', function($modal, $q) {
    angular.extend(Dialog, { $modal: $modal, $q: $q });

    return Dialog; // return constructor
  }];

  /* Angular module instanciation */
  angular.module('SOGo.UIDesktop', ['mm.foundation'])

  /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory)

  /**
   * @desc A directive evaluated when the escape key is pressed.
   */
    .directive('sgEscape', function() {
      var ESCAPE_KEY = 27;
      return function (scope, elem, attrs) {
        elem.bind('keydown', function (event) {
          if (event.keyCode === ESCAPE_KEY) {
            scope.$apply(attrs.sgEscape);
          }
        });
      };
    })

/*
 * sgDropdownContentToggle - Provides dropdown content functionality
 * @restrict class or attribute
 * @see https://github.com/pineconellc/angular-foundation/blob/master/src/dropdownToggle/dropdownToggle.js
 * @example:

   <a dropdown-toggle="#dropdown-content">My Dropdown Content</a>
   <div id="dropdown-content" class="sg-dropdown-content">
     <div>
       <h1>Hello</h1>
       <p>World!</p>
     </div>
   </div>
 */
    .directive('sgDropdownContentToggle', ['$document', '$window', '$location', '$position', function ($document, $window, $location, $position) {
      var openElement = null,
          closeMenu   = angular.noop;
      return {
        restrict: 'CA', // class and attribute
        scope: {
          dropdownToggle: '@sgDropdownContentToggle'
        },
        link: function(scope, element, attrs, controller) {
          var dropdown = angular.element($document[0].querySelector(scope.dropdownToggle));

          scope.$watch('$location.path', function() {
            closeMenu();
          });
          element.bind('click', function(event) {
            var elementWasOpen = (element === openElement);

            event.preventDefault();
            event.stopPropagation();

            if (!!openElement) {
              closeMenu();
            }

            if (!elementWasOpen && !element.hasClass('disabled') && !element.prop('disabled')) {
              dropdown.css('display', 'block');

              var offset = $position.offset(element),
                  dropdownParentOffset = $position.offset(angular.element(dropdown[0].offsetParent)),
                  dropdownWidth = dropdown.prop('offsetWidth'),
                  dropdownHeight = dropdown.prop('offsetHeight'),
                  dropdownCss = {},
                  left = Math.round(offset.left - dropdownParentOffset.left),
                  rightThreshold = $window.innerWidth - dropdownWidth - 8,
                  nub = angular.element(dropdown.children()[0]),
                  nubCss = {};

              if (left > rightThreshold) {
                // There's more place on the left side of the element
                left = rightThreshold;
                dropdown.removeClass('left').addClass('right');
                nub.removeClass('left').addClass('right');
              }

              dropdownCss.position = null;
              dropdownCss['max-width'] = null;
              // Place a third of the dropdown above the element
              dropdownCss.top = Math.round(offset.top + offset.height / 2 - dropdownHeight / 3),
              dropdownCss.left = Math.round(offset.left + offset.width + 10);

              if (dropdownCss.top + dropdownHeight > $window.innerHeight) {
                // Position dropdown at the very top of the window
                dropdownCss.top =  $window.innerHeight - dropdownHeight - 5;
                if (dropdownHeight > $window.innerHeight) {
                  // Resize height of dropdown to fit window
                  dropdownCss.height = ($window.innerHeight - 10) + 'px';
                }
              }

              // Place nub beside the element
              nubCss.top = Math.round(offset.top - dropdownCss.top + offset.height / 2 - nub.prop('offsetHeight') / 2) + 'px';

              // Apply CSS
              dropdownCss.top += 'px';
              dropdownCss.left += 'px';
              dropdown.css(dropdownCss);
              nub.css(nubCss);

              openElement = element;
              closeMenu = function (event) {
                if (event) {
                  // We ignore clicks that occur inside the dropdown content element, unless it's a button
                  var target = angular.element(event.target),
                      ignoreClick = false;
                  while (target[0]) {
                    if (target[0].tagName == 'BUTTON') break;
                    if (target[0] == dropdown[0]) {
                      ignoreClick = true;
                      break;
                    }
                    target = target.parent();
                  }
                  if (ignoreClick) return;
                }

                $document.unbind('click', closeMenu);
                dropdown.css('display', 'none');
                closeMenu = angular.noop;
                openElement = null;
              };
              $document.bind('click', closeMenu);
            }
          });

          if (dropdown) {
            dropdown.css('display', 'none');
          }
        }
      };
    }])

/*
 * sgSubscribe - Common subscription widget
 * @restrict class or attribute
 * @param {String} sgSubscribe - the folder type
 * @param {Function} sgSubscribeOnSelect - the function to call when subscribing to a folder
 * @example:

   <div sg-subscribe="contact" sg-subscribe-on-select="subscribeToFolder"></div>
 */
    .directive('sgSubscribe', [function() {
      return {
        restrict: 'CA',
        scope: {
          folderType: '@sgSubscribe',
          onFolderSelect: '=sgSubscribeOnSelect'
        },
        templateUrl: 'userFoldersTemplate', // UI/Templates/Contacts/UIxContactsUserFolders.wox
        controller: ['$scope', function($scope) {
          $scope.selectUser = function(i) {
            // Fetch folders of specific type for selected user
            $scope.users[i].$folders($scope.folderType).then(function() {
              $scope.selectedUser = $scope.users[i];
            });
          };
          $scope.selectFolder = function(folder) {
            console.debug("select folder " + folder.displayName);
            $scope.onFolderSelect(folder);
          };
        }],
        link: function(scope, element, attrs, controller) {
          // NOTE: We could also make these modifications in the wox template
          element.addClass('joyride-tip-guide');
          angular.element(element.children()[0]).addClass('joyride-content-wrapper');
          element.prepend('<span class="joyride-nub left"></span>');
        }
      };
    }])

/*
 * sgUserTypeahead - Typeahead of users, used internally by sgSubscribe
 * @restrict attribute
 * @param {String} sgModel - the folder type
 * @param {Function} sgSubscribeOnSelect - the function to call when subscribing to a folder
 * @see https://github.com/pineconellc/angular-foundation/blob/master/src/typeahead/typeahead.js
 * @example:

   <div sg-subscribe="contact" sg-subscribe-on-select="subscribeToFolder"></div>
 */
    .directive('sgUserTypeahead', ['$parse', '$q', '$timeout', '$position', 'sgUser', function($parse, $q, $timeout, $position, User) {
      return {
        restrict: 'A',
        require: 'ngModel',
        link: function(originalScope, element, attrs, controller) {

          var hasFocus,
              scope,
              resetMatches,
              getMatchesAsync,
              // Declare the timeout promise var outside the function scope so that stacked calls can be cancelled later
              timeoutPromise,
              // Minimal number of characters that needs to be entered before typeahead kicks-in
              minSearch = originalScope.$eval(attrs.sgSubscribeMinLength) || 3,
              // Minimal wait time after last character typed before typehead kicks-in
              waitTime = originalScope.$eval(attrs.sgSubscribeWaitMs) || 500,
              // Binding to a variable that indicates if matches are being retrieved asynchronously
              isLoadingSetter = $parse(attrs.sgSubscribeLoading).assign || angular.noop;

          // Create a child scope for the typeahead directive so we are not polluting original scope
          // with typeahead-specific data (users, query, etc.)
          scope = originalScope.$new();
          originalScope.$on('$destroy', function(){
            scope.$destroy();
          });

          resetMatches = function() {
            originalScope.users = [];
            originalScope.selectedUser = undefined;
            scope.activeIdx = -1;
          };

          getMatchesAsync = function(inputValue) {
            isLoadingSetter(originalScope, true);
            $q.when(User.$filter(inputValue)).then(function(matches) {
              // It might happen that several async queries were in progress if a user were typing fast
              // but we are interested only in responses that correspond to the current view value
              if (inputValue === controller.$viewValue && hasFocus) {
                if (matches.length > 0) {
                  scope.activeIdx = 0;
                  originalScope.users = matches;
                  originalScope.query = inputValue; // for the hightlighter
                }
                else {
                  resetMatches();
                }
                isLoadingSetter(originalScope, false);
              }
            }, function(){
              resetMatches();
              isLoadingSetter(originalScope, false);
            });
          };

          resetMatches();

          // We need to propagate user's query so we can higlight matches
          originalScope.query = undefined;

          // Plug into $parsers pipeline to open a typeahead on view changes initiated from DOM
          // $parsers kick-in on all the changes coming from the view as well as manually triggered by $setViewValue
          controller.$parsers.unshift(function (inputValue) {
            if (inputValue && inputValue.length >= minSearch) {
              if (waitTime > 0) {
                if (timeoutPromise) {
                  $timeout.cancel(timeoutPromise); // cancel previous timeout
                }
                timeoutPromise = $timeout(function() {
                  getMatchesAsync(inputValue);
                }, waitTime);
              }
              else {
                getMatchesAsync(inputValue);
              }
            }
            else {
              isLoadingSetter(originalScope, false);
              resetMatches();
            }
            return inputValue;
          });

          element.bind('blur', function (evt) {
            hasFocus = false;
          });

          element.bind('focus', function (evt) {
            hasFocus = true;
          });
        }
      };
    }]);

})();
