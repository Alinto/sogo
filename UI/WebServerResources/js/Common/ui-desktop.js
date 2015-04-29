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
    var alert = this.$modal.alert()
        .title(title)
        .content(content)
        .ok(l('OK'));
    this.$modal.show(alert);
  };

  /**
   * @name confirm
   * @desc Show a confirmation dialog box with buttons 'Cancel' and 'OK'
   * @param {string} title
   * @param {string} content
   * @returns a promise that resolves if the user has clicked on the 'OK' button
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

  /**
   * @name prompt
   * @desc Show a primpt dialog box with a input text field and the 'Cancel' and 'OK' buttons
   * @param {string} title
   * @param {string} label
   * @param {object} [options] - use a different input type by setting 'inputType'
   * @returns a promise that resolves with the input field value
   */
  Dialog.prompt = function(title, label, options) {
    var o = options || {},
        d = this.$q.defer();

    this.$modal.show({
      parent: angular.element(document.body),
      clickOutsideToClose: true,
      escapeToClose: true,
      template: [
        '<md-dialog flex="30" flex-sm="100">',
        '  <md-dialog-content layout="column">',
        '    <h2 class="md-title" ng-bind="title"></h2>',
        '    <md-input-container>',
        '      <label>' + label + '</label>',
        '      <input type="' + (o.inputType || 'text') + '"',
        '             aria-label="' + title + '"',
        '             ng-model="name" required="required"/>',
        '    </md-input-container>',
        '  </md-dialog-content>',
        '    <div class="md-actions">',
        '      <md-button ng-click="cancel()">',
        '        ' + l('Cancel'),
        '      </md-button>',
        '      <md-button class="md-primary" ng-click="ok()" ng-disabled="!name.length">',
        '        ' + l('OK'),
        '      </md-button>',
        '    </div>',
        '</md-dialog>'
      ].join(''),
      controller: PromptDialogController
    });

    function PromptDialogController(scope, $mdDialog) {
      scope.title = title;
      scope.name = "";
      scope.cancel = function() {
        d.reject();
        $mdDialog.hide();
      }
      scope.ok = function() {
        d.resolve(scope.name);
        $mdDialog.hide();
      }
    }

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
   * sgGravatarImage - A simple Gravatar directive (based on http://blog.lingohub.com/2014/08/better-ux-with-angularjs-directives/)
   * @memberof SOGo.UIDesktop
   * @example:

   <sg-gravatar-image email="test@email.com" size="50"></sg-gravatar-image>
  */
    .directive('sgGravatarImage', function () {
      return {
        restrict: 'AE',
        replace: true,
        required: 'email',
        template: '<img ng-src="https://www.gravatar.com/avatar/{{hash}}?s={{size}}&d=wavatar" />',
        link: function (scope, element, attrs) {
          attrs.$observe('email', function (value) {
            if(!value) { return; }

            // MD5 (Message-Digest Algorithm) by WebToolkit
            var md5=function(s){function L(k,d){return(k<<d)|(k>>>(32-d));}function K(G,k){var I,d,F,H,x;F=(G&2147483648);H=(k&2147483648);I=(G&1073741824);d=(k&1073741824);x=(G&1073741823)+(k&1073741823);if(I&d){return(x^2147483648^F^H);}if(I|d){if(x&1073741824){return(x^3221225472^F^H);}else{return(x^1073741824^F^H);}}else{return(x^F^H);}}function r(d,F,k){return(d&F)|((~d)&k);}function q(d,F,k){return(d&k)|(F&(~k));}function p(d,F,k){return(d^F^k);}function n(d,F,k){return(F^(d|(~k)));}function u(G,F,aa,Z,k,H,I){G=K(G,K(K(r(F,aa,Z),k),I));return K(L(G,H),F);}function f(G,F,aa,Z,k,H,I){G=K(G,K(K(q(F,aa,Z),k),I));return K(L(G,H),F);}function D(G,F,aa,Z,k,H,I){G=K(G,K(K(p(F,aa,Z),k),I));return K(L(G,H),F);}function t(G,F,aa,Z,k,H,I){G=K(G,K(K(n(F,aa,Z),k),I));return K(L(G,H),F);}function e(G){var Z;var F=G.length;var x=F+8;var k=(x-(x%64))/64;var I=(k+1)*16;var aa=Array(I-1);var d=0;var H=0;while(H<F){Z=(H-(H%4))/4;d=(H%4)*8;aa[Z]=(aa[Z]|(G.charCodeAt(H)<<d));H++;}Z=(H-(H%4))/4;d=(H%4)*8;aa[Z]=aa[Z]|(128<<d);aa[I-2]=F<<3;aa[I-1]=F>>>29;return aa;}function B(x){var k="",F="",G,d;for(d=0;d<=3;d++){G=(x>>>(d*8))&255;F="0"+G.toString(16);k=k+F.substr(F.length-2,2);}return k;}function J(k){k=k.replace(/rn/g,"n");var d="";for(var F=0;F<k.length;F++){var x=k.charCodeAt(F);if(x<128){d+=String.fromCharCode(x);}else{if((x>127)&&(x<2048)){d+=String.fromCharCode((x>>6)|192);d+=String.fromCharCode((x&63)|128);}else{d+=String.fromCharCode((x>>12)|224);d+=String.fromCharCode(((x>>6)&63)|128);d+=String.fromCharCode((x&63)|128);}}}return d;}var C=Array();var P,h,E,v,g,Y,X,W,V;var S=7,Q=12,N=17,M=22;var A=5,z=9,y=14,w=20;var o=4,m=11,l=16,j=23;var U=6,T=10,R=15,O=21;s=J(s);C=e(s);Y=1732584193;X=4023233417;W=2562383102;V=271733878;for(P=0;P<C.length;P+=16){h=Y;E=X;v=W;g=V;Y=u(Y,X,W,V,C[P+0],S,3614090360);V=u(V,Y,X,W,C[P+1],Q,3905402710);W=u(W,V,Y,X,C[P+2],N,606105819);X=u(X,W,V,Y,C[P+3],M,3250441966);Y=u(Y,X,W,V,C[P+4],S,4118548399);V=u(V,Y,X,W,C[P+5],Q,1200080426);W=u(W,V,Y,X,C[P+6],N,2821735955);X=u(X,W,V,Y,C[P+7],M,4249261313);Y=u(Y,X,W,V,C[P+8],S,1770035416);V=u(V,Y,X,W,C[P+9],Q,2336552879);W=u(W,V,Y,X,C[P+10],N,4294925233);X=u(X,W,V,Y,C[P+11],M,2304563134);Y=u(Y,X,W,V,C[P+12],S,1804603682);V=u(V,Y,X,W,C[P+13],Q,4254626195);W=u(W,V,Y,X,C[P+14],N,2792965006);X=u(X,W,V,Y,C[P+15],M,1236535329);Y=f(Y,X,W,V,C[P+1],A,4129170786);V=f(V,Y,X,W,C[P+6],z,3225465664);W=f(W,V,Y,X,C[P+11],y,643717713);X=f(X,W,V,Y,C[P+0],w,3921069994);Y=f(Y,X,W,V,C[P+5],A,3593408605);V=f(V,Y,X,W,C[P+10],z,38016083);W=f(W,V,Y,X,C[P+15],y,3634488961);X=f(X,W,V,Y,C[P+4],w,3889429448);Y=f(Y,X,W,V,C[P+9],A,568446438);V=f(V,Y,X,W,C[P+14],z,3275163606);W=f(W,V,Y,X,C[P+3],y,4107603335);X=f(X,W,V,Y,C[P+8],w,1163531501);Y=f(Y,X,W,V,C[P+13],A,2850285829);V=f(V,Y,X,W,C[P+2],z,4243563512);W=f(W,V,Y,X,C[P+7],y,1735328473);X=f(X,W,V,Y,C[P+12],w,2368359562);Y=D(Y,X,W,V,C[P+5],o,4294588738);V=D(V,Y,X,W,C[P+8],m,2272392833);W=D(W,V,Y,X,C[P+11],l,1839030562);X=D(X,W,V,Y,C[P+14],j,4259657740);Y=D(Y,X,W,V,C[P+1],o,2763975236);V=D(V,Y,X,W,C[P+4],m,1272893353);W=D(W,V,Y,X,C[P+7],l,4139469664);X=D(X,W,V,Y,C[P+10],j,3200236656);Y=D(Y,X,W,V,C[P+13],o,681279174);V=D(V,Y,X,W,C[P+0],m,3936430074);W=D(W,V,Y,X,C[P+3],l,3572445317);X=D(X,W,V,Y,C[P+6],j,76029189);Y=D(Y,X,W,V,C[P+9],o,3654602809);V=D(V,Y,X,W,C[P+12],m,3873151461);W=D(W,V,Y,X,C[P+15],l,530742520);X=D(X,W,V,Y,C[P+2],j,3299628645);Y=t(Y,X,W,V,C[P+0],U,4096336452);V=t(V,Y,X,W,C[P+7],T,1126891415);W=t(W,V,Y,X,C[P+14],R,2878612391);X=t(X,W,V,Y,C[P+5],O,4237533241);Y=t(Y,X,W,V,C[P+12],U,1700485571);V=t(V,Y,X,W,C[P+3],T,2399980690);W=t(W,V,Y,X,C[P+10],R,4293915773);X=t(X,W,V,Y,C[P+1],O,2240044497);Y=t(Y,X,W,V,C[P+8],U,1873313359);V=t(V,Y,X,W,C[P+15],T,4264355552);W=t(W,V,Y,X,C[P+6],R,2734768916);X=t(X,W,V,Y,C[P+13],O,1309151649);Y=t(Y,X,W,V,C[P+4],U,4149444226);V=t(V,Y,X,W,C[P+11],T,3174756917);W=t(W,V,Y,X,C[P+2],R,718787259);X=t(X,W,V,Y,C[P+9],O,3951481745);Y=K(Y,h);X=K(X,E);W=K(W,v);V=K(V,g);}var i=B(Y)+B(X)+B(W)+B(V);return i.toLowerCase();};

            scope.hash = md5(value.toLowerCase());
            scope.size = attrs.size;

            if(angular.isUndefined(scope.size)) {
              scope.size = 60; // default to 60 pixels
            }
          });
        }
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

    <md-button sg-subscribe="contact" sg-subscribe-on-select="subscribeToFolder">Subscribe ..</md-button>
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
        bindToController: true,
        controllerAs: 'vm',
        controller: ['$scope', '$mdDialog', function($scope, $mdDialog) {
          var vm = this;
          vm.showDialog = function() {
            $mdDialog.show({
              templateUrl: '../Contacts/UIxContactsUserFolders',
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
        link: function(scope, element, attrs, controller) {
          element.on('click', controller.showDialog);
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
        template: [
          '<style type="text/css">',
          '  .bg-folder{{ ngModel.id }} {',
          '    background-color: {{ ngModel.color }} !important;',
          '  }',
          '  .fg-folder{{ ngModel.id }} {',
          '    color: {{ ngModel.color }} !important;',
          '  }',
          '  .checkbox-folder{{ ngModel.id }}.md-checked .md-icon {',
          '    background-color: {{ ngModel.color }} !important;',
          '  }',
          '</style>'
        ].join('')
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
        template: [
          '<div class="event draggable">',
          '  <div class="eventInside">',
          '      <div class="gradient">',
          '      </div>',
          '      <div class="text">{{ block.component.c_title }}',
          '        <span class="icons">',
          '          <i ng-if="block.component.c_nextalarm" class="md-icon-alarm"></i>',
          '          <i ng-if="block.component.c_classification == 1" class="md-icon-visibility-off"></i>',
          '          <i ng-if="block.component.c_classification == 2" class="md-icon-vpn-key"></i>',
          '       </span></div>',
          '    </div>',
          '    <div class="topDragGrip"></div>',
          '    <div class="bottomDragGrip"></div>',
          '</div>'
        ].join(''),
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
        iElement.addClass('bg-folder' + scope.block.component.c_folder);
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
        iElement.addClass('bg-folder' + scope.block.component.c_folder);
      }
    }]);

})();
