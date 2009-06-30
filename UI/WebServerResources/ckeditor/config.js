/*
Copyright (c) 2003-2009, CKSource - Frederico Knabben. All rights reserved.
For licensing, see LICENSE.html or http://ckeditor.com/license
*/

CKEDITOR.editorConfig = function( config )
{
	// Define changes to default configuration here. For example:
	// config.language = 'fr';
	config.skin = 'kama';
  //TODO: This should work to remove the bottom DOM information, but doesn't
  // This way is on an instance of the config object
  config.removePlugins = "elementspath,kplahj";
};

// This way is global / static
CKEDITOR.config.removePlugins = "elementspath,kplahj";
