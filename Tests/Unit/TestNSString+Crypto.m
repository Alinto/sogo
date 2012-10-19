/* TestNSString+MD5SHA1.m - this file is part of SOGo
 *
 * Copyright (C) 2011, 2012 Jeroen Dekkers
 *
 * Author: Jeroen Dekkers <jeroen@dekkers.ch>
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

#import <Foundation/NSString.h>
#import "SOGo/NSString+Crypto.h"

#import "SOGoTest.h"

@interface TestNSData_plus_Crypto : SOGoTest
@end

@implementation TestNSData_plus_Crypto

- (void) test_dataCrypto
{
  const char *inStrings[] = { "SOGoSOGoSOGoSOGo", "éléphant", "2š", NULL };
  const char **inString;
  NSString *MD5Strings[] = { @"d3e8072c49511f099d254cc740c7e12a", @"bc6a1535589d6c3cf7999ac37018c11e", @"886ae9b58817fb8a63902feefcd18812" };
  NSString *SHA1Strings[] = { @"b7d891e0f3b42898fa66627b5cfa3d80501bae46", @"99a02f8802f8ea7e3ad91c4cc4d3ef5a7257c88f", @"32b89f3a9e6078db554cdd39f8571c09de7e8b21" };
  NSString **MD5String;
  NSString **SHA1String;
  NSString *result, *error;

  inString = inStrings;
  MD5String = MD5Strings;
  SHA1String = SHA1Strings;
  while (*inString)
    {
      result = [[NSString stringWithUTF8String: *inString] asMD5String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong MD5: '%@' (expected '%@')",
                        *inString, result, *MD5String];
      testWithMessage([result isEqualToString: *MD5String], error);
      result = [[NSString stringWithUTF8String: *inString] asSHA1String];
      error = [NSString stringWithFormat:
                          @"string '%s' wrong SHA1: '%@' (expected '%@')",
                        *inString, result, *SHA1String];
      testWithMessage([result isEqualToString: *SHA1String], error);
      inString++;
      MD5String++;
      SHA1String++;
    }
}

@end
