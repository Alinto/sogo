/**
 * @license Copyright (c) 2003-2012, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.html or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function( config ) {
    config.toolbarGroups = [
	{ name: 'basicstyles', groups: [ 'basicstyles' ] },
	{ name: 'paragraph',   groups: [ 'list', 'align' ] },
	{ name: 'links' },
	{ name: 'insert' },
        ['Font', 'FontSize'],
        { name: 'colors' },
        ['SpellChecker','Scayt']
    ];

    config.removeButtons = 'Anchor,Underline,Strike,Subscript,Superscript';
    config.removeDialogTabs = 'link:advanced';
    config.enterMode = CKEDITOR.ENTER_BR;
};
