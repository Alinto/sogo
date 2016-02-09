/**
 * @license Copyright (c) 2003-2013, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license
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

  config.removeButtons = 'Strike,Subscript,Superscript,BGColor,Anchor,Format';
  config.removeDialogTabs = 'link:advanced;image:advanced';
  config.enterMode = CKEDITOR.ENTER_BR;
  config.tabSpaces = 4;
  config.allowedContent = true; // don't filter tags

  // The list of fonts size to be displayed in the Font Size combo in the toolbar.
  config.fontSize_sizes = '8/8px;9/9px;10/10px;11/11px;12/12px;13/13px;14/14px;16/16px;18/18px;20/20px;22/22px;24/24px;26/26px;28/28px;36/36px;48/48px;72/72px';

  // Explicitly show the default site font size to the end user (as defined in contents.css)
  config.fontSize_defaultLabel = '13px';

  // The CSS file(s) to be used to apply style to editor content.
  // For example, the following ck.css could overwrite the font-size of .cke_editable
  //config.contentsCss = ['/SOGo.woa/WebServerResources/js/vendor/ckeditor/contents.css', // default CSS
  //                      '/css/ck.css']; // custom CSS

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
