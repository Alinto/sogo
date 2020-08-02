/* TestNGMimeAddressHeaderFieldGenerator.m - this file is part of SOGo
 *
 * Copyright (C) 2016
 *
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

#import <NGMime/NGMimeType.h>
#import <NGExtensions/NSString+Encoding.h>
#import "SOGoTest.h"
#include <stdio.h>

@interface TestNGMimeType : SOGoTest
@end

@implementation TestNGMimeType

- (void) test_EncodingForCharset
{
  int i;
  NSArray *cases = [NSArray arrayWithObjects:
                             @"utf8",
                             [NSNumber numberWithInt: NSUTF8StringEncoding],
                             [NSNumber numberWithInt: NSUTF8StringEncoding],

                             @"utf-8",
                             [NSNumber numberWithInt: NSUTF8StringEncoding],
                             [NSNumber numberWithInt: NSUTF8StringEncoding],

                             @"ascii",
                             [NSNumber numberWithInt: NSASCIIStringEncoding],
                             [NSNumber numberWithInt: NSASCIIStringEncoding],

                             @"us-ascii",
                             [NSNumber numberWithInt: NSASCIIStringEncoding],
                             [NSNumber numberWithInt: NSASCIIStringEncoding],

                             @"iso-8859-5",
                             [NSNumber numberWithInt: NSISOCyrillicStringEncoding],
                             [NSNumber numberWithInt: NSISOCyrillicStringEncoding],

                             @"windows-1251",
                             [NSNumber numberWithInt: NSWindowsCP1251StringEncoding],
                             [NSNumber numberWithInt: NSWindowsCP1251StringEncoding],

                             @"inexistent_encoding",
                             [NSNumber numberWithInt: NSISOLatin1StringEncoding],
                             [NSNumber numberWithInt: 0],

                             @"",
                             [NSNumber numberWithInt: [NSString defaultCStringEncoding]],
                             [NSNumber numberWithInt: 0],

                              nil];

  for (i=0; i < [cases count]; i+=3)
    {
      NSStringEncoding fromNGMimeType, fromNSString;
      NSString *charset = [cases objectAtIndex: i];
      NSStringEncoding fromNGMimeTypeExpected = [[cases objectAtIndex: i+1] intValue];
      NSStringEncoding fromNSStringExpected = [[cases objectAtIndex: i+2] intValue];
      NSString *error;

      if ([charset isEqualToString: @"nil"])
        charset = nil;

      fromNGMimeType = [NGMimeType stringEncodingForCharset: charset];
      error = [NSString
                stringWithFormat:
                @"[NGMimeType stringEncodingForCharset: %@]=%i expected: %i",
                charset, fromNGMimeType, fromNGMimeTypeExpected];
      testWithMessage(fromNGMimeType == fromNGMimeTypeExpected, error);

      fromNSString = [NSString stringEncodingForEncodingNamed: charset];
      error = [NSString
                stringWithFormat:
                @"[NSString stringEncodingForEncodingNamed: %@]=%i expected: %i",
                charset, fromNSString, fromNSStringExpected];
      testWithMessage(fromNSString == fromNSStringExpected, error);
    }
}

@end
