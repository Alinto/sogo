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

#if LIB_FOUNDATION_LIBRARY
#error SOGo will not work properly with libFoundation. \
       Please use gnustep-base instead.
#endif

#import <Foundation/NSClassDescription.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoClassSecurityInfo.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WEClientCapabilities.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <NGCards/NSDictionary+NGCards.h>
#import <UI/SOGoUI/SOGoACLAdvisory.h>

#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "SOGoAuthenticator.h"
#import "SOGoUserFolder.h"

#import "SOGoDAVRendererTypes.h"

#import "NSArray+Utilities.h"
#import "NSString+Utilities.h"

#import "SOGoObject.h"

@interface SOGoObject(Content)
- (NSString *)contentAsString;
@end

@interface SoClassSecurityInfo (SOGoAcls)

+ (id) defaultWebDAVPermissionsMap;

- (NSArray *) allPermissions;
- (NSArray *) allDAVPermissions;
- (NSArray *) DAVPermissionsForRole: (NSString *) role;
- (NSArray *) DAVPermissionsForRoles: (NSArray *) roles;

@end

@implementation SoClassSecurityInfo (SOGoAcls)

+ (id) defaultWebDAVPermissionsMap
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         @"read", SoPerm_AccessContentsInformation,
                       @"bind", SoPerm_AddDocumentsImagesAndFiles,
                       @"unbind", SoPerm_DeleteObjects,
                       @"write-acl", SoPerm_ChangePermissions,
                       @"write-content", SoPerm_ChangeImagesAndFiles,
                       @"read-free-busy", SOGoPerm_FreeBusyLookup,
                       NULL];
}

- (NSArray *) allPermissions
{
  return [defRoles allKeys];
}

- (NSArray *) allDAVPermissions
{
  NSEnumerator *allPermissions;
  NSMutableArray *davPermissions;
  NSDictionary *davPermissionsMap;
  NSString *sopePermission, *davPermission;

  davPermissions = [NSMutableArray array];

  davPermissionsMap = [[self class] defaultWebDAVPermissionsMap];
  allPermissions = [[self allPermissions] objectEnumerator];
  sopePermission = [allPermissions nextObject];
  while (sopePermission)
    {
      davPermission = [davPermissionsMap objectForCaseInsensitiveKey: sopePermission];
      if (davPermission && ![davPermissions containsObject: davPermission])
        [davPermissions addObject: davPermission];
      sopePermission = [allPermissions nextObject];
    }

  return davPermissions;
}

- (NSArray *) DAVPermissionsForRole: (NSString *) role
{
  return [self DAVPermissionsForRoles: [NSArray arrayWithObject: role]];
}

- (NSArray *) DAVPermissionsForRoles: (NSArray *) roles
{
  NSEnumerator *allPermissions;
  NSMutableArray *davPermissions;
  NSDictionary *davPermissionsMap;
  NSString *sopePermission, *davPermission;

  davPermissions = [NSMutableArray array];

  davPermissionsMap = [[self class] defaultWebDAVPermissionsMap];
  allPermissions = [[self allPermissions] objectEnumerator];
  sopePermission = [allPermissions nextObject];
  while (sopePermission)
    {
      if ([[defRoles objectForCaseInsensitiveKey: sopePermission]
            firstObjectCommonWithArray: roles])
        {
          davPermission
            = [davPermissionsMap objectForCaseInsensitiveKey: sopePermission];
          if (davPermission
              && ![davPermissions containsObject: davPermission])
            [davPermissions addObject: davPermission];
        }
      sopePermission = [allPermissions nextObject];
    }

  return davPermissions;
}

@end

@implementation SOGoObject

static BOOL kontactGroupDAV = YES;

+ (int)version {
  return 0;
}

+ (void) initialize
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  kontactGroupDAV = 
    [ud boolForKey:@"SOGoDisableKontact34GroupDAVHack"] ? NO : YES;

//   SoClass security declarations
  
//   require View permission to access the root (bound to authenticated ...)
  [[self soClassSecurityInfo] declareObjectProtected: SoPerm_View];

//   to allow public access to all contained objects (subkeys)
  [[self soClassSecurityInfo] setDefaultAccess: @"allow"];
  
//   /* require Authenticated role for View and WebDAV */
//   [[self soClassSecurityInfo] declareRole: SoRole_Owner
//                               asDefaultForPermission: SoPerm_View];
//   [[self soClassSecurityInfo] declareRole: SoRole_Owner
//                               asDefaultForPermission: SoPerm_WebDAVAccess];
}

