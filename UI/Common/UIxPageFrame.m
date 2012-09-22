
/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2005-2012 Inverse inc.

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSEnumerator.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */

#import <NGObjWeb/WOResourceManager.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserProfile.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoWebAuthenticator.h>

#import "UIxPageFrame.h"

@implementation UIxPageFrame

- (id) init
{
  if ((self = [super init]))
    {
      item = nil;
      title = nil;
      toolbar = nil;
      udKeys = nil;
      usKeys = nil;
      additionalJSFiles = nil;
      additionalCSSFiles = nil;
      systemAdditionalJSFiles = nil;
    }

  return self;
}

- (void) dealloc
{
  [item release];
  [title release];
  [toolbar release];
  [udKeys release];
  [usKeys release];
  [additionalJSFiles release];
  [additionalCSSFiles release];
  [systemAdditionalJSFiles release];
  [super dealloc];
}

/* accessors */

- (void) setTitle: (NSString *) _value
{
  ASSIGN (title, _value);
}

- (NSString *) title
{
  NSString *pageTitle;
  SOGoSystemDefaults *sd;

  if ([self isUIxDebugEnabled])
    pageTitle = title;
  else
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      pageTitle = [sd pageTitle];
      if (pageTitle == nil || ![pageTitle length])
	pageTitle = [self labelForKey: @"SOGo"];
    }

  return pageTitle;
}

- (void) setItem: (id) _item
{
  ASSIGN (item, _item);
}

- (id) item
{
  return item;
}

- (NSString *) ownerInContext
{
  return [[self clientObject] ownerInContext: nil];
}

