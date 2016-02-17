/* dbmsgdump.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2014 Inverse inc
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

/* A format-agnostic property list dumper.
   Usage: dbmsgdump [filename] */

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <NGExtensions/NSNull+misc.h>

#import <SOGo/BSONCodec.h>
#import "NSObject+PropertyList.h"

const char *indentationStep = "  ";


@implementation NSObject (plext)

- (void) _outputIndentation: (NSInteger) anInt
{
  NSInteger i;

  for (i = 0; i < anInt; i++)
    printf ("%s", indentationStep);
}

- (void) displayWithIndentation: (NSInteger) anInt
{
  printf ("(%s) %s",
          [NSStringFromClass (isa) UTF8String],
          [[self description] UTF8String]);
}

@end

@implementation NSDictionary (plext)

- (void) displayKey: (NSString *) key
    withIndentation: (NSInteger) anInt
{
  [self _outputIndentation: anInt];

  printf ("%s ", [[key description] UTF8String]);
  if ([key isKindOfClass: [NSValue class]])
    printf ("(%s: 0x%.8x) ", [(NSValue *) key objCType], [key intValue]);

  printf ("= ");
}

- (void) displayWithIndentation: (NSInteger) anInt
{
  NSUInteger i, max;
  NSArray *keys;
  NSInteger subIndent;
  NSString *key;

  keys = [self allKeys];
  max = [keys count];

  printf ("{ (%ld) items\n", (long) max);

  subIndent = anInt + 1;

  for (i = 0; i < max; i++)
    {
      key = [keys objectAtIndex: i];
      [self displayKey: key withIndentation: subIndent];
      [[self objectForKey: key] displayWithIndentation: subIndent];
      if (i < (max - 1))
        printf (",");
      printf ("\n");
    }

  [self _outputIndentation: anInt];
  printf ("}");
}

@end

@implementation NSArray (plext)

- (void) displayCount: (NSUInteger) count
      withIndentation: (NSInteger) anInt
{
  [self _outputIndentation: anInt];
  printf ("%lu = ", (unsigned long) count);
}

- (void) displayWithIndentation: (NSInteger) anInt
{
  NSUInteger i, max;
  NSInteger subIndent;

  max = [self count];

  printf ("[ (%ld) items\n", (long) max);

  subIndent = anInt + 1;

  for (i = 0; i < max; i++)
    {
      [self displayCount: i withIndentation: subIndent];
      [[self objectAtIndex: i] displayWithIndentation: subIndent];
      if (i < (max - 1))
        printf (",");
      printf ("\n");
    }

  [self _outputIndentation: anInt];
  printf ("]");
}

@end

