/*
 Copyright (C) 2000-2004 SKYRIX Software AG
 
 This file is part of OGo
 
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

#include "SOGoLRUCache.h"
#include "common.h"

@interface SOGoLRUCacheItem : NSObject
{
  id object;
  unsigned useCount;
}

- (id)initWithObject:(id)_obj;
- (id)object;

- (unsigned)useCount;

@end

@implementation SOGoLRUCacheItem

- (id)initWithObject:(id)_obj {
  self = [super init];
  if(self) {
    ASSIGN(self->object, _obj);
    self->useCount = 1;
  }
  return self;
}

- (id)object {
  self->useCount++;
  return self->object;
}

- (unsigned)useCount {
  return self->useCount;
}

@end

@implementation SOGoLRUCache

- (id)initWithCacheSize:(unsigned)_size {
  self = [super init];
  if(self) {
    self->size = _size;
    self->entries = [[NSMutableDictionary alloc] initWithCapacity:_size];
  }
  return self;
}

- (void)dealloc {
  [self->entries release];
  [super dealloc];
}

- (void)addObject:(id)_obj forKey:(id)_key {
  SOGoLRUCacheItem *item;
  
  NSAssert(_obj, @"Attempt to insert nil object!");
  
  if([self->entries count] >= self->size) {
    /* need to find minimum and get rid of it */
    NSEnumerator     *keyEnum;
    SOGoLRUCacheItem *item;
    id               key, leastUsedItemKey;
    unsigned         minimumUseCount = INT_MAX;
    
    keyEnum = [self->entries keyEnumerator];
    while((key = [keyEnum nextObject])) {
      item = [self->entries objectForKey:key];
      if([item useCount] < minimumUseCount) {
        minimumUseCount = [item useCount];
        leastUsedItemKey = key;
      }
    }
    [self->entries removeObjectForKey:leastUsedItemKey];
  }
  item = [[SOGoLRUCacheItem alloc] initWithObject:_obj];
  [self->entries setObject:item forKey:_key];
  [item release];
}

- (id)objectForKey:(id)_key {
  SOGoLRUCacheItem *item;
  
  item = [self->entries objectForKey:_key];
  if(!item)
    return nil;
  return [item object];
}

@end
