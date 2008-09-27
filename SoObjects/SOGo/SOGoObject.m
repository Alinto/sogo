/* SOGoGCSFolder.m - this file is part of SOGo
 *
 *  Copyright (C) 2004-2005 SKYRIX Software AG
 *  Copyright (C) 2006-2008 Inverse inc.
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/SoClass.h>
#import <NGObjWeb/SoObject+SoDAV.h>
#import <NGObjWeb/SoSelectorInvocation.h>
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
#import <UI/SOGoUI/SOGoACLAdvisory.h>

#import "LDAPUserManager.h"
#import "NSArray+Utilities.h"
#import "NSCalendarDate+SOGo.h"
#import "NSDictionary+Utilities.h"
#import "NSObject+DAV.h"
#import "NSObject+Utilities.h"
#import "NSString+Utilities.h"
#import "SOGoCache.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
#import "SOGoUserFolder.h"
#import "SOGoWebDAVAclManager.h"
#import "SOGoWebDAVValue.h"

#import "SOGoObject.h"

static BOOL kontactGroupDAV = YES;
static BOOL sendACLAdvisories = NO;

static NSDictionary *reportMap = nil;
static NSMutableDictionary *setterMap = nil;
static NSMutableDictionary *getterMap = nil;

SEL SOGoSelectorForPropertyGetter (NSString *property)
{
  SEL propSel;
  NSValue *propPtr;
  NSDictionary *map;
  NSString *methodName;

  if (!getterMap)
    getterMap = [NSMutableDictionary new];
  propPtr = [getterMap objectForKey: property];
  if (propPtr)
    propSel = [propPtr pointerValue];
  else
    {
      map = [SOGoObject defaultWebDAVAttributeMap];
      methodName = [map objectForKey: property];
      if (methodName)
	{
	  propSel = NSSelectorFromString (methodName);
	  if (propSel)
	    [getterMap setObject: [NSValue valueWithPointer: propSel]
		       forKey: property];
	}
    }

  return propSel;
}

SEL SOGoSelectorForPropertySetter (NSString *property)
{
  SEL propSel;
  NSValue *propPtr;
  NSDictionary *map;
  NSString *methodName;

  if (!setterMap)
    setterMap = [NSMutableDictionary new];
  propPtr = [setterMap objectForKey: property];
  if (propPtr)
    propSel = [propPtr pointerValue];
  else
    {
      map = [SOGoObject defaultWebDAVAttributeMap];
      methodName = [map objectForKey: property];
      if (methodName)
	{
	  propSel = NSSelectorFromString ([methodName davSetterName]);
	  if (propSel)
	    [setterMap setObject: [NSValue valueWithPointer: propSel]
		       forKey: property];
	}
    }

  return propSel;
}

@implementation SOGoObject

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  SOGoWebDAVAclManager *aclManager = nil;

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
				    davElement (@"read", @"DAV:"),
				  SoPerm_AccessContentsInformation,
				  davElement (@"bind", @"DAV:"),
				  SoPerm_AddDocumentsImagesAndFiles,
				  davElement (@"unbind", @"DAV:"),
				  SoPerm_DeleteObjects,
				  davElement (@"write-acl", @"DAV:"),
				  SoPerm_ChangePermissions,
				  davElement (@"write-content", @"DAV:"),
				  SoPerm_ChangeImagesAndFiles, NULL];
      [permissions retain];
    }

  return permissions; 
  } */

+ (void) initialize
{
  NSUserDefaults *ud;
  NSString *filename;
  NSBundle *bundle;

  ud = [NSUserDefaults standardUserDefaults];
  kontactGroupDAV = ![ud boolForKey:@"SOGoDisableKontact34GroupDAVHack"];
  sendACLAdvisories = [ud boolForKey: @"SOGoACLsSendEMailNotifications"];

  if (!reportMap)
    {
      bundle = [NSBundle bundleForClass: self];
      filename = [bundle pathForResource: @"DAVReportMap" ofType: @"plist"];
      if (filename
	  && [[NSFileManager defaultManager] fileExistsAtPath: filename])
	reportMap = [[NSDictionary alloc] initWithContentsOfFile: filename];
      else
	[self logWithFormat: @"DAV REPORT map not found!"];
    }
//   SoClass security declarations
  
//   require View permission to access the root (bound to authenticated ...)
//   [[self soClassSecurityInfo] declareObjectProtected: SoPerm_View];

//   to allow public access to all contained objects (subkeys)
//   [[self soClassSecurityInfo] setDefaultAccess: @"allow"];
  
//   /* require Authenticated role for View and WebDAV */
//   [[self soClassSecurityInfo] declareRole: SoRole_Owner
//                               asDefaultForPermission: SoPerm_View];
//   [[self soClassSecurityInfo] declareRole: SoRole_Owner
//                               asDefaultForPermission: SoPerm_WebDAVAccess];
}

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
		   pid, (int) f, sequence++, random];
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
      webdavAclManager = [[self class] webdavAclManager];
      activeUserIsOwner = NO;
    }

  return self;
}

