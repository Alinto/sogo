/* MAPIStoreMapping.m - this file is part of SOGo
 *
 * Copyright (C) 2010-2012 Inverse inc.
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
#import <NGExtensions/NSObject+Values.h>

#import <SOGo/NSString+Utilities.h>

#undef DEBUG
#include <mapistore/mapistore.h>
#include <mapistore/mapistore_errors.h>

#import "MAPIStoreTypes.h"

#import "MAPIStoreMapping.h"

#include <talloc.h>

static NSMutableDictionary *mappingRegistry = nil;

@implementation MAPIStoreMapping

+ (void) initialize
{
  mappingRegistry = [NSMutableDictionary new];
}

static inline id
MAPIStoreMappingKeyFromId (uint64_t idNbr)
{
  return [NSString stringWithUnsignedLongLong: idNbr];
}


+ (id) mappingForUsername: (NSString *) username
             withIndexing: (struct indexing_context *) indexing
{
  id mapping;

  mapping = [mappingRegistry objectForKey: username];
  if (!mapping)
    {
      mapping = [[self alloc] initForUsername: username
                                 withIndexing: indexing];
      [mapping autorelease];
    }

  return mapping;
}

- (id) init
{
  if ((self = [super init]))
    {
      memCtx = talloc_zero (NULL, TALLOC_CTX);
      indexing = NULL;
      useCount = 0;
    }

  return self;
}

- (void) increaseUseCount
{
  if (useCount == 0)
    {
      [mappingRegistry setObject: self forKey: username];
      [self logWithFormat: @"mapping registered (%@)", username];
    }
  useCount++;
}

- (void) decreaseUseCount
{
  useCount--;
  if (useCount == 0)
    {
      [mappingRegistry removeObjectForKey: username];
      [self logWithFormat: @"mapping deregistered (%@)", username];
    }
}

- (id) initForUsername: (NSString *) newUsername
          withIndexing: (struct indexing_context *) newIndexing
{
  if ((self = [self init]))
    {
      ASSIGN (username, newUsername);
      indexing = newIndexing;
    }

  return self;
}

- (void) dealloc
{
  [username release];
  talloc_free (memCtx);
  [super dealloc];
}

- (NSString *) urlFromID: (uint64_t) idNbr
{
  char* url; 

  indexing->get_uri(indexing, [username UTF8String],
                    memCtx, idNbr, &url, false);
  NSString *res = [[[NSString alloc] initWithUTF8String:url] autorelease];
  talloc_free(url);

  return res;
}

- (uint64_t) idFromURL: (NSString *) url
{
  enum mapistore_error ret;
  uint64_t idNbr;
  bool softDeleted;

  ret = indexing->get_fmid(indexing, [username UTF8String], [url UTF8String],
                           false, &idNbr, &softDeleted);

  if (ret == MAPISTORE_SUCCESS && !softDeleted)
    return idNbr;
  else
    return NSNotFound;
}

- (void) _updateFolderWithURL: (NSString *) oldURL
                      withURL: (NSString *) urlString
{
  NSArray *allKeys;
  NSUInteger count, max;
  NSString *currentKey, *newKey;
  id idKey;
  TDB_DATA key, dbuf;

  [oldURL retain];

  allKeys = [reverseMapping allKeys];
  max = [allKeys count];
  for (count = 0; count < max; count++)
    {
      currentKey = [allKeys objectAtIndex: count];
      if ([currentKey hasPrefix: oldURL])
        {
          newKey = [currentKey stringByReplacingPrefix: oldURL
                                            withPrefix: urlString];

          idKey = [reverseMapping objectForKey: currentKey];
          [mapping setObject: newKey forKey: idKey];
          [reverseMapping setObject: idKey forKey: newKey];
          [reverseMapping removeObjectForKey: currentKey];

          /* update the record in the indexing database */
          key.dptr = (unsigned char *) talloc_asprintf (NULL, "0x%.16"PRIx64,
                                                        (uint64_t) [idKey unsignedLongLongValue]);
          key.dsize = strlen ((const char *) key.dptr);

          dbuf.dptr = (unsigned char *) talloc_strdup (NULL,
                                                       [newKey UTF8String]);
          dbuf.dsize = strlen ((const char *) dbuf.dptr);
          tdb_store (indexing->tdb, key, dbuf, TDB_MODIFY);
          talloc_free (key.dptr);
          talloc_free (dbuf.dptr);
        }
    }

  [oldURL release];
}

