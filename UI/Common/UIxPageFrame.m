
/*
  Copyright (C) 2004-2005 SKYRIX Software AG
  Copyright (C) 2005-2022 Inverse inc.

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

#import <Foundation/NSNull.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */

#import <NGObjWeb/WOResourceManager.h>

#import <SOGo/NSArray+Utilities.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserSettings.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoWebAuthenticator.h>

#import "UIxPageFrame.h"

@implementation UIxPageFrame

- (id) init
{

  if ((self = [super init]))
    {
      NSString *filename;
      SOGoUserDefaults *ud;

      item = nil;
      title = nil;
      toolbar = nil;
      udKeys = nil;
      usKeys = nil;
      additionalJSFiles = nil;
      additionalCSSFiles = [NSMutableArray new];
      systemAdditionalJSFiles = nil;

      ud = [[context activeUser] userDefaults];
      if ([[ud animationMode] isEqualToString: @"none"])
        {
          filename = [self urlForResourceFilename: @"css/no-animation.css"];
          [additionalCSSFiles addObject: filename];
        }
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

  sd = [SOGoSystemDefaults sharedSystemDefaults];
  pageTitle = [sd pageTitle];
  if (pageTitle == nil || ![pageTitle length])
    pageTitle = (@"SOGo");

  if ([title length])
    pageTitle = [NSString stringWithFormat: @"%@ | %@", title, pageTitle];

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
  return (@"<!DOCTYPE html>");
}

/* Help URL */
- (NSString *) helpURL
{
  SOGoSystemDefaults *sd;
  NSString *s;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  if ((s = [sd helpURL]))
    return s;

  return @"";
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
  return [self relativePathToUserFolderSubPath: @"Preferences/"];
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
          : [self urlForResourceFilename: @"img/sogo.ico"]);
}

/* page based JavaScript */

- (NSDictionary *) _stringsForFramework: (NSString *) framework
{
  NSDictionary *moreStrings;
  NSString *language, *frameworkName;
  NSMutableDictionary* strings;
  id table;

  // When no framework is specified, we load the strings from UI/Common
  frameworkName = [NSString stringWithFormat: @"%@.SOGo",
			    (framework ? framework : [self frameworkName])];
  language = [[context resourceLookupLanguages] objectAtIndex: 0];

  table
    = [[self resourceManager] stringTableWithName: @"Localizable"
			      inFramework: frameworkName
			      languages: [NSArray arrayWithObject: language]];

  strings = [NSMutableDictionary dictionaryWithDictionary: table];

  if (framework)
    {
      moreStrings = [NSDictionary dictionaryWithObjectsAndKeys: [NSArray arrayWithObject: framework], @"_loadedFrameworks", nil];
    }
  else
    {
      // Add strings from Locale

      // AM/PM
      moreStrings = [NSDictionary dictionaryWithObjects: [locale objectForKey: NSAMPMDesignation]
                                                forKeys: [UIxComponent amPmLabelKeys]];
      [strings addEntriesFromDictionary: moreStrings];

      // Month names
      moreStrings = [NSDictionary dictionaryWithObjects: [locale objectForKey: NSMonthNameArray]
                                                forKeys: [UIxComponent monthLabelKeys]];
      [strings addEntriesFromDictionary: moreStrings];

      // Short month names
      moreStrings = [NSDictionary dictionaryWithObjects: [locale objectForKey: NSShortMonthNameArray]
                                                forKeys: [UIxComponent abbrMonthLabelKeys]];
    }
  [strings addEntriesFromDictionary: moreStrings];

  /* table is not really an NSDictionary but a hackish variation thereof */
  return strings;
}

- (NSString *) commonLocalizableStrings
{
  return [NSString stringWithFormat: @"var clabels = %@;",
                   [[self _stringsForFramework: nil] jsonRepresentation]];
}

- (NSString *) productLocalizableStrings
{
  NSString *frameworkName;

  frameworkName = [[context page] frameworkName];

  return [NSString stringWithFormat: @"var labels = %@;",
                   [[self _stringsForFramework: frameworkName] jsonRepresentation]];
}

- (WOResponse *) labelsAction
{
  WOResponse *response;
  NSDictionary *params, *data;
  NSString *frameworkName;

  params = [[[context request] contentAsString] objectFromJSONString];
  frameworkName = [params objectForKey: @"framework"];
  if (frameworkName)
    {
      data = [NSDictionary dictionaryWithObject: [self _stringsForFramework: frameworkName]
                                         forKey: @"labels"];
      response = [self responseWithStatus: 200 andJSONRepresentation: data];
    }
  else
    {
      data = [NSDictionary dictionaryWithObject: @"Missing framework name"
                                         forKey: @"message"];
      response = [self responseWithStatus: 400 andJSONRepresentation: data];
    }

  return response;
}

- (NSString *) angularModule
{
  NSString *frameworkName;

  frameworkName = [[context page] frameworkName];

  return [NSString stringWithFormat: @"SOGo.%@", frameworkName];
}

