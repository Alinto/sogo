/*
  Copyright (C) 2004 SKYRIX Software AG

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

#import "SOGoJSStringFormatter.h"
#import "common.h"

#import <NGObjWeb/SoHTTPAuthenticator.h>
#import <NGObjWeb/WOResourceManager.h>

#import <SOGo/NSString+Utilities.h>

#import <SOGo/SOGoUser.h>
#import <SOGo/SOGoObject.h>
#import <SOGo/SOGoCustomGroupFolder.h>
#import <SOGo/NSCalendarDate+SOGo.h>

#import "../Common/UIxJSClose.h"

#import "UIxComponent.h"

@interface UIxComponent (PrivateAPI)
- (void)_parseQueryString:(NSString *)_s;
- (NSMutableDictionary *)_queryParameters;
@end

@implementation UIxComponent

static NSMutableArray *dayLabelKeys       = nil;
static NSMutableArray *abbrDayLabelKeys   = nil;
static NSMutableArray *monthLabelKeys     = nil;
static NSMutableArray *abbrMonthLabelKeys = nil;

static BOOL uixDebugEnabled = NO;

+ (int)version {
  return [super version] + 0 /* v2 */;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  uixDebugEnabled = [ud boolForKey:@"SOGoUIxDebugEnabled"];

  if (dayLabelKeys == nil) {
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
    [abbrMonthLabelKeys addObject:@"a3_January"];
    [abbrMonthLabelKeys addObject:@"a3_February"];
    [abbrMonthLabelKeys addObject:@"a3_March"];
    [abbrMonthLabelKeys addObject:@"a3_April"];
    [abbrMonthLabelKeys addObject:@"a3_May"];
    [abbrMonthLabelKeys addObject:@"a3_June"];
    [abbrMonthLabelKeys addObject:@"a3_July"];
    [abbrMonthLabelKeys addObject:@"a3_August"];
    [abbrMonthLabelKeys addObject:@"a3_September"];
    [abbrMonthLabelKeys addObject:@"a3_October"];
    [abbrMonthLabelKeys addObject:@"a3_November"];
    [abbrMonthLabelKeys addObject:@"a3_December"];
  }
}

- (id) init
{
  if ((self = [super init]))
    {
      _selectedDate = nil;
    }

  return self;
}

- (void) dealloc
{
  [self->queryParameters release];
  if (_selectedDate)
    [_selectedDate release];
  [super dealloc];
}

/* query parameters */

