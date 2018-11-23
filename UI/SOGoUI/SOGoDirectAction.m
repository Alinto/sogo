/* SOGoDirectAction - this file is part of SOGo
 *
 * Copyright (C) 2007-2016 Inverse inc.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This file is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */

#import <NGObjWeb/SoObjects.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WOResponse.h>

#import <SoObjects/SOGo/NSObject+Utilities.h>
#import <SoObjects/SOGo/NSDictionary+Utilities.h>
#import <SoObjects/SOGo/NSString+Crypto.h>
#import <SoObjects/SOGo/NSString+Utilities.h>
#import <SoObjects/SOGo/SOGoSession.h>
#import <SoObjects/SOGo/SOGoSystemDefaults.h>
#import <SoObjects/SOGo/SOGoUser.h>
#import <SoObjects/SOGo/SOGoWebAuthenticator.h>
#import <SoObjects/SOGo/WOResourceManager+SOGo.h>

#import <NGExtensions/NSObject+Logs.h>

#import "SOGoDirectAction.h"

static SoProduct      *commonProduct      = nil;

@implementation SOGoDirectAction

+ (void) initialize
{
  if (commonProduct == nil)
    {
      // @see commonLabelForKey:
      commonProduct = [[SoProduct alloc] initWithBundle:
                               [NSBundle bundleForClass: NSClassFromString(@"CommonUIProduct")]];
    }
}

- (id) initWithContext: (WOContext *)_context;
{
  NSString *language;
  SOGoUserDefaults *userDefaults;
  WOResourceManager *resMgr;

  if ((self = [super initWithContext: _context]))
    {
      userDefaults = [[_context activeUser] userDefaults];
      if (!userDefaults)
        userDefaults = [SOGoSystemDefaults sharedSystemDefaults];
      language = [userDefaults language];
      resMgr = [[WOApplication application] resourceManager];
      ASSIGN (locale, [resMgr localeForLanguageNamed: language]);
    }

  return self;
}

- (void) dealloc
{
  [locale release];
  [super dealloc];
}

- (WOResponse *) responseWithStatus: (unsigned int) status
{
  WOResponse *response;

  response = [context response];
  [response setStatus: status];
  [response setHeader: @"text/plain; charset=utf-8" 
	    forKey: @"content-type"];

  return response;
}

- (WOResponse *) responseWithStatus: (unsigned int) status
			  andString: (NSString *) contentString
{
  WOResponse *response;

  response = [self responseWithStatus: status];
  [response appendContentString: contentString];

  return response;
}

- (WOResponse *) responseWithStatus: (unsigned int) status
	      andJSONRepresentation: (NSObject *) contentObject;
{
  WOResponse *response;

  response = [self responseWithStatus: status
                            andString: [contentObject jsonRepresentation]];
  [response setHeader: @"application/json" forKey: @"content-type"];

  return response;
}

- (WOResponse *) responseWith204
{
  WOResponse *response;

  response = [self responseWithStatus: 204];

  return response;
}

- (WOResponse *) redirectToLocation: (NSString *) newLocation
{
  WOResponse *response;

  response = [self responseWithStatus: 302];
  [response setHeader: newLocation forKey: @"location"];

  return response;
}

- (NSString *) labelForKey: (NSString *) _str
       withResourceManager: (WOResourceManager *) rm
{
  NSString *lKey, *lTable, *lVal;
  NSRange r;

  if ([_str length] == 0)
    return nil;

  if (rm == nil)
    [self warnWithFormat:@"missing resource manager!"];

  /* get parameters */
  r = [_str rangeOfString:@"/"];
  if (r.length > 0) {
    lTable = [_str substringToIndex:r.location];
    lKey   = [_str substringFromIndex:(r.location + r.length)];
  }
  else {
    lTable = nil;
    lKey   = _str;
  }
  lVal = lKey;

  if ([lKey hasPrefix:@"$"])
    lKey = [self valueForKeyPath:[lKey substringFromIndex:1]];
 
  if ([lTable hasPrefix:@"$"])
    lTable = [self valueForKeyPath:[lTable substringFromIndex:1]];
  
  /* lookup string */
  return [rm stringForKey: lKey
             inTableNamed: lTable
             withDefaultValue: lVal
             languages: [context resourceLookupLanguages]];
}

- (NSString *) commonLabelForKey: (NSString *) _str
{
  WOResourceManager *rm;

  rm = [commonProduct resourceManager];

  return [self labelForKey: _str withResourceManager: rm];
}

- (NSString *) labelForKey: (NSString *) _str
{
  WOResourceManager *rm;
  /* find resource manager */

  rm = [self pageResourceManager];

  return [self labelForKey: _str withResourceManager: rm];
}

- (WOResourceManager *) pageResourceManager
{
  WOResourceManager *rm;
  
  if ((rm = [[context page] resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];

  return rm;
}

- (NSString *) urlForResourceFilename: (NSString *) filename
{
  static NSMutableDictionary *pageToURL = nil;
  NSString *url;
  WOComponent *page;
  WOResourceManager *rm;
  NSBundle *pageBundle;

  if (filename)
    {
      if (!pageToURL)
        pageToURL = [[NSMutableDictionary alloc] initWithCapacity: 32];

      url = [pageToURL objectForKey: filename];
      if (!url)
        {
          rm = [self pageResourceManager];
          page = [context page];
          pageBundle = [NSBundle bundleForClass: [page class]];
          url = [rm urlForResourceNamed: filename
                    inFramework: [pageBundle bundlePath]
                    languages: nil
                    request: [context request]];
          if (!url)
            url = @"";
          else
            if ([url hasPrefix: @"http"])
              url = [url hostlessURL];
          [pageToURL setObject: url forKey: filename];
        }

//   NSLog (@"url for '%@': '%@'", filename, url);
    }
  else
    url = @"";

  return url;
}

//
// Protection against XSRF
//
- (id<WOActionResults>)performActionNamed:(NSString *)_actionName
{
  SOGoWebAuthenticator *auth;
  NSString *value, *token;
  NSArray *creds;

  auth = [[WOApplication application]
           authenticatorInContext: context];

  if (![[SOGoSystemDefaults sharedSystemDefaults] xsrfValidationEnabled] ||
      ![auth isKindOfClass: [SOGoWebAuthenticator class]])
    return [super performActionNamed: _actionName];

  // We grab the X-XSRF-TOKEN from the header or the URL
  token = [[context request] headerForKey: @"X-XSRF-TOKEN"];
  if (![token length])
    {
      token = [[context request] formValueForKey: @"X-XSRF-TOKEN"];
    }

  // We compare it with our session key
  value = [[context request]
           cookieValueForKey: [auth cookieNameInContext: context]];
  creds = [auth parseCredentials: value];

  value = [SOGoSession valueForSessionKey: [creds lastObject]];

  if ([token isEqualToString: [value asSHA1String]])
    return [super performActionNamed: _actionName];

  return nil;
}

@end
