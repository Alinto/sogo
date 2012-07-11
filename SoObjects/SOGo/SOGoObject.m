/* SOGoObject.m - this file is part of SOGo
 *
 *  Copyright (C) 2004-2005 SKYRIX Software AG
 *  Copyright (C) 2006-2009 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
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

#import <unistd.h>

#import <Foundation/NSBundle.h>
#import <Foundation/NSClassDescription.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoClass.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/WEClientCapabilities.h>
#import <NGObjWeb/WOApplication.h>
#import <NGObjWeb/WOContext.h>
#import <NGObjWeb/WOResourceManager.h>
#import <NGObjWeb/WOResponse.h>
#import <NGObjWeb/WORequest.h>
#import <NGObjWeb/WORequest+So.h>
#import <NGObjWeb/NSException+HTTP.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>
#import <DOM/DOMDocument.h>
#import <DOM/DOMNode.h>
#import <DOM/DOMProtocols.h>
#import <NGCards/NSDictionary+NGCards.h>
#import <SaxObjC/XMLNamespaces.h>

#import <SOGoUI/SOGoACLAdvisory.h>

#import "NSArray+Utilities.h"
#import "NSCalendarDate+SOGo.h"
#import "NSDictionary+Utilities.h"
#import "NSObject+DAV.h"
#import "NSObject+Utilities.h"
#import "NSString+DAV.h"
#import "NSString+Utilities.h"
#import "SOGoCache.h"
#import "SOGoDomainDefaults.h"
#import "SOGoPermissions.h"
#import "SOGoSystemDefaults.h"
#import "SOGoUser.h"
#import "SOGoUserDefaults.h"
#import "SOGoUserFolder.h"
#import "SOGoWebDAVAclManager.h"
#import "SOGoWebDAVValue.h"
#import "WORequest+SOGo.h"
#import "WOResponse+SOGo.h"

#import "SOGoObject.h"

@implementation SOGoObject

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    aclManager = [SOGoWebDAVAclManager new];

  return aclManager;
}

/*
+ (id) WebDAVPermissionsMap
{
  static NSDictionary *permissions = nil;

  if (!permissions)
    {
      permissions = [NSDictionary dictionaryWithObjectsAndKeys:
				    davElement (@"read", XMLNS_WEBDAV),
				  SoPerm_AccessContentsInformation,
				  davElement (@"bind", XMLNS_WEBDAV),
				  SoPerm_AddDocumentsImagesAndFiles,
				  davElement (@"unbind", XMLNS_WEBDAV),
				  SoPerm_DeleteObjects,
				  davElement (@"write-acl", XMLNS_WEBDAV),
				  SoPerm_ChangePermissions,
				  davElement (@"write-content", XMLNS_WEBDAV),
				  SoPerm_ChangeImagesAndFiles, NULL];
      [permissions retain];
    }

  return permissions; 
  } */

+ (NSString *) globallyUniqueObjectId
{
  /*
    4C08AE1A-A808-11D8-AC5A-000393BBAFF6
    SOGo-Web-28273-18283-288182
    printf( "%x", *(int *) &f);
  */
  static int pid = 0;
  static int sequence = 0;
  static float rndm = 0;
  float f;

  if (pid == 0)
    {
      pid = getpid();
      rndm = random();
    }
  sequence++;
  f = [[NSDate date] timeIntervalSince1970];

  return [NSString stringWithFormat:@"%0X-%0X-%0X-%0X",
		   pid, (int) f, sequence++, (int) rndm];
}

- (NSString *) globallyUniqueObjectId
{
  return [[self class] globallyUniqueObjectId];
}

/* containment */

+ (id) objectWithName: (NSString *)_name inContainer:(id)_container
{
  SOGoObject *object;

  object = [[self alloc] initWithName: _name inContainer: _container];
  [object autorelease];

  return object;
}

/* end of properties */

- (BOOL) doesRetainContainer
{
  return NO;
}

- (id) init
{
  if ((self = [super init]))
    {
      context = nil;
      nameInContainer = nil;
      container = nil;
      owner = nil;
      webdavAclManager = [[self class] webdavAclManager];
      activeUserIsOwner = NO;
      isInPublicZone = NO;
    }

  return self;
}

