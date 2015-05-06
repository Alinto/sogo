/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* JavaScript for common UI services */

(function() {
  'use strict';

  angular.module('SOGo.Common')

  /*
   * sgFolderTree - Provides hierarchical folders tree
   * @memberof SOGo.Common
   * @restrict element
   * @param {object} sgRoot
   * @param {object} sgFolder
   * @param {function} sgSelectFolder
   * @see https://github.com/marklagendijk/angular-recursion
   * @example:

     <sg-folder-tree ng-repeat="folder in folders track by folder.id"
                     sg-root="account"
                     sg-folder="folder"
                     sg-select-folder="setCurrentFolder"><!-- tree --></sg-folder-tree>
  */
    .directive('sgFolderTree', function(RecursionHelper) {
      return {
        restrict: 'E',
        scope: {
          root: '=sgRoot',
          folder: '=sgFolder',
          selectFolder: '=sgSelectFolder'
        },
        template: [
          '<md-list-item>',
          '  <md-item-content layout="row" layout-align="start center" flex>',
          '    <i class="md-icon-folder"></i>',
          '    <button class="md-button md-flex sg-item-name">{{folder.name}}</button>',
          '    <md-input-container class="md-flex md-tile-content ng-hide">'+
          '      <input type="text"',
          '             ng-model="folder.name"',
          '             ng-blur="save()"',
          '             sg-enter="save()"',
          '             sg-escape="revert()"/>',
          '    </md-input-container>',
          '    <span class="icon ng-hide" ng-cloak="ng-cloak">',
          '      <a class="icon" href="#"',
          '         dropdown-toggle="#folderProperties"',
          '         options="align:right"><i class="md-icon-more-vert"></i></a>',
          '    </span>',
          '  </md-item-content>',
          '</md-list-item>',
          '<sg-folder-tree ng-repeat="child in folder.children track by child.path"',
          '                sg-root="root"',
          '                sg-folder="child"',
          '                sg-select-folder="selectFolder"></sg-folder-tree>'
        ].join(''),
        compile: function(element) {
          return RecursionHelper.compile(element, function(scope, iElement, iAttrs, controller, transcludeFn) {
            var level, link, inputContainer, input, edit;

            // Set CSS class for folder hierarchical level
            level = scope.folder.path.split('/').length - 1;
            angular.element(iElement.find('i')[0]).addClass('sg-child-level-' + level);

            // Select dynamic elements
            link = angular.element(iElement.find('button')[0]);
            inputContainer = angular.element(iElement.find('md-input-container'));
            input = iElement.find('input')[0];

            var edit = function() {
                link.addClass('ng-hide');
                inputContainer.removeClass('ng-hide');
                input.focus();
                input.select();
            };

            // jQLite listeners

            // click - call the directive's external function sgSelectFolder
            link.on('click', function() {
              var list, items;
              if (!scope.mode.selected) {
                list = iElement.parent();
                while (list[0].tagName != 'MD-LIST') {
                  list = list.parent();
                }
                items = list.find('md-list-item');

                // Highlight element as "loading"
                items.removeClass('sg-active');
                items.removeClass('sg-loading');
                angular.element(iElement.find('md-list-item')[0]).addClass('sg-loading');

                // Call external function
                scope.selectFolder(scope.root, scope.folder);
              }
            });

            // dblclick - enter edit mode
            link.on('dblclick', function() {
              edit();
            });

            // Broadcast listeners

            // sgSelectFolder - broadcasted when the folder has been successfully loaded
            scope.$on('sgSelectFolder', function(event, folderId) {
              if (folderId == scope.folder.id) {
                var list = iElement.parent(),
                    items;

                scope.mode.selected = true;
                while (list[0].tagName != 'MD-LIST') {
                  list = list.parent();
                }
                items = list.find('md-list-item');

                // Hightlight element as "selected"
                angular.element(iElement.find('md-list-item')[0]).addClass('sg-active');
                angular.element(iElement.find('md-list-item')[0]).removeClass('sg-loading');

                // Show options button
                angular.forEach(items, function(element) {
                  var li = angular.element(element);
                  var spans = li.find('span');
                  angular.element(spans[0]).addClass('ng-hide');
                });
                angular.element(iElement.find('span')[0]).removeClass('ng-hide');
              }
              else {
                scope.mode.selected = false;
              }
            });

            // sgEditFolder - broadcasted when the user wants to rename the folder
            scope.$on('sgEditFolder', function(event, folderId) {
              if (scope.mode.selected && folderId == scope.folder.id) {
                edit();
              }
            });

            // Local scope variables and functions

            scope.mode = { selected: false };

            scope.save = function() {
              if (link.hasClass('ng-hide')) {
                inputContainer.addClass('ng-hide');
                link.removeClass('ng-hide');
                scope.$emit('sgSaveFolder', scope.folder.id);
              }
            };

            scope.revert = function() {
              scope.$emit('sgRevertFolder', scope.folder.id);
            };
          });
        }
      };
    })

  /*
   * sgDropdownContentToggle - Provides dropdown content functionality
   * @memberof SOGo.Common
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
  /*
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
                  dropdownCss.top = 5;
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
  */

  /*
   * UserTypeahead - Typeahead of users, used internally by sgSubscribe
   * @restrict attribute
   * @param {String} sgModel - the folder type
   * @param {Function} sgSubscribeOnSelect - the function to call when subscribing to a folder
   * @see https://github.com/pineconellc/angular-foundation/blob/master/src/typeahead/typeahead.js
   * @example:

    <div sg-subscribe="contact" sg-subscribe-on-select="subscribeToFolder"></div>
  */
    .directive('sgUserTypeahead', ['$parse', '$q', '$timeout', 'User', function($parse, $q, $timeout, User) {
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
    }])

})();
