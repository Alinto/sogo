/* SOGoParentFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006-2009 Inverse inc.
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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/SoSecurityManager.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <NGExtensions/NSObject+Logs.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>
#import <SaxObjC/XMLNamespaces.h>

#import "NSObject+DAV.h"
#import "SOGoGCSFolder.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"
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
      subFolderClass = Nil;
//       hasSubscribedSources = NO;
    }

  return self;
}

- (void) dealloc
{
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

- (void) _createPersonalFolder
{
  NSArray *roles;
  SOGoGCSFolder *folder;

  roles = [[context activeUser] rolesForObject: self inContext: context];
  if ([roles containsObject: SoRole_Owner])
    {
      folder = [subFolderClass objectWithName: @"personal" inContainer: self];
      [folder setDisplayName: [self defaultFolderName]];
      [folder
	setOCSPath: [NSString stringWithFormat: @"%@/personal", OCSPath]];
      if ([folder create])
	[subFolders setObject: folder forKey: @"personal"];
    }
}

- (NSException *) _fetchPersonalFolders: (NSString *) sql
			    withChannel: (EOAdaptorChannel *) fc
{
  NSArray *attrs;
  NSDictionary *row;
  BOOL hasPersonal;
  SOGoGCSFolder *folder;
  NSString *key;
  NSException *error;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  hasPersonal = NO;
  error = [fc evaluateExpressionX: sql];
  if (!error)
    {
      attrs = [fc describeResults: NO];
      row = [fc fetchAttributes: attrs withZone: NULL];
      while (row)
	{
	  key = [row objectForKey: @"c_path4"];
	  if ([key isKindOfClass: [NSString class]])
	    {
	      folder = [subFolderClass objectWithName: key inContainer: self];
	      hasPersonal = (hasPersonal || [key isEqualToString: @"personal"]);
	      [folder setOCSPath: [NSString stringWithFormat: @"%@/%@",
					    OCSPath, key]];
	      [subFolders setObject: folder forKey: key];
	    }
	  row = [fc fetchAttributes: attrs withZone: NULL];
	}

      if (!hasPersonal)
	[self _createPersonalFolder];
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
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if ([fc isOpen])
    {
      gcsFolderType = [[self class] gcsFolderType];
      
      sql
	= [NSString stringWithFormat: (@"SELECT c_path4 FROM %@"
				       @" WHERE c_path2 = '%@'"
				       @" AND c_folder_type = '%@'"),
		    [folderLocation gcsTableName],
		    [self ownerInContext: context],
		    gcsFolderType];
      error = [self _fetchPersonalFolders: sql withChannel: fc];
      [cm releaseChannel: fc];
//       sql = [sql stringByAppendingFormat:@" WHERE %@ = '%@'", 
//                  uidColumnName, [self uid]];
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

- (void) _appendSubscribedSource: (NSString *) sourceKey
{
  SOGoGCSFolder *subscribedFolder;

  subscribedFolder
    = [subFolderClass folderWithSubscriptionReference: sourceKey
		      inContainer: self];
  if (subscribedFolder
      && ![sm validatePermission: SOGoPerm_AccessObject
			onObject: subscribedFolder
		       inContext: context])
    [subscribedSubFolders setObject: subscribedFolder
			     forKey: [subscribedFolder nameInContainer]];
}

- (NSException *) appendSubscribedSources
{
  NSArray *subscribedReferences;
  NSUserDefaults *settings;
  NSEnumerator *allKeys;
  NSString *currentKey;
  NSException *error;

  error = nil; /* we ignore non-DB errors at this time... */

  settings = [[context activeUser] userSettings];
  subscribedReferences = [[settings objectForKey: nameInContainer]
			   objectForKey: @"SubscribedFolders"];
  if ([subscribedReferences isKindOfClass: [NSArray class]])
    {
      allKeys = [subscribedReferences objectEnumerator];
      while ((currentKey = [allKeys nextObject]))
	[self _appendSubscribedSource: currentKey];
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
      if ([newFolder create])
	{
	  [subFolders setObject: newFolder forKey: newNameInContainer];
	  error = nil;
	}
      else
        error = [NSException exceptionWithHTTPStatus: 400
			     reason: @"The new folder could not be created"];
    }

  return error;
}