- (id) initWithName: (NSString *) _name
	inContainer: (id) _container
{
  if ((self = [self init]))
    {
      if ([_name length] == 0)
        [NSException raise: NSInvalidArgumentException
                     format: @"'_name' must not be an empty string"];
      context = [[WOApplication application] context];
      nameInContainer = [_name copy];
      container = _container;
      if ([self doesRetainContainer])
	[_container retain];
      owner = [self ownerInContext: context];
    }

  return self;
}

- (void) dealloc
{
  [owner release];
  if ([self doesRetainContainer])
    [container release];
  [nameInContainer release];
  [super dealloc];
}

/* accessors */

- (void) setContext: (WOContext *) newContext
{
  context = newContext;
}

- (WOContext *) context
{
  return context;
}

- (void) setNameInContainer: (NSString *) theName
{
  ASSIGN(nameInContainer, theName);
}

- (NSString *) nameInContainer
{
  return nameInContainer;
}

- (NSString *) displayName
{
  return [self nameInContainer];
}

- (id) container
{
  return container;
}

/* ownership */

- (void) setOwner: (NSString *) newOwner
{
  NSString *uid;

  uid = [[context activeUser] login];
  activeUserIsOwner = [newOwner isEqualToString: uid];

  ASSIGN (owner, newOwner);
}

- (NSString *) ownerInContext: (id) localContext
{
  if (!owner)
    [self setOwner: [container ownerInContext: localContext]];

  return owner;
}

- (BOOL) ignoreRights
{
  SOGoUser *currentUser;
  NSString *login;
  BOOL ignoreRights;

  if (activeUserIsOwner)
    ignoreRights = YES;
  else
    {
      currentUser = [context activeUser];
      login = [currentUser login];
      ignoreRights = ([login isEqualToString: [self ownerInContext: context]]
                      || [currentUser isSuperUser]);
    }

  return ignoreRights;
}

- (BOOL) isInPublicZone
{
  if (!isInPublicZone)
    isInPublicZone = [container isInPublicZone];

  return isInPublicZone;
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

- (id) lookupName: (NSString *) lookupName
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id obj;
  SOGoCache *cache;
  NSString *httpMethod;

  cache = [SOGoCache sharedCache];
  obj = [cache objectNamed: lookupName inContainer: self];
  if (!obj)
    {
      httpMethod = [[localContext request] method];
      if ([httpMethod isEqualToString: @"REPORT"])
        obj = [self davReportInvocationForKey: lookupName];
      else
	{
	  obj = [[self soClass] lookupKey: lookupName inContext: localContext];
	  if (obj)
	    [obj bindToObject: self inContext: localContext];
	}

      if (obj)
	[cache registerObject: obj withName: lookupName inContainer: self];
    }

  return obj;
}

/* looking up shared objects */

- (SOGoUserFolder *) lookupUserFolder
{
  if (![container respondsToSelector:_cmd])
    return nil;
  
  return [container lookupUserFolder];
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
  return [self displayName];
}

