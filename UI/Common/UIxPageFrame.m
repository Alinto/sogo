/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import "common.h"
#import <NGObjWeb/SoComponent.h>
#import <NGObjWeb/WOComponent.h>

#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>

#import <SOGoUI/UIxComponent.h>

#import <Main/build.h>

#import "UIxPageFrame.h"

@implementation UIxPageFrame

- (id) init
{
  if ((self = [super init]))
    {
      item = nil;
      title = nil;
      toolbar = nil;
      additionalJSFiles = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [title release];
  [toolbar release];
  [additionalJSFiles release];
  [super dealloc];
}

/* accessors */

- (void) setTitle: (NSString *) _value
{
  ASSIGN (title, _value);
}

- (NSString *) title
{
  if ([self isUIxDebugEnabled])
    return title;

  return [self labelForKey: @"SOGo"];
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSString *) buildDate
{
  return SOGoBuildDate;
}

- (NSString *) ownerInContext
{
  return [[self clientObject] ownerInContext: nil];
}

- (NSString *) doctype
{
  return (@"<?xml version=\"1.0\"?>\n"
          @"<!DOCTYPE html"
          @" PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\""
          @" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">");
}

/* Help URL/target */

- (NSString *) helpURL
{
  return [NSString stringWithFormat: @"help/%@.html", title];
}

- (NSString *) helpWindowTarget
{
  return [NSString stringWithFormat: @"Help_%@", title];
}

/* notifications */

- (void) sleep
{
  [item release];
  item = nil;
  [super sleep];
}

/* URL generation */
// TODO: I think all this should be done by the clientObject?!

- (NSString *) relativeHomePath
{
  return [self relativePathToUserFolderSubPath: @""];
}

- (NSString *) relativeCalendarPath
{
  return [self relativePathToUserFolderSubPath: @"Calendar/"];
}

- (NSString *) relativeContactsPath
{
  return [self relativePathToUserFolderSubPath: @"Contacts/"];
}

- (NSString *) relativeMailPath
{
  return [self relativePathToUserFolderSubPath: @"Mail/"];
}

- (NSString *) relativePreferencesPath
{
  return [self relativePathToUserFolderSubPath: @"preferences"];
}

- (NSString *) logoffPath
{
  return [self relativePathToUserFolderSubPath: @"logoff"];
}

/* popup handling */
- (void) setPopup: (BOOL) popup
{
  isPopup = popup;
}

- (BOOL) isPopup
{
  return isPopup;
}

- (NSString *) bodyClasses
{
  return (isPopup ? @"popup" : @"main");
}

/* page based JavaScript */

- (NSString *) _stringsForFramework: (NSString *) framework
{
  NSString *language, *frameworkName;
  id table;

  frameworkName = [NSString stringWithFormat: @"%@.SOGo",
			    (framework ? framework : [self frameworkName])];
  language = [[context activeUser] language];
  if (!language)
    language = [SOGoUser language];

  table
    = [[self resourceManager] stringTableWithName: @"Localizable"
			      inFramework: frameworkName
			      languages: [NSArray arrayWithObject: language]];

  /* table is not really an NSDictionary but a hackish variation thereof */
  return [[NSDictionary dictionaryWithDictionary: table] jsonRepresentation];
}

- (NSString *) commonLocalizableStrings
{
  return [NSString stringWithFormat: @"var clabels = %@;",
		   [self _stringsForFramework: nil]];
}

- (NSString *) productLocalizableStrings
{
  NSString *frameworkName;

  frameworkName = [[context page] frameworkName];

  return [NSString stringWithFormat: @"var labels = %@;",
		   [self _stringsForFramework: frameworkName]];
}

- (NSString *) pageJavaScriptURL
{
  WOComponent *page;
  NSString *pageJSFilename;
  
  page     = [context page];
  pageJSFilename = [NSString stringWithFormat: @"%@.js",
			     NSStringFromClass([page class])];

  return [self urlForResourceFilename: pageJSFilename];
}

- (NSString *) productJavaScriptURL
{
  WOComponent *page;
  NSString *fwJSFilename;

  page = [context page];
  fwJSFilename = [NSString stringWithFormat: @"%@.js",
			   [page frameworkName]];
  
  return [self urlForResourceFilename: fwJSFilename];
}

- (BOOL) hasPageSpecificJavaScript
{
  return ([[self pageJavaScriptURL] length] > 0);
}

- (BOOL) hasProductSpecificJavaScript
{
  return ([[self productJavaScriptURL] length] > 0);
}

- (void) setJsFiles: (NSString *) newJSFiles
{
  NSEnumerator *jsFiles;
  NSString *currentFile, *filename;

  [additionalJSFiles release];
  additionalJSFiles = [NSMutableArray new];

  jsFiles = [[newJSFiles componentsSeparatedByString: @","] objectEnumerator];
  while ((currentFile = [jsFiles nextObject]))
    {
      filename = [self urlForResourceFilename:
			 [currentFile stringByTrimmingSpaces]];
      [additionalJSFiles addObject: filename];
    }
}

- (NSArray *) additionalJSFiles
{
  return additionalJSFiles;
}

- (NSString *) pageCSSURL
{
  WOComponent *page;
  NSString *pageJSFilename;

  page = [context page];
  pageJSFilename = [NSString stringWithFormat: @"%@.css",
			     NSStringFromClass([page class])];

  return [self urlForResourceFilename: pageJSFilename];
}

- (NSString *) productCSSURL
{
  WOComponent *page;
  NSString *fwJSFilename;

  page = [context page];
  fwJSFilename = [NSString stringWithFormat: @"%@.css",
			   [page frameworkName]];
  
  return [self urlForResourceFilename: fwJSFilename];
}

- (NSString *) thisPageURL
{
  return [[context page] uri];
}

- (BOOL) hasPageSpecificCSS
{
  return ([[self pageCSSURL] length] > 0);
}

- (BOOL) hasProductSpecificCSS
{
  return ([[self productCSSURL] length] > 0);
}

- (void) setToolbar: (NSString *) newToolbar
{
  ASSIGN (toolbar, newToolbar);
}

- (NSString *) toolbar
{
  return toolbar;
}

/* browser/os identification */

- (BOOL) isCompatibleBrowser
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];

  //NSLog(@"Browser = %@", [cc description]);
  NSLog(@"User agent = %@", [cc userAgent]);
  //NSLog(@"Browser major version = %i", [cc majorVersion]);

  return (([[cc userAgentType] isEqualToString: @"IE"]
	   && [cc majorVersion] >= 7)
	  || ([[cc userAgentType] isEqualToString: @"Mozilla"]
	      && [cc majorVersion] >= 5)
	  || ([[cc userAgentType] isEqualToString: @"Safari"]
	      && [cc majorVersion] >= 4)
	  //	  ([[cc userAgentType] isEqualToString: @"Konqueror"])
	   );
}

- (BOOL) isIE7Compatible
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];
  
  return ([cc isWindowsBrowser] &&
	  ([[cc userAgent] rangeOfString: @"NT 5.1"].location != NSNotFound ||
	   [[cc userAgent] rangeOfString: @"NT 6"].location != NSNotFound));
}

- (BOOL) isMac
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];

  return [cc isMacBrowser];
}

@end /* UIxPageFrame */
