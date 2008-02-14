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

#include "GCSFolderType.h"
#include "GCSFolder.h"
#include "GCSFieldInfo.h"
#include "GCSFieldExtractor.h"
#include "common.h"
#include <EOControl/EOKeyValueCoding.h>
#include <NGExtensions/NGResourceLocator.h>

@implementation GCSFolderType

- (id)initWithPropertyList:(id)_plist {
  if ((self = [super init])) {
    NSDictionary *plist = _plist;
    
    self->blobTablePattern  = [[plist objectForKey:@"blobTablePattern"] copy];
    self->quickTablePattern = [[plist objectForKey:@"quickTablePattern"]copy];
    
    self->extractorClassName = 
      [[plist objectForKey:@"extractorClassName"] copy];
    // TODO: qualifier;
    
    self->fields = [[GCSFieldInfo fieldsForPropertyList:
				    [plist objectForKey:@"fields"]] retain];
  }
  return self;
}

- (id)initWithContentsOfFile:(NSString *)_path {
  NSDictionary *plist;
  
  plist = [NSDictionary dictionaryWithContentsOfFile:_path];
  if (plist == nil) {
    NSLog(@"ERROR(%s): could not read dictionary at path %@", 
	  __PRETTY_FUNCTION__, _path);
    [self release];
    return nil;
  }
  return [self initWithPropertyList:plist];
}

+ (NGResourceLocator *)resourceLocator {
  NGResourceLocator *loc;
  
  // TODO: fix me, GCS instead of OCS
  loc = [NGResourceLocator resourceLocatorForGNUstepPath:
			     @"OCSTypeModels"
                           fhsPath:@"share/ocs"];
  return loc;
}

+ (id)folderTypeWithName:(NSString *)_typeName {
  NSString *filename, *path;

  // TODO: fix me, GCS instead of OCS
  filename = [_typeName stringByAppendingPathExtension:@"ocs"];
  path     = [[self resourceLocator] lookupFileWithName:filename];
  
  if (path != nil)
    return [[self alloc] initWithContentsOfFile:path];

  NSLog(@"ERROR(%s): did not find model for type: '%@'", 
	__PRETTY_FUNCTION__, _typeName);
  return nil;
}

- (id)initWithFolderTypeName:(NSString *)_typeName {
  // DEPRECATED
  [self release];
  return [[GCSFolderType folderTypeWithName:_typeName] retain];
}

- (void)dealloc {
  [self->extractor          release];
  [self->extractorClassName release];
  [self->blobTablePattern   release];
  [self->quickTablePattern  release];
  [self->fields             release];
  [self->fieldDict          release];
  [self->folderQualifier    release];
  [super dealloc];
}

/* operations */

- (NSString *)blobTableNameForFolder:(GCSFolder *)_folder {
  return [self->blobTablePattern 
	      stringByReplacingVariablesWithBindings:_folder];
}
- (NSString *)quickTableNameForFolder:(GCSFolder *)_folder {
  return [self->quickTablePattern
	      stringByReplacingVariablesWithBindings:_folder];
}

- (EOQualifier *)qualifierForFolder:(GCSFolder *)_folder {
  NSArray      *keys;
  NSDictionary *bindings;
  
  keys = [[self->folderQualifier allQualifierKeys] allObjects];
  if ([keys count] == 0)
    return self->folderQualifier;

  bindings = [_folder valuesForKeys:keys];
  return [self->folderQualifier qualifierWithBindings:bindings
	                        requiresAllVariables:NO];
}

/* generating SQL */

- (NSString *)sqlQuickCreateWithTableName:(NSString *)_tabName {
  NSMutableString *sql;
  unsigned i, count;
  
  sql = [NSMutableString stringWithCapacity:512];
  [sql appendString:@"CREATE TABLE "];
  [sql appendString:_tabName];
  [sql appendString:@" (\n"];

  count = [self->fields count];
  for (i = 0; i < count; i++) {
    if (i > 0) [sql appendString:@",\n"];
    
    [sql appendString:@"  "];
    [sql appendString:[[self->fields objectAtIndex:i] sqlCreateSection]];
  }
  
  [sql appendString:@"\n)"];
  
  return sql;
}

/* quick support */

- (GCSFieldExtractor *)quickExtractor {
  Class clazz;
  
  if (self->extractor != nil) {
    return [self->extractor isNotNull]
      ? self->extractor : (GCSFieldExtractor *)nil;
  }

  clazz = self->extractorClassName
    ? NSClassFromString(self->extractorClassName)
    : [GCSFieldExtractor class];
  if (clazz == Nil) {
    [self logWithFormat:@"ERROR: did not find field extractor class!"];
    return nil;
  }
  
  if ((self->extractor = [[clazz alloc] init]) == nil) {
    [self logWithFormat:@"ERROR: could not create field extractor of class %@",
	    clazz];
    return nil;
  }
  return self->extractor;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  [ms appendFormat:@" blobtable='%@'",  self->blobTablePattern];
  [ms appendFormat:@" quicktable='%@'", self->quickTablePattern];
  [ms appendFormat:@" fields=%@",       self->fields];
  [ms appendFormat:@" extractor=%@",    self->extractorClassName];
  
  if (self->folderQualifier)
    [ms appendFormat:@" qualifier=%@", self->folderQualifier];
  
  [ms appendString:@">"];
  return ms;
}

@end /* GCSFolderType */