/* DAV ACL properties */
- (SOGoWebDAVValue *) davOwner
{
  NSDictionary *ownerHREF;
  NSString *usersUrl;

  usersUrl = [NSString stringWithFormat: @"%@%@/",
		       [[WOApplication application] davURLAsString], owner];
  ownerHREF = davElementWithContent (@"href", XMLNS_WEBDAV, usersUrl);

  return [davElementWithContent (@"owner", XMLNS_WEBDAV, ownerHREF)
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davAclRestrictions
{
  NSArray *restrictions;

  restrictions = [NSArray arrayWithObjects:
			    davElement (@"grant-only", XMLNS_WEBDAV),
			  davElement (@"no-invert", XMLNS_WEBDAV),
			  nil];

  return [davElementWithContent (@"acl-restrictions", XMLNS_WEBDAV, restrictions)
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davPrincipalCollectionSet
{
  NSString *usersUrl;
  NSDictionary *collectionHREF;
  NSString *classes;

  if ([[context request] isICal4])
    {
      classes = [[self davComplianceClassesInContext: context]
                  componentsJoinedByString: @", "];
      [[context response] setHeader: classes forKey: @"DAV"];
    }

  /* WOApplication has no support for the DAV methods we define here so we
     use the user's principal object as a reference */
  usersUrl = [[WOApplication application] davURLAsString];
  collectionHREF = davElementWithContent (@"href", XMLNS_WEBDAV, usersUrl);

  return [davElementWithContent (@"principal-collection-set",
				 XMLNS_WEBDAV,
				 [NSArray arrayWithObject: collectionHREF])
				asWebDAVValue];
}

- (NSArray *) _davPrivilegesFromRoles: (NSArray *) roles
{
  NSEnumerator *privileges;
  NSDictionary *privilege;
  NSMutableArray *davPrivileges;

  davPrivileges = [NSMutableArray array];

  privileges = [[webdavAclManager davPermissionsForRoles: roles
				  onObject: self] objectEnumerator];
  while ((privilege = [privileges nextObject]))
    [davPrivileges addObject: davElementWithContent (@"privilege", XMLNS_WEBDAV,
						     privilege)];

  return davPrivileges;
}

- (SOGoWebDAVValue *) davCurrentUserPrivilegeSet
{
  NSArray *userRoles;

  userRoles = [[context activeUser] rolesForObject: self inContext: context];

  return [davElementWithContent (@"current-user-privilege-set",
				 XMLNS_WEBDAV,
				 [self _davPrivilegesFromRoles: userRoles])
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davSupportedPrivilegeSet
{
  return [davElementWithContent (@"supported-privilege-set",
				 XMLNS_WEBDAV,
				 [webdavAclManager treeAsWebDAVValue])
				asWebDAVValue];
}

#warning this method has probably some code shared with its pseudo principal equivalent
- (void)  _fillAces: (NSMutableArray *) aces
    withRolesForUID: (NSString *) currentUID
{
  NSMutableArray *currentAce;
  NSArray *roles;
  NSDictionary *currentGrant, *userHREF;
  NSString *principalURL;

  currentAce = [NSMutableArray array];
  roles = [[SOGoUser userWithLogin: currentUID roles: nil]
	    rolesForObject: self
	    inContext: context];
  if ([roles count])
    {
      principalURL = [NSString stringWithFormat: @"%@%@/",
			       [[WOApplication application] davURLAsString],
			       currentUID];
      userHREF = davElementWithContent (@"href", XMLNS_WEBDAV, principalURL);
      [currentAce addObject: davElementWithContent (@"principal", XMLNS_WEBDAV,
						    userHREF)];
      currentGrant
	= davElementWithContent (@"grant", XMLNS_WEBDAV,
				 [self _davPrivilegesFromRoles: roles]);
      [currentAce addObject: currentGrant];
      [aces addObject: davElementWithContent (@"ace", XMLNS_WEBDAV, currentAce)];
    }
}

- (void) _fillAcesWithRolesForPseudoPrincipals: (NSMutableArray *) aces
{
  NSArray *roles, *currentAce;
  NSDictionary *principal, *currentGrant, *principalHREF, *inherited;
  NSString *principalURL;
  SOGoUser *user;

//  DAV:self, DAV:property(owner), DAV:authenticated
  user = [context activeUser];

  principalURL = [NSString stringWithFormat: @"%@%@/",
                           [[WOApplication application] davURLAsString],
                       [self ownerInContext: nil]];
  principalHREF = davElementWithContent (@"href", XMLNS_WEBDAV, principalURL);
  inherited = davElementWithContent (@"inherited", XMLNS_WEBDAV,
                                     principalHREF),

  roles = [user rolesForObject: self inContext: context];
  if ([roles count])
    {
      principal = davElement (@"self", XMLNS_WEBDAV);
      currentGrant
	= davElementWithContent (@"grant", XMLNS_WEBDAV,
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray
                     arrayWithObjects: davElementWithContent (@"principal",
                                                              XMLNS_WEBDAV,
                                                              principal),
                     currentGrant,
                     inherited,
                     nil];
      [aces addObject: davElementWithContent (@"ace", XMLNS_WEBDAV, currentAce)];
    }

  user = [SOGoUser userWithLogin: [self ownerInContext: context] roles: nil];
  roles = [user rolesForObject: self inContext: context];
  if ([roles count])
    {
      principal = davElementWithContent (@"property", XMLNS_WEBDAV,
					 davElement (@"owner", XMLNS_WEBDAV));
      currentGrant
	= davElementWithContent (@"grant", XMLNS_WEBDAV,
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray
                     arrayWithObjects: davElementWithContent (@"principal",
                                                              XMLNS_WEBDAV,
                                                              principal),
                     currentGrant,
                     inherited,
                     nil];
      [aces addObject: davElementWithContent (@"ace", XMLNS_WEBDAV, currentAce)];
    }

  roles = [self aclsForUser: [self defaultUserID]];
  if ([roles count])
    {
      principal = davElement (@"authenticated", XMLNS_WEBDAV);
      currentGrant
	= davElementWithContent (@"grant", XMLNS_WEBDAV,
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray
                     arrayWithObjects: davElementWithContent (@"principal",
                                                              XMLNS_WEBDAV,
                                                              principal),
                     currentGrant,
                     inherited,
                     nil];
      [aces addObject: davElementWithContent (@"ace", XMLNS_WEBDAV, currentAce)];
    }
}

- (SOGoWebDAVValue *) davAcl
{
  NSEnumerator *uids;
  NSMutableArray *aces;
  NSString *currentUID;

  aces = [NSMutableArray array];

  [self _fillAcesWithRolesForPseudoPrincipals: aces];
  uids = [[self aclUsers] objectEnumerator];
  while ((currentUID = [uids nextObject]))
    [self _fillAces: aces withRolesForUID: currentUID];

  return [davElementWithContent (@"acl", XMLNS_WEBDAV, aces)
				asWebDAVValue];
}

/* actions */

- (id) DELETEAction: (id) _ctx
{
  id result;

  result = [self delete];
  /* Note: returning 'nil' breaks in SoObjectRequestHandler */
  if (!result)
    result = [NSNumber numberWithBool: YES]; /* delete worked out ... */
  
  return result;
}

- (BOOL) isFolderish
{
  [self subclassResponsibility: _cmd];

  return NO;
}

- (BOOL) davIsCollection
{
  return [self isFolderish];
}

- (NSString *) davContentType
{
  return @"text/plain";
}

- (NSString *) davLastModified
{
  return [[NSCalendarDate date] rfc822DateString];
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

- (NSString *) _parseXMLCommand: (id <DOMDocument>) document
{
  NSString *command;

  command = [[document firstChild] localName];

  return [NSString stringWithFormat: @"%@:", command];
}

- (id) davPOSTRequest: (WORequest *) request
      withContentType: (NSString *) cType
	    inContext: (WOContext *) localContext
{
  id obj;
  id <DOMDocument> document;
  SEL commandSel;
  NSString *command;

  obj = nil;

  if ([cType hasPrefix: @"application/xml"]
      || [cType hasPrefix: @"text/xml"])
    {
      document = [request contentAsDOMDocument];
      command = [[self _parseXMLCommand: document] davMethodToObjC];
      commandSel = NSSelectorFromString (command);
      if ([self respondsToSelector: commandSel])
	obj = [self performSelector: commandSel withObject: localContext];
    }

  return obj;
}

- (id) POSTAction: (id) localContext
{
  WORequest *rq;
  id obj;

  rq = [localContext request];
  if ([rq isSoWebDAVRequest])
    obj = [self davPOSTRequest: rq
		withContentType: [rq headerForKey: @"content-type"]
		inContext: localContext];
  else
    obj = nil;

  return obj;
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
- (NSArray *) parseETagList: (NSString *) list
{
  NSArray *etags;

  if (![list length] || [list isEqualToString:@"*"])
    etags = nil;
  else
    etags = [[list componentsSeparatedByString: @","] trimmedComponents];

  return etags;
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

/* roles required to obtain the "authorized subscriber" role */
- (NSArray *) subscriptionRoles
{
  return [container subscriptionRoles];
}

- (BOOL) addUserInAcls: (NSString *) uid
{
  BOOL result;
  SOGoDomainDefaults *dd;

  if ([uid length]
      && ![uid isEqualToString: [self ownerInContext: nil]])
    {
      [self setRoles: [self aclsForUser: uid]
	    forUser: uid];
      dd = [[context activeUser] domainDefaults];
      if ([dd aclSendEMailNotifications])
	[self sendACLAdditionAdvisoryToUser: uid];
      result = YES;
    }
  else
    result = NO;

  return result;
}

- (BOOL) removeUserFromAcls: (NSString *) uid
{
  BOOL result;
  SOGoDomainDefaults *dd;

  if ([uid length])
    {
      [self removeAclsForUsers: [NSArray arrayWithObject: uid]];
      dd = [[context activeUser] domainDefaults];
      if ([dd aclSendEMailNotifications])
	[self sendACLRemovalAdvisoryToUser: uid];
      result = YES;
    }
  else
    result = NO;

  return result;
}

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

- (void) setRoles: (NSArray *) roles
         forUsers: (NSArray *) users
{
  int count, max;

  max = [users count];
  for (count = 0; count < max; count++)
    [self setRoles: roles forUser: [users objectAtIndex: count]];
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
  SOGoUserDefaults *userDefaults;
  SOGoACLAdvisory *page;
  WOApplication *app;

  userDefaults = [[SOGoUser userWithLogin: uid roles: nil] userDefaults];
  language = [userDefaults language];
  pageName = [NSString stringWithFormat: @"SOGoACL%@%@Advisory",
		       language, template];

  app = [WOApplication application];
  page = [app pageWithName: pageName inContext: context];
  if (page == nil)
    [self errorWithFormat: @"Template %@ doesn't exist.", pageName];
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
  NSString *baseURL, *urlMethod, *fullHost;
  NSNumber *port;

  serverURL = [context serverURL];
  baseURL = [[self baseURLInContext: context] stringByUnescapingURL];
  path = [NSMutableArray arrayWithArray: [baseURL componentsSeparatedByString:
						    @"/"]];
  if ([baseURL hasPrefix: @"http"])
    {
      [path removeObjectAtIndex: 1];
      [path removeObjectAtIndex: 0];
      [path replaceObjectAtIndex: 0 withObject: @""];
    }
  urlMethod = [path objectAtIndex: 2];
  if (![urlMethod isEqualToString: expected])
    {
      if ([urlMethod isEqualToString: possible])
	[path replaceObjectAtIndex: 2 withObject: expected];
      else
	[path insertObject: expected atIndex: 2];
    }

  port = [serverURL port];
  if (port)
    fullHost = [NSString stringWithFormat: @"%@:%@",
			 [serverURL host], port];
  else
    fullHost = [serverURL host];

  url = [[NSURL alloc] initWithScheme: [serverURL scheme]
		       host: fullHost
		       path: [path componentsJoinedByString: @"/"]];
  [url autorelease];

  return url;
}

- (NSURL *) davURL
{
  return [self _urlPreferringParticle: @"dav" overThisOne: @"so"];
}

- (NSString *) davURLAsString
{
  return [[container davURLAsString]
           stringByAppendingFormat: @"%@", nameInContainer];
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

- (void) appendAttributesToDescription: (NSMutableString *) _ms
{
  if (nameInContainer) 
    [_ms appendFormat:@" name=%@", nameInContainer];
  if (container)
    [_ms appendFormat:@" container=0x%08X/%@", 
         container, [container valueForKey:@"nameInContainer"]];
}

- (NSString *) description
{
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%08X[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];

  return ms;
}

- (NSString *) loggingPrefix
{
  return [NSString stringWithFormat:@"<0x%08X[%@]:%@>",
		   self, NSStringFromClass([self class]),
		   [self nameInContainer]];
}

- (SOGoObject *) lookupObjectAtDAVUrl: (NSString *) davURL
{
  NSString *appName, *baseSearchURL, *subString, *objectName;
  NSRange searchRange;
  NSArray *sogoObjects;
  SOGoObject *currentObject, *resultObject;
  int count, max;

  resultObject = nil;

  appName = [[context request] applicationName];
  baseSearchURL = [NSString stringWithFormat: @"%@/dav/", appName];
  searchRange = [davURL rangeOfString: baseSearchURL];
  if (searchRange.location != NSNotFound)
    {
      subString = [davURL substringFromIndex: NSMaxRange (searchRange)];
      currentObject = (SOGoObject *) [WOApplication application];
      sogoObjects = [subString componentsSeparatedByString: @"/"];
      max = [sogoObjects count];
      for (count = 0; currentObject && count < max; count++)
        {
          objectName = [sogoObjects objectAtIndex: count];
          if ([objectName length])
            currentObject = [currentObject lookupName: objectName
                                            inContext: context
                                              acquire: NO];
        }
      resultObject = currentObject;
    }

  return resultObject;
}

- (NSArray *) davComplianceClassesInContext: (WOContext *) localContext
{
  NSMutableArray *classes;
  static NSArray *calendarClasses = nil, *contactsClasses = nil,
    *upperClasses = nil;
  NSArray *caldavClasses;
  BOOL found = NO, needCalDAVClasses = NO, needCardDAVClasses = NO;
  NSUInteger count, max;

  /* popuplate static arrays */
  if (!upperClasses)
    {
      upperClasses = [NSArray arrayWithObjects:
                                NSClassFromString (@"SOGoPublicBaseFolder"),
                              NSClassFromString (@"SOGoUserFolder"),
                              nil];
      [upperClasses retain];
    }

  if (!calendarClasses)
    {
      calendarClasses
        = [NSArray arrayWithObjects:
                     NSClassFromString (@"SOGoAppointmentFolders"),
                   NSClassFromString (@"SOGoAppointmentFolder"),
                   nil];
      [calendarClasses retain];
    }

  if (!contactsClasses)
    {
      contactsClasses
        = [NSArray arrayWithObjects:
                     NSClassFromString (@"SOGoContactFolders"),
                   NSClassFromString (@"SOGoContactGCSFolder"),
                   NSClassFromString (@"SOGoContactSourceFolder"),
                   nil];
      [contactsClasses retain];
    }

  /* determine which kind of object we are dealing with */
  if ([self isFolderish])
    {
      max = [upperClasses count];
      for (count = 0; !found && count < max; count++)
        {
          if ([self isKindOfClass: [upperClasses objectAtIndex: count]])
            {
              found = YES;
              needCalDAVClasses = YES;
              needCardDAVClasses = YES;
            }
        }

      max = [calendarClasses count];
      for (count = 0; !found && count < max; count++)
        {
          if ([self isKindOfClass: [calendarClasses objectAtIndex: count]])
            {
              found = YES;
              needCalDAVClasses = YES;
            }
        }

      max = [contactsClasses count];
      for (count = 0; !found && count < max; count++)
        {
          if ([self isKindOfClass: [contactsClasses objectAtIndex: count]])
            {
              found = YES;
              needCardDAVClasses = YES;
            }
        }
    }

  /* prepare the array */
  classes = [[super davComplianceClassesInContext: localContext]
                     mutableCopy];
  if (!classes)
    classes = [NSMutableArray new];
  [classes autorelease];

  /* generic */
  [classes addObject: @"access-control"];

  /* CardDAV */
  if (needCardDAVClasses)
    [classes addObject: @"addressbook"];

  /* CalDAV */
  if (needCalDAVClasses)
    {
      caldavClasses = [NSArray arrayWithObjects: @"calendar-access",
                               @"calendar-schedule",
                               @"calendar-auto-schedule",
                               @"calendar-proxy",
                               // @"calendarserver-private-events",
                               // @"calendarserver-private-comments",
                               // @"calendarserver-sharing",
                               // @"calendarserver-sharing-no-scheduling",
                               @"calendar-query-extended",
                               @"extended-mkcol",
                               @"calendarserver-principal-property-search",
                               nil];
      [classes addObjectsFromArray: caldavClasses];
    }

  return classes;
}

- (SOGoWebDAVValue *) davCurrentUserPrincipal
{
  NSDictionary *userHREF;
  NSString *login;
  SOGoUser *activeUser;
  SOGoWebDAVValue *davCurrentUserPrincipal;

  activeUser = [[self context] activeUser];
  login = [activeUser login];
  if ([login isEqualToString: @"anonymous"])
    davCurrentUserPrincipal = nil;
  else
    {
      userHREF = davElementWithContent (@"href", XMLNS_WEBDAV, [self davURLAsString]);
      davCurrentUserPrincipal
        = [davElementWithContent (@"current-user-principal",
                                  XMLNS_WEBDAV,
                                  userHREF)
                                 asWebDAVValue];
    }

  return davCurrentUserPrincipal;
}

/* dav acls */
- (NSString *) davRecordForUser: (NSString *) user
		     parameters: (NSArray *) params
{
  NSMutableString *userRecord;

  userRecord = [NSMutableString string];

  [userRecord appendFormat: @"<id>%@</id>",
	      [user stringByEscapingXMLString]];

  // Make sure to not call [SOGoUser userWithLogin...] here if nocn AND noemail
  // is specified. We'll avoid generating LDAP calls by doing so.
  if (![params containsObject: @"nocn"])
    {
      NSString *cn;

      cn = [[SOGoUser userWithLogin: user roles: nil] cn];
      if (!cn)
	cn = user;
      [userRecord appendFormat: @"<displayName>%@</displayName>",
		  [cn stringByEscapingXMLString]];
    }
  
  if (![params containsObject: @"noemail"])
    {
      NSString *email;

      email = [[[SOGoUser userWithLogin: user roles: nil]
		 allEmails] objectAtIndex: 0];
      if (email)
	[userRecord appendFormat: @"<email>%@</email>",
		    [email stringByEscapingXMLString]];
    }

  return userRecord;
}

- (NSString *) _davAclUserListQuery: (NSString *) theParameters
{
  NSMutableString *userList;
  NSString *defaultUserID, *currentUserID;
  NSEnumerator *users;
  NSArray *params;

  if (theParameters && [theParameters length])
    params = [[theParameters lowercaseString] componentsSeparatedByString: @","];
  else
    params = [NSArray array];

  userList = [NSMutableString string];

  defaultUserID = [self defaultUserID];
  if ([defaultUserID length])
    [userList appendFormat: @"<default-user><id>%@</id></default-user>",
	      [defaultUserID stringByEscapingXMLString]];
  users = [[self aclUsers] objectEnumerator];
  while ((currentUserID = [users nextObject]))
    {
      if (![currentUserID isEqualToString: defaultUserID])
	{
	  [userList appendFormat: @"<user>%@</user>",
		    [self davRecordForUser: currentUserID
			  parameters: params]];
	}
    }

  return userList;
}

- (NSString *) _davAclUserRoles: (NSString *) userName
{
  NSArray *roles;

  roles = [[self aclsForUser: userName] stringsWithFormat: @"<%@/>"];

  return [roles componentsJoinedByString: @""];
}

- (NSArray *) _davGetRolesFromRequest: (id <DOMNode>) node
{
  NSMutableArray *roles;
  NSArray *childNodes;
  NSString *currentRole;
  unsigned int count, max;

  roles = [NSMutableArray array];
  childNodes = [self domNode: node getChildNodesByType: DOM_ELEMENT_NODE];
  max = [childNodes count];
  for (count = 0; count < max; count++)
    {
      currentRole = [[childNodes objectAtIndex: count] localName];
      [roles addObject: currentRole];
    }

  return roles;
}

- (NSString *) _davAclActionFromQuery: (id <DOMDocument>) document
{
  id <DOMNode> node, userAttr;
  id <DOMNamedNodeMap> attrs;
  NSString *nodeName, *result, *response, *user;
  NSArray *childNodes, *allUsers, *allRoles;
  int i;

  result = nil;

  childNodes = [self domNode: [document documentElement]
		     getChildNodesByType: DOM_ELEMENT_NODE];
  if ([childNodes count])
    {
      node = [childNodes objectAtIndex: 0];
      nodeName = [node localName];

      //
      // We support parameters during the user-list REPORT.
      // We do that in order to avoid looking up from the LDAP
      // the CN and the EMAIL address of the users that are 
      // returned in the REPORT's response. That can be slow if
      // the LDAP server used for authentication is slow and this
      // information might not be necessary for scripting purposes.
      //
      // The following parameters are supported:
      //
      // nocn - avoid returning the CN
      // noemail - avoid returning the EMAIL address
      //
      // Both can be specified using:
      //
      // params=nocn,noemail
      //
      if ([nodeName isEqualToString: @"user-list"])
	{
	  result = [self _davAclUserListQuery: [[[node attributes] 
						  namedItem: @"params"]
						 nodeValue]];
	}
      else if ([nodeName isEqualToString: @"roles"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([user length])
	    result = [self _davAclUserRoles: user];
	}
      else if ([nodeName isEqualToString: @"set-roles"])
	{
	  // We support two ways of setting roles. The first one is, for example:
	  //
	  // <?xml version="1.0" encoding="UTF-8"?>
	  // <acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
	  // <set-roles user="alice"><PrivateViewer/></set-roles></acl-query>
	  // 
	  // while the second one, for mutliple users at the same time, is:
	  //
	  // <?xml version="1.0" encoding="UTF-8"?>
	  // <acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
	  // <set-roles users="alice,bob,bernard"><PrivateViewer/></set-roles></acl-query>
	  // 
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  
	  if ([user length])
	    allUsers = [NSArray arrayWithObject: user];
	  else
	    {
	      userAttr = [attrs namedItem: @"users"];
	      allUsers = [[userAttr nodeValue] componentsSeparatedByString: @","];
	    }
	  
	  allRoles = [self _davGetRolesFromRequest: node];
	  for (i = 0; i < [allUsers count]; i++)
	    {
	      [self setRoles: allRoles
                     forUser: [allUsers objectAtIndex: i]];
	    }
	  result = @"";
	}
      //
      // Here again, we support two ways of adding users. The first one is, for example:
      //
      // <?xml version="1.0" encoding="utf-8"?>
      // <acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
      // <add-user user="alice"/></acl-query>
      //
      // while the second one, for mutliple users at the same time, is:
      //
      // <?xml version="1.0" encoding="utf-8"?>
      // <acl-query xmlns="urn:inverse:params:xml:ns:inverse-dav">
      // <add-users users="alice,bob,bernard"/></acl-query>
      //
      else if ([nodeName isEqualToString: @"add-user"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([self addUserInAcls: user])
	    result = @"";
	}
      else if ([nodeName isEqualToString: @"add-users"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"users"];
	  allUsers = [[userAttr nodeValue] componentsSeparatedByString: @","];

	  for (i = 0; i < [allUsers count]; i++)
	    {
	      if ([self addUserInAcls: [allUsers objectAtIndex: i]])
		result = @"";
	      else
		{
		  result = nil;
		  break;
		}
	    } 
	}
      //
      // See the comment for add-user / add-users
      //
      else if ([nodeName isEqualToString: @"remove-user"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([self removeUserFromAcls: user])
	    result = @"";
	}
      else if ([nodeName isEqualToString: @"remove-users"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"users"];

	  allUsers = [[userAttr nodeValue] componentsSeparatedByString: @","];

	  for (i = 0; i < [allUsers count]; i++)
	    {
	      if ([self removeUserFromAcls: [allUsers objectAtIndex: i]])
		result = @"";
	      else
		{
		  result = nil;
		  break;
		}
	    }
	}
    }

  if (result)
    {
      if ([result length])
	response = [NSString stringWithFormat: @"<%@>%@</%@>",
			     nodeName, result, nodeName];
      else
	response = @"";
    }
  else
    response = nil;

  return response;
}

- (id) davAclQuery: (WOContext *) queryContext
{
  WOResponse *r;
  id <DOMDocument> document;
  NSString *content;

  r = [queryContext response];
  [r setContentEncoding: NSUTF8StringEncoding];
  [r setHeader: @"no-cache" forKey: @"pragma"];
  [r setHeader: @"no-cache" forKey: @"cache-control"];

  document = [[context request] contentAsDOMDocument];
  content = [self _davAclActionFromQuery: document];
  if (content)
    {
      if ([content length])
	{
	  [r setStatus: 207];
	  [r setHeader: @"application/xml; charset=\"utf-8\""
	     forKey: @"content-type"];
	  [r appendContentString:
	       @"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];
	  [r appendContentString: content];
	}
      else
 	[r setStatus: 204];
    }
  else
    [r setStatus: 400];

  return r;
}

- (NSException *) davSetProperties: (NSDictionary *) setProps
	     removePropertiesNamed: (NSArray *) removedProps
			 inContext: (WOContext *) localContext
{
  NSString *currentProp;
  NSException *exception;
  NSEnumerator *properties;
  id currentValue;
  SEL methodSel;

  properties = [[setProps allKeys] objectEnumerator];
  exception = nil;
  while (!exception
	 && (currentProp = [properties nextObject]))
    {
      methodSel = NSSelectorFromString ([currentProp davSetterName]);
      if ([self respondsToSelector: methodSel])
	{
	  currentValue = [setProps objectForKey: currentProp];
	  exception = [self performSelector: methodSel
                                 withObject: currentValue];
	}
      else
	exception
	  = [NSException exceptionWithHTTPStatus: 403
			 reason: [NSString stringWithFormat:
					     @"Property '%@' cannot be set.",
					   currentProp]];
    }

  return exception;
}

- (NSString *) davBooleanForResult: (BOOL) result
{
  return (result ? @"true" : @"false");
}

- (BOOL) isValidDAVBoolean: (NSString *) davBoolean
{
  static NSSet *validBooleans = nil;

  if (!validBooleans)
    {
      validBooleans = [NSSet setWithObjects: @"true", @"false", @"1", @"0",
                             nil];
      [validBooleans retain];
    }

  return [validBooleans containsObject: davBoolean];
}

- (BOOL) resultForDAVBoolean: (NSString *) davBoolean
{
  BOOL result;

  result = ([davBoolean isEqualToString: @"true"]
            || [davBoolean isEqualToString: @"1"]);

  return result;
}

- (NSString *) labelForKey: (NSString *) key
{
  return [self labelForKey: key inContext: context];
}

@end /* SOGoObject */
