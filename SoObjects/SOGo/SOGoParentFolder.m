/* SOGoParentFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2022 Inverse inc.
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


#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGObjWeb/WORequest.h>
#import <NGExtensions/NSObject+Logs.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <DOM/DOMProtocols.h>
#import <SaxObjC/XMLNamespaces.h>
#import <SOGo/SOGoUserDefaults.h>
#import <SOGo/SOGoUserSettings.h>

#import "NSObject+DAV.h"
#import "SOGoGCSFolder.h"
#import "SOGoPermissions.h"
#import "SOGoSource.h"
#import "SOGoUser.h"
#import "SOGoUserManager.h"
#import "SOGoWebDAVAclManager.h"

#import "SOGoParentFolder.h"

static SoSecurityManager *sm = nil;

@implementation SOGoParentFolder

+ (void) initialize
{
  if (!sm)
    sm = [SoSecurityManager sharedSecurityManager];
}

+ (SOGoWebDAVAclManager *) webdavAclManager
{
  static SOGoWebDAVAclManager *aclManager = nil;

  if (!aclManager)
    {
      aclManager = [SOGoWebDAVAclManager new];
      [aclManager registerDAVPermission: davElement (@"read",
						     XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission:
		    davElement (@"read-current-user-privilege-set",
				XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_WebDAVAccess
		  asChildOf: davElement (@"read", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"write",
						     XMLNS_WEBDAV)
		  abstract: YES
		  withEquivalent: nil
		  asChildOf: davElement (@"all", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"bind",
						     XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_AddFolders
		  asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager registerDAVPermission: davElement (@"unbind",
						     XMLNS_WEBDAV)
		  abstract: NO
		  withEquivalent: SoPerm_DeleteObjects
		  asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-properties", XMLNS_WEBDAV)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", XMLNS_WEBDAV)];
      [aclManager
	registerDAVPermission: davElement (@"write-content", XMLNS_WEBDAV)
	abstract: YES
	withEquivalent: nil
	asChildOf: davElement (@"write", XMLNS_WEBDAV)];
    }

  return aclManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      subFolders = nil;
      OCSPath = nil;
      subscribedSubFolders = nil;
      subFolderClass = Nil;
//       hasSubscribedSources = NO;
    }

  return self;
}

- (void) dealloc
{
  [subscribedSubFolders release];
  [subFolders release];
  [OCSPath release];
  [super dealloc];
}

+ (Class) subFolderClass
{
  [self subclassResponsibility: _cmd];

  return Nil;
}

+ (NSString *) gcsFolderType
{
  [self subclassResponsibility: _cmd];

  return nil;
}

- (void) setBaseOCSPath: (NSString *) newOCSPath
{
  ASSIGN (OCSPath, newOCSPath);
}

- (NSString *) defaultFolderName
{
  return @"Personal";
}

- (NSString *) collectedFolderName
{
  return @"Collected";
}

- (void) createSpecialFolder: (SOGoFolderType) folderType
{
  NSArray *roles;
  NSString *folderName;
  SOGoGCSFolder *folder;
  SOGoUser *folderOwner;
  SOGoUserDefaults *ud;
  
  roles = [[context activeUser] rolesForObject: self inContext: context];
  folderOwner = [SOGoUser userWithLogin: [self ownerInContext: context]];
  
  
  // We autocreate the calendars if the user is the owner, a superuser or
  // if it's a resource as we won't necessarily want to login as a resource
  // in order to create its database tables.
  // FolderType is an enum where 0 = Personal and 1 = collected
  if ([roles containsObject: SoRole_Owner] ||
      (folderOwner && [folderOwner isResource]))
  {
    if (folderType == SOGoPersonalFolder)
    {
      folderName = @"personal";
      folder = [subFolderClass objectWithName: folderName inContainer: self];
      [folder setDisplayName: [self defaultFolderName]];
      [folder setOCSPath: [NSString stringWithFormat: @"%@/%@", OCSPath, folderName]];
      
      if (![folder create])
        [subFolders setObject: folder forKey: folderName];
    }
    else if (folderType == SOGoCollectedFolder)
    {
      ud = [[context activeUser] userDefaults];
      if ([ud mailAddOutgoingAddresses]) {
        folderName = @"collected";
        folder = [subFolderClass objectWithName: folderName inContainer: self];
        [folder setDisplayName: [self collectedFolderName]];
        [folder setOCSPath: [NSString stringWithFormat: @"%@/%@", OCSPath, folderName]];
        
        if (![folder create])
          [subFolders setObject: folder forKey: folderName];
        
        [ud setSelectedAddressBook:folderName];
      }
    }
  }
}

- (NSException *) fetchSpecialFolders: (NSString *) sql
                          withChannel: (EOAdaptorChannel *) fc
                        andFolderType: (SOGoFolderType) folderType
{
  NSArray *attrs;
  NSDictionary *row;
  SOGoGCSFolder *folder;
  NSString *key;
  NSException *error;
  SOGoUserDefaults *ud;
  ud = [[context activeUser] userDefaults];

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  error = [fc evaluateExpressionX: sql];
  if (!error)
  {
    attrs = [fc describeResults: NO];
    while ((row = [fc fetchAttributes: attrs withZone: NULL]))
    {
      key = [row objectForKey: @"c_path4"];
            
      if ([key isKindOfClass: [NSString class]])
      {
        folder = [subFolderClass objectWithName: key inContainer: self];
          [folder setOCSPath: [NSString stringWithFormat: @"%@/%@", OCSPath, key]];
        
        if (folder)
        [subFolders setObject: folder forKey: key];
      }
    }
    if (folderType == SOGoPersonalFolder)
    {
      if (![subFolders objectForKey: @"personal"])
        [self createSpecialFolder: SOGoPersonalFolder];
    }
    else if (folderType == SOGoCollectedFolder)
    {
      if (![subFolders objectForKey: @"collected"])
        if ([[ud selectedAddressBook] isEqualToString:@"collected"])
          [self createSpecialFolder: SOGoCollectedFolder];
    }
  }
  return error;
}

- (NSException *) appendPersonalSources
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql, *gcsFolderType;
  NSException *error;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if ([fc isOpen])
  {
    gcsFolderType = [[self class] gcsFolderType];
    
    sql = [NSString stringWithFormat: (@"SELECT c_path4 FROM %@"
                                       @" WHERE c_path2 = '%@'"
                                       @" AND c_folder_type = '%@'"),
          [folderLocation gcsTableName], owner, gcsFolderType];
    
    error = [self fetchSpecialFolders: sql withChannel: fc andFolderType: SOGoPersonalFolder];
    
    [cm releaseChannel: fc];
  }
  else
    error = [NSException exceptionWithName: @"SOGoDBException"
			 reason: @"database connection could not be open"
			 userInfo: nil];

  return error;
}


- (NSException *) appendSystemSources
{
  return nil;
}

- (BOOL) _appendSubscribedSource: (NSString *) sourceKey
{
  SOGoGCSFolder *subscribedFolder;

  subscribedFolder
    = [subFolderClass folderWithSubscriptionReference: sourceKey
		      inContainer: self];

  // We check with -ocsFolderForPath if the folder also exists in the database.
  // This is important because user A could delete folder X, and user B has subscribed to it.
  // If the "default roles" are enabled for calendars/address books, -validatePersmission:.. will
  // work (grabbing the default role) and the deleted resource will be incorrectly returned.
  if (subscribedFolder
      && [subscribedFolder ocsFolderForPath: [subscribedFolder ocsPath]]
      && ![sm validatePermission: SOGoPerm_AccessObject
			onObject: subscribedFolder
		       inContext: context])
    {
      [subscribedSubFolders setObject: subscribedFolder
			       forKey: [subscribedFolder nameInContainer]];
      return YES;
    }
  
  return NO;
}

- (NSException *) appendSubscribedSources
{
  BOOL dirty, safeCheck, isConnected;
  NSEnumerator *sources;
  NSException *error;
  NSMutableArray *subscribedReferences;
  NSMutableDictionary *folderDisplayNames;
  NSObject <SOGoSource> *currentSource;
  NSString *activeUser, *domain, *currentKey;
  SOGoUser *ownerUser;
  SOGoUserSettings *settings;
  id o;
  int i;

  if (!subscribedSubFolders)
    subscribedSubFolders = [NSMutableDictionary new];

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  error = nil; /* we ignore non-DB errors at this time... */
  dirty = NO;
  safeCheck = NO;
  isConnected = YES;

  activeUser = [[context activeUser] login];
  domain = [[context activeUser] domain];
  ownerUser = [SOGoUser userWithLogin: owner];
  settings = [ownerUser userSettings];

  subscribedReferences = [NSMutableArray arrayWithArray: [[settings objectForKey: nameInContainer]
							   objectForKey: @"SubscribedFolders"]];
  o =  [[settings objectForKey: nameInContainer] objectForKey: @"FolderDisplayNames"];
  if (o)
    folderDisplayNames = [NSMutableDictionary dictionaryWithDictionary: o];
  else
    folderDisplayNames = nil;

  for (i = [subscribedReferences count] - 1; i >= 0; i--)
    {
      currentKey = [subscribedReferences objectAtIndex: i];
      if (![self _appendSubscribedSource: currentKey])
	{
	  // We no longer have access to this subscription, let's
	  // remove it from the current list.
	  [subscribedReferences removeObject: currentKey];
	  [folderDisplayNames removeObjectForKey: currentKey];
          if ([owner isEqualToString: activeUser])
            {
              // Safe check -- don't remove the subscription if any of the users sources has a connection failure.
              if (!safeCheck)
                {
                  safeCheck = YES;
                  sources = [[[SOGoUserManager sharedUserManager] sourcesInDomain: domain] objectEnumerator];
                  while (isConnected && (currentSource = [sources nextObject]))
                    {
                      isConnected = isConnected && [currentSource isConnected];
                    }
                }
              if (isConnected)
                // Synchronize settings only if the subscription is owned by the active user
                dirty = YES;
            }
	}
    }
  
  // If we changed the folder subscribtion list, we must sync it
  if (dirty)
    {
      if (subscribedReferences)
        [[settings objectForKey: nameInContainer] setObject: subscribedReferences
                                                     forKey: @"SubscribedFolders"];
      if (folderDisplayNames)
        [[settings objectForKey: nameInContainer] setObject: folderDisplayNames
                                                     forKey: @"FolderDisplayNames"];
      [settings synchronize];
    }
	    
  return error;
}

