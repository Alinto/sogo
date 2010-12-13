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

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

#import <NGExtensions/NSObject+Logs.h>

#import "MAPIStoreMapping.h"

#include <fcntl.h>
#include <tdb.h>
#include <talloc.h>

struct tdb_wrap {
	struct tdb_context *tdb;

	const char *name;
	struct tdb_wrap *next, *prev;
};

extern struct tdb_wrap *tdb_wrap_open(TALLOC_CTX *mem_ctx,
				      const char *name, int hash_size, int tdb_flags,
				      int open_flags, mode_t mode);

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

  uriStr = strdup ((const char *) data2.dptr);
  *(uriStr+(data2.dsize)) = 0;
  uri = [NSString stringWithUTF8String: uriStr];
  free (uriStr);

  mapping = data;
  [mapping setObject: uri forKey: idNbr];

  return 0;
}

static void
MAPIStoreMappingInitDictionary (NSMutableDictionary *mapping)
{
  struct tdb_wrap *wrap;
  TDB_CONTEXT *context;
  char *tdb_path;
  int rc;

  tdb_path  = "/usr/local/samba/private/mapistore/openchange/indexing.tdb";
  wrap = tdb_wrap_open(NULL, tdb_path, 0, TDB_NOLOCK, O_RDONLY, 0600);

  context = wrap->tdb;
  rc = tdb_traverse_read(wrap->tdb, MAPIStoreMappingTDBTraverse, mapping);

}

@implementation MAPIStoreMapping

+ (id) sharedMapping
{
  static id sharedMapping = nil;

  if (!sharedMapping)
    sharedMapping = [self new];

  return sharedMapping;
}

- (id) init
{
  NSNumber *idNbr;
  NSString *uri;
  NSArray *keys;
  NSUInteger count, max;

  if ((self = [super init]))
    {
      mapping = [NSMutableDictionary new];
      MAPIStoreMappingInitDictionary (mapping);
      reverseMapping = [NSMutableDictionary new];

      keys = [mapping allKeys];
      max = [keys count];
      for (count = 0; count < max; count++)
	{
	  idNbr = [keys objectAtIndex: count];
	  uri = [mapping objectForKey: idNbr];
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

  idKey = [NSNumber numberWithUnsignedLongLong: idNbr];
  if ([mapping objectForKey: idKey]
      || [reverseMapping objectForKey: urlString])
    {
      [self errorWithFormat: @"attempt to double register an entry ('%@', %lld)",
            urlString, idNbr];
      rc = NO;
    }
  else
    {
      if ([urlString hasSuffix: @".plist"])
	{
	  [self logWithFormat: @"coucou"];
	}
      [mapping setObject: urlString forKey: idKey];
      [reverseMapping setObject: idKey forKey: urlString];
      rc = YES;
      [self logWithFormat: @"registered url '%@' with id %lld (0x%.8x)",
            urlString, idNbr, (uint32_t) idNbr];
    }

  return rc;
}

@end
