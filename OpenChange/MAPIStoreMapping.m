/* MAPIStoreMapping.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
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

#include <inttypes.h>

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreTypes.h"

#import "MAPIStoreMapping.h"

#include <talloc.h>
#include <tdb.h>
#include <tdb_wrap.h>

@implementation MAPIStoreMapping

static int
MAPIStoreMappingTDBTraverse (TDB_CONTEXT *ctx, TDB_DATA data1, TDB_DATA data2,
			     void *data)
{
  NSMutableDictionary *mapping;
  NSNumber *idNbr;
  NSString *uri;
  char *idStr, *uriStr;
  uint64_t idVal;

  idStr = (char *) data1.dptr;
  idVal = strtoll (idStr, NULL, 16);
  idNbr = [NSNumber numberWithUnsignedLongLong: idVal];

  uriStr = strndup ((const char *) data2.dptr, data2.dsize);
  *(uriStr+(data2.dsize)) = 0;
  uri = [NSString stringWithUTF8String: uriStr];
  free (uriStr);

  mapping = data;
  [mapping setObject: uri forKey: idNbr];

  NSLog (@"preregistered url '%@' for id '%@'", uri, idNbr);

  return 0;
}

+ (id) mappingWithIndexing: (struct tdb_wrap *) indexing
{
  id newMapping;

  newMapping = [[self alloc] initWithIndexing: indexing];
  [newMapping autorelease];

  return newMapping;
}

- (id) init
{
  if ((self = [super init]))
    {
      mapping = [NSMutableDictionary new];
      reverseMapping = [NSMutableDictionary new];
      indexing = NULL;
    }

  return self;
}

- (id) initWithIndexing: (struct tdb_wrap *) newIndexing
{
  NSNumber *idNbr;
  NSString *uri;
  NSArray *keys;
  NSUInteger count, max;

  if ((self = [self init]))
    {
      indexing = newIndexing;
      tdb_traverse_read (indexing->tdb, MAPIStoreMappingTDBTraverse, mapping);
      keys = [mapping allKeys];
      max = [keys count];
      for (count = 0; count < max; count++)
	{
	  idNbr = [keys objectAtIndex: count];
	  uri = [mapping objectForKey: idNbr];
          [self logWithFormat: @"preregistered id '%@' for url '%@'", idNbr, uri];
	  [reverseMapping setObject: idNbr forKey: uri];
	}
    }

  return self;
}

- (void) dealloc
{
  [mapping release];
  [reverseMapping release];
  [super dealloc];
}

- (NSString *) urlFromID: (uint64_t) idNbr
{
  NSNumber *key;
  
  key = [NSNumber numberWithUnsignedLongLong: idNbr];
  
  return [mapping objectForKey: key];
}

- (uint64_t) idFromURL: (NSString *) url
{
  NSNumber *idKey;
  uint64_t idNbr;

  idKey = [reverseMapping objectForKey: url];
  if (idKey)
    idNbr = [idKey unsignedLongLongValue];
  else
    idNbr = NSNotFound;

  return idNbr;
}

- (BOOL) registerURL: (NSString *) urlString
              withID: (uint64_t) idNbr
{
  NSNumber *idKey;
  BOOL rc;
  TDB_DATA key, dbuf;

  idKey = [NSNumber numberWithUnsignedLongLong: idNbr];
  if ([mapping objectForKey: idKey]
      || [reverseMapping objectForKey: urlString])
    {
      [self errorWithFormat:
              @"attempt to double register an entry ('%@', %lld,"
            @" 0x%.16"PRIx64")",
            urlString, idNbr, idNbr];
      rc = NO;
    }
  else
    {
      [mapping setObject: urlString forKey: idKey];
      [reverseMapping setObject: idKey forKey: urlString];
      rc = YES;
      [self logWithFormat: @"registered url '%@' with id %lld (0x%.16"PRIx64")",
            urlString, idNbr, idNbr];

      /* Add the record given its fid and mapistore_uri */
      key.dptr = (unsigned char *) talloc_asprintf(NULL, "0x%.16"PRIx64, idNbr);
      key.dsize = strlen((const char *) key.dptr);

      dbuf.dptr = (unsigned char *) talloc_strdup(NULL, [urlString UTF8String]);
      dbuf.dsize = strlen((const char *) dbuf.dptr);
      tdb_store (indexing->tdb, key, dbuf, TDB_INSERT);
      talloc_free (key.dptr);
      talloc_free (dbuf.dptr);
    }

  return rc;
}

- (void) unregisterURLWithID: (uint64_t) idNbr
{
  NSNumber *idKey;
  NSString *urlString;

  idKey = [NSNumber numberWithUnsignedLongLong: idNbr];
  urlString = [mapping objectForKey: idKey];
  [reverseMapping removeObjectForKey: urlString];
  [mapping removeObjectForKey: idKey];
}

@end
