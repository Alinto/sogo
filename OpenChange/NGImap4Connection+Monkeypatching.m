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

#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>

#import <NGExtensions/NSObject+Logs.h>


@implementation NGImap4Connection (Monkeypatching)

- (NSArray *)fetchUIDs:(NSArray *)_uids inURL:(NSURL *)_url
                                        parts:(NSArray *)_parts
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
      [self errorWithFormat: @"could not fetch %d uids for url: %@", [_uids count], _url];
      return nil;
    }

    if (!result) {
      /* First iteration, first result */
      result = [[partial_result mutableCopy] autorelease];
      /* RawResponse has already been processed, ignore it */
      [result removeObjectForKey: @"RawResponse"];
      continue;
    }

    /* Merge partial_result into previous result */
    for (id key in [partial_result keyEnumerator]) {
      id obj, current_obj;

      current_obj = [result objectForKey: key];
      if (!current_obj) continue;

      obj = [partial_result objectForKey: key];
      if ([obj isKindOfClass: [NSArray class]]) {
        NSArray *data, *current_data, *new_data;
        data = obj;
        current_data = current_obj;
        new_data = [current_data arrayByAddingObjectsFromArray: data];
        [result setObject: new_data forKey: key];
      }
    }
  }

  return (id)result;
}

@end
