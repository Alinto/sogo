/*
  Copyright (C) 2007-2019 Inverse inc.

  This file is part of SOGo

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

#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSUserDefaults.h> /* for locale strings */
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoObjects.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGExtensions/NSURL+misc.h>

#import <SOGo/NSCalendarDate+SOGo.h>
#import <SOGo/NSDictionary+Utilities.h>
#import <SOGo/NSObject+Utilities.h>
#import <SOGo/NSString+Crypto.h>
#import <SOGo/NSString+Utilities.h>
#import <SOGo/SOGoBuild.h>
#import <SOGo/SOGoSession.h>
#import <SOGo/SOGoSystemDefaults.h>
#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoUserFolder.h>
#import <SOGo/SOGoWebAuthenticator.h>
#import <SOGo/WOContext+SOGo.h>
#import <SOGo/WOResourceManager+SOGo.h>

#import "UIxJSClose.h"


@interface UIxComponent (PrivateAPI)
- (void)_parseQueryString:(NSString *)_s;
- (NSMutableDictionary *)_queryParameters;
@end

@implementation UIxComponent

static NSMutableArray *amPmLabelKeys      = nil;
static NSMutableArray *dayLabelKeys       = nil;
static NSMutableArray *abbrDayLabelKeys   = nil;
static NSMutableArray *monthLabelKeys     = nil;
static NSMutableArray *abbrMonthLabelKeys = nil;
static SoProduct      *commonProduct      = nil;

+ (void)initialize {
  if (dayLabelKeys == nil) {
    amPmLabelKeys = [[NSMutableArray alloc] initWithCapacity:2];
    [amPmLabelKeys addObject:@"AM"];
    [amPmLabelKeys addObject:@"PM"];

    dayLabelKeys = [[NSMutableArray alloc] initWithCapacity:7];
    [dayLabelKeys addObject:@"Sunday"];
    [dayLabelKeys addObject:@"Monday"];
    [dayLabelKeys addObject:@"Tuesday"];
    [dayLabelKeys addObject:@"Wednesday"];
    [dayLabelKeys addObject:@"Thursday"];
    [dayLabelKeys addObject:@"Friday"];
    [dayLabelKeys addObject:@"Saturday"];

    abbrDayLabelKeys = [[NSMutableArray alloc] initWithCapacity:7];
    [abbrDayLabelKeys addObject:@"a2_Sunday"];
    [abbrDayLabelKeys addObject:@"a2_Monday"];
    [abbrDayLabelKeys addObject:@"a2_Tuesday"];
    [abbrDayLabelKeys addObject:@"a2_Wednesday"];
    [abbrDayLabelKeys addObject:@"a2_Thursday"];
    [abbrDayLabelKeys addObject:@"a2_Friday"];
    [abbrDayLabelKeys addObject:@"a2_Saturday"];

    monthLabelKeys = [[NSMutableArray alloc] initWithCapacity:12];
    [monthLabelKeys addObject:@"January"];
    [monthLabelKeys addObject:@"February"];
    [monthLabelKeys addObject:@"March"];
    [monthLabelKeys addObject:@"April"];
    [monthLabelKeys addObject:@"May"];
    [monthLabelKeys addObject:@"June"];
    [monthLabelKeys addObject:@"July"];
    [monthLabelKeys addObject:@"August"];
    [monthLabelKeys addObject:@"September"];
    [monthLabelKeys addObject:@"October"];
    [monthLabelKeys addObject:@"November"];
    [monthLabelKeys addObject:@"December"];

    abbrMonthLabelKeys = [[NSMutableArray alloc] initWithCapacity:12];
    [abbrMonthLabelKeys addObject:@"Jan"];
    [abbrMonthLabelKeys addObject:@"Feb"];
    [abbrMonthLabelKeys addObject:@"Mar"];
    [abbrMonthLabelKeys addObject:@"Apr"];
    [abbrMonthLabelKeys addObject:@"May"];
    [abbrMonthLabelKeys addObject:@"Jun"];
    [abbrMonthLabelKeys addObject:@"Jul"];
    [abbrMonthLabelKeys addObject:@"Aug"];
    [abbrMonthLabelKeys addObject:@"Sep"];
    [abbrMonthLabelKeys addObject:@"Oct"];
    [abbrMonthLabelKeys addObject:@"Nov"];
    [abbrMonthLabelKeys addObject:@"Dec"];

    // @see commonLabelForKey:
    commonProduct = [[SoProduct alloc] initWithBundle:
                             [NSBundle bundleForClass: NSClassFromString(@"CommonUIProduct")]];
  }
}

+ (NSArray *) amPmLabelKeys
{
  return (NSArray *) amPmLabelKeys;
}