+ (void) _fillDictionary: (NSMutableDictionary *) dictionary
          withDAVMethods: (NSString *) firstMethod, ...
{
  va_list ap;
  NSString *aclMethodName;
  NSString *methodName;
  SEL methodSel;

  va_start (ap, firstMethod);
  aclMethodName = firstMethod;
  while (aclMethodName)
    {
      methodName = [aclMethodName davMethodToObjC];
      methodSel = NSSelectorFromString (methodName);
      if (methodSel && [self instancesRespondToSelector: methodSel])
        [dictionary setObject: methodName
                    forKey: [NSString stringWithFormat: @"{DAV:}%@",
                                      aclMethodName]];
      else
        NSLog(@"************ method '%@' is still unimplemented!",
              methodName);
      aclMethodName = va_arg (ap, NSString *);
    }

  va_end (ap);
}

+ (NSDictionary *) defaultWebDAVAttributeMap
{
  static NSMutableDictionary *map = nil;

  if (!map)
    {
      map = [NSMutableDictionary
              dictionaryWithDictionary: [super defaultWebDAVAttributeMap]];
      [map retain];
      [self _fillDictionary: map
            withDAVMethods: @"owner", @"group", @"supported-privilege-set",
            @"current-user-privilege-set", @"acl", @"acl-restrictions",
            @"inherited-acl-set", @"principal-collection-set", nil];
    }

  return map;
}

/* containment */

+ (id) objectWithName: (NSString *)_name inContainer:(id)_container
{
  SOGoObject *object;

  object = [[self alloc] initWithName: _name inContainer: _container];
  [object autorelease];

  return object;
}

/* DAV ACL properties */
- (NSString *) davOwner
{
  return [NSString stringWithFormat: @"%@users/%@",
                   [self rootURLInContext: context],
		   [self ownerInContext: nil]];
}

- (NSString *) davAclRestrictions
{
  NSMutableString *restrictions;

  restrictions = [NSMutableString string];
  [restrictions appendString: @"<D:grant-only/>"];
  [restrictions appendString: @"<D:no-invert/>"];

  return restrictions;
}

- (SOGoDAVSet *) davPrincipalCollectionSet
{
  NSString *usersUrl;

  usersUrl = [NSString stringWithFormat: @"%@users",
                       [self rootURLInContext: context]];

  return [SOGoDAVSet davSetWithArray: [NSArray arrayWithObject: usersUrl]
                     ofValuesTaggedAs: @"D:href"];
}

- (SOGoDAVSet *) davCurrentUserPrivilegeSet
{
  SOGoAuthenticator *sAuth;
  SoUser *user;
  NSArray *roles;
  SoClassSecurityInfo *sInfo;
  NSArray *davPermissions;

  sAuth = [SOGoAuthenticator sharedSOGoAuthenticator];
  user = [sAuth userInContext: context];
  roles = [user rolesForObject: self inContext: context];
  sInfo = [[self class] soClassSecurityInfo];

  davPermissions
    = [[sInfo DAVPermissionsForRoles: roles] stringsWithFormat: @"<D:%@/>"];

  return [SOGoDAVSet davSetWithArray: davPermissions
                     ofValuesTaggedAs: @"D:privilege"];
}

- (SOGoDAVSet *) davSupportedPrivilegeSet
{
  SoClassSecurityInfo *sInfo;
  NSArray *allPermissions;

  sInfo = [[self class] soClassSecurityInfo];

  allPermissions = [[sInfo allDAVPermissions] stringsWithFormat: @"<D:%@/>"];

  return [SOGoDAVSet davSetWithArray: allPermissions
                     ofValuesTaggedAs: @"D:privilege"];
}

- (NSArray *) _davAcesFromAclsDictionary: (NSDictionary *) aclsDictionary
{
  NSEnumerator *keys;
  NSArray *privileges;
  NSMutableString *currentAce;
  NSMutableArray *davAces;
  NSString *currentKey, *principal;
  SOGoDAVSet *privilegesDS;

  davAces = [NSMutableArray array];
  keys = [[aclsDictionary allKeys] objectEnumerator];
  currentKey = [keys nextObject];
  while (currentKey)
    {
      currentAce = [NSMutableString string];
      if ([currentKey hasPrefix: @":"])
        [currentAce
          appendFormat: @"<D:principal><D:property><D:%@/></D:property></D:principal>",
          [currentKey substringFromIndex: 1]];
      else
	{
	  principal = [NSString stringWithFormat: @"%@users/%@",
				[self rootURLInContext: context],
				currentKey];
	  [currentAce
	    appendFormat: @"<D:principal><D:href>%@</D:href></D:principal>",
	    principal];
	}

      privileges = [[aclsDictionary objectForKey: currentKey]
                     stringsWithFormat: @"<D:%@/>"];
      privilegesDS = [SOGoDAVSet davSetWithArray: privileges
                                 ofValuesTaggedAs: @"privilege"];
      [currentAce appendString: [privilegesDS stringForTag: @"{DAV:}grant"
                                              rawName: @"grant"
                                              inContext: nil prefixes: nil]];
      [davAces addObject: currentAce];
      currentKey = [keys nextObject];
    }

  return davAces;
}

