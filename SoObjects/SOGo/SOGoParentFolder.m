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

#import <NGObjWeb/NSException+HTTP.h>
#import <GDLContentStore/GCSChannelManager.h>
#import <GDLContentStore/GCSFolderManager.h>
#import <GDLContentStore/NSURL+GCS.h>
#import <GDLAccess/EOAdaptorChannel.h>

#import "SOGoFolder.h"

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

- (void) _fetchPersonalFolders: (NSString *) sql
		   withChannel: (EOAdaptorChannel *) fc
{
  NSArray *attrs;
  NSDictionary *row;
  SOGoFolder *folder;
  BOOL hasPersonal;
  NSString *key, *path;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  hasPersonal = NO;
  [fc evaluateExpressionX: sql];
  attrs = [fc describeResults: NO];
  row = [fc fetchAttributes: attrs withZone: NULL];
  while (row)
    {
      folder
	= [subFolderClass folderWithName: [row objectForKey: @"c_path4"]
			  andDisplayName: [row objectForKey: @"c_foldername"]
			  inContainer: self];
      key = [row objectForKey: @"c_path4"];
      hasPersonal = (hasPersonal || [key isEqualToString: @"personal"]);
      [folder setOCSPath: [NSString stringWithFormat: @"%@/%@",
				    OCSPath, key]];
      [subFolders setObject: folder forKey: key];
      row = [fc fetchAttributes: attrs withZone: NULL];
    }

  if (!hasPersonal)
    {
      folder = [subFolderClass folderWithName: @"personal"
			       andDisplayName: @"personal"
			       inContainer: self];
      path = [NSString stringWithFormat: @"/Users/%@/%@/personal",
		       [self ownerInContext: context],
		       nameInContainer];
      [folder setOCSPath: path];
      [subFolders setObject: folder forKey: @"personal"];
    }
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
	= [NSString stringWithFormat: (@"SELECT c_path4, c_foldername FROM %@"
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

- (NSException *) newFolderWithName: (NSString *) name
{
  SOGoFolder *newFolder;
  NSException *error;

  if (!subFolderClass)
    subFolderClass = [[self class] subFolderClass];

  newFolder = [subFolderClass folderWithName: name
			      andDisplayName: name
			      inContainer: self];
  if ([newFolder isKindOfClass: [NSException class]])
    error = (NSException *) newFolder;
  else
    {
      [newFolder setOCSPath: [NSString stringWithFormat: @"%@/%@",
                                       OCSPath, name]];
      if ([newFolder create])
	error = nil;
      else
        error = [NSException exceptionWithHTTPStatus: 400
			     reason: @"The new folder could not be created"];
    }

  return error;
}

- (void) initSubFolders
{
  if (!subFolders)
    {
      subFolders = [NSMutableDictionary new];
      [self appendPersonalSources];
      [self appendSystemSources];
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

  return [subFolders allValues];
}

/* acls */
- (NSArray *) aclsForUser: (NSString *) uid
{
  return nil;
}

- (BOOL) davIsCollection
{
  return YES;
}

- (NSString *) davContentType
{
  return @"httpd/unix-directory";
}

@end