+ (NSArray *) abbrDayLabelKeys
{
  return (NSArray *) abbrDayLabelKeys;
}

+ (NSArray *) monthLabelKeys
{
  return (NSArray *) monthLabelKeys;
}

+ (NSArray *) abbrMonthLabelKeys
{
  return (NSArray *) abbrMonthLabelKeys;
}

- (id) init
{
  if ((self = [super init]))
    {
      _selectedDate = nil;
      queryParameters = nil;
      ASSIGN (userDefaults, [[context activeUser] userDefaults]);
      if (!userDefaults)
        ASSIGN (userDefaults, [SOGoSystemDefaults sharedSystemDefaults]);
      ASSIGN (languages, [context resourceLookupLanguages]);
      ASSIGN (locale,
              [[self resourceManager] localeForLanguageNamed: [languages objectAtIndex: 0]]);
    }

  return self;
}

- (void) dealloc
{
  [queryParameters release];
  [_selectedDate release];
  [locale release];
  [userDefaults release];
  [super dealloc];
}

/* query parameters */

- (void) _parseQueryString: (NSString *) _s
{
  NSEnumerator *e;
  NSMutableString *urlEncodedValue;
  NSString *part;
  NSRange  r;
  NSString *key, *value;

  e = [[_s componentsSeparatedByString:@"&"] objectEnumerator];
  while ((part = [e nextObject]))
    {
      r = [part rangeOfString:@"="];
      if (r.length == 0)
        {
      /* missing value of query parameter */
          key = [part stringByUnescapingURL];
          value = @"1";
        }
      else
        {
          key = [[part substringToIndex:r.location] stringByUnescapingURL];
          urlEncodedValue = [NSMutableString stringWithString: [part substringFromIndex:(r.location + r.length)]];
          [urlEncodedValue replaceString: @"+" withString: @" "];
          value = [urlEncodedValue stringByUnescapingURL];
        }
      if (key && value)
        [queryParameters setObject:value forKey:key];
    }
}

- (void) addKeepAliveFormValuesToQueryParameters
{
}

- (NSString *) queryParameterForKey: (NSString *) _key
{
  return [[self _queryParameters] objectForKey:_key];
}

- (void) setQueryParameter: (NSString *) _param
                    forKey: (NSString *) _key
{
  if (_key)
    {
      if (_param)
        [[self _queryParameters] setObject: _param forKey: _key];
      else
        [[self _queryParameters] removeObjectForKey: _key];
    }
}

- (NSMutableDictionary *) _queryParameters
{
  // TODO: this code is weird, should use WORequest methods for parsing
  WORequest *req;
  NSString  *uri;
  NSRange   r;
  NSString *qs;
  
  if (queryParameters)
    return queryParameters;

  queryParameters = [[NSMutableDictionary alloc] initWithCapacity:8];

  req = [context request];
  uri = [req uri];
  r   = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    {
      qs = [uri substringFromIndex:NSMaxRange(r)];
      [self _parseQueryString:qs];
    }
  
  /* add form values */
  [self addKeepAliveFormValuesToQueryParameters];

  return queryParameters;
}

- (NSDictionary *) queryParameters
{
  return [self _queryParameters];
}

- (NSDictionary *) queryParametersBySettingSelectedDate: (NSCalendarDate *) _date
{
  NSMutableDictionary *qp;
    
  qp = [[self queryParameters] mutableCopy];
  [self setSelectedDateQueryParameter:_date inDictionary:qp];
  return [qp autorelease];
}

- (void) setSelectedDateQueryParameter: (NSCalendarDate *) _newDate
                          inDictionary: (NSMutableDictionary *) _qp
{
  NSString *day;

  if (_newDate)
    {
      day = [self dateStringForDate: _newDate];
      [_qp setObject: day forKey: @"day"];
      [_qp setObject: [day substringToIndex: 6] forKey: @"month"];
    }
  else
    {
      [_qp removeObjectForKey:@"day"];
      [_qp removeObjectForKey:@"month"];
    }
}

- (NSString *) completeHrefForMethod: (NSString *) _method
{
  WOContext *ctx;
  NSDictionary *qp;
  NSString *qs, *qps, *href;

  qp = [self queryParameters];
  if ([qp count] > 0)
    {
      ctx = context;
      qps = [ctx queryPathSeparator];
      [ctx setQueryPathSeparator: @"&"];
      qs = [ctx queryStringFromDictionary: qp];
      [ctx setQueryPathSeparator: qps];
      href = [_method stringByAppendingFormat:@"?%@", qs];
    }
  else
    href = _method;

  return href;
}

