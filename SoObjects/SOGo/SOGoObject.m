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

#import "SOGoUser.h"
#import "SOGoObject.h"
#import "SOGoUserFolder.h"
#import <NGObjWeb/WEClientCapabilities.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import "common.h"

@interface SOGoObject(Content)
- (NSString *)contentAsString;
@end

@implementation SOGoObject

static BOOL kontactGroupDAV = YES;
static NSTimeZone *serverTimeZone = nil;

+ (int)version {
  return 0;
}

+ (void) initialize
{
  NSString *tzName;

  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  kontactGroupDAV = 
    [ud boolForKey:@"SOGoDisableKontact34GroupDAVHack"] ? NO : YES;

  /* SoClass security declarations */
  
  /* require View permission to access the root (bound to authenticated ...) */
  [[self soClassSecurityInfo] declareObjectProtected:SoPerm_View];
  
  /* to allow public access to all contained objects (subkeys) */
  [[self soClassSecurityInfo] setDefaultAccess:@"allow"];
  
  /* require Authenticated role for View and WebDAV */
  [[self soClassSecurityInfo] declareRole:SoRole_Authenticated
                              asDefaultForPermission:SoPerm_View];
  [[self soClassSecurityInfo] declareRole:SoRole_Authenticated
                              asDefaultForPermission:SoPerm_WebDAVAccess];

  if (!serverTimeZone)
    {
      tzName = [ud stringForKey: @"SOGoServerTimeZone"];
      if (!tzName)
        tzName = @"Canada/Eastern";
      serverTimeZone = [NSTimeZone timeZoneWithName: tzName];
      [serverTimeZone retain];
    }
}

/* containment */

+ (id) objectWithName: (NSString *)_name inContainer:(id)_container
{
  SOGoObject *object;

  object = [[self alloc] initWithName: _name inContainer: _container];
  [object autorelease];

  return object;
}

- (BOOL)doesRetainContainer {
  return YES;
}

- (id)initWithName:(NSString *)_name inContainer:(id)_container {
  if ((self = [super init])) {
    nameInContainer = [_name copy];
    container = 
      [self doesRetainContainer] ? [_container retain] : _container;
    userTimeZone = nil;
  }
  return self;
}

- (id)init {
  return [self initWithName:nil inContainer:nil];
}

- (void)dealloc {
  if ([self doesRetainContainer])
    [container release];
  if (userTimeZone)
    [userTimeZone release];
  [nameInContainer release];
  [super dealloc];
}

/* accessors */

- (NSString *)nameInContainer {
  return nameInContainer;
}
- (id)container {
  return container;
}

/* ownership */

- (NSString *)ownerInContext:(id)_ctx {
  return [[self container] ownerInContext:_ctx];
}

/* hierarchy */

- (NSArray *)fetchSubfolders {
  NSMutableArray *ma;
  NSArray  *names;
  unsigned i, count;
  
  if ((names = [self toManyRelationshipKeys]) == nil)
    return nil;
  
  count = [names count];
  ma    = [NSMutableArray arrayWithCapacity:count + 1];
  for (i = 0; i < count; i++) {
    id folder;
    
    folder = [self lookupName:[names objectAtIndex:i] inContext:nil 
		   acquire:NO];
    if (folder == nil)
      continue;
    if ([folder isKindOfClass:[NSException class]])
      continue;
    
    [ma addObject:folder];
  }
  return ma;
}

/* looking up shared objects */

- (SOGoUserFolder *)lookupUserFolder {
  if (![container respondsToSelector:_cmd])
    return nil;
  
  return [container lookupUserFolder];
}
- (SOGoGroupsFolder *)lookupGroupsFolder {
  return [[self lookupUserFolder] lookupGroupsFolder];
}

- (void)sleep {
  if ([self doesRetainContainer])
    [container release];
  container = nil;
}

/* operations */

- (NSException *)delete {
  return [NSException exceptionWithHTTPStatus:501 /* not implemented */
		      reason:@"delete not yet implemented, sorry ..."];
}

/* KVC hacks */

- (id)valueForUndefinedKey:(NSString *)_key {
  return nil;
}

/* WebDAV */

- (NSString *)davDisplayName {
  return [self nameInContainer];
}

/* actions */

- (id)DELETEAction:(id)_ctx {
  NSException *error;

  if ((error = [self delete]) != nil)
    return error;
  
  /* Note: returning 'nil' breaks in SoObjectRequestHandler */
  return [NSNumber numberWithBool:YES]; /* delete worked out ... */
}

- (id)GETAction:(id)_ctx {
  // TODO: I guess this should really be done by SOPE (redirect to
  //       default method)
  WORequest  *rq;
  WOResponse *r;
  NSString   *uri;
  
  r  = [(WOContext *)_ctx response];
  rq = [(WOContext *)_ctx request];
  
  if ([rq isSoWebDAVRequest]) {
    if ([self respondsToSelector:@selector(contentAsString)]) {
      NSException *error;
      id etag;
      
      if ((error = [self matchesRequestConditionInContext:_ctx]) != nil)
	return error;
      
      [r appendContentString:[self contentAsString]];
      
      if ((etag = [self davEntityTag]) != nil)
	[r setHeader:etag forKey:@"etag"];

      return r;
    }
    
    return [NSException exceptionWithHTTPStatus:501 /* not implemented */
			reason:@"no WebDAV GET support?!"];
  }
  
  uri = [rq uri];
  if (![uri hasSuffix:@"/"]) uri = [uri stringByAppendingString:@"/"];
  uri = [uri stringByAppendingString:@"view"];
  
  [r setStatus:302 /* moved */];
  [r setHeader:uri forKey:@"location"];
  return r;
}

