/* MAPIStoreMapping.h - this file is part of SOGo
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

#ifndef MAPISTOREMAPPING_H
#define MAPISTOREMAPPING_H

#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSString;

@interface MAPIStoreMapping : NSObject
{
  void *memCtx;
  NSString *username;
  struct tdb_wrap *indexing;
  NSMutableDictionary *mapping; /* FID/MID -> url */
  NSMutableDictionary *reverseMapping; /* url -> FID/MID */
  NSUInteger useCount;
}

+ (id) mappingForUsername: (NSString *) username
             withIndexing: (struct tdb_wrap *) indexing;

- (id) initForUsername: (NSString *) username
          withIndexing: (struct tdb_wrap *) indexing;


- (void) increaseUseCount;
- (void) decreaseUseCount;

- (NSString *) urlFromID: (uint64_t) idKey;

- (uint64_t) idFromURL: (NSString *) url;
- (BOOL) registerURL: (NSString *) urlString
              withID: (uint64_t) idNbr;
- (void) registerURLs: (NSArray *) urlString
              withIDs: (NSArray *) idNbrs;
- (void) unregisterURLWithID: (uint64_t) idNbr;
- (void) updateID: (uint64_t) idNbr
          withURL: (NSString *) urlString;

@end

#endif /* MAPISTOREMAPPING_H */