- (void) updateID: (uint64_t) idNbr
          withURL: (NSString *) urlString
{
  NSString *oldURL;
  id idKey;
  TDB_DATA key, dbuf;

  idKey = MAPIStoreMappingKeyFromId (idNbr);
  oldURL = [mapping objectForKey: idKey];
  if (oldURL)
    {
      if ([oldURL hasSuffix: @"/"]) /* is container ? */
        {
          if (![urlString hasSuffix: @"/"])
            [NSException raise: NSInvalidArgumentException
                        format: @"a container url must have an ending '/'"];
          tdb_transaction_start (indexing->tdb);
          [self _updateFolderWithURL: oldURL withURL: urlString];
          tdb_transaction_commit (indexing->tdb);
        }
      else
        {
          if ([urlString hasSuffix: @"/"])
            [NSException raise: NSInvalidArgumentException
                        format: @"a leaf url must not have an ending '/'"];
          [mapping setObject: urlString forKey: idKey];
          [reverseMapping setObject: idKey forKey: urlString];
          [reverseMapping removeObjectForKey: oldURL];

          /* update the record in the indexing database */
          key.dptr = (unsigned char *) talloc_asprintf(NULL, "0x%.16"PRIx64, idNbr);
          key.dsize = strlen((const char *) key.dptr);

          dbuf.dptr = (unsigned char *) talloc_strdup (NULL, [urlString UTF8String]);
          dbuf.dsize = strlen((const char *) dbuf.dptr);
          tdb_store (indexing->tdb, key, dbuf, TDB_MODIFY);
          talloc_free (key.dptr);
          talloc_free (dbuf.dptr);
        }
    }
}

- (BOOL) registerURL: (NSString *) urlString
              withID: (uint64_t) idNbr
{
  id idKey;
  BOOL rc;
  TDB_DATA key, dbuf;

  idKey = MAPIStoreMappingKeyFromId (idNbr);
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
      // [self logWithFormat: @"registered url '%@' with id %lld (0x%.16"PRIx64")",
      //       urlString, idNbr, idNbr];

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

- (void) registerURLs: (NSArray *) urlStrings
              withIDs: (NSArray *) idNbrs
{
  uint64_t count, max, newID;

  max = [urlStrings count];
  if (max == [idNbrs count])
    {
      tdb_transaction_start (indexing->tdb);
      for (count = 0; count < max; count++)
        {
          newID = [[idNbrs objectAtIndex: count]
                    unsignedLongLongValue];
          [self registerURL: [urlStrings objectAtIndex: count]
                     withID: newID];
        }
      tdb_transaction_commit (indexing->tdb);
    }
  else
    [NSException raise: NSInvalidArgumentException
                format: @"number of urls and ids do not match"];
}

- (void) unregisterURLWithID: (uint64_t) idNbr
{
  NSString *urlString;
  id idKey;
  TDB_DATA key;

  idKey = MAPIStoreMappingKeyFromId (idNbr);
  urlString = [mapping objectForKey: idKey];
  if (urlString)
    {
      // [self logWithFormat: @"unregistering url '%@' with id %lld (0x%.16"PRIx64")",
      //       urlString, idNbr, idNbr];
      [reverseMapping removeObjectForKey: urlString];
      [mapping removeObjectForKey: idKey];

      /* We hard-delete the entry from the indexing database */
      key.dptr = (unsigned char *) talloc_asprintf(NULL, "0x%.16"PRIx64, idNbr);
      key.dsize = strlen((const char *) key.dptr);
  
      tdb_delete(indexing->tdb, key);
      talloc_free(key.dptr);
    }
}

@end
