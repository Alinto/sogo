/* TestNGMailAddressParser.m - this file is part of SOGo
 *
 * Copyright (C) 2015 Inverse inc.
 *
 * Author: Luc Charland <lcharland@inverse.ca>
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
        @"wolfgang@test.com",    // email alone
        @"<wolfgang@test.com>",  // email between brackets
        @"\"<wolfgang@test.com>\" <wolfgang@test.com>", // doubled
//        @"\"wolfgang@inverse.ca\" <wolfgang@test.com>", // with and without br.
        @"Àñinéoblabla <wolfgang@test.com>", // accented full name
        @"Àñinéoblabla Bla Blé <wolfgang@test.com>", // accented and multiword
        @"Wolfgang Sourdeau \"Bla Bla\" <wolfgang@test.com>", // partly quoted
        @"Wolfgang Sourdeau <wolfgang@test.com>", // full name + email
        @"Wolfgang, Sourdeau <wolfgang@test.com>", // full name with comma + email
        @"wolf", // name only, no domain
        nil ];
  NSArray *expectedAddresses = [NSArray arrayWithObjects:
        @"wolfgang@test.com",    // email alone
        @"wolfgang@test.com",    // email between brackets
        @"wolfgang@test.com", // doubled
//        @"\"wolfgang@inverse.ca\" <wolfgang@test.com>", // with and without br.
        @"wolfgang@test.com", // accented full name
        @"wolfgang@test.com", // accented
        // and multiword

        /* NOTE: the following are wrong but tolerated for now */
        @"wolfgang@test.com", // partly quoted
        @"wolfgang@test.com", // full name + email
        @"wolfgang@test.com", // full name with comma + email
        @"wolf", // name only, no domain
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
      //NSLog(@"COUNT: %d", count);
      //NSLog(@"\trawAddress: %@", rawAddress);
      //NSLog(@"\tparsedRecipient: %@", parsedRecipient);
      result = [parsedRecipient address];
      //NSLog(@"\tresult:     %@", result);
      //NSLog(@"\tcurrentExp: %@", currentExp);
      error = [NSString
                stringWithFormat: @"received '%@' instead of '%@' for '%@'",
                result, currentExp, rawAddress];
      testWithMessage([result isEqualToString: currentExp], error);
    }
}

- (void) test_multipleEmailParsing_value_
{
  NSArray *rawAddresses = [NSArray arrayWithObjects:
        @"wolfgang@test.com",    // email alone
        @"test1a@test.com, test1b@here.now",
        @"\"wolfgang@inverse.ca\" <wolfgang@test.com>", // with and without br.
        @"Wolf One <test2a@test.com>, Wolf Two <test2b@here.now>", // TWO full names + email
        @"Three, Wolf <test3a@test.com>, Four, Wolf <test3b@here.now>", // TWO full names with comma + email
        @"luc, francis", // Two partial names
        @"Three A <threea@test.com>, Three B <threeb@test.com>, Three C <threec@test.com>", // Three mails
        nil ];
  NSArray *expectedAddresses = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects: @"wolfgang@test.com", nil],    // email alone
        [NSArray arrayWithObjects: @"test1a@test.com", @"test1b@here.now", nil],   // test1 a/b
        [NSArray arrayWithObjects: @"wolfgang@test.com", nil], // with and without br.
        [NSArray arrayWithObjects: @"test2a@test.com",  @"test2b@here.now", nil],  // test2 a/b 
        [NSArray arrayWithObjects: @"test3a@test.com",  @"test3b@here.now", nil],  // test3 a/b 
        [NSArray arrayWithObjects: @"luc",  @"francis", nil],  
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
      //NSLog(@"COUNT: %d", count);
      //NSLog(@"\tcurrentRaw: %@", currentRaw);
      //NSLog(@"\texpectedRecipients: %@", expectedRecipients);
      parser = [NGMailAddressParser mailAddressParserWithString: currentRaw];
      parsedRecipients = [parser parseAddressList];
      //NSLog(@"\tparsedRecipients: %@ (count %d)", parsedRecipients, [parsedRecipients count]);
      int innercount;
      for (innercount = 0; innercount < [parsedRecipients count]; innercount++)
        {
          //NSLog(@"\t\tcount: %d innercount:%d", count, innercount);
          parsedRecipient = [parsedRecipients objectAtIndex:innercount];
          //NSLog(@"\t\tparsedRecipient: %@", parsedRecipient);
          result = [parsedRecipient address];
          //NSLog(@"\t\tresult:     %@", result);
          currentExp = [expectedRecipients objectAtIndex:innercount];
          //NSLog(@"\t\tcurrentExp: %@", result, currentExp);
          error = [NSString
                stringWithFormat: @"received '%@' instead of '%@' for '%@'",
                result, currentExp, currentRaw];
          testWithMessage([result isEqualToString: currentExp], error);
        }

      currentRaw++;
      currentExp++;
    }
}
@end

