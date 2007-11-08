/* SOGoParentFolder.m - this file is part of SOGo
 *
 * Copyright (C) 2006, 2007 Inverse groupe conseil
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
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

#import <NGObjWeb/NSException+HTTP.h>
#import <NGObjWeb/WOContext+SoObjects.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import "SOGoGCSFolder.h"
#import "SOGoPermissions.h"
#import "SOGoUser.h"

#import "SOGoParentFolder.h"

@implementation SOGoParentFolder

- (id) init
{
  if ((self = [super init]))
    {
      subFolders = nil;
      OCSPath = nil;
      subFolderClass = Nil;
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

- (void) _fetchPersonalFolders: (NSString *) sql
		   withChannel: (EOAdaptorChannel *) fc
{
  NSArray *attrs;
  NSDictionary *row;
  BOOL hasPersonal;
  SOGoGCSFolder *folder;
  NSString *key;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  hasPersonal = NO;
  [fc evaluateExpressionX: sql];
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

- (void) appendPersonalSources
{
  GCSChannelManager *cm;
  EOAdaptorChannel *fc;
  NSURL *folderLocation;
  NSString *sql, *gcsFolderType;

  cm = [GCSChannelManager defaultChannelManager];
  folderLocation
    = [[GCSFolderManager defaultFolderManager] folderInfoLocation];
  fc = [cm acquireOpenChannelForURL: folderLocation];
  if (fc)
    {
      gcsFolderType = [[self class] gcsFolderType];
      
      sql
	= [NSString stringWithFormat: (@"SELECT c_path4 FROM %@"
				       @" WHERE c_path2 = '%@'"
				       @" AND c_folder_type = '%@'"),
		    [folderLocation gcsTableName],
		    [self ownerInContext: context],
		    gcsFolderType];
      [self _fetchPersonalFolders: sql withChannel: fc];
      [cm releaseChannel: fc];
//       sql = [sql stringByAppendingFormat:@" WHERE %@ = '%@'", 
//                  uidColumnName, [self uid]];
    }
}

- (void) appendSystemSources
{
}

- (void) appendSubscribedSources
{
  NSArray *subscribedReferences;
  NSUserDefaults *settings;
  NSEnumerator *allKeys;
  NSString *currentKey;
  SOGoGCSFolder *subscribedFolder;

  settings = [[context activeUser] userSettings];
  subscribedReferences = [[settings objectForKey: nameInContainer]
			   objectForKey: @"SubscribedFolders"];
  if ([subscribedReferences isKindOfClass: [NSArray class]])
    {
      allKeys = [subscribedReferences objectEnumerator];
      currentKey = [allKeys nextObject];
      while (currentKey)
	{
	  subscribedFolder
	    = [subFolderClass folderWithSubscriptionReference: currentKey
			      inContainer: self];
	  [subFolders setObject: subscribedFolder
		      forKey: [subscribedFolder nameInContainer]];
	  currentKey = [allKeys nextObject];
	}
    }
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

- (void) initSubFolders
{
  NSString *login;

  if (!subFolders)
    {
      subFolders = [NSMutableDictionary new];
      [self appendPersonalSources];
      [self appendSystemSources];
      login = [[context activeUser] login];
      if ([login isEqualToString: owner])
	[self appendSubscribedSources];
    }
}

- (id) lookupName: (NSString *) name
        inContext: (WOContext *) lookupContext
          acquire: (BOOL) acquire
{
  id obj;

  /* first check attributes directly bound to the application */
  obj = [super lookupName: name inContext: lookupContext acquire: NO];
  if (!obj)
    {
      if (!subFolders)
        [self initSubFolders];

      obj = [subFolders objectForKey: name];
    }

  return obj;
}

- (NSArray *) toManyRelationshipKeys
{
  if (!subFolders)
    [self initSubFolders];

  return [subFolders allKeys];
}

- (NSArray *) subFolders
{
  if (!subFolders)
    [self initSubFolders];

  return [[subFolders allValues]
	   sortedArrayUsingSelector: @selector (compare:)];
}

@end
