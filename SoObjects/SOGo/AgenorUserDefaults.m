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

#include "AgenorUserDefaults.h"
#include <GDLContentStore/GCSChannelManager.h>
#include <GDLContentStore/NSURL+GCS.h>
#include <GDLAccess/EOAdaptorChannel.h>
#include <GDLAccess/EOAdaptorContext.h>
#include <GDLAccess/EOAttribute.h>
#include "common.h"

@implementation AgenorUserDefaults

static NSString *uidColumnName = @"uid";

- (id)initWithTableURL:(NSURL *)_url uid:(NSString *)_uid {
  if ((self = [super init])) {
    if (_url == nil || [_uid length] < 1) {
      [self errorWithFormat:@"tried to create AgenorUserDefaults w/o args!"];
      [self release];
      return nil;
    }

    self->parent = [[NSUserDefaults standardUserDefaults] retain];
    self->url = [_url copy];
    self->uid = [_uid copy];
  }
  return self;
}
- (id)init {
  return [self initWithTableURL:nil uid:nil];
}

- (void)dealloc {
  [self->attributes release];
  [self->lastFetch  release];
  [self->parent     release];
  [self->url        release];
  [self->uid        release];
  [super dealloc];
}

/* accessors */

- (NSURL *)tableURL {
  return self->url;
}
- (NSString *)uid {
  return self->uid;
}

- (NSUserDefaults *)parentDefaults {
  return self->parent;
}

/* operation */

- (void)_loadAttributes:(NSArray *)_attrs {
  NSMutableArray      *fields;
  NSMutableDictionary *attrmap;
  unsigned i, count;
  
  fields  = [[NSMutableArray      alloc] initWithCapacity:16];
  attrmap = [[NSMutableDictionary alloc] initWithCapacity:16];
  for (i = 0, count = [_attrs count]; i < count; i++) {
    EOAttribute *attr;
    NSString    *name;
    
    attr = [_attrs objectAtIndex:i];
    name = [attr valueForKey:@"name"];
    [attrmap setObject:attr forKey:name];
    
    if (![name isEqual:uidColumnName]) 
      [fields  addObject:name];
  }
  
  ASSIGNCOPY(self->fieldNames, fields);
  ASSIGNCOPY(self->attributes, attrmap);
  [attrmap release];
  [fields  release];
}

- (BOOL)primaryFetchProfile {
  GCSChannelManager *cm;
  EOAdaptorChannel  *channel;
  NSDictionary      *row;
  NSException       *ex;
  NSString          *sql;
  NSArray           *attrs;
  
  cm = [GCSChannelManager defaultChannelManager];
  if ((channel = [cm acquireOpenChannelForURL:[self tableURL]]) == nil) {
    [self errorWithFormat:@"failed to acquire channel for URL: %@", 
	  [self tableURL]];
    return NO;
  }
  
  /* generate SQL */
  
  sql = [[self tableURL] gcsTableName];
  sql = [@"SELECT * FROM " stringByAppendingString:sql];
  sql = [sql stringByAppendingFormat:@" WHERE %@ = '%@'", 
	     uidColumnName, [self uid]];
  
  /* run SQL */
  
  if ((ex = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"could not run SQL '%@': %@", sql, ex];
    [cm releaseChannel:channel];
    return NO;
  }

  /* fetch schema */
  
  attrs = [channel describeResults:NO /* don't beautify */];
  [self _loadAttributes:attrs];
  
  /* fetch values */
  
  row = [channel fetchAttributes:attrs withZone:NULL];
  self->defFlags.isNew = (row != nil) ? 0 : 1;
  [channel cancelFetch];
  
  /* remember values */
  
  [self->values release]; self->values = nil;
  self->values = (row != nil)
    ? [row mutableCopy]
    : [[NSMutableDictionary alloc] initWithCapacity:8];
  [self->values removeObjectForKey:uidColumnName];
  
  ASSIGN(self->lastFetch, [NSCalendarDate date]);
  self->defFlags.modified = 0;
  
  [cm releaseChannel:channel];
  return YES;
}

- (NSString *)formatValue:(id)_value forAttribute:(EOAttribute *)_attribute {
  NSString *s;
  
  if (![_value isNotNull])
    return @"NULL";
  
  if ([[_attribute externalType] hasPrefix:@"int"])
    return [_value stringValue];
  
  s = [_value stringValue];
  s = [s stringByReplacingString:@"'" withString:@"''"];
  s = [[@"'" stringByAppendingString:s] stringByAppendingString:@"'"];
  return s;
}