- (void) _parseQueryString: (NSString *) _s
{
  NSEnumerator *e;
  NSString *part;
  NSRange  r;
  NSString *key, *value;

  e = [[_s componentsSeparatedByString:@"&"] objectEnumerator];
  part = [e nextObject];
  while (part)
    {
      r = [part rangeOfString:@"="];
      if (r.length == 0)
        {
      /* missing value of query parameter */
          key   = [part stringByUnescapingURL];
          value = @"1";
        }
      else
        {
          key   = [[part substringToIndex:r.location] stringByUnescapingURL];
          value = [[part substringFromIndex:(r.location + r.length)] 
                    stringByUnescapingURL];
        }
      [self->queryParameters setObject:value forKey:key];
      part = [e nextObject];
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
  
  if (self->queryParameters)
    return self->queryParameters;

  self->queryParameters = [[NSMutableDictionary alloc] initWithCapacity:8];

  req = [[self context] request];
  uri = [req uri];
  r   = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    {
      qs = [uri substringFromIndex:NSMaxRange(r)];
      [self _parseQueryString:qs];
    }
  
  /* add form values */
  [self addKeepAliveFormValuesToQueryParameters];

  return self->queryParameters;
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
  if (_newDate)
    [_qp setObject: [self dateStringForDate: _newDate] forKey: @"day"];
  else
    [_qp removeObjectForKey:@"day"];
}

- (NSString *) completeHrefForMethod: (NSString *) _method
{
  WOContext *ctx;
  NSDictionary *qp;
  NSString *qs, *qps, *href;

  qp = [self queryParameters];
  if ([qp count] > 0)
    {
      ctx = [self context];
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
    
  uri = [[[self context] request] uri];
    
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

  ctx = [self context];
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
  SOGoObject *currentClient, *parent;
  BOOL found;
  Class objectClass, groupFolderClass, userFolderClass;
  WOContext *ctx;

  groupFolderClass = [SOGoCustomGroupFolder class];
  userFolderClass = [SOGoUserFolder class];

  currentClient = [self clientObject];
  objectClass = [currentClient class];
  found = (objectClass == groupFolderClass || objectClass == userFolderClass);
  while (!found && currentClient)
    {
      parent = [currentClient container];
      objectClass = [parent class];
      if (objectClass == groupFolderClass
          || objectClass == userFolderClass)
        found = YES;
      else
        currentClient = parent;
    }

  ctx = [self context];

  return [[currentClient baseURLInContext:ctx] hostlessURL];
}

- (NSString *) resourcesPath
{
  WOResourceManager *rm;

  if ((rm = [self resourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];

  return [rm webServerResourcesPath];
}

- (NSString *) ownPath
{
  NSString *uri;
  NSRange  r;
  
  uri = [[[self context] request] uri];
  
  /* first: cut off query parameters */
  
  r = [uri rangeOfString:@"?" options:NSBackwardsSearch];
  if (r.length > 0)
    uri = [uri substringToIndex:r.location];

  return uri;
}

- (NSString *) relativePathToUserFolderSubPath: (NSString *) _sub
{
  NSString *dst, *rel;

  dst = [[self userFolderPath] stringByAppendingPathComponent:_sub];
  rel = [dst urlPathRelativeToPath:[self ownPath]];

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
            inTimeZone: [[self clientObject] userTimeZone]];
      [_selectedDate retain];
    }

  return _selectedDate;
}

- (NSString *) dateStringForDate: (NSCalendarDate *) _date
{
  [_date setTimeZone: [[self clientObject] userTimeZone]];

  return [_date descriptionWithCalendarFormat:@"%Y%m%d"];
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
  [jsClose setRefreshMethod: methodName];

  return jsClose;
}

/* SoUser */

- (SoUser *) user
{
  WOContext *ctx;
  
  ctx = [self context];

  return [[[self clientObject] authenticatorInContext: ctx] userInContext: ctx];
}

- (NSString *) shortUserNameForDisplay
{
  // TODO: better use a SoUser formatter?
  // TODO: who calls that?
  NSString *s;
  NSRange  r;
  
  // TODO: USE USER MANAGER INSTEAD!
  
  s = [[self user] login];
  if ([s length] < 10)
    return s;
    
  // TODO: algorithm might be inappropriate, depends on the actual UID
    
  r = [s rangeOfString:@"."];
  if (r.length == 0)
    return s;
    
  return [s substringToIndex:r.location];
}

/* labels */

- (NSString *) labelForKey: (NSString *) _str
{
  WOResourceManager *rm;
  NSArray *languages;
  NSString *lKey, *lTable, *lVal;
  NSRange r;

  if ([_str length] == 0)
    return nil;
  
  /* lookup languages */
    
  languages = [[self context] resourceLookupLanguages];
    
  /* find resource manager */
    
  if ((rm = [self pageResourceManager]) == nil)
    rm = [[WOApplication application] resourceManager];
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
  
#if 0
  if ([lVal hasPrefix:@"$"])
    lVal = [self valueForKeyPath:[lVal substringFromIndex:1]];
  
#endif
  
  /* lookup string */
  return [rm stringForKey: lKey
             inTableNamed: lTable
             withDefaultValue: lVal
             languages: languages];
}

- (NSString *) localizedNameForDayOfWeek:(unsigned)_dayOfWeek {
  NSString *key =  [dayLabelKeys objectAtIndex:_dayOfWeek % 7];
  return [self labelForKey:key];
}

- (NSString *)localizedAbbreviatedNameForDayOfWeek:(unsigned)_dayOfWeek {
  NSString *key =  [abbrDayLabelKeys objectAtIndex:_dayOfWeek % 7];
  return [self labelForKey:key];
}

- (NSString *)localizedNameForMonthOfYear:(unsigned)_monthOfYear {
  NSString *key =  [monthLabelKeys objectAtIndex:(_monthOfYear - 1) % 12];
  return [self labelForKey:key];
}

- (NSString *)localizedAbbreviatedNameForMonthOfYear:(unsigned)_monthOfYear {
  NSString *key =  [abbrMonthLabelKeys objectAtIndex:(_monthOfYear - 1) % 12];
  return [self labelForKey:key];
}

/* HTTP method safety */

- (BOOL)isInvokedBySafeMethod {
  // TODO: move to WORequest?
  NSString *m;
  
  m = [[[self context] request] method];
  if ([m isEqualToString:@"GET"])  return YES;
  if ([m isEqualToString:@"HEAD"]) return YES;
  return NO;
}

/* locale */

- (NSDictionary *)locale {
  /* we need no fallback here, as locale is guaranteed to be set by sogod */
  return [[self context] valueForKey:@"locale"];
}

- (WOResourceManager *) pageResourceManager
{
  WOResourceManager *rm;
  
  if ((rm = [[[self context] page] resourceManager]) == nil)
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
          page = [[self context] page];
          pageBundle = [NSBundle bundleForClass: [page class]];
          url = [rm urlForResourceNamed: filename
                    inFramework: [pageBundle bundlePath]
                    languages: nil
                    request: [[self context] request]];
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

/* debugging */

- (BOOL)isUIxDebugEnabled {
  return uixDebugEnabled;
}

@end /* UIxComponent */
