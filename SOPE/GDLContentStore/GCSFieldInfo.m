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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import <NGExtensions/NSNull+misc.h>
#import <NGExtensions/NSObject+Logs.h>

#import "GCSFieldInfo.h"

@implementation GCSFieldInfo

+ (NSArray *)fieldsForPropertyList:(NSArray *)_plist {
  NSMutableArray *fields;
  unsigned i, count;
  
  if (_plist == nil)
    return nil;
  
  count = [_plist count];
  fields = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    GCSFieldInfo *field;

    field = [[GCSFieldInfo alloc] initWithPropertyList:
				    [_plist objectAtIndex:i]];
    if (field != nil) [fields addObject:field];
    [field release];
  }
  return fields;
}

- (id)initWithPropertyList:(id)_plist {
  if ((self = [super init])) {
    NSDictionary *plist = _plist;
    
    self->columnName = [[plist objectForKey:@"columnName"] copy];
    self->sqlType    = [[plist objectForKey:@"sqlType"]    copy];
    
    self->allowsNull   = [[plist objectForKey:@"allowsNull"]   boolValue];
    self->isPrimaryKey = [[plist objectForKey:@"isPrimaryKey"] boolValue];
    
    if (![self->columnName isNotNull] || ![self->sqlType isNotNull]) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self->columnName release];
  [self->sqlType    release];
  [super dealloc];
}

/* accessors */

- (NSString *)columnName {
  return self->columnName;
}
- (NSString *)sqlType {
  return self->sqlType;
}

- (BOOL)doesAllowNull {
  return self->allowsNull;
}
- (BOOL)isPrimaryKey {
  return self->isPrimaryKey;
}

/* generating SQL */

- (NSString *)sqlCreateSection {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:32];
  [ms appendString:[self columnName]];
  [ms appendString:@" "];
  [ms appendString:[self sqlType]];
  
  [ms appendString:@" "];
  if (![self doesAllowNull]) [ms appendString:@"NOT "];
  [ms appendString:@"NULL"];
  
  if ([self isPrimaryKey]) [ms appendString:@" PRIMARY KEY"];
  return ms;
}

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)ms {
  id tmp;
  
  if ((tmp = [self columnName]) != nil) [ms appendFormat:@" column=%@", tmp];
  if ((tmp = [self sqlType])    != nil) [ms appendFormat:@" sql=%@",    tmp];
  
  if ([self doesAllowNull]) [ms appendString:@" allows-null"];
  if ([self isPrimaryKey])  [ms appendString:@" pkey"];
}

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [self appendAttributesToDescription:ms];
  [ms appendString:@">"];
  return ms;
}

@end /* GCSFieldInfo */