- (NSString *)generateSQLForInsert {
  NSMutableString *sql;
  unsigned i, count;
  
  if ([self->values count] == 0)
    return nil;
  
  sql = [NSMutableString stringWithCapacity:2048];
  
  [sql appendString:@"INSERT INTO "];
  [sql appendString:[[self tableURL] gcsTableName]];
  [sql appendString:@" ( uid"];

  for (i = 0, count = [self->fieldNames count]; i < count; i++) {
    EOAttribute *attr;
    
    attr = [self->attributes objectForKey:[self->fieldNames objectAtIndex:i]];
    [sql appendString:@", "];
    [sql appendString:[attr columnName]];
  }
  
  [sql appendString:@") VALUES ("];
  
  [sql appendString:@"'"];
  [sql appendString:[self uid]]; // TODO: escaping necessary?
  [sql appendString:@"'"];
  
  for (i = 0, count = [self->fieldNames count]; i < count; i++) {
    EOAttribute *attr;
    id value;
    
    attr  = [self->attributes objectForKey:[self->fieldNames objectAtIndex:i]];
    value = [self->values objectForKey:[self->fieldNames objectAtIndex:i]];
    
    [sql appendString:@", "];
    [sql appendString:[self formatValue:value forAttribute:attr]];
  }
  
  [sql appendString:@")"];
  return sql;
}

- (NSString *)generateSQLForUpdate {
  NSMutableString *sql;
  unsigned i, count;
  
  if ([self->values count] == 0)
    return nil;
  
  sql = [NSMutableString stringWithCapacity:2048];
  
  [sql appendString:@"UPDATE "];
  [sql appendString:[[self tableURL] gcsTableName]];
  [sql appendString:@" SET "];
  
  for (i = 0, count = [self->fieldNames count]; i < count; i++) {
    EOAttribute *attr;
    NSString    *name;
    id value;
    
    name  = [self->fieldNames objectAtIndex:i];
    value = [self->values objectForKey:name];
    attr  = [self->attributes objectForKey:name];
    
    if (i != 0) [sql appendString:@", "];
    [sql appendString:[attr columnName]];
    [sql appendString:@" = "];
    [sql appendString:[self formatValue:value forAttribute:attr]];
  }
  
  [sql appendString:@" WHERE "];
  [sql appendString:uidColumnName];
  [sql appendString:@" = '"];
  [sql appendString:[self uid]];
  [sql appendString:@"'"];
  return sql;
}

- (BOOL)primaryStoreProfile {
  GCSChannelManager *cm;
  EOAdaptorChannel  *channel;
  NSException       *ex;
  NSString          *sql;
  
  cm = [GCSChannelManager defaultChannelManager];
  if ((channel = [cm acquireOpenChannelForURL:[self tableURL]]) == nil) {
    [self errorWithFormat:@"failed to acquire channel for URL: %@", 
	  [self tableURL]];
    return NO;
  }
  
  /* run SQL */
  
  sql = self->defFlags.isNew
    ? [self generateSQLForInsert] 
    : [self generateSQLForUpdate];
  if ((ex = [channel evaluateExpressionX:sql]) != nil) {
    [self errorWithFormat:@"could not run SQL '%@': %@", sql, ex];
    [cm releaseChannel:channel];
    return NO;
  }
  
  /* commit */
  
  ex = nil;
  if ([[channel adaptorContext] hasOpenTransaction])
    ex = [channel evaluateExpressionX:@"COMMIT TRANSACTION"];
  
  [cm releaseChannel:channel];
  
  if (ex != nil) {
    [self errorWithFormat:@"could not commit transaction for update: %@", ex];
    return NO;
  }
  
  self->defFlags.modified = 0;
  self->defFlags.isNew    = 0;
  return YES;
}


- (BOOL)fetchProfile {
  if (self->values != nil)
    return YES;
  
  return [self primaryFetchProfile];
}

- (NSArray *)primaryDefaultNames {
  if (![self fetchProfile])
    return nil;
  
  return self->fieldNames;
}

/* value access */

- (void)setObject:(id)_value forKey:(NSString *)_key {
  if (![self fetchProfile])
    return;
  
  if (![self->fieldNames containsObject:_key]) {
    [self errorWithFormat:@"tried to write key: '%@'", _key];
    return;
  }
  
  /* check whether the value is actually modified */
  if (!self->defFlags.modified) {
    id old;

    old = [self->values objectForKey:_key];
    if (old == _value || [old isEqual:_value]) /* value didn't change */
      return;
  
    /* we need to this because our typed accessors convert to strings */
    // TODO: especially problematic with bools
    if ([_value isKindOfClass:[NSString class]]) {
      if (![old isKindOfClass:[NSString class]])
        if ([[old description] isEqualToString:_value])
  	return;
    }
  }
  
  /* set in hash and mark as modified */
  [self->values setObject:(_value ? _value : [NSNull null])  forKey:_key];
  self->defFlags.modified = 1;
}