- (NSString *) ownMethodName
{
  NSString *uri;
  NSRange  r;
    
  uri = [[context request] uri];
    
  /* first: cut off query parameters */
    
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];
    
  /* next: strip trailing slash */

  if ([uri hasSuffix: @"/"])
    uri = [uri substringToIndex: ([uri length] - 1)];
  r = [uri rangeOfString:@"/" options: NSBackwardsSearch];
    
  /* then: cut of last path component */
    
  if (r.length == 0) // no slash? are we at root?
    return @"/";
    
  return [uri substringFromIndex: (r.location + 1)];
}

- (NSString *) userFolderPath
{
  WOContext *ctx;
  NSEnumerator *objects;
  SOGoObject *currentObject;
  BOOL found;

  ctx = context;
  objects = [[ctx objectTraversalStack] objectEnumerator];
  currentObject = [objects nextObject];
  found = NO;
  while (currentObject
         && !found)
    if ([currentObject isKindOfClass: [SOGoUserFolder class]])
      found = YES;
    else
      currentObject = [objects nextObject];

  return [[currentObject baseURLInContext:ctx] hostlessURL];
}

- (NSString *) applicationPath
{
  NSString *appName;

  appName = [[context request] applicationName];

  return [NSString stringWithFormat: @"/%@", appName];
}

- (NSString *) modulePath
{
  if ([[self parent] respondsToSelector: @selector(modulePath)])
    {
      NSString *baseURL;

      baseURL = [[self clientObject] baseURLInContext: context];

      if (!baseURL)
        baseURL = @"/SOGo/so/";

      if ([baseURL hasSuffix: [NSString stringWithFormat: @"%@/", [[self parent] modulePath]]])
        return baseURL;

      return [NSString stringWithFormat: @"%@%@", baseURL, [[self parent] modulePath]];
    }

  return @"SOGo";
}

- (NSString *) ownPath
{
  NSString *uri;
  NSRange  r;
  
  uri = [[context request] uri];
  
  /* first: cut off query parameters */
  
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];

  return uri;
}

- (NSString *) relativePathToUserFolderSubPath: (NSString *) _sub
{
  NSString *dst, *rel, *theme;

  dst = [[self userFolderPath] stringByAppendingPathComponent: _sub];
  rel = [dst urlPathRelativeToPath:[self ownPath]];

  theme = [[context request] formValueForKey: @"theme"];
  if ([theme length])
    rel = [NSString stringWithFormat: @"%@?theme=%@", rel, theme];

  return rel;
}

- (NSCalendarDate *) selectedDate
{
  if (!_selectedDate)
    {
      _selectedDate
        = [NSCalendarDate
            dateFromShortDateString: [self queryParameterForKey: @"day"]
            andShortTimeString: [self queryParameterForKey: @"hm"]
            inTimeZone: [userDefaults timeZone]];
      [_selectedDate retain];
    }

  return _selectedDate;
}

- (NSString *) currentDayDescription
{
  NSDictionary *currentDay;
  SOGoUser *user;

  user = [context activeUser];
  if (user)
    currentDay = [user currentDay];
  else
    currentDay = [NSDictionary dictionary];

  return [currentDay jsonRepresentation];
}

- (NSString *) dateStringForDate: (NSCalendarDate *) _date
{
  [_date setTimeZone: [userDefaults timeZone]];

  return [_date descriptionWithCalendarFormat: @"%Y%m%d"];
}

- (BOOL) hideFrame
{
  return ([[self queryParameterForKey: @"noframe"] boolValue]);
}

- (UIxComponent *) jsCloseWithRefreshMethod: (NSString *) methodName
{
  UIxJSClose *jsClose;

  jsClose = [UIxJSClose new];
  [jsClose autorelease];
  [jsClose setRefreshMethod: [methodName doubleQuotedString]];

  return jsClose;
}

/* common conditions */
- (BOOL) canCreateOrModify
{
  SoSecurityManager *sm;

  sm = [SoSecurityManager sharedSecurityManager];

  return (![sm validatePermission: SoPerm_ChangeImagesAndFiles
	       onObject: [self clientObject]
	       inContext: context]);
}

- (BOOL) singleWindowModeEnabled
{
  //WEClientCapabilities *cc;
  NSString *value;
  BOOL result;
  
  //cc = [[context request] clientCapabilities];
  
  //NSLog(@"User agent = %@, Type = %@, OS = %@, CPU = %@, Browser major version = %i", [cc userAgent], [cc userAgentType], [cc os], [cc cpu], [cc majorVersion]);

  value = [[context request] cookieValueForKey: @"SOGoWindowMode"];
  result = ([value isEqualToString: @"single"]);

  //NSLog(@"Single window mode %@", result?@"enabled":@"disabled");

  return result;
}

