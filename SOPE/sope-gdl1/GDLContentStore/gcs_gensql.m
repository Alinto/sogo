/*
  Copyright (C) 2005 SKYRIX Software AG

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

#import <Foundation/NSObject.h>

@class NSUserDefaults, NSArray;
@class GCSFolderManager;

@interface Tool : NSObject
{
  NSUserDefaults *ud;
}

+ (int)runWithArgs:(NSArray *)_args;
- (int)run;

@end

#include <GDLContentStore/GCSFolderType.h>
#include "common.h"

@implementation Tool

- (id)init {
  if ((self = [super init])) {
    self->ud = [[NSUserDefaults standardUserDefaults] retain];
  }
  return self;
}
- (void)dealloc {
  [self->ud release];
  [super dealloc];
}

/* operation */

- (int)runOnTable:(NSString *)_tableName typeName:(NSString *)_typeName {
  GCSFolderType *folderType;
  
  if ((folderType = [GCSFolderType folderTypeWithName:_typeName]) != nil) {
    NSString *s;
    
    s = [folderType sqlQuickCreateWithTableName:_tableName];
    
    fwrite([s cString], 1, [s cStringLength], stdout);
    printf("\n");
  }
  else {
    fprintf(stderr, "ERROR: did not find GCS type: '%s'\n", 
	    [_typeName cString]);
  }
  
  return 0;
}

- (int)run {
  NSEnumerator *e;
  NSString *tableName, *typeName;
  
  e = [[[NSProcessInfo processInfo] argumentsWithoutDefaults] 
                       objectEnumerator];
  [e nextObject]; // skip tool name
  
  while ((tableName = [e nextObject]) != nil) {
    typeName = [e nextObject];
    if (typeName == nil) {
      [self logWithFormat:@"got tablename '%@' but no type?!", tableName];
      break;
    }
    
    [self runOnTable:tableName typeName:typeName];
  }
  
  return 0;
}
+ (int)runWithArgs:(NSArray *)_args {
  return [(Tool *)[[[self alloc] init] autorelease] run];
}

@end /* Tool */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  rc = [Tool runWithArgs:
               [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  
  [pool release];
  return rc;
}
