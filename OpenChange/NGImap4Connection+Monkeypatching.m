/* NGImap4Connection+Monkeypatching.m - this file is part of SOGo
 *
 * Copyright (C) 2014 Jesús García Sáez
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

#import "NGImap4Connection+Monkeypatching.h"

#import <Foundation/NSValue.h>
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSObject+Logs.h>


@implementation NGImap4Connection (Monkeypatching)

- (NSArray *) fetchUIDs: (NSArray *) _uids
                  inURL: (NSURL *) _url
                  parts: (NSArray *) _parts
{
  // currently returns a dict?!
  /*
    Allowed fetch keys:
      UID
      BODY.PEEK[<section>]<<partial>>
      BODY            [this is the bodystructure, supported]
      BODYSTRUCTURE   [not supported yet!]
      ENVELOPE        [this is a parsed header, but does not include type]
      FLAGS
      INTERNALDATE
      RFC822
      RFC822.HEADER
      RFC822.SIZE
      RFC822.TEXT
  */
  NSMutableDictionary *result = nil;
  NSUInteger i, total, step = 1000;

  if (_uids == nil || [_uids count] == 0)
    return nil;

  /* select folder */

  if (![self selectFolder:_url])
    return nil;

  /* fetch parts */

  total = [_uids count];
  for (i = 0; i < total; i += step) {
    NSRange range;
    NSArray *partial_uids;
    NSDictionary *partial_result;

    range = NSMakeRange(i, (i + step) > total ? (total - i) : step);
    partial_uids = [_uids subarrayWithRange: range];

    /* We will only fetch "step" uids each time */
    partial_result = [[self client] fetchUids:partial_uids parts:_parts];

    if (![[partial_result valueForKey:@"result"] boolValue]) {
      [self errorWithFormat: @"Error fetching %u uids for url: %@",
	                         total, _url];
      return nil;
    }

    if (result == nil) {
      /* First iteration, first result */
      result = [[partial_result mutableCopy] autorelease];
    } else {
      /* Merge partial_result into previous result */
      [self _mergeDict: partial_result into: result];
    }
  }

  return (id)result;
}

- (void) _mergeDict: (NSDictionary *) source
               into: (NSMutableDictionary *) target
{
  for (id key in [source keyEnumerator]) {
    id obj, current_obj;

    current_obj = [target objectForKey: key];
    if (current_obj == nil) {
      /* This should never happen but just in case... */
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"nonexistent key %@ on current target", key];
      continue;
    }

    obj = [source objectForKey: key];
    if ([obj isKindOfClass: [NSArray class]]) {
      NSArray *data, *current_data, *new_data;
      data = obj;
      current_data = current_obj;
      new_data = [current_data arrayByAddingObjectsFromArray: data];
      [target setObject: new_data forKey: key];
    } else if ([obj isKindOfClass: [NGMutableHashMap class]]) {
      [self _mergeNGHashMap: obj into: current_obj];
    } else if ([obj isKindOfClass: [NSNumber class]]) {
      if (obj != current_obj) {
        [self errorWithFormat: @"Error merging fetchUids results: "
                               @"incorrect value for key %@: %@ != %@",
                               key, obj, current_obj];
      }
    } else {
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"ignored %@ (%@) key", key, [key class]];
    }
  }
}

- (void) _mergeNGHashMap: (NGMutableHashMap *) source
                    into: (NGMutableHashMap *) target
{
  for (id key in [source keyEnumerator]) {
    NSArray *obj, *current_obj;

    current_obj = [target objectsForKey: key];
    if (current_obj == nil) {
      /* This should never happen but just in case... */
      [self errorWithFormat: @"Error merging fetchUids results: "
                             @"nonexistent key %@ on current target", key];
      continue;
    }

    if ([current_obj count] == 1) {
      /* Merge only results, that means fields with more than 1 object */
      continue;
    }

    obj = [source objectsForKey: key];
    [target addObjects: obj forKey: key];
  }
}

@end