- (id)objectForKey:(NSString *)_key {
  id value;
  
  if (![self fetchProfile])
    return nil;
  
  if (![self->fieldNames containsObject:_key])
    return [self->parent objectForKey:_key];
  
  value = [self->values objectForKey:_key];
  return [value isNotNull] ? value : nil;
}

- (void)removeObjectForKey:(NSString *)_key {
  [self setObject:nil forKey:_key];
}

/* saving changes */

- (BOOL)synchronize {
  if (!self->defFlags.modified) /* was not modified */
    return YES;
  
  /* ensure fetched data (more or less guaranteed by modified!=0) */
  if (![self fetchProfile])
    return NO;
  
  /* store */
  if (![self primaryStoreProfile]) {
    [self primaryFetchProfile];
    return NO;
  }
  
  /* refetch */
  return [self primaryFetchProfile];
}

- (void)flush {
  [self->values     release]; self->values     = nil;
  [self->fieldNames release]; self->fieldNames = nil;
  [self->attributes release]; self->attributes = nil;
  [self->lastFetch  release]; self->lastFetch  = nil;
  self->defFlags.modified = 0;
  self->defFlags.isNew    = 0;
}

/* typed accessors */

- (NSArray *)arrayForKey:(NSString *)_key {
  id obj = [self objectForKey:_key];
  return [obj isKindOfClass:[NSArray class]] ? obj : nil;
}

- (NSDictionary *)dictionaryForKey:(NSString *)_key {
  id obj = [self objectForKey:_key];
  return [obj isKindOfClass:[NSDictionary class]] ? obj : nil;
}

- (NSData *)dataForKey:(NSString *)_key {
  id obj = [self objectForKey:_key];
  return [obj isKindOfClass:[NSData class]] ? obj : nil;
}

- (NSArray *)stringArrayForKey:(NSString *)_key {
  id obj = [self objectForKey:_key];
  int n;
  Class strClass = [NSString class];
  
  if (![obj isKindOfClass:[NSArray class]])
    return nil;
	
  for (n = [obj count]-1; n >= 0; n--) {
    if (![[obj objectAtIndex:n] isKindOfClass:strClass])
      return nil;
  }
  return obj;
}

- (NSString *)stringForKey:(NSString *)_key {
  id obj = [self objectForKey:_key];
  return [obj isKindOfClass:[NSString class]] ? obj : nil;
}

- (BOOL)boolForKey:(NSString *)_key {
  // TODO: need special support here for int-DB fields
  id obj;
  
  if ((obj = [self objectForKey:_key]) == nil)
    return NO;
  if ([obj isKindOfClass:[NSString class]]) {
    if ([obj compare:@"YES" options:NSCaseInsensitiveSearch] == NSOrderedSame)
      return YES;
  }
  if ([obj respondsToSelector:@selector(intValue)])
    return [obj intValue] ? YES : NO;
  return NO;
}

- (float)floatForKey:(NSString *)_key {
  id obj = [self stringForKey:_key];
  return (obj != nil) ? [obj floatValue] : 0.0;
}
- (int)integerForKey:(NSString *)_key {
  id obj = [self stringForKey:_key];
  return (obj != nil) ? [obj intValue] : 0;
}

- (void)setBool:(BOOL)value forKey:(NSString *)_key {
  // TODO: need special support here for int-DB fields
  [self setObject:(value ? @"YES" : @"NO") forKey:_key];
}
- (void)setFloat:(float)value forKey:(NSString *)_key {
  [self setObject:[NSString stringWithFormat:@"%f", value] forKey:_key];
}
- (void)setInteger:(int)value forKey:(NSString *)_key {
  [self setObject:[NSString stringWithFormat:@"%d", value] forKey:_key];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:16];
  [ms appendFormat:@"<0x%08X[%@]>", self, NSStringFromClass([self class])];
  [ms appendFormat:@" uid=%@",        self->uid];
  [ms appendFormat:@" url=%@",        [self->url absoluteString]];
  [ms appendFormat:@" parent=0x%08X", self->parent];
  [ms appendString:@">"];
  return ms;
}

@end /* AgenorUserDefaults */
