/**
 * @license Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function( config ) {
    config.toolbarGroups = [
        [ 'Bold', 'Italic', 'TextColor' ],
        ['Font', 'FontSize'],
	{ name: 'paragraph',   groups: [ 'list', 'indent', 'align' ] },
	{ name: 'links' },
	{ name: 'insert' },
        ['SpellChecker','Scayt']
    ];

    config.removeButtons = 'Anchor,Underline,Strike,Subscript,Superscript';
    config.removeDialogTabs = 'link:advanced';
    config.enterMode = CKEDITOR.ENTER_BR;
};
