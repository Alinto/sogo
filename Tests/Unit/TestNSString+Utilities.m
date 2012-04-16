/* TestNSString+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
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

/* This file is encoded in utf-8. */

#import <SOGo/NSString+Utilities.h>

#import "SOGoTest.h"

@interface TestNSString_plus_Utilities : SOGoTest
@end

@implementation TestNSString_plus_Utilities

- (void) test_countOccurrencesOfString
{
  NSUInteger count;

  count = [@"abcdefa" countOccurrencesOfString: @"a"];
  failIf(count != 2);
  count = [@"abcdefa" countOccurrencesOfString: @"b"];
  failIf(count != 1);
  count = [@"" countOccurrencesOfString: @""];
  failIf(count != 0);
  count = [@"" countOccurrencesOfString: @"b"];
  failIf(count != 0);
  count = [@"roge" countOccurrencesOfString: @"roger"];
  failIf(count != 0);
}

- (void) test_encryptdecrypt
{
  NSString *secret = @"this is a secret";
  NSString *password = @"qwerty";
  NSString *encresult, *decresult;
  
  encresult = [secret encryptWithKey: nil];
  failIf(encresult != nil);
  encresult = [secret encryptWithKey: @""];
  failIf(encresult != nil);

  encresult = [secret encryptWithKey: password];
  failIf(encresult == nil);

  decresult = [encresult decryptWithKey: nil];
  failIf(decresult != nil);
  decresult = [encresult decryptWithKey: @""];
  failIf(decresult != nil);

  decresult = [encresult decryptWithKey: password];
  failIf(![decresult isEqualToString: secret]);
}

@end