- (NSException *) newFolderWithName: (NSString *) name
		 andNameInContainer: (NSString *) newNameInContainer
{
  SOGoGCSFolder *newFolder;
  NSException *error;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  newFolder = [subFolderClass objectWithName: newNameInContainer
			      inContainer: self];
  if ([newFolder isKindOfClass: [NSException class]])
    error = (NSException *) newFolder;
  else
    {
      [newFolder setDisplayName: name];
      [newFolder setOCSPath: [NSString stringWithFormat: @"%@/%@",
                                       OCSPath, newNameInContainer]];
      error = [newFolder create];
      if (!error)
	{
	  [subFolders setObject: newFolder forKey: newNameInContainer];
	  error = nil;
	}
      else if ([[error name] isEqual: @"GCSExitingFolder"])
        {
          error = [self exceptionWithHTTPStatus: 405
                                         reason: [error reason]];
        }
      else
        {
          [self errorWithFormat: @"An error occured when creating a folder: %@ - %@", [error name], [error reason]];
          error = [self exceptionWithHTTPStatus: 400
                                         reason: @"The new folder could not be created"];
        }
    }

  return error;
}

- (NSException *) newFolderWithName: (NSString *) name
		    nameInContainer: (NSString **) newNameInContainer
{
  NSString *newFolderID;
  NSException *error;

  newFolderID = *newNameInContainer;
  
  if (!newFolderID)
    newFolderID = [self globallyUniqueObjectId];
  
  error = [self newFolderWithName: name
		andNameInContainer: newFolderID];
  if (error)
    *newNameInContainer = nil;
  else
    *newNameInContainer = newFolderID;

  return error;
}