- (void) _appendRolesForPseudoPrincipals: (NSMutableDictionary *) aclsDictionary
                   withClassSecurityInfo: (SoClassSecurityInfo *) sInfo
{
  NSArray *perms;

  perms = [sInfo DAVPermissionsForRole: SoRole_Owner];
  if ([perms count])
    [aclsDictionary setObject: perms forKey: @":owner"];
  perms = [sInfo DAVPermissionsForRole: SoRole_Authenticated];
  if ([perms count])
    [aclsDictionary setObject: perms forKey: @":authenticated"];
  perms = [sInfo DAVPermissionsForRole: SoRole_Anonymous];
  if ([perms count])
    [aclsDictionary setObject: perms forKey: @":unauthenticated"];
}

- (SOGoDAVSet *) davAcl
{
  NSArray *roles;
  NSEnumerator *uids;
  NSMutableDictionary *aclsDictionary;
  NSString *currentUID;
  SoClassSecurityInfo *sInfo;

  aclsDictionary = [NSMutableDictionary dictionary];
  uids = [[self aclUsers] objectEnumerator];
  sInfo = [[self class] soClassSecurityInfo];

  currentUID = [uids nextObject];
  while (currentUID)
    {
      roles = [self aclsForUser: currentUID];
      [aclsDictionary setObject: [sInfo DAVPermissionsForRoles: roles]
                      forKey: currentUID];
      currentUID = [uids nextObject];
    }
  [self _appendRolesForPseudoPrincipals: aclsDictionary
        withClassSecurityInfo: sInfo];

  return [SOGoDAVSet davSetWithArray:
                       [self _davAcesFromAclsDictionary: aclsDictionary]
                     ofValuesTaggedAs: @"D:ace"];
}

/* end of properties */

- (BOOL) doesRetainContainer
{
  return YES;
}

- (id) init
{
  if ((self = [super init]))
    {
      context = nil;
      nameInContainer = nil;
      container = nil;
      owner = nil;
    }

  return self;
}

- (id) initWithName: (NSString *) _name
	inContainer: (id) _container
{
  if ((self = [self init]))
    {
      context = [[WOApplication application] context];
      [context retain];
      nameInContainer = [_name copy];
      container = _container;
      if ([self doesRetainContainer])
	[_container retain];
      owner = [self ownerInContext: context];
      if (owner)
	[owner retain];
    }

  return self;
}

- (void) dealloc
{
  [context release];
  [owner release];
  if ([self doesRetainContainer])
    [container release];
  [nameInContainer release];
  [super dealloc];
}

/* accessors */

- (NSString *) nameInContainer
{
  return nameInContainer;
}

- (id) container
{
  return container;
}

/* ownership */

- (void) setOwner: (NSString *) newOwner
{
  ASSIGN (owner, newOwner);
}

- (NSString *) ownerInContext: (id) localContext
{
  if (!owner)
    owner = [container ownerInContext: context];

  return owner;
}

/* hierarchy */