- (NSException *) newFolderWithName: (NSString *) name
		    nameInContainer: (NSString **) newNameInContainer
{
  NSString *newFolderID;
  NSException *error;

  newFolderID = [self globallyUniqueObjectId];
  error = [self newFolderWithName: name
		andNameInContainer: newFolderID];
  if (error)
    *newNameInContainer = nil;
  else
    *newNameInContainer = newFolderID;

  return error;
}

- (NSException *) initSubFolders;
{
  NSException *error;

  if (!subFolders)
    {
      subFolders = [NSMutableDictionary new];
      error = [self appendPersonalSources];
      if (!error)
	error = [self appendSystemSources];
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

- (NSException *) initSubscribedSubFolders
{
  NSArray *subscribedReferences;
  NSUserDefaults *settings;
  NSEnumerator *allKeys;
  NSString *currentKey, *login;
  NSException *error;

  error = nil; /* we ignore non-DB errors at this time... */
  login = [[context activeUser] login];

  if (!subscribedSubFolders && [login isEqualToString: owner])
    {
      subscribedSubFolders = [NSMutableDictionary new];
      settings = [[context activeUser] userSettings];
      subscribedReferences = [[settings objectForKey: nameInContainer]
			       objectForKey: @"SubscribedFolders"];
      if ([subscribedReferences isKindOfClass: [NSArray class]])
	{
	  allKeys = [subscribedReferences objectEnumerator];
	  while ((currentKey = [allKeys nextObject]))
	    [self _appendSubscribedSource: currentKey];
	}
    }
  
  return error;
}

- (NSArray *) fetchContentObjectNames
{
  return nil;
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
      // Lookup in personal folders
      error = [self initSubFolders];
      if (error)
	{
	  [self errorWithFormat: @"a database error occured: %@", [error reason]];
	  obj = [NSException exceptionWithHTTPStatus: 503];
	}
      else
	obj = [subFolders objectForKey: name];
      
      if (!obj)
	{
	  // Lookup in subscribed folders
	  error = [self initSubscribedSubFolders];
	  if (error)
	    {
	      [self errorWithFormat: @"a database error occured: %@", [error reason]];
	      obj = [NSException exceptionWithHTTPStatus: 503];
	    }
	  else
	    obj = [subscribedSubFolders objectForKey: name];
	}
    }
  
  return obj;
}

- (NSArray *) subFolders
{
  NSMutableArray *ma;
  NSException *error;

  error = [self initSubFolders];
  if (error)
    {
      /* We exceptionnally raise the exception here because doPROPFIND:
	 will not care for errors in its response from
	 toManyRelationShipKeys, which may in turn trigger the
	 disappearance of user folders in the SOGo extensions. */
      [error raise];
    }
  
  error = [self initSubscribedSubFolders];
  if (error)
    [error raise];

  ma = [NSMutableArray arrayWithArray: [subFolders allValues]];
  if ([subscribedSubFolders count])
    [ma addObjectsFromArray: [subscribedSubFolders allValues]];

  return [ma sortedArrayUsingSelector: @selector (compare:)];
}

- (BOOL) hasLocalSubFolderNamed: (NSString *) name
{
  NSArray *subs;
  NSException *error;
  int i, count;
  BOOL rc = NO;

  error = [self initSubFolders];
  if (error)
    [error raise];
    
  subs = [subFolders allValues];
  count = [subs count];

  for (i = 0; i < count; i++)
    if ([name isEqualToString: [[subs objectAtIndex: i] displayName]])
      rc = YES;

  return rc;
}

- (NSArray *) toManyRelationshipKeys
{
  NSEnumerator *sortedSubFolders;
  NSMutableArray *keys;
  SOGoGCSFolder *currentFolder;

  keys = [NSMutableArray array];
  sortedSubFolders = [[self subFolders] objectEnumerator];
  while ((currentFolder = [sortedSubFolders nextObject]))
    [keys addObject: [currentFolder nameInContainer]];

  return keys;
}

- (NSException *) davCreateCollection: (NSString *) pathInfo
			    inContext: (WOContext *) localContext
{
  return [self newFolderWithName: pathInfo
	       andNameInContainer: pathInfo];
}

@end
