/* -*- Mode: js; indent-tabs-mode: nil; js-indent-level: 2 -*- */

(function() {
  /* jshint validthis: true */
  'use strict';

  /**
   * $sgHotkeys - A service to associate keyboard shortcuts to actions.
   * @memberof SOGo.Common
   *
   * @description
   * This service is a modified version of angular-hotkeys-light by Eugene Brodsky:
   * https://github.com/fupslot/angular-hotkeys-light
   */
  function $sgHotkeys() {

    // Key-code values for various meta-keys.
    // Source : http://www.cambiaresearch.com/articles/15/javascript-char-codes-key-codes
    //          http://unixpapa.com/js/key.html
    // Date: Oct 02, 2015.
    var KEY_CODES = {
      8: 'backspace',
      9: 'tab',
      13: 'enter',
      16: 'shift',
      17: 'ctrl',
      18: 'alt',
      19: 'pause',
      20: 'caps',
      27: 'escape',
      32: 'space',
      33: 'pageup',
      34: 'pagedown',
      35: 'end',
      36: 'home',
      37: 'left',
      38: 'up',
      39: 'right',
      40: 'down',
      45: 'insert',
      46: 'delete',
      // Numpad
      96: '0',
      97: '1',
      98: '2',
      99: '3',
      100: '4',
      101: '5',
      102: '6',
      103: '7',
      104: '8',
      105: '9',
      106: '*',
      107: '+',
      109: '-',
      110: '.',
      111: '/',
      // Function keys
      112: 'f1',
      113: 'f2',
      114: 'f3',
      115: 'f4',
      116: 'f5',
      117: 'f6',
      118: 'f7',
      119: 'f8',
      120: 'f9',
      121: 'f10',
      122: 'f11',
      123: 'f12'
    };
    // Char-code values for characters that require a key combinations
    var CHAR_CODES = {
      42: '*',
      63: '?'
    };

    this.$get = getService;

    getService.$inject = ['$rootScope', '$window'];
    function getService($rootScope, $window) {

      var wrapWithApply = function (fn) {
        return function(event, args) {
          $rootScope.$apply(function() {
            fn.call(this, event, args);
          }.bind(this));
        };
      };

      var HotKey = function(params) {
        this.id = params.id || guid();
        this.key = params.key;
        this.description = params.description || null;
        this.context = params.context || null;
        this.callback = params.callback;
        this.preventInClass = params.preventInClass;
        this.args = params.args;
        this.onKeyUp = false;

        if (this.key.length > 1)
          // Automatically translate common hotkeys
          this.lkey = l('key_' + this.key);
      };

      HotKey.prototype.clone = function() {
        return new HotKey(this);
      };

      var Hotkeys = function() {
        /**
         * Sometimes a UI wants keybindings which are global, so called hotkeys.
         * Keys are keystrings (identify key combinations) and values are objects
         * with keys callback, context.
         */
        this._hotkeys = {};

        /**
         * Sometimes a UI wants keybindings for keyup behaviour.
         */
        this._hotkeysUp = {};

        /**
         * Keybindings are ignored by default when coming from a form input field.
         */
        this._preventIn = ['INPUT', 'SELECT', 'TEXTAREA', 'MD-OPTION'];

        /**
         * Keybindings are ignored by default when coming from special elements
         */
        this._preventInClass = ['md-chip-content', 'ck-content', 'ck-widget', 'ck-editor__editable', 'ck-editor__nested-editable', 'ck-table-bogus-paragraph'];

        this._onKeydown = this._onKeydown.bind(this);
        this._onKeyup = this._onKeyup.bind(this);
        this._onKeypress = this._onKeypress.bind(this);

        this.initialize();
      };

      /**
       * Binds Keydown, Keyup with the window object
       */
      Hotkeys.prototype.initialize = function() {
        this.registerHotkey(
          this.createHotkey({
            key: '?',
            description: l('Show or hide this help'),
            callback: this._toggleCheatSheet.bind(this)
          })
        );

        $window.addEventListener('keydown', this._onKeydown, true);
        $window.addEventListener('keyup', this._onKeyup, true);
        $window.addEventListener('keypress', this._onKeypress, true);
      };

      /**
       * Invokes callback functions assosiated with the given hotkey
       * @param  {Event} event
       * @param  {String} keyString hotkey
       * @param  {Array.<HotKey>} hotkeys List of registered callbacks for
       *                                  the given hotkey
       * @private
       */
      Hotkeys.prototype._invokeHotkeyHandlers = function(event, keyString, hotkeys) {
        for (var i = 0, l = hotkeys.length; i < l; i++) {
          var hotkey = hotkeys[i],
              target = event.target || event.srcElement,
              nodeName = target.nodeName.toUpperCase();
          if (!_.includes(this._preventIn, nodeName) &&
              _.intersection(target.classList, this._preventInClass).length === 0 &&
              _.intersection(target.classList, hotkey.preventInClass).length === 0) {
            try {
              hotkey.callback.call(hotkey.context, event, hotkey.args);
            } catch(e) {
              console.error('HotKeys: ', hotkey.key, e.message);
            }
          }
        }
      };

      /**
       * Keydown Event Handler
       * @private
       */
      Hotkeys.prototype._onKeydown = function(event) {
        var keyString = this.keyStringFromEvent(event);
        if (this._hotkeys[keyString]) {
          this._invokeHotkeyHandlers(event, keyString, this._hotkeys[keyString]);
        }
      };

      /**
       * Keyup Event Handler
       * @private
       */
      Hotkeys.prototype._onKeyup = function(event) {
        var keyString = this.keyStringFromEvent(event);
        if (this._hotkeysUp[keyString]) {
          this._invokeHotkeyHandlers(this._hotkeysUp[keyString], keyString);
        }
      };

      /**
       * Keypress Event Handler
       * @private
       */
      Hotkeys.prototype._onKeypress = function(event) {
        var charCode, keyString;

        charCode = event.keyCode || event.which;
        keyString = CHAR_CODES[charCode];
        if (keyString && this._hotkeys[keyString]) {
          this._invokeHotkeyHandlers(event, keyString, this._hotkeys[keyString]);
        }
      };

      /**
      * Cross-browser method which can extract a key string from an event.
      * Key strings are of the form
      *
      *   ctrl+alt+shift+meta+character
      *
      * where each of the 4 modifiers may or may not appear, but always appear
      * in that order if they do appear.
      *
      * TODO : this is not yet implemented fully. The trouble is, the keyCode,
      * charCode, and which properties of the DOM standard KeyboardEvent are
      * discouraged in favour of the use of key and char, but key and char are
      * not yet implemented in Gecko nor in Blink/Webkit. We need to leverage
      * keyCode/charCode so that current browser versions are supported, but also
      * look to key and char because they're apparently more useful and are the
      * future.
      */
      Hotkeys.prototype.keyStringFromEvent = function(event) {
        var result = [];
        var key = event.which;

        if (KEY_CODES[key]) {
          key = KEY_CODES[key];
        } else {
          key = String.fromCharCode(key).toLowerCase();
        }

        if (event.ctrlKey)  { result.push('ctrl');  }
        if (event.altKey)   { result.push('alt');   }
        if (event.shiftKey) { result.push('shift'); }
        if (event.metaKey)  { result.push('meta');  }
        result.push(key);
        return _.uniq(result).join('+');
      };

      /**
      * Unregister a hotkey (shortcut) helper for (keyUp/keyDown).
      *
      * @param {String}   params.key      - valid key string.
      */
      Hotkeys.prototype._deregisterHotkey = function(hotkey) {
        var ret;
        var table = this._hotkeys;

        if (hotkey.onKeyUp) {
          table = this._hotkeysUp;
        }

        if (table[hotkey.key]) {
          var callbackArray = table[hotkey.key];
          for (var i = 0; i < callbackArray.length; ++i) {
            var callbackData = callbackArray[i];
            if ((hotkey.callback === callbackData.callback &&
                 callbackData.context === hotkey.context) ||
                (hotkey.id === callbackData.id)) {
              ret = callbackArray.splice(i, 1);
            }
          }
          if (callbackArray.length === 0)
            delete this._hotkeys[hotkey.key];
        }
        return ret;
      };

      /**
       * Unregister hotkeys
       * @param  {Hotkey}  hotkey A hotkey object
       * @return {Array}
       */
      Hotkeys.prototype.deregisterHotkey = function(hotkey) {
        var result = [];

        this._validateHotkey(hotkey);

        if (angular.isArray(hotkey.key)) {
          for (var i = hotkey.key.length - 1; i >= 0; i--) {
            var clone = hotkey.clone();
            clone.key = hotkey.key[i];
            var ret = this._deregisterHotkey(clone);
            if (ret !== void 0) {
              result.push(ret[0]);
            }
          }
        } else {
          result.push(this._deregisterHotkey(hotkey));
        }
        return result;
      };

      /**
       * Validate HotKey type
       */
      Hotkeys.prototype._validateHotkey = function(hotkey) {
        if (!(hotkey instanceof HotKey)) {
          throw new TypeError('Hotkeys: Expected a hotkey object be instance of HotKey');
        }
      };

      /**
      * Register a hotkey (shortcut) helper for (keyUp/keyDown).
      * @param {Object} params Parameters object
      * @param {String}   params.key      - valid key string.
      * @param {Function} params.callback - routine to run when key is pressed.
      * @param {Object}   params.context  - @this value in the callback.
      * @param [Boolean]  params.onKeyUp  - if this is intended for a keyup.
      * @param [String]   params.id       - the identifier for this registration.
      */
      Hotkeys.prototype._registerKey = function(hotkey) {
        var table = this._hotkeys;

        if (hotkey.onKeyUp) {
          table = this._hotkeysUp;
        }

        table[hotkey.key] = table[hotkey.key] || [];
        table[hotkey.key].push(hotkey);
        return hotkey;
      };

      Hotkeys.prototype._registerKeys = function(hotkey) {
        var result = [];

        if (angular.isArray(hotkey.key)) {
          for (var i = hotkey.key.length - 1; i >= 0; i--) {
            var clone = hotkey.clone();
            clone.id = guid();
            clone.key = hotkey.key[i];
            result.push(this._registerKey(clone));
          }
        } else {
          result.push(this._registerKey(hotkey));
        }
        return result;
      };

      /**
      * Register a hotkey (shortcut). see _registerHotKey
      */
      Hotkeys.prototype.registerHotkey = function(hotkey) {
        this._validateHotkey(hotkey);
        return this._registerKeys(hotkey);
      };

      /**
      * Register a hotkey (shortcut) keyup behavior.
      * see _registerHotKey
      */
      Hotkeys.prototype.registerHotkeyUp = function(hotkey) {
        this._validateHotkey(hotkey);
        hotkey.onKeyUp = true;
        this._registerKeys(hotkey);
      };

      /**
       * Creates new hotkey object.
       * @param  {Object} args
       * @return {HotKey}
       */
      Hotkeys.prototype.createHotkey = function(args) {
        if (args.key === null || args.key === void 0) {
          throw new TypeError('HotKeys: Argument "key" is required');
        }

        if (args.callback === null || args.callback === void 0) {
          throw new TypeError('HotKeys: Argument "callback" is required');
        }

        args.callback = wrapWithApply(args.callback);
        return new HotKey(args);
      };

      /**
       * Checks if given shortcut match the event
       * @param  {Event} event An event
       * @param  {String|Array} key A shortcut
       * @return {Boolean}
       */
      Hotkeys.prototype.match = function(event, key) {
        if (!angular.isArray(key)) {
          key = [key];
        }

        var eventHotkey = this.keyStringFromEvent(event);
        return Boolean(~key.indexOf(eventHotkey));
      };

      /**
       *  Build and display (or hide) the hotkeys cheat sheet
       *
       * If a hotkey is registered multiple times, only the description of the first registered
       * hotkey is displayed.
       */
      Hotkeys.prototype._toggleCheatSheet = function() {
        var _this = this;

        if (this._cheatSheet) {
          Hotkeys.$modal.hide();
          this._cheatSheet = null;
        }
        else {
          this._cheatSheet = Hotkeys.$modal
            .show({
              clickOutsideToClose: true,
              escapeToClose: true,
              template: [
                '<md-dialog>',
                '  <md-toolbar class="md-hue-2">',
                '    <div class="md-toolbar-tools">',
                '      <div ng-bind="::\'Keyboard Shortcuts\' | loc"></div>',
                '    </div>',
                '  </md-toolbar>',
                '  <md-dialog-content>',
                '    <md-list>',
                '      <md-list-item ng-repeat="(hotkey, keys) in hotkeys">',
                '        {{keys[0].description}}',
                '        <div class="md-secondary sg-hotkey-container">',
                '          <sg-hotkey>{{keys[0].lkey || hotkey}}</sg-hotkey>',
                '        </div>',
                '      </md-list-item>',
                '    </md-list>',
                '  </md-dialog-content>',
                '</md-dialog>'
              ].join(''),
              controller: CheatSheetController,
              locals: {
                hotkeys: _this._hotkeys
              }
            })
            .finally(function() {
              _this._cheatSheet = null;
            });
        }

        CheatSheetController.$inject = ['$scope', 'hotkeys'];
        function CheatSheetController($scope, hotkeys) {
          $scope.hotkeys = hotkeys;
          $scope.closeDialog = function() {
            Hotkeys.$modal.hide();
          };
        }
      };

      return Hotkeys;
    }
  }

  sgHotkeys.$inject = ['$mdDialog', '$sgHotkeys'];
  function sgHotkeys($mdDialog, $sgHotkeys) {
    angular.extend($sgHotkeys, { $modal: $mdDialog });

    return new $sgHotkeys();
  }

  angular
    .module('SOGo.Common')
    .service('sgHotkeys', sgHotkeys)
    .provider('$sgHotkeys', $sgHotkeys);
})();