/* etag support */

- (NSArray *)parseETagList:(NSString *)_c {
  NSMutableArray *ma;
  NSArray  *etags;
  unsigned i, count;
  
  if ([_c length] == 0)
    return nil;
  if ([_c isEqualToString:@"*"])
    return nil;
  
  etags = [_c componentsSeparatedByString:@","];
  count = [etags count];
  ma    = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSString *etag;
    
    etag = [[etags objectAtIndex:i] stringByTrimmingSpaces];
#if 0 /* this is non-sense, right? */
    if ([etag hasPrefix:@"\""] && [etag hasSuffix:@"\""])
      etag = [etag substringWithRange:NSMakeRange(1, [etag length] - 2)];
#endif
    
    if (etag != nil) [ma addObject:etag];
  }
  return ma;
}

- (NSException *)checkIfMatchCondition:(NSString *)_c inContext:(id)_ctx {
  /* 
     Only run the request if one of the etags matches the resource etag,
     usually used to ensure consistent PUTs.
  */
  NSArray  *etags;
  NSString *etag;
  
  if ([_c isEqualToString:@"*"])
    /* to ensure that the resource exists! */
    return nil;
  
  if ((etags = [self parseETagList:_c]) == nil)
    return nil;
  if ([etags count] == 0) /* no etags to check for? */
    return nil;
  
  etag = [self davEntityTag];
  if ([etag length] == 0) /* has no etag, ignore */
    return nil;
  
  if ([etags containsObject:etag]) {
    [self debugWithFormat:@"etag '%@' matches: %@", etag, 
          [etags componentsJoinedByString:@","]];
    return nil; /* one etag matches, so continue with request */
  }

  /* hack for Kontact 3.4 */
  
  if (kontactGroupDAV) {
    WEClientCapabilities *cc;
    
    cc = [[(WOContext *)_ctx request] clientCapabilities];
    if ([[cc userAgentType] isEqualToString:@"Konqueror"]) {
      if ([cc majorVersion] == 3 && [cc minorVersion] == 4) {
	[self logWithFormat:
		@"WARNING: applying Kontact 3.4 GroupDAV hack"
		@" - etag check is disabled!"
		@" (can be enabled using 'ZSDisableKontact34GroupDAVHack')"];
	return nil;
      }
    }
  }
  
  // TODO: we might want to return the davEntityTag in the response
  [self debugWithFormat:@"etag '%@' does not match: %@", etag, 
	[etags componentsJoinedByString:@","]];
  return [NSException exceptionWithHTTPStatus:412 /* Precondition Failed */
		      reason:@"Precondition Failed"];
}

- (NSException *)checkIfNoneMatchCondition:(NSString *)_c inContext:(id)_ctx {
  /*
    If one of the etags is still the same, we can ignore the request.
    
    Can be used for PUT to ensure that the object does not exist in the store
    and for GET to retrieve the content only if if the etag changed.
  */
  
  if (![_c isEqualToString:@"*"] && 
      [[[_ctx request] method] isEqualToString:@"GET"]) {
    NSString *etag;
    NSArray  *etags;
    
    if ((etags = [self parseETagList:_c]) == nil)
      return nil;
    if ([etags count] == 0) /* no etags to check for? */
      return nil;
    
    etag = [self davEntityTag];
    if ([etag length] == 0) /* has no etag, ignore */
      return nil;
    
    if ([etags containsObject:etag]) {
      [self debugWithFormat:@"etag '%@' matches: %@", etag, 
	      [etags componentsJoinedByString:@","]];
      /* one etag matches, so stop the request */
      return [NSException exceptionWithHTTPStatus:304 /* Not Modified */
			  reason:@"object was not modified"];
    }
    
    return nil;
  }
  
#if 0
  if ([_c isEqualToString:@"*"])
    return nil;
  
  if ((a = [self parseETagList:_c]) == nil)
    return nil;
#else
  [self logWithFormat:@"TODO: implement if-none-match for etag: '%@'", _c];
#endif
  return nil;
}

- (NSException *)matchesRequestConditionInContext:(id)_ctx {
  NSException *error;
  WORequest *rq;
  NSString  *c;
  
  if ((rq = [(WOContext *)_ctx request]) == nil)
    return nil; /* be tolerant - no request, no condition */
  
  if ((c = [rq headerForKey:@"if-match"]) != nil) {
    if ((error = [self checkIfMatchCondition:c inContext:_ctx]) != nil)
      return error;
  }
  if ((c = [rq headerForKey:@"if-none-match"]) != nil) {
    if ((error = [self checkIfNoneMatchCondition:c inContext:_ctx]) != nil)
      return error;
  }
  
  return nil;
}

- (NSTimeZone *) serverTimeZone
{
  return serverTimeZone;
}

- (NSTimeZone *) userTimeZone
{
  NSUserDefaults *userPrefs;
  WOContext *context;

  if (!userTimeZone)
    {
      context = [[WOApplication application] context];
      userPrefs = [[context activeUser] userDefaults];
      userTimeZone = [NSTimeZone
                       timeZoneWithName: [userPrefs stringForKey: @"timezonename"]];
      if (userTimeZone)
        [userTimeZone retain];
      else
        userTimeZone = [self serverTimeZone];
    }

  return userTimeZone;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms {
  if (nameInContainer) 
    [_ms appendFormat:@" name=%@", nameInContainer];
  if (container)
    [_ms appendFormat:@" container=0x%08X/%@", 
         container, [container valueForKey:@"nameInContainer"]];
}

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];

  return ms;
}

@end /* SOGoObject */