- (BOOL) userHasCalendarAccess
{
  SOGoUser *user;

  user = [context activeUser];

  return [user canAccessModule: @"Calendar"];
}

- (BOOL) userHasMailAccess
{
  SOGoUser *user;

  user = [context activeUser];

  return [user canAccessModule: @"Mail"];
}

/* SoUser */

- (NSString *) shortUserNameForDisplay
{
  return [[context activeUser] login];
}

/* Common defaults and settings */

- (int) minimumSearchLength
{
  return [[[context activeUser] domainDefaults] searchMinimumWordLength];
}

- (NSString *) minimumSearchLengthLabel
{
  NSDictionary *defaults;

  defaults = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: [self minimumSearchLength]]
                                         forKey: @"minimumSearchLength"];
  return [defaults keysWithFormat: [self commonLabelForKey: @"Enter at least %{minimumSearchLength} characters"]];
}

/* labels */

- (NSString *) framework
{
  return [[context page] frameworkName];
}

- (NSString *) labelForKey: (NSString *) _str
{
  WOResourceManager *rm;
  /* find resource manager */

  rm = [self pageResourceManager];

  return [self labelForKey: _str withResourceManager: rm];
}

- (NSString *) commonLabelForKey: (NSString *) _str
{
  WOResourceManager *rm;

  rm = [commonProduct resourceManager];

  return [self labelForKey: _str withResourceManager: rm];
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
             languages: languages];
}

- (NSString *) localizedNameForDayOfWeek: (unsigned) dayOfWeek
{
  return [[locale objectForKey: NSWeekDayNameArray] objectAtIndex: dayOfWeek % 7];
}

- (NSString *) localizedAbbreviatedNameForDayOfWeek: (unsigned) dayOfWeek
{
  // Defined in Common bundle
  return [self commonLabelForKey: [abbrDayLabelKeys objectAtIndex: dayOfWeek % 7]];
}

- (NSString *) localizedNameForMonthOfYear: (unsigned) monthOfYear
{
  // Defined in Locale
  return [[locale objectForKey: NSMonthNameArray] objectAtIndex: (monthOfYear - 1) % 12];
}

- (NSString *) localizedAbbreviatedNameForMonthOfYear: (unsigned) monthOfYear
{
  // Defined in Locale
  return [[locale objectForKey: NSShortMonthNameArray] objectAtIndex: (monthOfYear - 1) % 12];
}

/* HTTP method safety */

- (BOOL)isInvokedBySafeMethod {
  // TODO: move to WORequest?
  NSString *m;
  
  m = [[context request] method];
  if ([m isEqualToString:@"GET"])  return YES;
  if ([m isEqualToString:@"HEAD"]) return YES;
  return NO;
}

/* locale */

- (NSDictionary *)locale {
  /* we need no fallback here, as locale is guaranteed to be set by sogod */
  return [context valueForKey: @"locale"];
}

- (NSString *) localeCode
{
  // WARNING : NSLocaleCode is not defined in <Foundation/NSUserDefaults.h>
  // Region subtag must be separated by a dash
  NSMutableString *s = [NSMutableString stringWithString: [locale objectForKey: @"NSLocaleCode"]];

  [s replaceOccurrencesOfString: @"_"
                     withString: @"-"
                        options: 0
                          range: NSMakeRange(0, [s length])];

  return s;
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
  return [self responseWithStatus: 204];
}

- (WOResponse *) redirectToLocation: (NSString *) newLocation
{
  WOResponse *response;
  NSURL *url;
  NSMutableString *location;
  NSString *theme, *query;

  location = [NSMutableString stringWithString: newLocation];
  theme = [[context request] formValueForKey: @"theme"];
  if ([theme length])
    {
      url = [NSURL URLWithString: newLocation];
      query = [url query];
      if ([query length])
        {
          if ([query rangeOfString: @"theme="].length == 0)
            [location appendFormat: @"&theme=%@", theme];
        }
      else
        [location appendFormat: @"?theme=%@", theme];
    }

  response = [self responseWithStatus: 302];
  [response setHeader: location forKey: @"location"];

  return response;
}

/* debugging */

- (NSString *) buildDate
{
  return SOGoBuildDate;
}

- (BOOL) isUIxDebugEnabled
{
  SOGoSystemDefaults *sd;

  sd = [SOGoSystemDefaults sharedSystemDefaults];

  return [sd uixDebugEnabled];
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

  // If the action is 'connect' (or 'logoff'), we let it go as the token
  // needs to be created (or destroyed) during the session initialization
  if ([_actionName isEqualToString: @"connect"] ||
      [_actionName isEqualToString: @"logoff"])
    {
      return [super performActionNamed: _actionName];
    }

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

@end /* UIxComponent */