- (NSString *) pageJavaScriptURL
{
  WOComponent *page;
  NSString *theme, *filename, *url;
  
  url = nil;
  page = [context page];
  theme = [context objectForKey: @"theme"];
  if ([theme length])
    {
      filename = [NSString stringWithFormat: @"js/%@/%@.js", theme, NSStringFromClass([page class])];
      url = [self urlForResourceFilename: filename];
    }
  if ([url length] == 0)
    {
      // No theme defined or no specific JavaScript for the theme; rollback to default JavaScript
      filename = [NSString stringWithFormat: @"js/%@.js", NSStringFromClass([page class])];
      url = [self urlForResourceFilename: filename];
    }
  //NSLog(@"pageJavaScript => %@", filename);

  return url;
}

- (NSString *) productJavaScriptURL
{
  WOComponent *page;
  NSString *theme, *filename, *url;

  url = nil;
  page = [context page];
  [context resourceLookupLanguages];
  theme = [context objectForKey: @"theme"];
  if ([theme length])
    {
      filename = [NSString stringWithFormat: @"js/%@/%@.js", theme, [page frameworkName]];
      url = [self urlForResourceFilename: filename];
    }
  if ([url length] == 0)
    {
      filename = [NSString stringWithFormat: @"js/%@.js", [page frameworkName]];
      url = [self urlForResourceFilename: filename];
    }
  //NSLog(@"productJavaScript => %@", filename);
  
  return url;
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

  cssFiles = [[newCSSFiles componentsSeparatedByString: @","] objectEnumerator];
  while ((currentFile = [cssFiles nextObject]))
    {
      filename = [self urlForResourceFilename: [NSString stringWithFormat: @"css/%@", [currentFile stringByTrimmingSpaces]]];
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
      filename = [self urlForResourceFilename: [NSString stringWithFormat: @"js/%@", [currentFile stringByTrimmingSpaces]]];
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
          filename = [self urlForResourceFilename: [currentFile stringByTrimmingSpaces]];
          [systemAdditionalJSFiles addObject: filename];
        }
    }

  return systemAdditionalJSFiles;
}

- (NSString *) pageCSSURL
{
  WOComponent *page;
  NSString *filename;

  page = [context page];
  filename = [NSString stringWithFormat: @"css/%@.css",
                       NSStringFromClass([page class])];

  return [self urlForResourceFilename: filename];
}

- (NSString *) productCSSURL
{
  WOComponent *page;
  NSString *filename;

  page = [context page];
  filename = [NSString stringWithFormat: @"css/%@.css",
                       [page frameworkName]];
  
  return [self urlForResourceFilename: filename];
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

- (BOOL) usesOpenIdAuthentication
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return [[sd authenticationType] isEqualToString: @"openid"];
}

- (BOOL) usesSAML2Authenticationx
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return [[sd authenticationType] isEqualToString: @"saml2"];
}

- (NSString *) userIdentification
{
  NSString *v;

  /* The "identification" term is used in the human sense here. */
  if ([[context activeUser] primaryIdentity] 
          && [[[context activeUser] primaryIdentity] objectForKey:@"fullName"]
          && [[[[[context activeUser] primaryIdentity] objectForKey:@"fullName"] stringByReplacingOccurrencesOfString:@" " withString:@""] length] > 0) {
    v = [[[context activeUser] primaryIdentity] objectForKey:@"fullName"];
  } else {
    v = [[context activeUser] cn];
  }

  return (v ? v : @"");
}

- (NSString *) userEmail
{
  NSDictionary *identity;

  identity = [[context activeUser] defaultIdentity];

  return [identity objectForKey: @"email"];
}


- (BOOL) canLogoff
{
  BOOL canLogoff;
  id auth;
  SOGoSystemDefaults *sd;
  NSString *authType;

  auth = [[self clientObject] authenticatorInContext: context];
  if ([auth respondsToSelector: @selector (cookieNameInContext:)])
    {
      sd = [SOGoSystemDefaults sharedSystemDefaults];
      authType = [sd authenticationType];
      if ([authType isEqualToString: @"cas"])
	      canLogoff = [sd CASLogoutEnabled];
      else if ([authType isEqualToString: @"saml2"])
	      canLogoff = [sd SAML2LogoutEnabled];
      else if ([authType isEqualToString: @"openid"])
	      canLogoff = [sd openIdLogoutEnabled];
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

- (BOOL) disableInk
{
  SOGoUserDefaults *ud;
  WEClientCapabilities *cc;

  ud = [[context activeUser] userDefaults];
  cc = [[context request] clientCapabilities];

  return [[cc userAgentType] isEqualToString: @"IE"] ||
    [[ud animationMode] isEqualToString: @"limited"] ||
    [[ud animationMode] isEqualToString: @"none"];
}

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

@end /* UIxPageFrame */

@interface UIxSidenavToolbarTemplate : UIxComponent
@end

@implementation UIxSidenavToolbarTemplate
@end
