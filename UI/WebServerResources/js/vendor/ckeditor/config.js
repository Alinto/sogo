/**
 * @license Copyright (c) 2003-2019, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see https://ckeditor.com/legal/ckeditor-oss-license
 */

CKEDITOR.editorConfig = function( config ) {
  // Define changes to default configuration here.
  // For the complete reference see:
  // https://ckeditor.com/docs/ckeditor4/latest/api/CKEDITOR_config.html

  // The toolbar groups arrangement, optimized for a single toolbar row.
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

  // The default plugins included in the basic setup define some buttons that
  // are not needed in a basic editor. They are removed here.
  config.removeButtons = 'Strike,Subscript,Superscript,BGColor,Anchor,Format,Image';

  // Dialog windows are also simplified.
  config.removeDialogTabs = 'link:advanced';

  config.enterMode = CKEDITOR.ENTER_BR;
  config.tabSpaces = 4;
  // config.fullPage = true; include header and body
  config.allowedContent = true; // don't filter tags
  config.entities = false;

  // Configure autogrow
  // https://ckeditor.com/docs/ckeditor4/latest/guide/dev_autogrow.html
  config.autoGrow_onStartup = true;
  config.autoGrow_minHeight = 300;
  config.autoGrow_bottomSpace = 0;

  // Disables the built-in words spell checker if browser provides one. Defaults to true.
  // https://ckeditor.com/docs/ckeditor4/latest/api/CKEDITOR_config.html#cfg-disableNativeSpellChecker
  //config.disableNativeSpellChecker = false;

  // Whether to show the browser native context menu when the Ctrl or Meta (Mac) key is pressed on opening the context
  // menu with the right mouse button click or the Menu key. Defaults to true.
  // https://ckeditor.com/docs/ckeditor4/latest/api/CKEDITOR_config.html#cfg-browserContextMenuOnCtrl
  //config.browserContextMenuOnCtrl = false;

  // If enabled, turns on SCAYT automatically after loading the editor. Defaults to false.
  // https://ckeditor.com/docs/ckeditor4/latest/api/CKEDITOR_config.html#cfg-scayt_autoStartup
  //config.scayt_autoStartup = true;
};
