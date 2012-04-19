/* NSDictionary+NGCards.m - this file is part of SOPE
 *
 * Copyright (C) 2006 Inverse inc.
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
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
#import <Foundation/NSString.h>

#import "NSArray+NGCards.h"
#import "NSString+NGCards.h"

#import "NSDictionary+NGCards.h"

@interface NSArray (NGCardsVersit)

- (BOOL) _renderAsSubValuesInString: (NSMutableString *) aString
                       asAttributes: (BOOL) asAttributes;
- (BOOL) _renderAsOrderedValuesInString: (NSMutableString *) aString
                                withKey: (NSString *) key;

@end

@implementation NSArray (NGCardsVersit)

- (BOOL) _renderAsSubValuesInString: (NSMutableString *) aString
                       asAttributes: (BOOL) asAttributes
{
  NSUInteger count, max;
  NSString *subValue, *escaped;
  BOOL previousWasEmpty = YES, rendered = NO;

  max = [self count];
  for (count = 0; count < max; count++)
    {
      if (!previousWasEmpty)
        [aString appendString: @","];
      subValue = [self objectAtIndex: count];

      /* We MUST quote attribute values that have a ":" in them
         and that not already quoted */
      if (asAttributes && [subValue length] > 2
          && [subValue rangeOfString: @":"].length
          && [subValue characterAtIndex: 0] != '"'
          && ![subValue hasSuffix: @"\""])
        subValue = [NSString stringWithFormat: @"\"%@\"", subValue];

      escaped = [subValue escapedForCards];
      if ([escaped length] > 0)
        {
          [aString appendString: escaped];
          previousWasEmpty = NO;
          rendered = YES;
        }
      else
        previousWasEmpty = YES;
    }

  return rendered;
}

- (BOOL) _renderAsOrderedValuesInString: (NSMutableString *) aString
                                withKey: (NSString *) key
{
  NSUInteger count, max, lastRendered = 0;
  BOOL rendered = NO;
  NSArray *subValues;
  NSMutableString *substring;

  max = [self count];
  for (count = 0; count < max; count++)
    {
      subValues = [self objectAtIndex: count];
      substring = [NSMutableString string];
      if ([subValues _renderAsSubValuesInString: substring
                                   asAttributes: NO])
        {
          if (lastRendered == 0 && [key length] > 0)
            [aString appendFormat: @"%@=", key];

          while (lastRendered < count)
            {
              [aString appendString: @";"];
              lastRendered++;
            }
          [aString appendString: substring];
          rendered = YES;
        }
    }

  return rendered;
}

@end

@implementation NSDictionary (NGCardsExtension)

- (id) objectForCaseInsensitiveKey: (NSString *) aKey
{
  NSString *realKey;
  NSArray *keys;

  keys = [self allKeys];
  realKey = [keys valueForCaseInsensitiveString: aKey];

  return ((realKey) ? [self objectForKey: realKey] : nil);
}

- (void) versitRenderInString: (NSMutableString *) aString
              withKeyOrdering: (NSArray *) ordering
                 asAttributes: (BOOL) asAttributes
{
  NSMutableArray *keys;
  NSUInteger count, max, rendered = 0, keyIndex, newKeyIndex;
  NSArray *orderedValues;
  NSString *key;
  NSMutableString *substring;

  keys = [[self allKeys] mutableCopy];
  [keys autorelease];

  /* We reorder the fields based on the "ordering" array, by first placing
     those that are specified and then the rest of them. */
  newKeyIndex = 0;
  max = [ordering count];
  for (count = 0; count < max; count++)
    {
      key = [ordering objectAtIndex: count];
      keyIndex = [keys indexOfObject: key];
      if (keyIndex != NSNotFound)
        {
          if (keyIndex != newKeyIndex)
            {
              [keys removeObjectAtIndex: keyIndex];
              [keys insertObject: key atIndex: newKeyIndex];
            }
          newKeyIndex++;
        }
    }

  max = [keys count];
  for (count = 0; count < max; count++)
    {
      key = [keys objectAtIndex: count];
      orderedValues = [self objectForKey: key];
      substring = [NSMutableString string];
      if (asAttributes)
        {
          if ([orderedValues _renderAsSubValuesInString: substring
                                           asAttributes: YES])
            {
              if (rendered > 0)
                [aString appendString: @";"];
              [aString appendFormat: @"%@=%@",
                       [key uppercaseString], substring];
              rendered++;
            }
        }
      else if ([orderedValues _renderAsOrderedValuesInString: substring
                                                     withKey: [key uppercaseString]])
        {
          if (rendered > 0)
            [aString appendString: @";"];
          [aString appendString: substring];
          rendered++;
        }
    }
}

@end
