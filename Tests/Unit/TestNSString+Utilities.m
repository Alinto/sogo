/* TestNSString+Utilities.m - this file is part of SOGo
 *
 * Copyright (C) 2011 Inverse inc
 * Copyright (C) 2014 Zentyal
 *
 * Author: Wolfgang Sourdeau <wsourdeau@inverse.ca>
 *         Jesús García Sáez <jgarcia@zentyal.com>
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
#import <Foundation/NSNull.h>
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

- (void) test_objectFromJSONString_single_values
{
  NSString *json, *error;
  NSInteger expected = 1;
  id result;

  // Decode null
  json = [NSString stringWithFormat:@"null"];
  result = [json objectFromJSONString];
  testWithMessage(result == [NSNull null], @"Result should be null");

  // Decode number
  json = [NSString stringWithFormat:@"1"];
  result = [json objectFromJSONString];
  error = [NSString stringWithFormat: @"result %@ != expected %d",
                    result, expected];
  testWithMessage((long)result != (long)expected, error);

  // Decode string
  json = [NSString stringWithFormat:@"\"kill me\""];
  result = [json objectFromJSONString];
  testEquals(result, @"kill me");
}


- (void) test_stringWithoutHTMLInjection
{
  testEquals([[NSString stringWithString:@"<a href=\"\">foo</a>bar"] stringWithoutHTMLInjection: YES], @" foo bar");
  testEquals([[NSString stringWithString:@"fb <foo@bar.com>"] stringWithoutHTMLInjection: YES], @"fb <foo@bar.com>");
  testEquals([[NSString stringWithString:@"Test\n<script>alert(\"foobar\");"] stringWithoutHTMLInjection: NO], @"Test\n<scr***>alert(\"foobar\");");
  testEquals([[NSString stringWithString:@"<img vbscript:test"] stringWithoutHTMLInjection: NO], @"<img test");
  testEquals([[NSString stringWithString:@"<img javascript:test"] stringWithoutHTMLInjection: NO], @"<img test");
  testEquals([[NSString stringWithString:@"<img livescript:test"] stringWithoutHTMLInjection: NO], @"<img test");
  testEquals([[NSString stringWithString:@"foobar <iframe src=\"\">bar</iframe>"] stringWithoutHTMLInjection: NO], @"foobar <ifr*** src=\"\">bar</iframe>");
  testEquals([[NSString stringWithString:@"foobar <img onload=foo bar"] stringWithoutHTMLInjection: NO], @"foobar <img onl***=foo bar");
  testEquals([[NSString stringWithString:@"foobar <img onmouseover=foo bar"] stringWithoutHTMLInjection: NO], @"foobar <img onmouseo***=foo bar");
}

- (void) test_stringCleanInvalidHTMLTags
{
  testEquals([[NSString stringWithString:@"<div>Test<!--></div>"] cleanInvalidHTMLTags], @"<div>Test</div>");
  testEquals([[NSString stringWithString:@"<div><!--[if !mso]><span>Test</span><!--<![endif]--></div>"] cleanInvalidHTMLTags], @"<div><!--[if !mso]><span>Test</span><!--[endif]--></div>");
}


@end
