/* dbmsgdump.m - this file is part of SOGo
 *
 * Copyright (C) 2011-2012 Inverse inc
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

const char *indentationStep = "  ";

@interface NSObject (plext)

- (void) displayWithIndentation: (NSInteger) anInt;

@end

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

static void
OCDumpPListData (NSData *content)
{
  NSDictionary *d;
  NSPropertyListFormat format;
  NSString *error = nil;
  const char *formatName;

  d = [NSPropertyListSerialization propertyListFromData: content
                                       mutabilityOption: NSPropertyListImmutable
                                                 format: &format
                                       errorDescription: &error];
  if (d)
    {
      switch (format)
        {
        case  NSPropertyListOpenStepFormat:
          formatName = "OpenStep";
          break;
        case NSPropertyListXMLFormat_v1_0:
          formatName = "XML";
          break;
        case NSPropertyListBinaryFormat_v1_0:
          formatName = "Binary";
          break;
        case NSPropertyListGNUstepFormat:
          formatName = "GNUstep";
          break;
        case NSPropertyListGNUstepBinaryFormat:
          formatName = "GNUstep binary";
          break;
        default: formatName = "unknown";
        }

      printf ("File format is: %s\n", formatName);
      [d displayWithIndentation: 0];
      printf ("\n");
    }
  else
    printf ("an error occurred: %s\n", [error UTF8String]);
}