- (NSArray *) fetchSubfolders
{
  NSMutableArray *ma;
  NSArray  *names;
  unsigned i, count;
  
  if ((names = [self toManyRelationshipKeys]) == nil)
    return nil;
  
  count = [names count];
  ma    = [NSMutableArray arrayWithCapacity:count + 1];
  for (i = 0; i < count; i++) {
    id folder;

    folder = [self lookupName: [names objectAtIndex:i]
                   inContext: nil 
		   acquire: NO];
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

- (void) sleep
{
  if ([self doesRetainContainer])
    [container release];
  container = nil;
}

/* operations */

- (NSException *) delete
{
  return [NSException exceptionWithHTTPStatus: 501 /* not implemented */
		      reason: @"delete not yet implemented, sorry ..."];
}

/* KVC hacks */

- (id) valueForUndefinedKey: (NSString *) _key
{
  return nil;
}

/* WebDAV */

- (NSString *) davDisplayName
{
  return [self nameInContainer];
}

/* actions */

- (id) DELETEAction: (id) _ctx
{
  NSException *error;

  if ((error = [self delete]) != nil)
    return error;
  
  /* Note: returning 'nil' breaks in SoObjectRequestHandler */
  return [NSNumber numberWithBool:YES]; /* delete worked out ... */
}

- (NSString *) davContentType
{
  return @"text/plain";
}

- (WOResponse *) _webDAVResponse: (WOContext *) localContext
{
  WOResponse *response;
  NSString *contentType;
  id etag;

  response = [localContext response];
  contentType = [NSString stringWithFormat: @"%@; charset=utf8",
			  [self davContentType]];
  [response setHeader: contentType forKey: @"content-type"];
  [response appendContentString: [self contentAsString]];
  etag = [self davEntityTag];
  if (etag)
    [response setHeader: etag forKey: @"etag"];

  return response;
}

- (id) GETAction: (id) localContext
{
  // TODO: I guess this should really be done by SOPE (redirect to
  //       default method)
  WORequest *request;
  NSString *uri;
  NSException *error;
  id value;

  request = [localContext request];  
  if ([request isSoWebDAVRequest])
    {
      if ([self respondsToSelector: @selector (contentAsString)])
	{
	  error = [self matchesRequestConditionInContext: localContext];
	  if (error)
	    value = error;
	  else
	    value = [self _webDAVResponse: localContext];
	}
      else
	value = [NSException exceptionWithHTTPStatus: 501 /* not implemented */
			     reason: @"no WebDAV GET support?!"];
    }
  else
    {
      value = [localContext response];
      uri = [[request uri] composeURLWithAction: @"view"
			   parameters: [request formValues]
			   andHash: NO];
      [value setStatus: 302 /* moved */];
      [value setHeader: uri forKey: @"location"];
    }

  return value;
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

/* acls */

- (NSArray *) aclUsers
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSArray *) aclsForUser: (NSString *) uid
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) setRoles: (NSArray *) roles
          forUser: (NSString *) uid
{
  [self subclassResponsibility: _cmd];
}

- (void) removeAclsForUsers: (NSArray *) users
{
  [self subclassResponsibility: _cmd];
}

- (NSString *) defaultUserID
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) sendACLAdvisoryTemplate: (NSString *) template
			  toUser: (NSString *) uid
{
  NSString *language, *pageName;
  SOGoUser *user;
  SOGoACLAdvisory *page;
  WOApplication *app;

  user = [SOGoUser userWithLogin: uid roles: nil];
  language = [user language];
  pageName = [NSString stringWithFormat: @"SOGoACL%@%@Advisory",
		       language, template];

  app = [WOApplication application];
  page = [app pageWithName: pageName inContext: context];
  [page setACLObject: self];
  [page setRecipientUID: uid];
  [page send];
}

- (void) sendACLAdditionAdvisoryToUser: (NSString *) uid
{
  return [self sendACLAdvisoryTemplate: @"Addition"
	       toUser: uid];
}

- (void) sendACLRemovalAdvisoryToUser: (NSString *) uid
{
  return [self sendACLAdvisoryTemplate: @"Removal"
	       toUser: uid];
}

- (NSURL *) _urlPreferringParticle: (NSString *) expected
		       overThisOne: (NSString *) possible
{
  NSURL *serverURL, *url;
  NSMutableArray *path;
  NSString *baseURL, *urlMethod;

  serverURL = [context serverURL];
  baseURL = [[self baseURLInContext: context] stringByUnescapingURL];
  path = [NSMutableArray arrayWithArray: [baseURL componentsSeparatedByString:
						    @"/"]];
  urlMethod = [path objectAtIndex: 2];
  if (![urlMethod isEqualToString: expected])
    {
      if ([urlMethod isEqualToString: possible])
	[path replaceObjectAtIndex: 2 withObject: expected];
      else
	[path insertObject: expected atIndex: 2];
    }

  url = [[NSURL alloc] initWithScheme: [serverURL scheme]
		       host: [serverURL host]
		       path: [path componentsJoinedByString: @"/"]];
  [url autorelease];

  return url;
}

- (NSURL *) davURL
{
  return [self _urlPreferringParticle: @"dav" overThisOne: @"so"];
}

- (NSURL *) soURL
{
  return [self _urlPreferringParticle: @"so" overThisOne: @"dav"];
}

- (NSURL *) soURLToBaseContainerForUser: (NSString *) uid
{
  NSURL *soURL, *baseSoURL;
  NSArray *basePath;
  NSMutableArray *newPath;

  soURL = [self soURL];
  basePath = [[soURL path] componentsSeparatedByString: @"/"];
  newPath
    = [NSMutableArray arrayWithArray:
			[basePath subarrayWithRange: NSMakeRange (0, 5)]];
  [newPath replaceObjectAtIndex: 3 withObject: uid];

  baseSoURL = [[NSURL alloc] initWithScheme: [soURL scheme]
			     host: [soURL host]
			     path: [newPath componentsJoinedByString: @"/"]];
  [baseSoURL autorelease];

  return baseSoURL;
}

- (NSURL *) soURLToBaseContainerForCurrentUser
{
  NSString *currentLogin;

  currentLogin = [[context activeUser] login];

  return [self soURLToBaseContainerForUser: currentLogin];
}

- (NSString *) httpURLForAdvisoryToUser: (NSString *) uid
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (NSString *) resourceURLForAdvisoryToUser: (NSString *) uid
{
  [self subclassResponsibility: _cmd];

  return nil;
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
