/* TestNGMailAddressParser.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Inverse inc.
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

#import <NGMail/NGMailAddressParser.h>
#import <NGMail/NGMailAddress.h>

#import "SOGoTest.h"

@interface TestNGMailAddressParser : SOGoTest
@end

@implementation TestNGMailAddressParser

/* important: this file must be encoded in iso-8859-1, due to issues with the
   objc compiler */
- (void) test_singleEmailParsing_value_
{
  NSArray *rawAddresses = [NSArray arrayWithObjects: 
        @"johndown@test.com",    // email alone
        @"<johndown@test.com>",  // email between brackets
        @"\"<johndown@test.com>\" <johndown@test.com>", // doubled
        @"\"johndown@inverse.ca\" <johndown@test.com>", // with and without br.
        @"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla?= <johndown@test.com>", // accented full name
        @"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla_Bla_Bl=C3=A9?= <johndown@test.com>", // accented and multiword
        @"John Down \"Bla Bla\" <johndown@test.com>", // partly quoted
        @"John Down <johndown@test.com>", // full name + email
        @"John, Down <johndown@test.com>", // full name with comma + email
        @"john", // name only, no domain
        nil ];
  NSArray *expectedAddresses = [NSArray arrayWithObjects:
        @"johndown@test.com", // email alone
        @"johndown@test.com", // email between brackets
        @"johndown@test.com", // doubled
        @"johndown@test.com", // with and without br.
        @"johndown@test.com", // accented full name
        @"johndown@test.com", // accented
        // and multiword
        /* NOTE: the following are wrong but tolerated for now */
        @"johndown@test.com", // partly quoted
        @"johndown@test.com", // full name + email
        @"johndown@test.com", // full name with comma + email
        @"john", // name only, no domain
        nil ];
  NSString *rawAddress, *currentExp, *result, *error;
  NGMailAddressParser *parser;
  NGMailAddress *parsedRecipient;

  int count = 0;
  for (count = 0; count < [rawAddresses count]; count++)
    {
      rawAddress = [rawAddresses objectAtIndex:count];
      currentExp = [expectedAddresses objectAtIndex:count];
      parser = [NGMailAddressParser mailAddressParserWithString: rawAddress];
      parsedRecipient = [parser parse];
      result = [parsedRecipient address];
      error = [NSString
                stringWithFormat: @"[%d] received '%@' instead of '%@' for '%@'",
                count, result, currentExp, rawAddress];
      testWithMessage([result isEqualToString: currentExp], error);
    }
}

- (void) test_multipleEmailParsing_value_
{
  NSArray *rawAddresses = [NSArray arrayWithObjects:
        @"johndown@test.com",    // email alone
        @"test1a@test.com, test1b@here.now",
        @"\"johndown@inverse.ca\" <johndown@test.com>", // with and without br.
        @"John One <test2a@test.com>, John Two <test2b@here.now>", // TWO full names + email
        @"Three, John <test3a@test.com>, Four, John <test3b@here.now>", // TWO full names with comma + email
        @"john, down", // Two partial names
        @"Three A <threea@test.com>, Three B <threeb@test.com>, Three C <threec@test.com>", // Three mails
        nil ];
  NSArray *expectedAddresses = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects: @"johndown@test.com", nil],    // email alone
        [NSArray arrayWithObjects: @"test1a@test.com", @"test1b@here.now", nil],   // test1 a/b
        [NSArray arrayWithObjects: @"johndown@test.com", nil], // with and without br.
        [NSArray arrayWithObjects: @"test2a@test.com",  @"test2b@here.now", nil],  // test2 a/b 
        [NSArray arrayWithObjects: @"test3a@test.com",  @"test3b@here.now", nil],  // test3 a/b 
        [NSArray arrayWithObjects: @"john",  @"down", nil],  
        [NSArray arrayWithObjects: @"threea@test.com",  @"threeb@test.com", @"threec@test.com", nil],  // test a/b/c 
        nil ];
  NSString *currentRaw, *currentExp, *result, *error;
  NGMailAddressParser *parser = nil;
  NSArray *parsedRecipients = nil;
  NSArray *expectedRecipients = nil;
  NGMailAddress *parsedRecipient = nil;

  int count = 0;
  for (count = 0; count < [rawAddresses count]; count++)
    {
      currentRaw = [rawAddresses objectAtIndex: count];
      expectedRecipients = [expectedAddresses objectAtIndex: count];
      parser = [NGMailAddressParser mailAddressParserWithString: currentRaw];
      parsedRecipients = [parser parseAddressList];
      int innercount;
      for (innercount = 0; innercount < [parsedRecipients count]; innercount++)
        {
          parsedRecipient = [parsedRecipients objectAtIndex:innercount];
          result = [parsedRecipient address];
          currentExp = [expectedRecipients objectAtIndex:innercount];
          error = [NSString
                stringWithFormat: @"received '%@' instead of '%@' for '%@'",
                result, currentExp, currentRaw];
          testWithMessage([result isEqualToString: currentExp], error);
        }

    }
}
@end