- (NSString *) doctype
{
  return (@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
          @"<!DOCTYPE html"
          @" PUBLIC \"-//W3C//DTD XHTML 1.1//EN\""
          @" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">");
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

- (NSString *) relativeAdministrationPath
{
  return [self relativePathToUserFolderSubPath: @"Administration/"];
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

- (NSString *) siteFavicon
{
  NSString *siteFavicon;
  
  siteFavicon = [[SOGoSystemDefaults sharedSystemDefaults]
                  faviconRelativeURL];

  return (siteFavicon
          ? siteFavicon
          : [self urlForResourceFilename: @"sogo.ico"]);
}

/* page based JavaScript */

- (NSString *) _stringsForFramework: (NSString *) framework
{
  NSString *language, *frameworkName;
  NSMutableDictionary* strings;
  SOGoUserDefaults *ud;
  id table;

  // When no framework is specified, we load the strings from UI/Common
  frameworkName = [NSString stringWithFormat: @"%@.SOGo",
			    (framework ? framework : [self frameworkName])];
  ud = [[context activeUser] userDefaults];
  if (!ud)
    ud = [SOGoSystemDefaults sharedSystemDefaults];
  language = [ud language];

  table
    = [[self resourceManager] stringTableWithName: @"Localizable"
			      inFramework: frameworkName
			      languages: [NSArray arrayWithObject: language]];

  strings = [NSMutableDictionary dictionaryWithDictionary: table];

  if (!framework)
    {
      // Add strings from Locale
      NSDictionary *moreStrings;

      // Month names
      moreStrings = [NSDictionary dictionaryWithObjects: [locale objectForKey: NSMonthNameArray]
                                                forKeys: [UIxComponent monthLabelKeys]];
      [strings addEntriesFromDictionary: moreStrings];

      // Short month names
      moreStrings = [NSDictionary dictionaryWithObjects: [locale objectForKey: NSShortMonthNameArray]
                                                forKeys: [UIxComponent abbrMonthLabelKeys]];
      [strings addEntriesFromDictionary: moreStrings];
    }

  /* table is not really an NSDictionary but a hackish variation thereof */
  return [strings jsonRepresentation];
}

- (NSString *) commonLocalizableStrings
{
  NSString *rc;

  if (isPopup)
    rc = @"";
  else
    rc = [NSString stringWithFormat: @"var clabels = %@;",
          [self _stringsForFramework: nil]];

  return rc;
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

- (void) setCssFiles: (NSString *) newCSSFiles
{
  NSEnumerator *cssFiles;
  NSString *currentFile, *filename;

  [additionalCSSFiles release];
  additionalCSSFiles = [NSMutableArray new];

  cssFiles
    = [[newCSSFiles componentsSeparatedByString: @","] objectEnumerator];
  while ((currentFile = [cssFiles nextObject]))
    {
      filename = [self urlForResourceFilename:
			 [currentFile stringByTrimmingSpaces]];
      [additionalCSSFiles addObject: filename];
    }
}

- (NSArray *) additionalCSSFiles
{
  return additionalCSSFiles;
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

- (NSArray *) systemAdditionalJSFiles
{
  NSArray *prefsJSFiles;
  SOGoDomainDefaults *dd;
  int count, max;
  NSString *currentFile, *filename;

  if (!systemAdditionalJSFiles)
    {
      systemAdditionalJSFiles = [NSMutableArray new];
      dd = [[context activeUser] domainDefaults];
      prefsJSFiles = [dd additionalJSFiles];
      max = [prefsJSFiles count];
      for (count = 0; count < max; count++)
        {
          currentFile = [prefsJSFiles objectAtIndex: count];
          filename = [self urlForResourceFilename:
                             [currentFile stringByTrimmingSpaces]];
          [systemAdditionalJSFiles addObject: filename];
        }
    }

  return systemAdditionalJSFiles;
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

- (BOOL) _moduleIs: (NSString *) moduleName
{
  NSString *frameworkName;

  frameworkName = [[context page] frameworkName];

  return [frameworkName isEqualToString: moduleName];
}

- (BOOL) isCalendar
{
  return [self _moduleIs: @"SchedulerUI"];
}

- (BOOL) isContacts
{
  return [self _moduleIs: @"ContactsUI"];
}

- (BOOL) isMail
{
  return [self _moduleIs: @"MailerUI"];
}

- (BOOL) isAdministration
{
  return [self _moduleIs: @"AdministrationUI"];
}

- (void) setToolbar: (NSString *) newToolbar
{
  ASSIGN (toolbar, newToolbar);
}

- (NSString *) toolbar
{
  return toolbar;
}

- (BOOL) isSuperUser
{
  SOGoUser *user;

  user = [context activeUser];

  return ([user respondsToSelector: @selector (isSuperUser)]
	  && [user isSuperUser]);
}

- (BOOL) usesCASAuthentication
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return [[sd authenticationType] isEqualToString: @"cas"];
}

- (NSString *) userIdentification
{
  /* The "identification" term is used in the human sense here. */
  return [[context activeUser] cn];
}

- (BOOL) canLogoff
{
  BOOL canLogoff;
  id auth;
  SOGoSystemDefaults *sd;

  auth = [[self clientObject] authenticatorInContext: context];
  if ([auth respondsToSelector: @selector (cookieNameInContext:)])
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      if ([[sd authenticationType] isEqualToString: @"cas"])
	canLogoff = [sd CASLogoutEnabled];
      else
	canLogoff = [[auth cookieNameInContext: context] length] > 0;
    }
  else
    canLogoff = NO;

  return canLogoff;
}

- (NSString *) userLanguage
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [ud language];
}

- (BOOL) userHasVacationEnabled
{
  NSDictionary *vacationOptions;

  vacationOptions = [[[context activeUser] userDefaults] vacationOptions];

  return (vacationOptions && [[vacationOptions objectForKey: @"enabled"] boolValue]);
}

/* UserDefaults, UserSettings */
- (NSString *) _dictionaryWithKeys: (NSArray *) keys
                        fromSource: (SOGoDefaultsSource *) source
{
  NSString *key;
  int count, max;
  NSMutableDictionary *dict;
  NSNull *nsNull;
  id value;

  nsNull = [NSNull null];

  max = [keys count];

  dict = [NSMutableDictionary dictionaryWithCapacity: max];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      value = [source objectForKey: key];
      if (!value)
        value = nsNull;
      [dict setObject: value forKey: key];
    }

  return [dict jsonRepresentation];
}

- (void) setUserDefaultsKeys: (NSString *) newKeys
{
  [udKeys release];
  udKeys = [[newKeys componentsSeparatedByString: @","] trimmedComponents];
  [udKeys retain];
}

- (BOOL) hasUserDefaultsKeys
{
  return ([udKeys count] > 0);
}

- (NSString *) userDefaults
{
  SOGoUserDefaults *ud;

  ud = [[context activeUser] userDefaults];

  return [self _dictionaryWithKeys: udKeys fromSource: ud];
}

- (void) setUserSettingsKeys: (NSString *) newKeys
{
  [usKeys release];
  usKeys = [[newKeys componentsSeparatedByString: @","] trimmedComponents];
  [usKeys retain];
}

- (BOOL) hasUserSettingsKeys
{
  return ([usKeys count] > 0);
}

- (NSString *) userSettings
{
  SOGoUserSettings *us;

  us = [[context activeUser] userSettings];

  return [self _dictionaryWithKeys: usKeys fromSource: us];
}

/* browser/os identification */

- (BOOL) isCompatibleBrowser
{
  WEClientCapabilities *cc;

  cc = [[context request] clientCapabilities];

  //NSLog(@"Browser = %@", [cc description]);
  //NSLog(@"User agent = %@", [cc userAgent]);
  //NSLog(@"Browser major version = %i", [cc majorVersion]);

  return (([[cc userAgentType] isEqualToString: @"IE"]
	   && [cc majorVersion] >= 7)
	  || ([[cc userAgentType] isEqualToString: @"Mozilla"]
	      && [cc majorVersion] >= 5)
	  || ([[cc userAgentType] isEqualToString: @"Safari"]
	      && [cc majorVersion] >= 3)
	  || ([[cc userAgentType] isEqualToString: @"Konqueror"]
	      && [cc majorVersion] >= 4)
	  || [[cc userAgentType] isEqualToString: @"Opera"]
	   );
}

- (int) minimumSearchLength
{
  return [[[context activeUser] domainDefaults] searchMinimumWordLength];
}

@end /* UIxPageFrame */
