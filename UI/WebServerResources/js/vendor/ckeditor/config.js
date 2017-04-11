/**
 * @license Copyright (c) 2003-2016, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function( config ) {
  // For the complete reference:
  // http://docs.ckeditor.com/#!/api/CKEDITOR.config
  config.toolbarGroups = [
    { name: 'basicstyles', groups: [ 'basicstyles' ] },
    { name: 'colors' },
    { name: 'paragraph', groups: [ 'list', 'indent', 'blocks', 'align' ] },
    { name: 'links' },
    { name: 'insert' },
    { name: 'editing', groups: [ 'spellchecker' ] },
    { name: 'styles' },
    { name: 'mode' }
  ];

  config.removeButtons = 'Strike,Subscript,Superscript,BGColor,Anchor,Format,Image';
  config.removeDialogTabs = 'link:advanced';
  config.enterMode = CKEDITOR.ENTER_BR;
  config.tabSpaces = 4;
  config.allowedContent = true; // don't filter tags
  config.entities = false;

  // Configure autogrow
  // http://docs.ckeditor.com/#!/guide/dev_autogrow
  config.autoGrow_onStartup = true;
  config.autoGrow_minHeight = 300;
  config.autoGrow_bottomSpace = 0;

  // Disables the built-in words spell checker if browser provides one. Defaults to true.
  // http://docs.ckeditor.com/#!/api/CKEDITOR.config-cfg-disableNativeSpellChecker
  //config.disableNativeSpellChecker = false;

  // Whether to show the browser native context menu when the Ctrl or Meta (Mac) key is pressed on opening the context
  // menu with the right mouse button click or the Menu key. Defaults to true.
  // http://docs.ckeditor.com/#!/api/CKEDITOR.config-cfg-browserContextMenuOnCtrl
  //config.browserContextMenuOnCtrl = false;

  // If enabled, turns on SCAYT automatically after loading the editor. Defaults to false.
  // http://docs.ckeditor.com/#!/api/CKEDITOR.config-cfg-scayt_autoStartup
  //config.scayt_autoStartup = true;
};