- (NSException *) initSubFolders
{
  NSException *error;

  if (!subFolders)
    {
      subFolders = [NSMutableDictionary new];
      error = [self appendPersonalSources];
      if (!error)
        if ([self respondsToSelector:@selector(appendCollectedSources)])
          error = [self performSelector:@selector(appendCollectedSources)];
      if (!error)
        error = [self appendSystemSources]; // TODO : Not really a testcase, see function
      if (error)
      {
        [subFolders release];
        subFolders = nil;
      }
    }
  else
    error = nil;

  return error;
}

- (void) removeSubFolder: (NSString *) subfolderName
{
  [subFolders removeObjectForKey: subfolderName];
}

- (NSException *) initSubscribedSubFolders
{
  NSException *error;
  SOGoUser *currentUser;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  error = nil; /* we ignore non-DB errors at this time... */
  currentUser = [context activeUser];
  if (!subscribedSubFolders
      && ([[currentUser login] isEqualToString: owner]
          || [currentUser isSuperUser]))
    {
      subscribedSubFolders = [NSMutableDictionary new];
      error = [self appendSubscribedSources];
    }

  return error;
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id obj;
  NSException *error;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: name inContext: lookupContext acquire: NO];
  if (!obj)
    {
      obj = [self lookupPersonalFolder: name
                        ignoringRights: NO];
      if (!obj)
	{
	  // Lookup in subscribed folders
	  error = [self initSubscribedSubFolders];
	  if (error)
	    {
	      [self errorWithFormat: @"a database error occured: %@", [error reason]];
	      obj = [self exceptionWithHTTPStatus: 503];
	    }
	  else
	    obj = [subscribedSubFolders objectForKey: name];
	}
    }
  
  return obj;
}

- (id) lookupPersonalFolder: (NSString *) name
             ignoringRights: (BOOL) ignoreRights
{
  NSException *error;
  id obj;

  error = [self initSubFolders];
  if (error)
    {
      [self errorWithFormat: @"a database error occured: %@", [error reason]];
      obj = [self exceptionWithHTTPStatus: 503];
    }
  else
    {
      obj = [subFolders objectForKey: name];
      if (obj && !ignoreRights && ![self ignoreRights]
          && [sm validatePermission: SOGoPerm_AccessObject
                           onObject: obj
                          inContext: context])
        obj = nil;
    }

  return obj;
}

