/* TestNGMimeAddressHeaderFieldGenerator.m - this file is part of SOGo
 *
 * Copyright (C) 2010 Inverse inc.
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

#import <NGMime/NGMimeHeaderFieldGenerator.h>

#import "SOGoTest.h"

@interface TestNGMimeAddressHeaderFieldGenerator : SOGoTest
@end

@implementation TestNGMimeAddressHeaderFieldGenerator

/* important: this file must be encoded in iso-8859-1, due to issues with the
   objc compiler */
- (void) test_generateDataForHeaderFieldNamed_value_
{
  /* TODO: The 2 last ones fail but are actually minor issues in NGMimeBlabla. */
  NSString *rawAddresses[]
    = { @"wolfgang@test.com",    // email alone
        @"<wolfgang@test.com>",  // email between brackets
        //@"\"<wolfgang@test.com>\" <wolfgang@test.com>", // doubled
        //@"\"wolfgang@inverse.ca\" <wolfgang@test.com>", // with and without br.
        //@"��in�oblabla <wolfgang@test.com>", // accented full name
        //@"��in�oblabla Bla Bl� <wolfgang@test.com>", // accented and multiword
        //@"Wolfgang Sourdeau \"Bla Bla\" <wolfgang@test.com>", // partly quoted
        //@"Wolfgang Sourdeau <wolfgang@test.com>", // full name + email
        nil };
  NSString *expectedAddresses[]
    = { @"wolfgang@test.com",    // email alone
        @"wolfgang@test.com",    // email between brackets
        //@"\"<wolfgang@test.com>\" <wolfgang@test.com>", // doubled
        //@"\"wolfgang@inverse.ca\" <wolfgang@test.com>", // with and without br.
        //@"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla?= <wolfgang@test.com>", // accented full name
        //@"=?utf-8?q?=C3=80=C3=B1in=C3=A9oblabla_Bla_Bl=C3=A9?= <wolfgang@test.com>", // accented
        // and multiword

        /* NOTE: the following are wrong but tolerated for now */
        //@"Wolfgang Sourdeau \"Bla Bla\" <wolfgang@test.com>", // partly quoted
        //@"Wolfgang Sourdeau <wolfgang@test.com>", // full name + email
        nil };
  NSString **currentRaw, **currentExp, *result, *error;
  NGMimeAddressHeaderFieldGenerator *generator;

  generator = [NGMimeAddressHeaderFieldGenerator headerFieldGenerator];

  currentRaw = rawAddresses;
  currentExp = expectedAddresses;
  while (*currentRaw)
    {
      result
        = [[NSString alloc]
            initWithData:
              [generator generateDataForHeaderFieldNamed: @"from"
                                                   value: *currentRaw]
                encoding: NSASCIIStringEncoding];

      error = [NSString
                stringWithFormat: @"received '%@' instead of '%@' for '%@'",
                result, *currentExp, *currentRaw];
      testWithMessage([result isEqualToString: *currentExp], error);

      [result release];
      currentRaw++;
      currentExp++;
    }
}

@end

