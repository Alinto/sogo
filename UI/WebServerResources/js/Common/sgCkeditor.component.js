/* -*- Mode: javascript; indent-tabs-mode: nil; c-basic-offset: 2 -*- */

(function() {
  'use strict';

  /**
   * sgCkeditor - A component for the CKEditor v4
   * Based on https://github.com/jziggas/ng-ck/.
   * @memberof SOGo.Common
   * @example:
     <sg-ckeditor
        config="$ctrl.config"
        on-instance-ready="$ctrl.onEditorReady($editor)"
        on-focus="$ctrl.onEditorFocus($editor)"
        ng-model="$ctrl.content"></sg-ckeditor>
  */
  function sgCkeditorConfigProvider() {
    // Default plugins that have successfully passed through Angular's $sanitize service
    var defaultConfiguration = {
      toolbarGroups: [
        { name: 'basicstyles', groups: [ 'basicstyles' ] },
        { name: 'colors' },
        { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align' ] },
        { name: 'links' },
        { name: 'insert' },
        { name: 'editing', groups: [ 'spellchecker' ] },
        { name: 'styles' },
        { name: 'mode' }
      ],

      // The default plugins included in the basic setup define some buttons that
      // are not needed in a basic editor. They are removed here.
      removeButtons: 'Strike,Subscript,Superscript,BGColor,Anchor,Format,Image',

      // Dialog windows are also simplified.
      removeDialogTabs: 'link:advanced',

      enterMode: CKEDITOR.ENTER_BR,
      tabSpaces: 4,
      // fullPage: true, include header and body
      allowedContent: true, // don't filter tags
      entities: false,

      // Configure autogrow
      // https://ckeditor.com/docs/ckeditor4/latest/guide/dev_autogrow.html
      autoGrow_onStartup: true,
      autoGrow_minHeight: 300,
      autoGrow_bottomSpace: 0,
      language: 'en',

      // The Upload Image plugin requires a remote URL to be defined even though we won't use it
      imageUploadUrl: '/SOGo/'
    };

    var events = [
      'activeEnterModeChange',
      'activeFilterChange',
      'afterCommandExec',
      'afterInsertHtml',
      'afterPaste',
      'afterPasteFromWord',
      'afterSetData',
      'afterUndoImage',
      'ariaEditorHelpLabel',
      'autogrow',
      'beforeCommandExec',
      'beforeDestroy',
      'beforeGetData',
      'beforeModeUnload',
      'beforeSetMode',
      'beforeUndoImage',
      'blur',
      'change',
      'configLoaded',
      'contentDirLoaded',
      'contentDom',
      'contentDomInvalidated',
      'contentDomUnload',
      'customConfigLoaded',
      'dataFiltered',
      'dataReady',
      'destroy',
      'dialogHide',
      'dialogShow',
      'dirChanged',
      'doubleclick',
      'dragend',
      'dragstart',
      'drop',
      'elementsPathUpdate',
      'fileUploadRequest',
      'fileUploadResponse',
      'floatingSpaceLayout',
      'focus',
      'getData',
      'getSnapshot',
      'insertElement',
      'insertHtml',
      'insertText',
      'instanceReady',
      'key',
      'langLoaded',
      'loadSnapshot',
      'loaded',
      'lockSnapshot',
      'maximize',
      'menuShow',
      'mode',
      'notificationHide',
      'notificationShow',
      'notificationUpdate',
      'paste',
      'pasteFromWord',
      'pluginsLoaded',
      'readOnly',
      'removeFormatCleanup',
      'required',
      'resize',
      'save',
      'saveSnapshot',
      'selectionChange',
      'setData',
      'stylesSet',
      'template',
      'toDataFormat',
      'toHtml',
      'unlockSnapshot',
      'updateSnapshot',
      'widgetDefinition'
    ];

    var config = angular.copy(defaultConfiguration);

    this.$get = function () {
      return {
        config: config,
        events: events
      }
    };
  }

  var sgCkeditorComponent = {
    controllerAs: 'vm',
    require: {
      ngModelCtrl: 'ngModel'
    },
    bindings: {
      checkTextLength: '<?',
      config: '<?',
      maxLength: '<?',
      minLength: '<?',
      ckMargin: '@?',
      onActiveEnterModeChange: '&?',
      onActiveFilterChange: '&?',
      onAfterCommandExec: '&?',
      onAfterInsertHtml: '&?',
      onAfterPaste: '&?',
      onAfterPasteFromWord: '&?',
      onAfterSetData: '&?',
      onAfterUndoImage: '&?',
      onAriaEditorHelpLabel: '&?',
      onAutogrow: '&?',
      onBeforeCommandExec: '&?',
      onBeforeDestroy: '&?',
      onBeforeGetData: '&?',
      onBeforeModeUnload: '&?',
      onBeforeSetMode: '&?',
      onBeforeUndoImage: '&?',
      onBlur: '&?',
      onChange: '&?',
      onConfigLoaded: '&?',
      onContentChanged: '&?', // Not CKEditor API
      onContentDirLoaded: '&?',
      onContentDom: '&?',
      onContentDomInvalidated: '&?',
      onContentDomUnload: '&?',
      onCustomConfigLoaded: '&?',
      onDataFiltered: '&?',
      onDataReady: '&?',
      onDestroy: '&?', // Not sure if this works because of the cleanup done in $onDestroy. Needs testing.
      onDialogHide: '&?',
      onDialogShow: '&?',
      onDirChanged: '&?',
      onDoubleclick: '&?',
      onDragend: '&?',
      onDragstart: '&?',
      onDrop: '&?',
      onElementsPathUpdate: '&?',
      onFileUploadRequest: '&?',
      onFileUploadResponse: '&?',
      onFloatingSpaceLayout: '&?',
      onFocus: '&?',
      onGetData: '&?',
      onGetSnapshot: '&?',
      onInsertElement: '&?',
      onInsertHtml: '&?',
      onInsertText: '&?',
      onInstanceReady: '&?',
      onKey: '&?',
      onLangLoaded: '&?',
      onLoadSnapshot: '&?',
      onLoaded: '&?',
      onLockSnapshot: '&?',
      onMaximize: '&?',
      onMenuShow: '&?',
      onMode: '&?',
      onNotificationHide: '&?',
      onNotificationShow: '&?',
      onNotificationUpdate: '&?',
      onPaste: '&?',
      onPasteFromWord: '&?',
      onPluginsLoaded: '&?',
      onReadOnly: '&?',
      onRemoveFormatCleanup: '&?',
      onRequired: '&?',
      onResize: '&?',
      onSave: '&?',
      onSaveSnapshot: '&?',
      onSelectionChange: '&?',
      onSetData: '&?',
      onStylesSet: '&?',
      onTemplate: '&?',
      onToDataFormat: '&?',
      onToHtml: '&?',
      onUnlockSnapshot: '&?',
      onUpdateSnapshot: '&?',
      onWidgetDefinition: '&?',
      placeholder: '<?',
      readOnly: '<?',
      required: '<?'
    },
    template: '<textarea ng-attr-placeholder="{{vm.placeholder}}"></textarea>',
    controller: sgCkeditorController
  };

  sgCkeditorController.$inject = ['$element', '$scope', '$parse', '$timeout', 'sgCkeditorConfig'];
  function sgCkeditorController ($element, $scope, $parse, $timeout, sgCkeditorConfig) {
    var vm = this;
    var config;
    var content;
    var editor;
    var editorElement;
    var editorChanged = false;
    var modelChanged = false;

    this.$onInit = function () {
      vm.ngModelCtrl.$render = function () {
        if (editor) {
          editor.setData(vm.ngModelCtrl.$viewValue, {
            noSnapshot: true,
            callback: function () {
              editor.fire('updateSnapshot')
            }
          })
        }
      };

      config = vm.config ? angular.merge(sgCkeditorConfig.config, vm.config) : sgCkeditorConfig.config;

      if (config.language) {
        // Pickup the first matching language supported by SCAYT
        // See http://docs.ckeditor.com/#!/guide/dev_howtos_scayt
        config.scayt_sLang = _.find(['en_US', 'en_GB', 'pt_BR', 'da_DK', 'nl_NL', 'en_CA', 'fi_FI', 'fr_FR', 'fr_CA', 'de_DE', 'el_GR', 'it_IT', 'nb_NO', 'pt_PT', 'es_ES', 'sv_SE'], function(sLang) {
          return sLang.lastIndexOf(config.language, 0) == 0;
        }) || 'en_US';

        // Disable caching of the language
        // See https://github.com/WebSpellChecker/ckeditor-plugin-scayt/issues/126
        config.scayt_disableOptionsStorage = 'lang';
      }

      if (vm.ckMargin) {
        // Set the margin of the iframe editable content
        CKEDITOR.addCss('.cke_editable { margin-top: ' + vm.ckMargin +
                        '; margin-left: ' + vm.ckMargin +
                        '; margin-right: ' + vm.ckMargin + '; }');
      }
    };

    this.$postLink = function () {
      editorElement = $element[0].children[0];
      editor = CKEDITOR.replace(editorElement, config);

      editor.on('instanceReady', onInstanceReady);
      editor.on('pasteState', onEditorChange);
      editor.on('change', onEditorChange);
      editor.on('paste', onEditorPaste);
      editor.on('fileUploadRequest', onEditorFileUploadRequest);

      if (content) {
        modelChanged = true
        editor.setData(content, {
          noSnapshot: true,
          callback: function () {
            editor.fire('updateSnapshot')
          }
        });
      }
    };

    this.$onChanges = function (changes) {
      if (
        changes.ngModel &&
          changes.ngModel.currentValue !== changes.ngModel.previousValue
      ) {
        content = changes.ngModel.currentValue;
        if (editor && !editorChanged) {
          if (content) {
            editor.setData(content, {
              noSnapshot: true,
              callback: function () {
                editor.fire('updateSnapshot')
              }
            });
            modelChanged = true;
          }
        }
        editorChanged = false;
      }
      if (editor && changes.readOnly) {
        editor.setReadOnly(changes.readOnly.currentValue);
      }
    }

    this.$onDestroy = function () {
      editor.destroy();
    }

    function onInstanceReady (event) {
      // Register binded callbacks for all available events
      _.forEach(_.filter(sgCkeditorConfig.events, function (eventName) {
        return eventName != 'instanceReady';
      }), function (eventName) {
        var callbackName = 'on' + eventName[0].toUpperCase() + eventName.slice(1);
        if (vm[callbackName]) {
          editor.on(eventName, function (event) {
            vm[callbackName]({
              '$event': event,
              '$editor': editor
            });
          });
        }
      });

      if (vm.onInstanceReady) {
        vm.onInstanceReady({
          '$event': event,
          '$editor': editor
        });
      }

      // vm.ngModelCtrl.$render();
    }

    function onEditorChange () {
      var html = editor.getData();
      var text = editor.document.getBody().getText();

      if (text === '\n') {
        text = '';
      }

      if (!modelChanged && html !== vm.ngModelCtrl.$viewValue) {
        editorChanged = true;
        vm.ngModelCtrl.$setViewValue(html);
        validate(vm.checkTextLength ? text : html);
        if (vm.onContentChanged) {
          vm.onContentChanged({
            'editor': editor,
            'html': html,
            'text': text
          });
        }
      }
      modelChanged = false;
    }

    function onEditorPaste (event) {
      var html;
      if (event.data.type == 'html') {
        html = event.data.dataValue;
        // Remove images to avoid ghost image in Firefox; images will be handled by the Image Upload plugin
        event.data.dataValue = html.replace(/<img( [^>]*)?>/gi, '');
      }
    }

    function onEditorFileUploadRequest (event) {
      // Intercept the request when an image is pasted, keep an inline base64 version only.
      var data, img;
      data = event.data.fileLoader.data;
      img = editor.document.createElement('img');
      img.setAttribute('src', data);
      editor.insertElement(img);
      event.cancel();
    }

    function validate (body) {
      if (vm.maxLength) {
        vm.ngModelCtrl.$setValidity('maxlength', body.length > vm.maxLength + 1);
      }
      if (vm.minLength) {
        vm.ngModelCtrl.$setValidity('minlength', body.length <= vm.minLength);
      }
      if (vm.required) {
        vm.ngModelCtrl.$setValidity('required', body.length > 0);
      }
    }
  }

  angular
    .module('sgCkeditor', [])
    .provider('sgCkeditorConfig', sgCkeditorConfigProvider)
    .component('sgCkeditor', sgCkeditorComponent);
})();