- (id) initWithName: (NSString *) _name
	inContainer: (id) _container
{
  if ((self = [self init]))
    {
      context = [[WOApplication application] context];
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
  NSString *uid;

  if (!owner)
    {
      owner = [container ownerInContext: context];
      uid = [[localContext activeUser] login];
      activeUserIsOwner = [owner isEqualToString: uid];
    }

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

- (NSString *) _reportSelector: (NSString *) reportName
{
  NSString *methodName, *objcMethod, *resultName;
  SEL reportSel;

  resultName = nil;

  methodName = [reportMap objectForKey: reportName];
  if (methodName)
    {
      objcMethod = [NSString stringWithFormat: @"%@:", methodName];
      reportSel = NSSelectorFromString (objcMethod);
      if ([self respondsToSelector: reportSel])
	resultName = objcMethod;
    }

  return resultName;
}

- (id) lookupName: (NSString *) lookupName
        inContext: (id) localContext
          acquire: (BOOL) acquire
{
  id obj;
  SOGoCache *cache;
  NSString *objcMethod, *httpMethod;

  cache = [SOGoCache sharedCache];
  obj = [cache objectNamed: lookupName inContainer: self];
  if (!obj)
    {
      httpMethod = [[localContext request] method];
      if ([httpMethod isEqualToString: @"REPORT"])
	{
	  objcMethod = [self _reportSelector: lookupName];
	  if (objcMethod)
	    {
	      obj = [[SoSelectorInvocation alloc]
		      initWithSelectorNamed: objcMethod
		      addContextParameter: YES];
	      [obj autorelease];
	    }
	}
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

// - (SOGoGroupsFolder *) lookupGroupsFolder
// {
//   return [[self lookupUserFolder] lookupGroupsFolder];
// }

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

/* DAV ACL properties */
- (SOGoWebDAVValue *) davOwner
{
  NSDictionary *ownerHREF;
  NSString *usersUrl;

  usersUrl = [NSString stringWithFormat: @"%@%@/",
		       [[WOApplication application] davURL], owner];
  ownerHREF = davElementWithContent (@"href", @"DAV:", usersUrl);

  return [davElementWithContent (@"owner", @"DAV:", ownerHREF)
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davAclRestrictions
{
  NSArray *restrictions;

  restrictions = [NSArray arrayWithObjects:
			    davElement (@"grant-only", @"DAV:"),
			  davElement (@"no-invert", @"DAV:"),
			  nil];

  return [davElementWithContent (@"acl-restrictions", @"DAV:", restrictions)
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davPrincipalCollectionSet
{
  NSString *usersUrl;
  NSDictionary *collectionHREF;

  /* WOApplication has no support for the DAV methods we define here so we
     use the user's principal object as a reference */
  usersUrl = [NSString stringWithFormat: @"%@%@/",
		       [[WOApplication application] davURL], owner];
  collectionHREF = davElementWithContent (@"href", @"DAV:", usersUrl);

  return [davElementWithContent (@"principal-collection-set",
				 @"DAV:",
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
    [davPrivileges addObject: davElementWithContent (@"privilege", @"DAV:",
						     privilege)];

  return davPrivileges;
}

- (SOGoWebDAVValue *) davCurrentUserPrivilegeSet
{
  NSArray *userRoles;

  userRoles = [[context activeUser] rolesForObject: self inContext: context];

  return [davElementWithContent (@"current-user-privilege-set",
				 @"DAV:",
				 [self _davPrivilegesFromRoles: userRoles])
				asWebDAVValue];
}

- (SOGoWebDAVValue *) davSupportedPrivilegeSet
{
  return [davElementWithContent (@"supported-privilege-set",
				 @"DAV:",
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

  currentAce = [NSMutableArray new];
  roles = [[SOGoUser userWithLogin: currentUID roles: nil]
	    rolesForObject: self
	    inContext: context];
  if ([roles count])
    {
      principalURL = [NSString stringWithFormat: @"%@%@/",
			       [[WOApplication application] davURL],
			       currentUID];
      userHREF = davElementWithContent (@"href", @"DAV:", principalURL);
      [currentAce addObject: davElementWithContent (@"principal", @"DAV:",
						    userHREF)];
      currentGrant
	= davElementWithContent (@"grant", @"DAV:",
				 [self _davPrivilegesFromRoles: roles]);
      [currentAce addObject: currentGrant];
      [aces addObject: davElementWithContent (@"ace", @"DAV:", currentAce)];
      [currentAce release];
    }
}

- (void) _fillAcesWithRolesForPseudoPrincipals: (NSMutableArray *) aces
{
  NSArray *roles, *currentAce;
  NSDictionary *principal, *currentGrant;
  SOGoUser *user;

//  DAV:self, DAV:property(owner), DAV:authenticated
  user = [context activeUser];
  roles = [user rolesForObject: self inContext: context];
  if ([roles count])
    {
      principal = davElement (@"self", @"DAV:");
      currentGrant
	= davElementWithContent (@"grant", @"DAV:",
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray arrayWithObjects:
			      davElementWithContent (@"principal", @"DAV:",
						     principal),
			    currentGrant, nil];
      [aces addObject: davElementWithContent (@"ace", @"DAV:", currentAce)];
    }

  user = [SOGoUser userWithLogin: [self ownerInContext: context] roles: nil];
  roles = [user rolesForObject: self inContext: context];
  if ([roles count])
    {
      principal = davElementWithContent (@"property", @"DAV:",
					 davElement (@"owner", @"DAV:"));
      currentGrant
	= davElementWithContent (@"grant", @"DAV:",
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray arrayWithObjects:
			      davElementWithContent (@"principal", @"DAV:",
						     principal),
			    currentGrant, nil];
      [aces addObject: davElementWithContent (@"ace", @"DAV:", currentAce)];
    }

  roles = [self aclsForUser: [self defaultUserID]];
  if ([roles count])
    {
      principal = davElement (@"authenticated", @"DAV:");
      currentGrant
	= davElementWithContent (@"grant", @"DAV:",
				 [self _davPrivilegesFromRoles: roles]);
      currentAce = [NSArray arrayWithObjects:
			      davElementWithContent (@"principal", @"DAV:",
						     principal),
			    currentGrant, nil];
      [aces addObject: davElementWithContent (@"ace", @"DAV:", currentAce)];
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

  return [davElementWithContent (@"acl", @"DAV:", aces)
				asWebDAVValue];
}

#warning all REPORT method should be standardized...
- (NSDictionary *) _formalizePrincipalMatchResponse: (NSArray *) hrefs
{
  NSDictionary *multiStatus;
  NSEnumerator *hrefList;
  NSString *currentHref;
  NSMutableArray *responses;
  NSArray *responseElements;

  responses = [NSMutableArray new];

  hrefList = [hrefs objectEnumerator];
  while ((currentHref = [hrefList nextObject]))
    {
      responseElements
	= [NSArray arrayWithObjects: davElementWithContent (@"href", @"DAV:",
							    currentHref),
		   davElementWithContent (@"status", @"DAV:",
					  @"HTTP/1.1 200 OK"),
		   nil];
      [responses addObject: davElementWithContent (@"response", @"DAV:",
						   responseElements)];
    }

  multiStatus = davElementWithContent (@"multistatus", @"DAV:", responses);
  [responses release];

  return multiStatus;
}

- (NSDictionary *) _handlePrincipalMatchSelf
{
  NSString *davURL, *userLogin;
  NSArray *principalURL;

  davURL = [[WOApplication application] davURL];
  userLogin = [[context activeUser] login];
  principalURL
    = [NSArray arrayWithObject: [NSString stringWithFormat: @"%@%@/", davURL,
					  userLogin]];
  return [self _formalizePrincipalMatchResponse: principalURL];
}

- (void) _fillArrayWithPrincipalsOwnedBySelf: (NSMutableArray *) hrefs
{
  NSString *url;
  NSArray *roles;

  roles = [[context activeUser] rolesForObject: self inContext: context];
  if ([roles containsObject: SoRole_Owner])
    {
      url = [[self davURL] absoluteString];
      [hrefs addObject: url];
    }
}

- (NSDictionary *)
    _handlePrincipalMatchPrincipalProperty: (id <DOMElement>) child
{
  NSMutableArray *hrefs;
  NSDictionary *response;

  hrefs = [NSMutableArray new];
  [self _fillArrayWithPrincipalsOwnedBySelf: hrefs];

  response = [self _formalizePrincipalMatchResponse: hrefs];
  [hrefs release];

  return response;
}

- (NSDictionary *) _handlePrincipalMatchReport: (id <DOMDocument>) document
{
  NSDictionary *response;
  id <DOMElement> documentElement, queryChild;
  NSArray *children;
  NSString *queryTag;

  documentElement = [document documentElement];
  children = [self domNode: documentElement
		   getChildNodesByType: DOM_ELEMENT_NODE];
  if ([children count] == 1)
    {
      queryChild = [children objectAtIndex: 0];
      queryTag = [queryChild tagName];
      if ([queryTag isEqualToString: @"self"])
	response = [self _handlePrincipalMatchSelf];
      else if ([queryTag isEqualToString: @"principal-property"])
	response = [self _handlePrincipalMatchPrincipalProperty: queryChild];
      else
	response = [NSException exceptionWithHTTPStatus: 400
				reason: @"Query element must be either "
				@" '{DAV:}principal-property' or '{DAV:}self'"];
    }
  else
    response = [NSException exceptionWithHTTPStatus: 400
			    reason: @"Query must have one element:"
			    @" '{DAV:}principal-property' or '{DAV:}self'"];

  return response;
}

- (WOResponse *) davPrincipalMatch: (WOContext *) localContext
{
  WOResponse *r;
  id <DOMDocument> document;
  NSDictionary *xmlResponse;

  r = [context response];

  document = [[context request] contentAsDOMDocument];
  xmlResponse = [self _handlePrincipalMatchReport: document];
  if ([xmlResponse isKindOfClass: [NSException class]])
    r = (WOResponse *) xmlResponse;
  else
    {
      [r setStatus: 207];
      [r setContentEncoding: NSUTF8StringEncoding];
      [r setHeader: @"text/xml; charset=\"utf-8\"" forKey: @"content-type"];
      [r setHeader: @"no-cache" forKey: @"pragma"];
      [r setHeader: @"no-cache" forKey: @"cache-control"];
      [r appendContentString:
	   @"<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n"];
      [r appendContentString: [xmlResponse asWebDavStringWithNamespaces: nil]];
    }

  return r;
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

/* roles required to obtain the "authorized subscriber" role */
- (NSArray *) subscriptionRoles
{
  return [container subscriptionRoles];
}

- (BOOL) addUserInAcls: (NSString *) uid
{
  BOOL result;

  if ([uid length]
      && ![uid isEqualToString: [self ownerInContext: nil]]
      && [[LDAPUserManager sharedUserManager]
	   contactInfosForUserWithUIDorEmail: uid])
    {
      [self setRoles: [self aclsForUser: uid]
	    forUser: uid];
      if (sendACLAdvisories)
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

  if ([uid length])
    {
      [self removeAclsForUsers: [NSArray arrayWithObject: uid]];
      if (sendACLAdvisories)
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

- (NSArray *) _languagesForLabels
{
  NSMutableArray *languages;
  NSArray *browserLanguages;
  NSString *language;
  NSUserDefaults *ud;

  languages = [NSMutableArray array];

  language = [[context activeUser] language];
  [languages addObject: language];
  browserLanguages = [[context request] browserLanguages];
  [languages addObjectsFromArray: browserLanguages];
  ud = [NSUserDefaults standardUserDefaults];
  language = [ud stringForKey: @"SOGoDefaultLanguage"];
  if (language)
    [languages addObject: language];
  [languages addObject: @"English"];

  return languages;
}

- (NSString *) labelForKey: (NSString *) key
{
  NSString *language, *label;
  NSArray *paths;
  NSEnumerator *languages;
  NSBundle *bundle;
  NSDictionary *strings;

  label = nil;

  bundle = [NSBundle bundleForClass: [self class]];
  if (!bundle)
    bundle = [NSBundle mainBundle];
  languages = [[self _languagesForLabels] objectEnumerator];

  while (!label && (language = [languages nextObject]))
    {
      paths = [bundle pathsForResourcesOfType: @"strings"
		      inDirectory: [NSString stringWithFormat: @"%@.lproj",
					     language]
		      forLocalization: language];
      if ([paths count] > 0)
	{
	  strings = [NSDictionary
		      dictionaryFromStringsFile: [paths objectAtIndex: 0]];
	  label = [strings objectForKey: key];
	}
    }
  if (!label)
    label = key;
  
  return label;
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

- (NSArray *) davComplianceClassesInContext: (WOContext *) localContext
{
  NSMutableArray *newClasses;

  newClasses
    = [NSMutableArray arrayWithArray:
			[super davComplianceClassesInContext: localContext]];
  [newClasses addObject: @"access-control"];

  return newClasses;
}

/* dav acls */
- (NSString *) davRecordForUser: (NSString *) user
{
  NSMutableString *userRecord;
  SOGoUser *sogoUser;
  NSString *cn, *email;

  userRecord = [NSMutableString string];

  [userRecord appendFormat: @"<id>%@</id>",
	      [user stringByEscapingXMLString]];
  sogoUser = [SOGoUser userWithLogin: user roles: nil];
  cn = [sogoUser cn];
  if (!cn)
    cn = user;
  [userRecord appendFormat: @"<displayName>%@</displayName>",
	      [cn stringByEscapingXMLString]];
  email = [[sogoUser allEmails] objectAtIndex: 0];
  if (email)
    [userRecord appendFormat: @"<email>%@</email>",
		[email stringByEscapingXMLString]];

  return userRecord;
}

- (NSString *) _davAclUserListQuery
{
  NSMutableString *userList;
  NSString *defaultUserID, *currentUserID;
  NSEnumerator *users;

  userList = [NSMutableString string];

  defaultUserID = [self defaultUserID];
  if ([defaultUserID length])
    [userList appendFormat: @"<default-user><id>%@</id></default-user>",
	      [defaultUserID stringByEscapingXMLString]];
  users = [[self aclUsers] objectEnumerator];
  while ((currentUserID = [users nextObject]))
    if (![currentUserID isEqualToString: defaultUserID])
      [userList appendFormat: @"<user>%@</user>",
		[self davRecordForUser: currentUserID]];

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
  NSArray *childNodes;

  result = nil;

  childNodes = [self domNode: [document documentElement]
		     getChildNodesByType: DOM_ELEMENT_NODE];
  if ([childNodes count])
    {
      node = [childNodes objectAtIndex: 0];
      nodeName = [node localName];
      if ([nodeName isEqualToString: @"user-list"])
	result = [self _davAclUserListQuery];
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
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([user length])
	    {
	      [self setRoles: [self _davGetRolesFromRequest: node]
		    forUser: user];
	      result = @"";
	    }
	}
      else if ([nodeName isEqualToString: @"add-user"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([self addUserInAcls: user])
	    result = @"";
	}
      else if ([nodeName isEqualToString: @"remove-user"])
	{
	  attrs = [node attributes];
	  userAttr = [attrs namedItem: @"user"];
	  user = [userAttr nodeValue];
	  if ([self removeUserFromAcls: user])
	    result = @"";
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
	     removePropertiesNamed: (NSDictionary *) removedProps
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
	  = [NSException exceptionWithHTTPStatus: 404
			 reason: [NSString stringWithFormat:
					     @"Property '%@' cannot be set.",
					   currentProp]];
    }

  return exception;
}

- (SOGoWebDAVValue *) davSupportedReportSet
{
  NSDictionary *currentValue;
  NSEnumerator *reportKeys;
  NSMutableArray *reportSet;
  NSString *currentKey;

  reportSet = [NSMutableArray array];

  reportKeys = [[reportMap allKeys] objectEnumerator];
  while ((currentKey = [reportKeys nextObject]))
    if ([self _reportSelector: currentKey])
      {
	currentValue = [currentKey asDavInvocation];
	[reportSet addObject: davElementWithContent(@"report",
						    @"DAV:",
						    currentValue)];
      }

  return [davElementWithContent (@"supported-report-set", @"DAV:", reportSet)
				asWebDAVValue];
}

@end /* SOGoObject */

@implementation SOGoObject (SOGoDomHelpers)

- (NSArray *) domNode: (id <DOMNode>) node
  getChildNodesByType: (DOMNodeType ) type
{
  NSMutableArray *nodes;
  id <DOMNode> currentChild;

  nodes = [NSMutableArray array];

  currentChild = [node firstChild];
  while (currentChild)
    {
      if ([currentChild nodeType] == type)
	[nodes addObject: currentChild];
      currentChild = [currentChild nextSibling];
    }

  return nodes;
}

@end
