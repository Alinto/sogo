/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of SOGo.

  SOGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOGo; see the file COPYING. If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGExtensions/NSString+misc.h>

#import <EOControl/EOQualifier.h>

#import <EOControl/EOKeyValueCoding.h>
#import <NGExtensions/NGResourceLocator.h>

#import "GCSFolderType.h"
#import "GCSFolder.h"
#import "GCSFieldInfo.h"

@implementation GCSFolderType

+ (id) folderTypeWithName: (NSString *) _typeName
{
  NSString *filename, *path;
  GCSFolderType *folderType;

  // TODO: fix me, GCS instead of OCS
  filename = [_typeName stringByAppendingPathExtension:@"ocs"];
  path = [[self resourceLocator] lookupFileWithName: filename];
 
  if (path)
    {
      folderType = [[self alloc] initWithContentsOfFile: path];
      [folderType autorelease];
    }
  else
    {
      folderType = nil;
      NSLog(@"ERROR(%s): did not find model for type: '%@'", 
	    __PRETTY_FUNCTION__, _typeName);
    }

  return folderType;
}

- (id) initWithPropertyList: (id) _plist
{
  NSDictionary *plist = _plist;
 
  if ((self = [super init]))
    {
      blobTablePattern = [[plist objectForKey:@"blobTablePattern"] copy];
      quickTablePattern = [[plist objectForKey:@"quickTablePattern"] copy];
 
      extractorClassName = 
	[[plist objectForKey: @"extractorClassName"] copy];
      // TODO: qualifier;
 
      fields = [[GCSFieldInfo fieldsForPropertyList:
				[plist objectForKey:@"fields"]] retain];
      quickFields = [[GCSFieldInfo fieldsForPropertyList:
                                     [plist objectForKey:@"quickFields"]] retain];
    }

  return self;
}

- (id) initWithContentsOfFile: (NSString *) _path
{
  NSDictionary *plist;
 
  plist = [NSDictionary dictionaryWithContentsOfFile: _path];
  if (plist)
    [self initWithPropertyList: plist];
  else
    {
      NSLog(@"ERROR(%s): could not read dictionary at path %@", 
	    __PRETTY_FUNCTION__, _path);
      [self release];
      self = nil;
    }

  return self;
}

+ (NGResourceLocator *) resourceLocator
{
  NGResourceLocator *loc;
 
  // TODO: fix me, GCS instead of OCS
  loc = [NGResourceLocator resourceLocatorForGNUstepPath:
			     @"OCSTypeModels"
			   fhsPath:@"share/ocs"];
  return loc;
}

- (void) dealloc
{
  [extractorClassName release];
  [blobTablePattern release];
  [quickTablePattern release];
  [fields release];
  [quickFields release];
  [folderQualifier release];
  [super dealloc];
}

/* operations */

- (NSString *) blobTableNameForFolder: (GCSFolder *) _folder
{
  return [blobTablePattern 
	   stringByReplacingVariablesWithBindings:_folder];
}

- (NSString *) quickTableNameForFolder: (GCSFolder *) _folder
{
  return [quickTablePattern
	   stringByReplacingVariablesWithBindings:_folder];
}

- (EOQualifier *) qualifierForFolder: (GCSFolder *) _folder
{
  NSArray *keys;
  NSDictionary *bindings;
 
  keys = [[folderQualifier allQualifierKeys] allObjects];
  if ([keys count] == 0)
    return folderQualifier;

  bindings = [_folder dictionaryWithValuesForKeys:keys];
  return [folderQualifier qualifierWithBindings:bindings
			  requiresAllVariables:NO];
}

/* generating SQL */

- (NSString *) sqlQuickCreateWithTableName: (NSString *) _tabName
{
  NSMutableString *sql;
  unsigned i, count;
 
  sql = [NSMutableString stringWithFormat: @"CREATE TABLE %@ (", _tabName];
  count = [quickFields count];
  for (i = 0; i < count; i++)
    {
      if (i > 0) [sql appendString:@", "];
      [sql appendFormat: @" %@", [[quickFields objectAtIndex:i] sqlCreateSection]];
    }
  [sql appendString:@"\n)"];
 
  return sql;
}

- (NSArray *) quickFields
{
  return quickFields;
}

- (NSArray *) fields
{
  return fields;
}

/* description */

- (NSString *) description
{
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  [ms appendFormat:@" blobtable='%@'", blobTablePattern];
  [ms appendFormat:@" quicktable='%@'", quickTablePattern];
  [ms appendFormat:@" fields=%@", fields];
  [ms appendFormat:@" quickFields=%@", fields];
  [ms appendFormat:@" extractor=%@", extractorClassName];
 
  if (folderQualifier)
    [ms appendFormat:@" qualifier=%@", folderQualifier];
 
  [ms appendString:@">"];
  return ms;
}

@end /* GCSFolderType */