- (NSArray *) subFolders
{
  NSMutableArray *ma;
  NSException *error;
  NSString *requestMethod;
  BOOL isPropfind;

  requestMethod = [[context request] method];
  isPropfind = [requestMethod isEqualToString: @"PROPFIND"];

  error = [self initSubFolders];
  if(error)
  {
    [self errorWithFormat: @"a database error occured when inititializing the subFolders: %@", [error reason]];
    if(isPropfind)
    {
      /* We exceptionnally raise the exception here because doPROPFIND: will
	 not care for errors in its response from toManyRelationShipKeys,
	 which may in turn trigger the disappearance of user folders in the
	 SOGo extensions. */
      [error raise];
    }
  }

  error = [self initSubscribedSubFolders];
  if (error)
  {
    [self errorWithFormat: @"a database error occured when subscribing to subfolders: %@", [error reason]];
    if(isPropfind)
      [error raise];
  }
    

  ma = [NSMutableArray arrayWithArray: [subFolders allValues]];
  if ([subscribedSubFolders count])
    [ma addObjectsFromArray: [subscribedSubFolders allValues]];

  return [ma sortedArrayUsingSelector: @selector (compare:)];
}

- (BOOL) hasLocalSubFolderNamed: (NSString *) name
{
  NSArray *subs;
  NSString *currentDisplayName;
  int i, count;
  BOOL rc;

  rc = NO;

#warning check error here
  [self initSubFolders];

  subs = [subFolders allValues];
  count = [subs count];
  for (i = 0; !rc && i < count; i++)
    {
      currentDisplayName = [[subs objectAtIndex: i] displayName];
      rc = [name isEqualToString: currentDisplayName];
    }

  return rc;
}

- (NSArray *) toManyRelationshipKeys
{
  NSEnumerator *sortedSubFolders;
  NSMutableArray *keys;
  SOGoGCSFolder *currentFolder;
  BOOL ignoreRights;

  ignoreRights = [self ignoreRights];

  keys = [NSMutableArray array];
  sortedSubFolders = [[self subFolders] objectEnumerator];
  while ((currentFolder = [sortedSubFolders nextObject]))
    {
      if (ignoreRights
          || ![sm validatePermission: SOGoPerm_AccessObject
                            onObject: currentFolder
                           inContext: context])
        [keys addObject: [currentFolder nameInContainer]];
    }

  return keys;
}

- (NSException *) davCreateCollection: (NSString *) pathInfo
			    inContext: (WOContext *) localContext
{  
  id <DOMDocument> document;
  //
  // We check if we got a MKCOL with the addressbook resource on the
  // calendar-homeset collection (/Calendar). If so, we abort the
  // operation and return the proper error code.
  //
  // See http://tools.ietf.org/html/rfc5689 for all details.
  //
  document = [[localContext request] contentAsDOMDocument];
  
  // If a payload was specified, lets get it in order to see
  // if we must accept or reject the MKCOL operation. If we 
  // don't have any payload (what SOGo Connector / Integrators
  // sends right now), we proceed as before.
  if (document)
    {
      NSMutableArray *supportedTypes;
      id <DOMNodeList> children;
      id <DOMElement> element;
      NSException *error;
      NSArray *allTypes;
      id o;

      BOOL supported;
      int i;

      error = [self initSubFolders];
      supported = YES;

      if (error)
	{
	  [self errorWithFormat: @"a database error occured: %@", [error reason]];
	  return [NSException exceptionWithDAVStatus: 503];
	}
      
      // We assume "personal" exists. In fact, if it doesn't, something
      // is seriously broken.
      allTypes = [[subFolders objectForKey: @"personal"] davResourceType];
      supportedTypes = [NSMutableArray array];
      
      for (i = 0; i < [allTypes count]; i++)
	{
	  o = [allTypes objectAtIndex: i];
	  if ([o isKindOfClass: [NSArray class]])
	    o = [o objectAtIndex: 0];
	  
	  [supportedTypes addObject: o];
	}
      
      children = [[(NSArray *)[[document documentElement] getElementsByTagName: @"resourcetype"]
			      lastObject] childNodes];
      
      // We check if all the provided types are supported.
      // In case one of them is not, we reject the operation.
      for (i = 0; i < [children length]; i++)
	{
	  element = [children objectAtIndex: i];
	  
	  if ([element nodeType] == DOM_ELEMENT_NODE &&
	      ![supportedTypes containsObject: [element nodeName]])
	    supported = NO;
	}
      
      if (!supported)
	{
	  return [NSException exceptionWithDAVStatus: 403];
	}
    }

  return [self newFolderWithName: pathInfo
	       andNameInContainer: pathInfo];
}

@end
