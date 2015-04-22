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
    var d = this.$q.defer(),
        confirm = this.$modal.confirm()
        .title(title)
        .content(content)
        .ok(l('OK'))
        .cancel(l('Cancel'));
    this.$modal.show(confirm).then(function() {
      d.resolve();
    }, function() {
      d.reject();
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
  Dialog.$factory = ['$q', '$mdDialog', function($q, $mdDialog) {
    angular.extend(Dialog, { $q: $q , $modal: $mdDialog });

    return Dialog; // return constructor
  }];

  /* Angular module instanciation */
  angular.module('SOGo.UIDesktop', ['ngMaterial', 'RecursionHelper'])

  /* Factory registration in Angular module */
    .factory('sgDialog', Dialog.$factory)

  /**
   * sgEnter - A directive evaluated when the enter key is pressed
   * @memberof SOGo.UIDesktop
   * @example:

     <input type="text"
            sg-enter="save($index)" />
   */
    .directive('sgEnter', function() {
      var ENTER_KEY = 13;
      return function(scope, element, attrs) {
        element.bind("keydown keypress", function(event) {
          if (event.which === ENTER_KEY) {
            scope.$apply(function() {
              scope.$eval(attrs.sgEnter);
            });
            event.preventDefault();
          }
        });
      };
    })

  /**
   * sgEscape - A directive evaluated when the escape key is pressed
   * @memberof SOGo.UIDesktop
   * @example:

     <input type="text"
            sg-escape="revertEditing($index)" />
   */
    .directive('sgEscape', function() {
      var ESCAPE_KEY = 27;
      return function(scope, elem, attrs) {
        elem.bind('keydown', function(event) {
          if (event.keyCode === ESCAPE_KEY) {
            scope.$apply(attrs.sgEscape);
          }
        });
      };
    })

  /**
   * sgFocusOn - A directive that sets the focus on its element when the specified string is broadcasted
   * @memberof SOGo.UIDesktop
   * @see {@link SOGo.UIDesktop.sgFocus}
   * @example:

     <input type="text"
            sg-focus-on="username" />
   */
    .directive('sgFocusOn', function() {
      return function(scope, elem, attr) {
        scope.$on('sgFocusOn', function(e, name) {
          if (name === attr.sgFocusOn) {
            elem[0].focus();
            elem[0].select();
          }
        });
      };
    })

  /**
   * sgFocus - A service to set the focus on the element associated to a specific string
   * @memberof SOGo.UIDesktop
   * @param {string} name - the string identifier of the element
   * @see {@link SOGo.UIDesktop.sgFocusOn}
   */
    .factory('sgFocus', ['$rootScope', '$timeout', function($rootScope, $timeout) {
      return function(name) {
        $timeout(function() {
          $rootScope.$broadcast('sgFocusOn', name);
        });
      }
    }])

  /*
   * sgFolderTree - Provides hierarchical folders tree
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @param {object} sgRoot
   * @param {object} sgFolder
   * @param {function} sgSetFolder
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
        template:
          '<md-list-item>' +
          '  <md-item-content layout="row" layout-align="start center" flex>' +
          '    <i class="md-icon-folder"></i>' +
          '    <button class="md-button md-flex sg-item-name">{{folder.name}}</button>' +
          '    <md-input-container class="md-flex md-tile-content ng-hide">'+
          '      <input type="text"' +
          '             ng-model="folder.name"' +
          '             ng-blur="save()"' +
          '             sg-enter="save()"' +
          '             sg-escape="revert()"/>' +
          '    </md-input-container>' +
          '    <span class="icon ng-hide" ng-cloak="ng-cloak">' +
          '      <a class="icon" href="#"' +
          '         dropdown-toggle="#folderProperties"' +
          '         options="align:right"><i class="md-icon-more-vert"></i></a>' +
          '    </span>' +
          '  </md-item-content>' +
          '</md-list-item>' +
          '<sg-folder-tree ng-repeat="child in folder.children track by child.path"' +
          '                data-sg-root="root"' +
          '                data-sg-folder="child"' +
          '                data-sg-select-folder="selectFolder"></sg-folder-tree>',
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
   * @memberof SOGo.UIDesktop
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
   * sgSubscribe - Common subscription widget
   * @restrict class or attribute
   * @param {String} sgSubscribe - the folder type
   * @param {Function} sgSubscribeOnSelect - the function to call when subscribing to a folder
   * @example:

    <div sg-subscribe="contact" sg-subscribe-on-select="subscribeToFolder"></div>
  */
    .directive('sgSubscribe', [function() {
      console.debug('registering sgSubscribe');
      return {
        restrict: 'A',
        scope: {
          folderType: '@sgSubscribe',
          onFolderSelect: '&sgSubscribeOnSelect'
        },
        replace: false,
        link: function(scope, element, attrs, controller) {
          element.on('click', controller.showDialog);
        },
        controllerAs: 'vm',
        bindToController: true,
        controller: ['$scope', '$mdDialog', function($scope, $mdDialog) {
          var vm = this;
          vm.showDialog = function() {
            $mdDialog.show({
              templateUrl: 'UIxContactsUserFolders',
              clickOutsideToClose: true,
	      locals: {
                folderType: vm.folderType,
                onFolderSelect: vm.onFolderSelect
              },
              controller: function($scope, folderType, onFolderSelect) {
                $scope.selectUser = function(i) {
                  // Fetch folders of specific type for selected user
                  $scope.users[i].$folders(folderType).then(function() {
                    $scope.selectedUser = $scope.users[i];
                  });
                };
                $scope.selectFolder = function(folder) {
                  onFolderSelect({folderData: folder});
                };
              }
            });
          };
        }],
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
    .directive('sgUserTypeahead', ['$parse', '$q', '$timeout', 'sgUser', function($parse, $q, $timeout, User) {
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

  /*
   * sgSearch - Search within a list of items
   * @memberof SOGo.UIDesktop
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
    .directive('sgSearch', ['$compile', function($compile) {
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
        selectEl.attr('ng-model', '$sgSearchController.searchField');
        selectEl.attr('ng-change', '$sgSearchController.onChange()');

        return function postLink(scope, iElement, iAttr, controller) {
          $compile(mdInputEl)(scope);
          $compile(selectEl)(scope);
          $compile(tElement.find('md-button'))(scope.$parent);

          scope.$watch('$sgSearchController.searchText', angular.bind(controller, controller.onChange));
        }
      }
    }])
    .controller('sgSearchController', ['$scope', '$element', function($scope, $element) {
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
    }])

  /*
   * sgFolderStylesheet - Add CSS stylesheet for folder (addressbook or calendar)
   * @memberof SOGo.UIDesktop
   * @restrict attribute
   * @param {object} ngModel - the object literal describing the folder (an Addressbook or Calendar instance)
   * @example:

    <div sg-folder-stylesheet="true"
         ng-repeat="calendar in calendars.list"
         ng-model="calendar" />
   </div>
  */
    .directive('sgFolderStylesheet', [function() {
      return {
        restrict: 'A',
        require: 'ngModel',
        scope: {
          ngModel: '='
        },
        template:
          '<style type="text/css">' +
          '  .folder{{ ngModel.id }} {' +
          '    background-color: {{ ngModel.color }} !important;' +
          '  }' +
          '</style>'
      }
    }])

  /*
   * sgCalendarDayTable - Build list of blocks for a specific day
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @param {object} sgBlocks - the events blocks definitions for the current view
   * @param {string} sgDay - the day of the events to display
   * @example:

   <sg-calendar-day-table
       sg-blocks="calendar.blocks"
       sg-day="20150330" />
  */
    .directive('sgCalendarDayTable', [function() {
      return {
        restrict: 'E',
        scope: {
          blocks: '=sgBlocks',
          day: '@sgDay'
        },
        template:
          '<sg-calendar-day-block class="event draggable"' +
          '                   ng-repeat="block in blocks[day]"' +
          '                   sg-block="block"/>',
      };
    }])

  /*
   * sgCalendarDayBlock - An event block to be displayed in a week
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @example:

   <sg-calendar-day-block
       ng-repeat="block in blocks[day]"
       sg-block="block"/>
  */
    .directive('sgCalendarDayBlock', [function() {
      return {
        restrict: 'E',
        scope: {
          block: '=sgBlock'
        },
        replace: true,
        template:
          '<div class="event draggable">' +
          '  <div class="eventInside">' +
          '      <div class="gradient">' +
          '      </div>' +
          '      <div class="text">{{ block.component.c_title }}<span class="icons"></span></div>' +
          '    </div>' +
          '    <div class="topDragGrip"></div>' +
          '    <div class="bottomDragGrip"></div>' +
          '</div>',
        link: link
      };

      function link(scope, iElement, attrs) {
        // Compute overlapping (5%)
        var pc = 100 / scope.block.siblings,
            left = scope.block.position * pc,
            right = 100 - (scope.block.position + 1) * pc;

        if (pc < 100) {
          if (left > 0)
            left -= 5;
          if (right > 0)
            right -= 5;
        }

        // Set position
        iElement.css('left', left + '%');
        iElement.css('right', right + '%');
        iElement.addClass('starts' + scope.block.start);
        iElement.addClass('lasts' + scope.block.length);
        iElement.addClass('folder' + scope.block.component.c_folder);
      }
    }])

  /*
   * sgCalendarMonthDay - Build list of blocks for a specific day in a month
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @param {object} sgBlocks - the events blocks definitions for the current view
   * @param {string} sgDay - the day of the events to display
   * @example:

   <sg-calendar-monh-day
       sg-blocks="calendar.blocks"
       sg-day="20150408" />
  */
    .directive('sgCalendarMonthDay', [function() {
      return {
        restrict: 'E',
        scope: {
          blocks: '=sgBlocks',
          day: '@sgDay'
        },
        replace: true,
        template:
          '<sg-calendar-month-event' +
          '  ng-repeat="block in blocks[day]"' +
          '  sg-block="block"/>',
      };
    }])

  /*
   * sgCalendarMonthEvent - An event block to be displayed in a month
   * @memberof SOGo.UIDesktop
   * @restrict element
   * @param {object} sgBlock - the event block definition
   * @example:

   <sg-calendar-month-event
       ng-repeat="block in blocks[day]"
       sg-block="block"/>
  */
    .directive('sgCalendarMonthEvent', [function() {
      return {
        restrict: 'E',
        scope: {
          block: '=sgBlock'
        },
        replace: true,
        template:
          '<div class="sg-event">' +
          '        <span ng-if="!block.component.c_isallday">{{ block.starthour }} - </span>' +
          '        {{ block.component.c_title }}' +
          '        <span class="icons">' +
          '          <i ng-if="block.component.c_nextalarm" class="md-icon-alarm"></i>' +
          '          <i ng-if="block.component.c_classification == 1" class="md-icon-visibility-off"></i>' +
          '          <i ng-if="block.component.c_classification == 2" class="md-icon-vpn-key"></i>' +
          '        </span>' +
          '  <div class="leftDragGrip"></div>' +
          '  <div class="rightDragGrip"></div>' +
          '  </div>' +
          '</div>',
        link: link
      };

      function link(scope, iElement, attrs) {
        iElement.addClass('folder' + scope.block.component.c_folder);
      }
    }]);

})();
