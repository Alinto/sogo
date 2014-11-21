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
  char* url = NULL;
  enum mapistore_error ret;
  bool soft_delete = false;

  ret = indexing->get_uri(indexing, [username UTF8String],
                          memCtx, idNbr, &url, &soft_delete);
  if (ret != MAPISTORE_SUCCESS)
    return NULL;
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
  const char *searchURL;
  uint64_t idNbr;
  bool softDeleted;
  NSString *current;
  NSString *newURL;

  if ([oldURL isEqualToString: urlString]) return;

  searchURL = [[oldURL stringByAppendingString:@"*"] UTF8String];

  while (indexing->get_fmid(indexing, [username UTF8String],
         searchURL,true, &idNbr, &softDeleted) == MAPISTORE_SUCCESS)
  {
    // Ignore deleted
    if (softDeleted) continue;

    current = [self urlFromID:idNbr];
    newURL = [current stringByReplacingPrefix: oldURL withPrefix: urlString];
    indexing->update_fmid(indexing, [username UTF8String], idNbr, [newURL UTF8String]);
  }
}

- (void) updateID: (uint64_t) idNbr
          withURL: (NSString *) urlString
{
  NSString *oldURL;

  oldURL = [self urlFromID: idNbr];
  if (oldURL)
    {
      if ([oldURL hasSuffix: @"/"]) /* is container ? */
        {
          if (![urlString hasSuffix: @"/"])
            [NSException raise: NSInvalidArgumentException
                        format: @"a container url must have an ending '/'"];
          [self _updateFolderWithURL: oldURL withURL: urlString];
        }
      else
        {
          if ([urlString hasSuffix: @"/"])
            [NSException raise: NSInvalidArgumentException
                        format: @"a leaf url must not have an ending '/'"];

          indexing->update_fmid(indexing, [username UTF8String],
                                idNbr, [urlString UTF8String]);
        }
    }
}

- (BOOL) registerURL: (NSString *) urlString
              withID: (uint64_t) idNbr
{
  NSString *oldURL;
  uint64_t oldIdNbr;
  bool rc;

  oldURL = [self urlFromID: idNbr];
  if (oldURL != NULL)
    {
      [self errorWithFormat:
	     @"url with idNbr already registered: (oldUrl='%@', newUrl='%@', id=x%.16"PRIx64")",
	     oldURL, urlString, idNbr];
      return NO;
    }

  oldIdNbr = [self idFromURL: urlString];
  if (oldIdNbr != NSNotFound)
    {
      [self errorWithFormat:
              @"attempt to double register an entry with idNbr ('%@', %lld,"
            @" 0x%.16"PRIx64", oldid=0x%.16"PRIx64")",
            urlString, idNbr, idNbr, oldIdNbr];
      return NO;
    }
  else
    {
      rc = YES;
      // [self logWithFormat: @"registered url '%@' with id %lld (0x%.16"PRIx64")",
      //       urlString, idNbr, idNbr];

      /* Add the record given its fid and mapistore_uri */
      indexing->add_fmid(indexing, [username UTF8String],
                         idNbr, [urlString UTF8String]);
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
      for (count = 0; count < max; count++)
        {
          newID = [[idNbrs objectAtIndex: count]
                    unsignedLongLongValue];
          [self registerURL: [urlStrings objectAtIndex: count]
                     withID: newID];
        }
    }
  else
    [NSException raise: NSInvalidArgumentException
                format: @"number of urls and ids do not match"];
}

- (void) unregisterURLWithID: (uint64_t) idNbr
{
  indexing->del_fmid(indexing, [username UTF8String],
                     idNbr, MAPISTORE_PERMANENT_DELETE);
}

@end
