/**
 * @license Copyright (c) 2003-2013, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function( config ) {
    config.toolbar = [
        { name: 'basicstyles', items: [ 'Bold', 'Italic', 'Underline', 'TextColor' ] },
        { name: 'paragraph', items: [ 'NumberedList', 'BulletedList',
                                      '-',
                                      'Blockquote', 'Outdent', 'Indent',
                                      '-',
                                      'JustifyLeft', 'JustifyCenter', 'JustifyRight' ] },
        { name: 'links', items: [ 'Link', 'Unlink' ] },
        { name: 'insert', items: [ 'Image', 'Table' ] },
        { name: 'editing', items: [ 'Font', 'FontSize', 'Scayt' ] }
    ];
    config.toolbarGroups = [
        { name: 'basicstyles' },
	{ name: 'paragraph' },
	{ name: 'links' },
	{ name: 'insert' },
        { name: 'editing' }
    ];

    config.removeDialogTabs = 'link:advanced;image:advanced';
    config.enterMode = CKEDITOR.ENTER_BR;

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
